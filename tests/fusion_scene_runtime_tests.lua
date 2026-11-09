-- Synthetic Fusion host tests for production graph operations.
-- This tests our state and graph contracts. It does NOT render pixels
-- and is NOT evidence that DaVinci Resolve Studio 20 passed host QA.
local runtime = dofile("fusion/cartorig_scene_runtime.lua")
local checks = 0
local function expect(condition, reason)
    checks = checks + 1
    if not condition then error("ASSERTION: " .. reason, 2) end
end
local function expect_failure(action, code)
    local ok, reason = pcall(action)
    expect(not ok and tostring(reason):find(code, 1, true) ~= nil,
        "expected " .. code .. " error, saw " .. tostring(reason))
end

local function new_comp()
    local comp = { list = {}, state = {}, undo = {}, active = nil }
    local flow = {
        Select = function(_, tool, enabled)
            if tool then comp.active = enabled ~= false and tool or nil
            else comp.active = nil end
        end
    }
    comp.CurrentFrame = { FlowView = flow }

    function comp:GetData(key) return self.state[key] end
    function comp:SetData(key, value) self.state[key] = value end
    function comp:GetToolList() return self.list end
    function comp:SetActiveTool(tool) self.active = tool end
    function comp:StartUndo(label)
        expect(self.openUndo == nil, "Undo cannot be nested")
        self.openUndo = label
    end
    function comp:EndUndo(accepted)
        expect(self.openUndo ~= nil, "Undo must have started")
        self.undo[#self.undo + 1] = { label = self.openUndo, accepted = accepted }
        self.openUndo = nil
    end
    function comp:AddTool(kind, _, x, y)
        local t = { ID = kind, inputs = {}, links = {}, values = {}, data = {},
                    graphX = x, graphY = y, animations = {} }
        function t:SetData(key, val) self.data[key] = val end
        function t:GetData(key) return self.data[key] end
        function t:SetAttrs(attrs)
            for k, v in pairs(attrs) do self.values[k] = v end
        end
        function t:SetInput(input, val, time)
            if time ~= nil then
                self.animations[input] = self.animations[input] or {}
                self.animations[input][time] = val
            else
                self.inputs[input] = val
            end
            return true
        end
        function t:ConnectInput(name, upstream)
            self.links[name] = upstream
            return true
        end
        function t:AddModifier(input, kind)
            if kind ~= "BezierSpline" then return false end
            self.modifiers = self.modifiers or {}
            self.modifiers[input] = kind
            return true
        end
        local function port(name)
            return {
                GetConnectedOutput = function()
                    if (t.modifiers or {})[name] then
                        return { GetTool = function() return { ID = "BezierSpline" } end }
                    end
                    return t.links[name]
                end
            }
        end
        t.Input = port("Input")
        t.Blend = port("Blend")
        self.list[#self.list + 1] = t
        return t
    end
    return comp
end

local function find(comp, identity, role)
    for _, tool in ipairs(comp:GetToolList()) do
        local tag = tool:GetData("CartoRigAtomic.IdentityV2")
        if type(tag) == "table" and tag.objectId == identity and tag.role == role then
            return tool
        end
    end
end

local comp = new_comp()
local output = comp:AddTool("MediaOut", false, 4, 0)
expect(runtime.inspect(comp).state == "NO_SCENE", "no auto scene on import")
expect(#comp.list == 1, "import did not create Fusion nodes")
expect_failure(function() runtime.add_marker(comp, "Uninitialized", 0, 0) end,
               "NO_SCENE")

local result = runtime.create(comp)
expect(result.state == "SCENE_READY", "Scene creation persists")
expect(#result.objects == 0, "Scene initialization creates no author objects")
expect(#comp.list == 3, "one Background and shared Transform added")
expect(#comp.undo == 1 and comp.undo[1].accepted, "scene grouped into Undo")
expect(output.links.Input and output.links.Input.ID == "Transform",
       "MediaOut gets owned camera without changing other nodes")
local scene = comp:GetData("CartoRigAtomic.SceneV2")
local base = find(comp, scene.sceneId, "base")
local camera = find(comp, scene.cameraId, "camera")
expect(base ~= nil and camera ~= nil, "Base Map and Camera persist identities")
expect(camera.links.Input == base, "camera begins with base background only")
for _, tool in ipairs(comp.list) do
    expect(next(tool.animations) == nil, "Scene creation never writes keyframes")
end
expect_failure(function() runtime.create(comp) end, "ALREADY_EXISTS")

local marker1 = runtime.add_marker(comp, "São Paulo", -46.6333, -23.5505)
local control1 = find(comp, marker1, "control")
local merge1 = find(comp, marker1, "merge")
local mask1 = find(comp, marker1, "mask")
expect(control1 ~= nil and mask1 ~= nil and merge1 ~= nil,
       "Marker has real Fusion Background, EllipseMask and Merge")
expect(control1.links.EffectMask == mask1, "Marker is actually masked")
expect(mask1.inputs.Center[1] > 0 and mask1.inputs.Center[2] > 0,
       "geographic coordinate projected to Fusion normalized space")
expect(merge1.links.Background == base, "first object composited over base")
expect(camera.links.Input == merge1, "camera receives first object")
expect(next(merge1.animations) == nil, "No automatic motion when adding marker")

local marker2 = runtime.add_marker(comp, "Brasília", -47.8825, -15.7942)
local merge2 = find(comp, marker2, "merge")
expect(merge2.links.Background == merge1, "second object added in authored draw order")
expect(camera.links.Input == merge2, "camera receives latest scene stack")
expect(marker1 ~= marker2, "independent stable object IDs")

local label = runtime.add_label(comp, "São Paulo", -46.6333, -23.5505)
local labelControl = find(comp, label, "control")
expect(labelControl.ID == "TextPlus", "Label uses native Fusion TextPlus")
expect(labelControl.inputs.StyledText == "São Paulo", "Unicode label preserved")
expect(#runtime.inspect(comp).objects == 3, "Scene tree reconstructs from comp state")

-- Tool names must never be the canonical object identity.
control1:SetAttrs({ TOOLS_Name = "Renamed by user" })
expect(runtime.select(comp, marker1) == control1,
       "select object by stable metadata after manual tool rename")
expect(comp.active == control1, "native Fusion tool becomes Inspector selection")

-- Same camera applied to every geoanchored layer, all keys in native host.
runtime.focus(comp, -46.6333, -23.5505, 2)
expect(camera.inputs.Size == 2, "native Transform Size carries zoom")
expect(camera.inputs.Center[1] > 0.5, "camera recenters on east/west coordinate")
expect(camera.links.Input == find(comp, label, "merge"), "focus preserves stack links")

runtime.fade_in(comp, marker1, 100, 24)
expect(merge1.modifiers.Blend == "BezierSpline", "actual native Spline modifier")
expect(merge1.animations.Blend[100] == 0 and
       merge1.animations.Blend[124] == 1, "host keys at exact integer frames")
expect(next(merge2.animations) == nil, "other Marker animation not touched")
expect_failure(function() runtime.fade_in(comp, marker1, 100, 24) end,
               "MOTION_CONFLICT")
runtime.fade_in(comp, marker2, 110, 12)
expect(merge2.animations.Blend[110] == 0 and
       merge2.animations.Blend[122] == 1, "second marker has independent Spline")
expect(next(labelControl.animations) == nil, "Label not animated by marker")

local before = #comp.list
expect_failure(function() runtime.add_marker(comp, "Invalid", 400, 0) end,
               "INVALID_COORDINATES")
expect_failure(function() runtime.add_label(comp, "", 0, 0) end, "INVALID_NAME")
expect(#comp.list == before, "invalid authoring creates no nodes")

-- Closing Scene UI does not destroy persistent Fusion nodes or curves.
local reopened = runtime.inspect(comp)
expect(reopened.sceneId == scene.sceneId and #reopened.objects == 3,
       "scene recovers with UI closed and reopened")
expect(merge1.animations.Blend[124] == 1, "keyframes persist independent of Scene UI")

local another = new_comp()
another:AddTool("MediaOut")
runtime.create(another)
expect(#runtime.inspect(another).objects == 0,
       "different compositions have independent scenes")
expect(runtime.inspect(comp).sceneId ~= runtime.inspect(another).sceneId,
       "scene IDs are distinct across compositions")

local busy = new_comp()
local existingOutput = busy:AddTool("MediaOut")
local foreign = busy:AddTool("MediaIn")
existingOutput:ConnectInput("Input", foreign)
expect_failure(function() runtime.create(busy) end, "OUTPUT_BUSY")
expect(#busy.list == 2 and existingOutput.links.Input == foreign,
       "never hijack or delete unrelated Fusion nodes")

print("PASS: " .. checks .. " original Fusion graph / Control / Motion assertions")
