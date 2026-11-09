-- CartoRig Atomic Scene (Fusion 20) — first operational implementation.
-- Menu entry lives in Fusion Scripts > Comp after installation.
-- The build system embeds the original cartorig_scene_runtime.lua at this marker.
local Runtime = @@EMBED_RUNTIME@@
local Geo = @@EMBED_CATALOG@@

local fusionApp = rawget(_G, "fu") or rawget(_G, "fusion")
local bmdApi = rawget(_G, "bmd")
if not fusionApp or not bmdApi or not fusionApp.UIManager then
    print("CARTORIG_SCENE_UNAVAILABLE: Fusion UI Manager is not accessible.")
    return
end

local ui = fusionApp.UIManager
local dispatcher = bmdApi.UIDispatcher(ui)
if not dispatcher then
    print("CARTORIG_SCENE_UNAVAILABLE: Cannot start the native window dispatcher.")
    return
end

local window = dispatcher:AddWindow({
    ID = "CartoRigAtomicFusionScene",
    WindowTitle = "CartoRig — Scene",
    Geometry = { 150, 130, 480, 630 },
    Spacing = 9
}, ui:VGroup{
    ID = "Root",
    Spacing = 8,
    ui:Label{ ID = "Title", Text = "CARTORIG  /  SCENE" },
    ui:Label{ ID = "Composition", Text = "Composition: not selected" },
    ui:Label{ ID = "State", Text = "Scene not loaded" },
    ui:HGroup{
        ui:Button{ ID = "Refresh", Text = "Refresh" },
        ui:Button{ ID = "Create", Text = "Create Scene" }
    },
    ui:Label{ Text = "FIND OFFLINE LOCATION" },
    ui:HGroup{
        ui:LineEdit{ ID = "Search", Text = "" },
        ui:Button{ ID = "SearchButton", Text = "Search" }
    },
    ui:Combo{ ID = "LocationFilter" },
    ui:Combo{ ID = "SearchResults" },
    ui:Label{ ID = "LocationDetail", Text = "Enter a location name to search the installed index." },
    ui:HGroup{
        ui:Button{ ID = "AddFoundMarker", Text = "Add Marker" },
        ui:Button{ ID = "AddFoundLabel", Text = "Add Label" },
        ui:Button{ ID = "FocusFound", Text = "Focus Camera" }
    },
    ui:Label{ Text = "SCENE OBJECTS" },
    ui:Combo{ ID = "Objects" },
    ui:Button{ ID = "Reveal", Text = "Reveal in Fusion Inspector" },
    ui:HGroup{
        ui:Button{ ID = "Rename", Text = "Rename" },
        ui:Button{ ID = "MoveUp", Text = "Move Up" },
        ui:Button{ ID = "MoveDown", Text = "Move Down" }
    },
    ui:HGroup{
        ui:Button{ ID = "Show", Text = "Show" },
        ui:Button{ ID = "Hide", Text = "Hide" },
        ui:Button{ ID = "Lock", Text = "Lock" },
        ui:Button{ ID = "Unlock", Text = "Unlock" }
    },
    ui:HGroup{
        ui:Button{ ID = "Group", Text = "Group Selected" },
        ui:Button{ ID = "Delete", Text = "Delete (Confirm)" }
    },
    ui:Label{ Text = "ADD GEOANCHORED OBJECT" },
    ui:Label{ Text = "Name" },
    ui:LineEdit{ ID = "Name", Text = "" },
    ui:HGroup{
        ui:VGroup{
            ui:Label{ Text = "Longitude (-180..180)" },
            ui:LineEdit{ ID = "Longitude", Text = "0" }
        },
        ui:VGroup{
            ui:Label{ Text = "Latitude (-90..90)" },
            ui:LineEdit{ ID = "Latitude", Text = "0" }
        }
    },
    ui:HGroup{
        ui:Button{ ID = "Marker", Text = "Add Marker" },
        ui:Button{ ID = "Label", Text = "Add Label" }
    },
    ui:Label{ Text = "SHARED CAMERA" },
    ui:HGroup{
        ui:Label{ Text = "Zoom" },
        ui:LineEdit{ ID = "Zoom", Text = "1" },
        ui:Button{ ID = "Focus", Text = "Focus on Coordinates" }
    },
    ui:Label{ ID = "Feedback", Text = "Ready. All edits use Fusion Undo." },
    ui:Button{ ID = "Close", Text = "Close Scene" }
})

if not window then
    print("CARTORIG_SCENE_UNAVAILABLE: UI Manager did not create Scene.")
    return
end

local items = window:GetItems()
local binding = nil
local choices = {}
local matching = {}
local catalog = nil
local dataIssue = nil
local selectedObjectId = nil
local pendingDelete = nil

local scriptLocation = debug.getinfo(1, "S").source
local scriptFolder = scriptLocation and
    scriptLocation:match("^@(.+[\\/])[^\\/]+$")
