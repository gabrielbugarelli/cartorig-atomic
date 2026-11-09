-- CartoRig Atomic / Fusion-native scene engine.
-- CR-PS-2.0: brand-new implementation, no legacy CartoRig code/assets.
-- This module does not create UI, depends only on Fusion composition methods.
-- Scene operations are explicit and undo-scoped; no startup side effects.
local M = {}

local SCENE_KEY = "CartoRigAtomic.SceneV2"
local TOOL_KEY = "CartoRigAtomic.IdentityV2"
local VERSION = 2

local function fail(code, message)
    error(code .. ": " .. message, 2)
end

local function object_tool(comp, scene, identity, role)
    for _, tool in pairs(comp:GetToolList(false) or {}) do
        local ok, data = pcall(function() return tool:GetData(TOOL_KEY) end)
        if ok and type(data) == "table" and data.sceneId == scene.sceneId
            and data.objectId == identity and data.role == role then
            return tool
        end
    end
    return nil
end


local function graph_input(tool, inputName)
    local port = tool[inputName]
    if not port then return nil end
    local ok, upstream = pcall(function() return port:GetConnectedOutput() end)
    if not ok then
        fail("HOST_GRAPH", "Unable to inspect Fusion input " .. inputName)
    end
    if upstream and type(upstream.GetTool) == "function" then
        local got, owner = pcall(function() return upstream:GetTool() end)
        if got and owner then return owner end
    end
    return upstream
end

local function equal_tool(a, b)
    if a == b then return true end
    if not a or not b then return false end
    local aAttrs, bAttrs
    local okA = pcall(function() aAttrs = a:GetAttrs() end)
    local okB = pcall(function() bAttrs = b:GetAttrs() end)
    if okA and okB and type(aAttrs) == "table" and type(bAttrs) == "table" and
        aAttrs.TOOLS_RegID and bAttrs.TOOLS_RegID then
        return aAttrs.TOOLS_RegID == bAttrs.TOOLS_RegID and
            aAttrs.TOOLB_GUID ~= nil and aAttrs.TOOLB_GUID == bAttrs.TOOLB_GUID
    end
    return false
end

