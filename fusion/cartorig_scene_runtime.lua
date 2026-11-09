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
    return data
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
    local tail = object_tool(comp, scene, scene.tailId, "tail")
    if not base or not camera or not tail then
        fail("SCENE_BROKEN", "Scene graph is incomplete. No modifications were made")
    end
    for _, obj in ipairs(scene.objects) do
        if not object_tool(comp, scene, obj.id, "control") or
            not object_tool(comp, scene, obj.id, "merge") then
            fail("SCENE_BROKEN", "Missing Fusion tool for " .. obj.name)
        end
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
            lon = obj.lon, lat = obj.lat
        }
    end
    return { state = "SCENE_READY", sceneId = scene.sceneId, objects = objects }
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
            tailId = sceneId, nextId = 1, objects = {},
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
    local id = next_id(scene)
    return undo(comp, "CartoRig: Add " .. kind, function()
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
            id = id, kind = kind, name = name, lon = lon, lat = lat
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
