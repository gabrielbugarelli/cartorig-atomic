-- Synthetic Fusion host tests for production graph operations.
-- This tests our state and graph contracts. It does NOT render pixels
-- and is NOT evidence that DaVinci Resolve Studio 20 passed host QA.
local runtime = dofile("fusion/cartorig_scene_runtime.lua")
_G.Polyline=function(data) return data end
_G.FuID=function(data) return data[1] end
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
        function t:Delete()
            for i, candidate in ipairs(comp.list) do
                if candidate == self then
                    table.remove(comp.list, i)
                    return true
                end
            end
            return false
        end
        function t:GetAttrs() return self.values end
        t.Comp = comp
        function t:Refresh() self.refreshed = true return true end
        function t:GetInput(key)
            if self.inputs[key] ~= nil then return self.inputs[key] end
            if key=="Blend" then return 1.0 end
            if key=="Size" then return 1.0 end
            return nil
        end
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
        t.Size = port("Size")
        t.Center = port("Center")
        t.Background = port("Background")
        t.Foreground = port("Foreground")
        t.EffectMask = port("EffectMask")
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
expect(result.state == "SCENE_EMPTY", "Scene creation persists with no author objects")
expect(#result.objects == 0, "Scene initialization creates no author objects")
expect(#comp.list == 3, "one Background and shared Transform added")
expect(#comp.undo == 1 and comp.undo[1].accepted, "scene grouped into Undo")
expect(output.links.Input and output.links.Input.ID == "Transform",
       "MediaOut gets owned camera without changing other nodes")
local scene = comp:GetData("CartoRigAtomic.SceneV2")
local base = find(comp, scene.sceneId, "base")
local camera = find(comp, scene.cameraId, "camera")
expect(base ~= nil and camera ~= nil, "Base Map and Camera persist identities")
expect(camera.UserControls.CR2MotionApply.ICS_ControlPage=="Motion",
       "Camera has native Inspector Motion page")
expect(camera.UserControls.CR2MotionApply.BTNCS_Execute:find("MO-CAM-02",1,true),
       "Camera Zoom To can apply from its own Inspector even with Scene closed")
expect(camera.links.Input == base, "camera begins with base background only")
for _, tool in ipairs(comp.list) do
    expect(next(tool.animations) == nil, "Scene creation never writes keyframes")
end
expect_failure(function() runtime.create(comp) end, "ALREADY_EXISTS")

local marker1 = runtime.add_marker(comp, "São Paulo", -46.6333, -23.5505,
    {id="ne10m:city:12345", kind="City", name="São Paulo",
     country="Brazil", parent="São Paulo",
     point={lon=-46.6333,lat=-23.5505}})
local control1 = find(comp, marker1, "control")
local merge1 = find(comp, marker1, "merge")
local mask1 = find(comp, marker1, "mask")
expect(control1 ~= nil and mask1 ~= nil and merge1 ~= nil,
       "Marker has real Fusion Background, EllipseMask and Merge")
expect(control1.UserControls.CR2MotionApply.ICS_ControlPage=="Motion",
       "Marker exposes native Inspector Motion without using Scene controls")
expect(control1.UserControls.CR2MotionApply.BTNCS_Execute:find("MO-MRK-01",1,true),
       "Marker Fade In callback carries a native Fusion Spline preset")
expect(runtime.inspect(comp).objects[1].sourceRef.featureId=="ne10m:city:12345",
       "Natural Earth identity survives authored Marker creation")
expect(runtime.inspect(comp).objects[1].sourceRef.provider=="Natural Earth",
       "SourceRef carries explicit geographic provenance")
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
expect(labelControl.UserControls.CR2MotionApply.ICS_ControlPage=="Motion",
       "Label has native Motion page on its selected TextPlus tool")
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
expect_failure(function()
    runtime.add_marker(comp, "Wrong source", -46.6, -23.5,
        {id="ne10m:city:12345", kind="City", name="São Paulo",
         point={lon=-46.6333,lat=-23.5505}})
end, "SOURCE_MISMATCH")
expect_failure(function() runtime.add_label(comp, "", 0, 0) end, "INVALID_NAME")
expect(#comp.list == before, "invalid authoring creates no nodes")

-- Closing Scene UI does not destroy persistent Fusion nodes or curves.
local reopened = runtime.inspect(comp)
expect(reopened.sceneId == scene.sceneId and #reopened.objects == 3,
       "scene recovers with UI closed and reopened")
expect(merge1.animations.Blend[124] == 1, "keyframes persist independent of Scene UI")


-- Complete scene CRUD must change only the authored object and preserve
-- unrelated nodes, stable object IDs and independent Fusion Spline curves.
local originalMarker = marker1
expect(runtime.rename(comp, marker1, "São Paulo custom label") == marker1,
       "rename does not change object ID")
expect(runtime.inspect(comp).objects[1].name == "São Paulo custom label",
       "rename is in persisted Fusion metadata")
expect(runtime.select(comp, marker1) == control1,
       "tool rename and display rename do not break object references")

runtime.set_visibility(comp, marker1, false)
expect(merge1.values.TOOLB_PassThrough == true,
       "Hide bypasses only its owned Merge")
expect(merge1.animations.Blend[124] == 1,
       "Hide never destroys native animation")
expect(runtime.inspect(comp).objects[1].visible == false,
       "Visibility stored separately from opacity and keys")
runtime.set_visibility(comp, marker1, true)
expect(merge1.values.TOOLB_PassThrough == false,
       "Show restores the authored object")
expect(runtime.inspect(comp).objects[1].visible == true,
       "Show state persists")

runtime.set_lock(comp, marker1, true)
expect(runtime.inspect(comp).objects[1].locked == true,
       "Lock state is persisted")
expect_failure(function() runtime.rename(comp, marker1, "Not allowed") end, "LOCKED")
expect_failure(function() runtime.remove(comp, marker1) end, "LOCKED")
expect_failure(function() runtime.move(comp, marker1, 1) end, "LOCKED")
runtime.set_lock(comp, marker1, false)
expect(runtime.inspect(comp).objects[1].locked == false, "Unlock is explicit")

local groupId = runtime.create_group(comp, "Capital labels", { marker1, label })
expect(type(groupId) == "string", "organizational Group has stable identity")
expect(#runtime.inspect(comp).groups == 1, "Group appears in scene state")
expect(runtime.inspect(comp).objects[1].groupId == groupId,
       "group membership persists independently from node properties")
runtime.ungroup(comp, groupId)
expect(#runtime.inspect(comp).groups == 0, "Ungroup deletes only organization")
expect(runtime.inspect(comp).objects[1].groupId == nil,
       "Ungroup preserves geographic object")

runtime.move(comp, marker1, 1)
expect(comp:GetData("CartoRigAtomic.SceneV2").objects[2].id == marker1,
       "Move down changes global scene order")
expect(merge1.links.Background == merge2,
       "Move down rewires image draw order, preserving object IDs")
expect(merge2.links.Background == base,
       "Moved earlier object connects to original Base Map")
expect(camera.links.Input == find(comp, label, "merge"),
       "Camera remains connected to top of scene stack")
expect_failure(function() runtime.move(comp, label, 1) end, "ORDER_BOUNDARY")

local priorCount = #comp:GetToolList()
runtime.remove(comp, marker2)
expect(#runtime.inspect(comp).objects == 2,
       "deletion removes only selected cartographic object")
expect(#comp:GetToolList() == priorCount - 3,
       "deletion removes marker control, mask and Merge")
expect(find(comp, marker2, "control") == nil,
       "deleted object no longer has managed Fusion Control")
expect(#comp.undo > 7, "each operation is a native host Undo transaction")
expect(comp:GetData("CartoRigAtomic.SceneV2").objects[1].id == marker1,
       "remaining objects keep authored order")
expect(camera.links.Input == find(comp, label, "merge"),
       "deleting middle object does not disconnect MediaOut")
expect(runtime.inspect(comp).sceneId == scene.sceneId,
       "scene survives CRUD without changing identity")


-- Execute the literal Inspector button callbacks under the synthetic Fusion
-- host. Buttons write native Spline keys without Scene UIManager or a process.
comp.CurrentTime = 150
function comp:GetAttrs() return { COMPN_RenderEnd = 400 } end
local compile=loadstring or load
local labelMerge=find(comp, label, "merge")
labelControl.inputs.CR2MotionDuration=18
local oldTool,oldComp=_G.tool,_G.comp
_G.tool,_G.comp=labelControl,comp
local compiled,problem=compile(labelControl.UserControls.CR2MotionApply.BTNCS_Execute)
expect(type(compiled)=="function", "Inspector callback is executable standalone Lua")
compiled()
expect(labelMerge.animations.Blend[150]==0 and
       labelMerge.animations.Blend[168]==1,
       "Inspector Label button creates real Fusion Spline keys from playhead")
expect(labelControl:GetData("CartoRigAtomic.MotionBindingV2").presetId=="MO-LBL-01",
       "Motion provenance stored on Label tool, independent of Scene window")
camera.inputs.CR2MotionDuration=30
camera.inputs.CR2TargetZoom=6
_G.tool=camera
local camButton=assert(compile(camera.UserControls.CR2MotionApply.BTNCS_Execute))
camButton()
expect(camera.animations.Size[150]==2 and
       camera.animations.Size[180]==6,
       "Inspector Camera Zoom To creates native Size Spline without touching Center")
expect(camera:GetData("CartoRigAtomic.MotionBindingV2").presetId=="MO-CAM-02",
       "Camera Motion binding persists on camera Fusion tool")
_G.tool,_G.comp=oldTool,oldComp

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


-- Region and Route are actual native Fusion image-producing layer graphs,
-- never static lookup points pretending to be a polygon.
local state = {
    id="ne10m:state:ap-actual",kind="State",name="Amapá",
    parent="Brazil",country="Brazil"
}
local statePolygon={
    id=state.id,ringCount=3,
    rings={
        {kind="O",vertices={
            {lon=-52,lat=-1},{lon=-50,lat=-1},
            {lon=-50,lat=2},{lon=-52,lat=2}}},
        {kind="H",vertices={
            {lon=-51,lat=.3},{lon=-50.7,lat=.3},
            {lon=-50.7,lat=.7},{lon=-51,lat=.7}}},
        {kind="O",vertices={
            {lon=-54,lat=0},{lon=-53.5,lat=0},
            {lon=-53.5,lat=1},{lon=-54,lat=1}}},
    }
}
expect(runtime.contains_point(statePolygon,-51.05,.1)==true,
    "Macapá point is inside the explicit state polygon")
expect(runtime.contains_point(statePolygon,-50.8,.5)==false,
    "admin1 polygon hole must exclude point")
expect(runtime.contains_point(statePolygon,-53.75,.5)==true,
    "multipolygon island fragment is independently included")
expect(runtime.contains_point(statePolygon,-49,.1)==false,
    "points outside polygon are rejected")

local regionId = runtime.add_region(comp,state,statePolygon)
local regionControl=find(comp,regionId,"control")
local regionRender=find(comp,regionId,"render")
local regionMerge=find(comp,regionId,"merge")
local regionFillMask=find(comp,regionId,"shape1")
local regionHoleMask=find(comp,regionId,"shape2")
local regionBorder=find(comp,regionId,"border")
expect(regionControl and regionRender and regionMerge and regionFillMask and
    regionHoleMask and regionBorder,
    "Region has fully managed native background, fill, hole, stroke and composite")
expect(regionControl.links.EffectMask==find(comp,regionId,"shape3"),
    "Region final fill mask carries all multipart rings")
expect(regionHoleMask.inputs.PaintMode=="Subtract",
    "inner ring subtracts rather than covering a real geographic lake/hole")
expect(regionMerge.links.Foreground==regionRender,
    "Region stroke composite is the authored visible layer")
expect(regionControl.inputs.TopLeftRed==130/255,
    "Region uses approved neutral grey-blue default rather than editorial highlight")
expect(runtime.inspect(comp).objects[#runtime.inspect(comp).objects].sourceRef.featureId==
    state.id,"Region keeps Natural Earth polygon provenance")
expect(#regionFillMask.inputs.Polyline.Points==4,
    "real polygon vertices become one vector mask, not thousands of Fusion nodes")
expect_failure(function()
    runtime.add_region(comp,{id="ne10m:city:1",kind="City",name="São Paulo"},
                       statePolygon)
end,"INVALID_REGION")
expect_failure(function()
    runtime.add_region(comp,{id="wrong",kind="State",name="Other"},
                       statePolygon)
end,"NO_GEOMETRY")

local origin={id="ne10m:city:bsb",name="Brasília",lon=-47.9,lat=-15.8}
local arrival={id="ne10m:city:macapa",name="Macapá",lon=-51.05,lat=.1}
expect_failure(function()
    runtime.add_route(comp,origin,nil,{destinationState=state,
                                       destinationGeometry=statePolygon})
end,"ENDPOINT_REQUIRED")
expect_failure(function()
    runtime.add_route(comp,origin,{name="Outside",lon=-41,lat=.1},
      {destinationState=state,destinationGeometry=statePolygon})
end,"ENDPOINT_OUTSIDE_STATE")
local routeId=runtime.add_route(comp,origin,arrival,
    {destinationState=state,destinationGeometry=statePolygon,pathType="Curved"})
local routeControl=find(comp,routeId,"control")
local routePath=find(comp,routeId,"shape"..tostring(#comp:GetData(
    "CartoRigAtomic.SceneV2").objects))
local routeObject=runtime.inspect(comp).objects[#runtime.inspect(comp).objects]
expect(routeObject.kind=="Route","route has a distinct author object identity")
local routeMeta=comp:GetData("CartoRigAtomic.SceneV2").objects[
    #comp:GetData("CartoRigAtomic.SceneV2").objects].route
expect(routeMeta.from.sourceId==origin.id and routeMeta.to.sourceId==arrival.id,
    "chosen city endpoints persist with independent source identity")
expect(routeMeta.destinationStateId==state.id and routeMeta.pathType=="Curved",
    "route carries destination-region ID and spatial path type")
expect(routeControl.inputs.TopLeftRed==214/255,
    "native editable line defaults to neutral cartographic stroke")
expect(find(comp,routeId,"merge").links.Foreground==routeControl,
    "Route is visible in Fusion image compositing stack")
local regionNodeCount=#comp.list
runtime.remove(comp,regionId)
expect(not find(comp,regionId,"control") and not find(comp,regionId,"render"),
    "Deleting Region removes only its fully-owned native rendering graph")
expect(#comp.list==regionNodeCount-10,
    "Deleting Region removes all fill/stroke polygons, backgrounds and merges")
expect(find(comp,routeId,"control")==routeControl,
    "Deleting an independent Region does not destroy Route Control")
expect(find(comp,routeId,"merge").links.Background==find(comp,label,"merge"),
    "Region removal reconnects the remaining independent draw stack")

local antimeridianId=runtime.add_route(comp,
    {id="origin-east",name="East",lon=179,lat=0},
    {id="destination-west",name="West",lon=-179,lat=0},
    {pathType="Straight",name="Dateline crossing"})
local dateline=comp:GetData("CartoRigAtomic.SceneV2").objects[
    #comp:GetData("CartoRigAtomic.SceneV2").objects]
expect(dateline.route.segments==2,
    "short antimeridian route must split at world map seam")
local maskA=find(comp,antimeridianId,
    "shape"..tostring((#comp:GetData("CartoRigAtomic.SceneV2").objects)*100+1))
local maskB=find(comp,antimeridianId,
    "shape"..tostring((#comp:GetData("CartoRigAtomic.SceneV2").objects)*100+2))
expect(maskA and maskB and maskB.links.EffectMask==maskA,
    "dateline route is two additive vector masks, never a globe-wide diagonal")
expect(math.abs(maskA.inputs.Polyline.Points[1].X-
                maskA.inputs.Polyline.Points[2].X)<.01,
    "east of dateline path does not cross central world geography")
expect(math.abs(maskB.inputs.Polyline.Points[1].X-
                maskB.inputs.Polyline.Points[2].X)<.01,
    "west of dateline path remains spatially local")


print("PASS: " .. checks .. " original Fusion graph / Control / Motion assertions")