if scriptFolder then
    local dataPath = scriptFolder .. "CartoRigAtomic_Data" ..
        package.config:sub(1, 1) .. "places.tsv"
    local ok, loaded = pcall(Geo.from_file, dataPath)
    if ok then catalog = loaded else dataIssue = tostring(loaded) end
else
    dataIssue = "CATALOG_PATH: Resolve did not expose an installed script directory."
end
for _, option in ipairs({ "All", "Country", "State", "City", "Continent" }) do
    items.LocationFilter:AddItem(option)
end
items.LocationFilter.CurrentIndex = 0

local function current_comp()
    -- Never fall back to the first composition when a different composition
    -- may now be active. Wrong-context mutations are prohibited.
    local current = fusionApp.CurrentComp
    return current
end

local function label_error(error)
    local text = tostring(error or "")
    local code = text:match("([A-Z_]+: [^\n]+)")
    if code then return code end
    return "HOST_OPERATION_FAILED: No changes were requested to the active scene."
end

local function feedback(message)
    items.Feedback.Text = message
end

local function sync()
    local current = current_comp()
    binding = nil
    choices = {}
    items.Objects:Clear()
    if not current then
        items.Composition.Text = "Composition: none"
        items.State.Text = "NO_COMP — Select a Fusion composition"
        feedback("Select a Fusion composition before editing.")
        return
    end
    local name = "Active Fusion composition"
    local ok, attrs = pcall(function() return current:GetAttrs() end)
    if ok and type(attrs) == "table" then
        name = tostring(attrs.COMPS_Name or name)
    end
    items.Composition.Text = "Composition: " .. name
    local inspected, state = pcall(Runtime.inspect, current)
    if not inspected then
        items.State.Text = "SCENE_ERROR — Repair before editing"
        feedback(label_error(state))
        return
    end
    binding = current
    items.State.Text = "State: " .. state.state
    local groups = {}
    for _, group in ipairs(state.groups or {}) do groups[group.id] = group.name end
    local selectIndex = 0
    for i, object in ipairs(state.objects) do
        choices[#choices+1] = object.id
        local prefix = object.groupId and
            ("[" .. tostring(groups[object.groupId] or "Group") .. "] ") or ""
        local suffix = object.locked and " [Locked]" or
            (object.visible == false and " [Hidden]" or "")
        items.Objects:AddItem(prefix .. object.kind .. " — " .. object.name .. suffix)
        if object.id == selectedObjectId then selectIndex = i - 1 end
    end
    if #choices == 0 then
        selectedObjectId = nil
        items.Objects:AddItem("No authored objects")
    else
        items.Objects.CurrentIndex = selectIndex
        selectedObjectId = choices[selectIndex + 1]
    end
    if dataIssue then
        feedback(dataIssue)
    else
        feedback("Scene synchronized. Offline catalog: " ..
            tostring(catalog and catalog.count or 0) .. " places.")
    end
end

local function require_current()
    local current = current_comp()
    if not current or not binding or current ~= binding then
        error("WRONG_CONTEXT: Composition changed. Click Refresh before editing.", 0)
    end
    return current
end

local function selected_id()
    local index = tonumber(items.Objects.CurrentIndex) or -1
    local id = choices[index + 1]
    if not id then
        error("NO_SELECTION: Select a CartoRig object.", 0)
    end
    selectedObjectId = id
    return id
end

local function handle(action)
    local ok, result = pcall(function()
        local comp = require_current()
        return action(comp)
    end)
    if not ok then
        feedback(label_error(result))
        return
    end
    if type(result) == "string" then selectedObjectId = result end
    sync()
    if type(result) == "string" then
        feedback("Success: " .. result)
    else
        feedback("Operation completed in Fusion.")
    end
end

function window.On.Refresh.Clicked(_)
    sync()
end

function window.On.Create.Clicked(_)
    -- Creating a scene is deliberate; never create it when opening the UI.
    local current = current_comp()
    if not current then feedback("NO_COMP: Select a Fusion composition.") return end
    local ok, result = pcall(Runtime.create, current)
    if not ok then feedback(label_error(result)) return end
    sync()
    feedback("Scene created; no geographic objects or motion added.")
end

function window.On.Marker.Clicked(_)
    handle(function(comp)
        return Runtime.add_marker(comp, items.Name.Text,
            items.Longitude.Text, items.Latitude.Text)
    end)
end

function window.On.Label.Clicked(_)
    handle(function(comp)
        return Runtime.add_label(comp, items.Name.Text,
            items.Longitude.Text, items.Latitude.Text)
    end)
end

function window.On.Focus.Clicked(_)
    handle(function(comp)
        return Runtime.focus(comp, items.Longitude.Text,
            items.Latitude.Text, items.Zoom.Text)
    end)
end

function window.On.Reveal.Clicked(_)
    handle(function(comp) return Runtime.select(comp, selected_id()) end)
end


local function current_match()
    if not catalog then
        error(dataIssue or "CATALOG_MISSING: Offline data is unavailable", 0)
    end
    local index = tonumber(items.SearchResults.CurrentIndex) or -1
    local row = matching[index + 1]
    if not row then error("NO_RESULT: Select a real location from Search Results", 0) end
    return row
end

local function run_search()
    matching = {}
    items.SearchResults:Clear()
    items.LocationDetail.Text = "No location selected"
    if not catalog then
        feedback(dataIssue or "CATALOG_MISSING: Offline data is unavailable.")
        return
    end
    local filterIndex = tonumber(items.LocationFilter.CurrentIndex) or 0
    local types = { "All", "Country", "State", "City", "Continent" }
    local filter = types[filterIndex + 1] or "All"
    matching = catalog:search(items.Search.Text, filter, 40)
    for _, row in ipairs(matching) do
        local parent = row.parent ~= "" and row.parent or row.country
        items.SearchResults:AddItem(
            row.name .. " — " .. row.kind .. " — " .. parent)
    end
    if #matching == 0 then
        items.SearchResults:AddItem("No location found in offline data")
        feedback("NO_MATCH: Refine the search or clear the filter.")
    else
        items.SearchResults.CurrentIndex = 0
        feedback(tostring(#matching) ..
            " matching locations. Search alone does not change the Scene.")
    end
end

local function action_for_result(operation)
    handle(function(comp)
        local row = current_match()
        if not row.point then
            error("NO_POINT: " .. row.kind ..
                " has polygon data, not a city point. Choose a point.",
                0)
        end
        if operation == "marker" then
            return Runtime.add_marker(comp, row.name,
                row.point.lon, row.point.lat, row)
        elseif operation == "label" then
            return Runtime.add_label(comp, row.name,
                row.point.lon, row.point.lat, row)
        else
            return Runtime.focus(comp,
                row.point.lon, row.point.lat, items.Zoom.Text)
        end
    end)
end

function window.On.SearchButton.Clicked(_)
    run_search()
end

function window.On.LocationFilter.CurrentIndexChanged(_)
    if items.Search.Text ~= "" then run_search() end
end

function window.On.SearchResults.CurrentIndexChanged(_)
    local index = tonumber(items.SearchResults.CurrentIndex) or -1
    local row = matching[index + 1]
    if not row then return end
    local geometry = row.point and "Point (WGS84)" or
        "Administrative region (polygon data, renderer pending)"
    items.LocationDetail.Text = row.name .. " — " .. row.kind ..
        " — " .. row.country .. " — " .. geometry
end

function window.On.AddFoundMarker.Clicked(_)
    action_for_result("marker")
end

function window.On.AddFoundLabel.Clicked(_)
    action_for_result("label")
end

function window.On.FocusFound.Clicked(_)
    action_for_result("focus")
end

function window.On.Rename.Clicked(_)
    handle(function(comp)
        return Runtime.rename(comp, selected_id(), items.Name.Text)
    end)
end
function window.On.MoveUp.Clicked(_)
    handle(function(comp)
        return Runtime.move(comp, selected_id(), -1)
    end)
end
function window.On.MoveDown.Clicked(_)
    handle(function(comp)
        return Runtime.move(comp, selected_id(), 1)
    end)
end
function window.On.Show.Clicked(_)
    handle(function(comp)
        return Runtime.set_visibility(comp, selected_id(), true)
    end)
end
function window.On.Hide.Clicked(_)
    handle(function(comp)
        return Runtime.set_visibility(comp, selected_id(), false)
    end)
end
function window.On.Lock.Clicked(_)
    handle(function(comp)
        return Runtime.set_lock(comp, selected_id(), true)
    end)
end
function window.On.Unlock.Clicked(_)
    handle(function(comp)
        return Runtime.set_lock(comp, selected_id(), false)
    end)
end
function window.On.Group.Clicked(_)
    handle(function(comp)
        return Runtime.create_group(comp, items.Name.Text, { selected_id() })
    end)
end
function window.On.Delete.Clicked(_)
    local ok, id = pcall(selected_id)
    if not ok then feedback(label_error(id)) return end
    if pendingDelete ~= id then
        pendingDelete = id
        feedback("CONFIRM DELETE: Click Delete again to remove only this CartoRig object.")
        return
    end
    pendingDelete = nil
    handle(function(comp) return Runtime.remove(comp, id) end)
end

function window.On.Close.Clicked(_)
    dispatcher:ExitLoop()
end
function window.On.CartoRigAtomicFusionScene.Close(_)
    dispatcher:ExitLoop()
end

sync()
window:Show()
dispatcher:RunLoop()
window:Hide()