local function copy_table(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy_table(v) end
    return out
end

local function object_index(scene, id)
    for i, obj in ipairs(scene.objects) do
        if obj.id == id then return i, obj end
    end
    fail("OBJECT_MISSING", "The selected object no longer belongs to this Scene")
end

local function tagged(tool, sceneId, objectId, role)
    tool:SetData(TOOL_KEY, {
        schema = VERSION, sceneId = sceneId,
        objectId = objectId, role = role
    })
    return tool
end

local function add_tool(comp, kind, name, x, y, sceneId, objectId, role)
    -- Explicit graph coordinates prevent Fusion's automatic insertion from
    -- silently connecting or moving foreign nodes.
    local tool = comp:AddTool(kind, false, x, y)
    if not tool then fail("HOST_ADD_TOOL", "Fusion could not create " .. kind) end
    tool:SetAttrs({ TOOLS_Name = name })
    return tagged(tool, sceneId, objectId, role)
end

local function checked_link(tool, input, upstream)
    if not tool:ConnectInput(input, upstream) then
        fail("HOST_CONNECTION", "Cannot connect Fusion input " .. input)
    end
end

local function undo(comp, label, operation)
    -- Each user's action should be a single native Undo item.
    comp:StartUndo(label)
    local ok, result = xpcall(operation, debug.traceback)
    comp:EndUndo(ok)
    if not ok then error(result, 0) end
    return result
end

local function validate_position(lon, lat)
    lon, lat = tonumber(lon), tonumber(lat)
    if not lon or not lat or lon ~= lon or lat ~= lat or
        lon < -180 or lon > 180 or lat < -90 or lat > 90 then
        fail("INVALID_COORDINATES", "Longitude must be -180..180 and latitude -90..90")
    end
    return lon, lat
end

local function coords(lon, lat)
    -- Equirectangular world mapping; Fusion's Y origin is bottom.
    return { (lon + 180) / 360, (lat + 90) / 180 }
end

local function point(x, y)
    return { [1] = x, [2] = y }
end

local function safe_name(name)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if name == "" or #name > 96 then
        fail("INVALID_NAME", "Object name must be 1-96 UTF-8 bytes")
    end
    return name
end

local function get_scene(comp)
    local data = comp:GetData(SCENE_KEY)
    if data == nil then return nil end
    if type(data) ~= "table" or data.schema ~= VERSION or
        type(data.sceneId) ~= "string" or type(data.objects) ~= "table" then
        fail("SCENE_VERSION", "Unsupported CartoRig scene state; no changes made")
    end
    return copy_table(data)
end

local function require_scene(comp)
    local scene = get_scene(comp)
    if not scene then fail("NO_SCENE", "Create a CartoRig Scene in this Fusion composition") end
    return scene
end

local function next_id(scene)
    local result = scene.sceneId .. "-" .. tostring(scene.nextId)
    scene.nextId = scene.nextId + 1
    return result
end

local function validate_graph(comp, scene)
    local base = object_tool(comp, scene, scene.sceneId, "base")
    local camera = object_tool(comp, scene, scene.cameraId, "camera")
    local tail = (scene.tailId == scene.sceneId) and base
        or object_tool(comp, scene, scene.tailId, "merge")
    if not base or not camera or not tail then
        fail("SCENE_BROKEN", "Scene graph is incomplete. No modifications were made")
    end
    for _, obj in ipairs(scene.objects) do
        if not object_tool(comp, scene, obj.id, "control") or
            not object_tool(comp, scene, obj.id, "merge") then
            fail("SCENE_BROKEN", "Missing Fusion tool for " .. obj.name)
        end
    end
    local expected = tail
    if not equal_tool(graph_input(camera, "Input"), expected) then
        fail("SCENE_BROKEN", "Camera input was externally changed. No modifications made")
    end
    local previous = base
    for _, obj in ipairs(scene.objects) do
        local merge = object_tool(comp, scene, obj.id, "merge")
        if not equal_tool(graph_input(merge, "Background"), previous) then
            fail("SCENE_BROKEN", "Object draw stack was externally modified")
        end
        if not equal_tool(graph_input(merge, "Foreground"),
            object_tool(comp, scene, obj.id, "control")) then
            fail("SCENE_BROKEN", "Object foreground link was externally modified")
        end
        previous = merge
    end
    return base, camera, tail
end

local function find_output(comp)
    local output
    for _, tool in pairs(comp:GetToolList(false) or {}) do
        if tool.ID == "MediaOut" then
            if output then fail("MULTIPLE_OUTPUTS", "Choose a composition with one MediaOut") end
            output = tool
        end
    end
    if not output then
        return nil
    end
    local ok, connected = pcall(function()
        return output.Input:GetConnectedOutput()
    end)
    if not ok then
        fail("OUTPUT_UNVERIFIED", "Cannot verify existing MediaOut connection")
    end
    if connected ~= nil then
        fail("OUTPUT_BUSY", "MediaOut is already connected; no external nodes were changed")
    end
    return output
end

function M.inspect(comp)
    local scene = get_scene(comp)
    if not scene then return { state = "NO_SCENE", objects = {} } end
    validate_graph(comp, scene)
    local objects = {}
    for _, obj in ipairs(scene.objects) do
        objects[#objects + 1] = {
            id = obj.id, kind = obj.kind, name = obj.name,
            lon = obj.lon, lat = obj.lat, visible = obj.visible ~= false,
            locked = obj.locked == true, groupId = obj.groupId
        }
    end
    return { state = #objects == 0 and "SCENE_EMPTY" or "SCENE_READY",
        sceneId = scene.sceneId, objects = objects,
        groups = copy_table(scene.groups or {}) }
end

function M.create(comp)
    if get_scene(comp) then
        fail("ALREADY_EXISTS", "This composition already contains CartoRig Scene")
    end
    local output = find_output(comp)
    return undo(comp, "CartoRig: Create Scene", function()
        local sceneId = "cr2-" .. tostring(math.floor(os.time())) ..
            "-" .. tostring(math.random(100000, 999999))
        local scene = {
            schema = VERSION, sceneId = sceneId,
            cameraId = sceneId .. "-camera",
            tailId = sceneId, nextId = 1, objects = {}, groups = {},
            projection = "Equirectangular",
            displayMode = "Full Map"
        }
        local background = add_tool(comp, "Background", "CR2_Base_Map", -5, 0,
            sceneId, sceneId, "base")
        -- Neutral background ONLY: real terrestrial geometry is added by
        -- the geographic renderer. Never claim that flat color is a map.
        background:SetInput("TopLeftRed", 0.063)
        background:SetInput("TopLeftGreen", 0.157)
        background:SetInput("TopLeftBlue", 0.235)
        background:SetInput("TopLeftAlpha", 1.0)

        local camera = add_tool(comp, "Transform", "CR2_Camera", 5, 0,
            sceneId, scene.cameraId, "camera")
        camera:SetInput("Center", point(0.5, 0.5))
        camera:SetInput("Size", 1.0)
        checked_link(camera, "Input", background)

        if not output then
            output = add_tool(comp, "MediaOut", "CR2_MediaOut", 8, 0,
                sceneId, sceneId, "output")
        end
        checked_link(output, "Input", camera)
        comp:SetData(SCENE_KEY, scene)
        return M.inspect(comp)
    end)
end

local function add_object(comp, kind, name, lon, lat)
    name = safe_name(name)
    lon, lat = validate_position(lon, lat)
    local scene = require_scene(comp)
    local _, camera, tail = validate_graph(comp, scene)
    return undo(comp, "CartoRig: Add " .. kind, function()
        local id = next_id(scene)
        local n = #scene.objects + 1
        local source
        if kind == "Marker" then
            source = add_tool(comp, "Background", "CR2_Marker_" .. n,
                -4, n * 2, scene.sceneId, id, "control")
            source:SetInput("TopLeftRed", 0.86)
            source:SetInput("TopLeftGreen", 0.40)
            source:SetInput("TopLeftBlue", 0.16)
            source:SetInput("TopLeftAlpha", 1.0)
            local mask = add_tool(comp, "EllipseMask", "CR2_Mask_" .. n,
                -6, n * 2, scene.sceneId, id, "mask")
            local c = coords(lon, lat)
            mask:SetInput("Center", point(c[1], c[2]))
            mask:SetInput("Width", 0.015)
            mask:SetInput("Height", 0.015)
            checked_link(source, "EffectMask", mask)
        elseif kind == "Label" then
            source = add_tool(comp, "TextPlus", "CR2_Label_" .. n,
                -4, n * 2, scene.sceneId, id, "control")
            local c = coords(lon, lat)
            source:SetInput("StyledText", name)
            source:SetInput("Center", point(c[1], c[2]))
            source:SetInput("Size", 0.04)
        else
            fail("INVALID_OBJECT_TYPE", "Unsupported object type")
        end

        local merge = add_tool(comp, "Merge", "CR2_Merge_" .. n,
            2, n * 2, scene.sceneId, id, "merge")
        checked_link(merge, "Background", tail)
        checked_link(merge, "Foreground", source)
        checked_link(camera, "Input", merge)

        scene.tailId = id
        scene.objects[#scene.objects + 1] = {
            id = id, kind = kind, name = name, lon = lon, lat = lat,
            visible = true, locked = false
        }
        comp:SetData(SCENE_KEY, scene)
        return id
    end)
end

function M.add_marker(comp, name, lon, lat)
    return add_object(comp, "Marker", name, lon, lat)
end

function M.add_label(comp, name, lon, lat)
    return add_object(comp, "Label", name, lon, lat)
end

local function ensure_unlocked(object)
    if object.locked then
        fail("LOCKED", "Unlock " .. object.name .. " before changing it")
    end
end

local function rewire_stack(comp, scene)
    local base, camera = validate_graph(comp, scene)
    local previous = base
    for _, object in ipairs(scene.objects) do
        local layer = object_tool(comp, scene, object.id, "merge")
        checked_link(layer, "Background", previous)
        previous = layer
    end
    checked_link(camera, "Input", previous)
    scene.tailId = #scene.objects == 0 and scene.sceneId
        or scene.objects[#scene.objects].id
end

function M.rename(comp, objectId, newName)
    newName = safe_name(newName)
    local scene = require_scene(comp)
    validate_graph(comp, scene)
    local _, obj = object_index(scene, objectId)
    ensure_unlocked(obj)
    return undo(comp, "CartoRig: Rename Object", function()
        obj.name = newName
        comp:SetData(SCENE_KEY, scene)
        return objectId
    end)
end

function M.set_visibility(comp, objectId, visible)
    if type(visible) ~= "boolean" then
        fail("INVALID_VISIBILITY", "Visibility must be true or false")
    end
    local scene = require_scene(comp)
    validate_graph(comp, scene)
    local _, obj = object_index(scene, objectId)
    ensure_unlocked(obj)
    local merge = object_tool(comp, scene, objectId, "merge")
    return undo(comp, visible and "CartoRig: Show Object"
        or "CartoRig: Hide Object", function()
        -- Fusion pass-through suppresses this composite layer without
        -- destroying or modifying the Blend animation curve.
        if merge:SetAttrs({ TOOLB_PassThrough = not visible }) == false then
            fail("HOST_VISIBILITY", "Fusion refused pass-through update")
        end
        obj.visible = visible
        comp:SetData(SCENE_KEY, scene)
        return visible
    end)
end

function M.set_lock(comp, objectId, locked)
    if type(locked) ~= "boolean" then
        fail("INVALID_LOCK", "Lock must be true or false")
    end
    local scene = require_scene(comp)
    validate_graph(comp, scene)
    local _, obj = object_index(scene, objectId)
    return undo(comp, locked and "CartoRig: Lock Object"
        or "CartoRig: Unlock Object", function()
        obj.locked = locked
        comp:SetData(SCENE_KEY, scene)
        return locked
    end)
end

function M.move(comp, objectId, direction)
    direction = tonumber(direction)
    if direction ~= -1 and direction ~= 1 then
        fail("INVALID_DIRECTION", "Choose Move Up or Move Down")
    end
    local scene = require_scene(comp)
    validate_graph(comp, scene)
    local index, obj = object_index(scene, objectId)
    ensure_unlocked(obj)
    local target = index + direction
    if target < 1 or target > #scene.objects then
        fail("ORDER_BOUNDARY", "Object is already at that end of the draw stack")
    end
    ensure_unlocked(scene.objects[target])
    return undo(comp, "CartoRig: Reorder Object", function()
        scene.objects[index], scene.objects[target] =
            scene.objects[target], scene.objects[index]
        -- Rewire against the original host graph, which still matches
        -- the previous persistent order until the explicit action succeeds.
        local base = object_tool(comp, scene, scene.sceneId, "base")
        local camera = object_tool(comp, scene, scene.cameraId, "camera")
        local previous = base
        for _, object in ipairs(scene.objects) do
            local merge = object_tool(comp, scene, object.id, "merge")
            checked_link(merge, "Background", previous)
            previous = merge
        end
        checked_link(camera, "Input", previous)
        scene.tailId = scene.objects[#scene.objects].id
        comp:SetData(SCENE_KEY, scene)
        return target
    end)
end

function M.remove(comp, objectId)
    local scene = require_scene(comp)
    validate_graph(comp, scene)
    local index, obj = object_index(scene, objectId)
    ensure_unlocked(obj)
    local control = object_tool(comp, scene, objectId, "control")
    local merge = object_tool(comp, scene, objectId, "merge")
    local mask = object_tool(comp, scene, objectId, "mask")
    local upstream = index == 1
        and object_tool(comp, scene, scene.sceneId, "base")
        or object_tool(comp, scene, scene.objects[index - 1].id, "merge")
    local downstream = index == #scene.objects
        and object_tool(comp, scene, scene.cameraId, "camera")
        or object_tool(comp, scene, scene.objects[index + 1].id, "merge")
    return undo(comp, "CartoRig: Delete Object", function()
        checked_link(downstream, index == #scene.objects
            and "Input" or "Background", upstream)
        -- Only explicitly tagged CartoRig-owned tools are ever deleted.
        if not merge:Delete() then
            fail("HOST_DELETE", "Fusion could not delete managed Merge")
        end
        if not control:Delete() then
            fail("HOST_DELETE", "Fusion could not delete managed Control")
        end
        if mask and not mask:Delete() then
            fail("HOST_DELETE", "Fusion could not delete managed Mask")
        end
        table.remove(scene.objects, index)
        scene.tailId = #scene.objects == 0 and scene.sceneId
            or scene.objects[#scene.objects].id
        comp:SetData(SCENE_KEY, scene)
        return objectId
    end)
end

function M.create_group(comp, name, selectedIds)
    name = safe_name(name)
    if type(selectedIds) ~= "table" or #selectedIds == 0 then
        fail("INVALID_GROUP", "Select at least one object to group")
    end
    local scene = require_scene(comp)
    validate_graph(comp, scene)
    local unique = {}
    local selections = {}
    for _, id in ipairs(selectedIds) do
        if unique[id] then fail("INVALID_GROUP", "Duplicate object in selection") end
        unique[id] = true
        local _, obj = object_index(scene, id)
        ensure_unlocked(obj)
        selections[#selections+1] = obj
    end
    return undo(comp, "CartoRig: Group Objects", function()
        local groupId = next_id(scene)
        scene.groups = scene.groups or {}
        scene.groups[#scene.groups+1] = { id = groupId, name = name }
        for _, obj in ipairs(selections) do obj.groupId = groupId end
        comp:SetData(SCENE_KEY, scene)
        return groupId
    end)
end

function M.ungroup(comp, groupId)
    local scene = require_scene(comp)
    validate_graph(comp, scene)
    local index
    for i, g in ipairs(scene.groups or {}) do
        if g.id == groupId then index = i break end
    end
    if not index then fail("GROUP_MISSING", "Group no longer exists") end
    for _, obj in ipairs(scene.objects) do
        if obj.groupId == groupId then ensure_unlocked(obj) end
    end
    return undo(comp, "CartoRig: Ungroup Objects", function()
        for _, obj in ipairs(scene.objects) do
            if obj.groupId == groupId then obj.groupId = nil end
        end
        table.remove(scene.groups, index)
        comp:SetData(SCENE_KEY, scene)
        return groupId
    end)
end

function M.select(comp, objectId)
    local scene = require_scene(comp)
    validate_graph(comp, scene)
    local found
    for _, object in ipairs(scene.objects) do
        if object.id == objectId then found = object break end
    end
    if not found then fail("OBJECT_MISSING", "Selected object no longer exists") end
    local tool = object_tool(comp, scene, objectId, "control")
    if not tool then fail("SCENE_BROKEN", "Control tool is missing") end
    local flow = comp.CurrentFrame and comp.CurrentFrame.FlowView
    if flow and flow.Select then flow:Select() flow:Select(tool, true) end
    comp:SetActiveTool(tool)
    return tool
end

function M.focus(comp, lon, lat, zoom)
    lon, lat = validate_position(lon, lat)
    zoom = tonumber(zoom)
    if not zoom or zoom < 0.25 or zoom > 100 or zoom ~= zoom then
        fail("INVALID_ZOOM", "Zoom must be between 0.25 and 100")
    end
    local scene = require_scene(comp)
    local _, camera = validate_graph(comp, scene)
    local pos = coords(lon, lat)
    return undo(comp, "CartoRig: Focus Camera", function()
        -- Transform is evaluated by Fusion; the camera is a genuine node
        -- and every authored geographic layer shares the same transform.
        camera:SetInput("Size", zoom)
        camera:SetInput("Center", point(
            0.5 + (0.5 - pos[1]) * zoom,
            0.5 + (0.5 - pos[2]) * zoom
        ))
        return true
    end)
end

function M.fade_in(comp, objectId, firstFrame, duration)
    firstFrame = tonumber(firstFrame)
    duration = tonumber(duration)
    if not firstFrame or firstFrame % 1 ~= 0 or
        not duration or duration % 1 ~= 0 or duration < 1 or duration > 10000 then
        fail("INVALID_MOTION", "Choose an integer start frame and duration 1..10000")
    end
    local scene = require_scene(comp)
    validate_graph(comp, scene)
    local found
    for _, object in ipairs(scene.objects) do
        if object.id == objectId then found = object break end
    end
    if not found then fail("OBJECT_MISSING", "Object no longer exists") end
    local merge = object_tool(comp, scene, objectId, "merge")
    -- Do not destroy manually edited Fusion Spline curves.
    local ok, existing = pcall(function()
        return merge.Blend:GetConnectedOutput()
    end)
    if not ok then
        fail("MOTION_UNVERIFIED", "Cannot verify native Blend animation")
    end
    if existing ~= nil then
        fail("MOTION_CONFLICT", "Blend already has animation. Edit it in Fusion Spline")
    end
    return undo(comp, "CartoRig: Fade In", function()
        if not merge:AddModifier("Blend", "BezierSpline") then
            fail("MOTION_HOST", "Fusion did not attach a native BezierSpline")
        end
        merge:SetInput("Blend", 0.0, firstFrame)
        merge:SetInput("Blend", 1.0, firstFrame + duration)
        -- Keyframes are stored on the Fusion tool, never in UIManager.
        return true
    end)
end

return M
