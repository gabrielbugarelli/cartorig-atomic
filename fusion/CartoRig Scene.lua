-- CartoRig Atomic Scene (Fusion 20) — first operational implementation.
-- Menu entry lives in Fusion Scripts > Comp after installation.
-- The build system embeds the original cartorig_scene_runtime.lua at this marker.
local Runtime = @@EMBED_RUNTIME@@
local Geo = @@EMBED_CATALOG@@
local Shapes = @@EMBED_GEOMETRY@@

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
    ui:HGroup{
        ui:Button{ ID = "SelectBase", Text = "Base Map Control" },
        ui:Button{ ID = "SelectCamera", Text = "Camera Control" }
    },
    ui:HGroup{
        ui:Combo{ ID = "DisplayMode" },
        ui:Button{ ID = "SetMode", Text = "Set Display Mode" }
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
        ui:Button{ ID = "AddFoundRegion", Text = "Add Region" },
        ui:Button{ ID = "AddFoundMarker", Text = "Add Marker" },
        ui:Button{ ID = "AddFoundLabel", Text = "Add Label" },
        ui:Button{ ID = "FocusFound", Text = "Focus" }
    },
    ui:Button{ ID = "SetFlyTarget", Text = "Use Selected City as Fly To Target" },
    ui:Label{ Text = "CAMERA FIT — EXPLICIT TARGET SELECTION" },
    ui:HGroup{
        ui:Button{ ID = "AddFitSelection", Text = "Add Selected Place" },
        ui:Button{ ID = "ClearFitSelection", Text = "Clear" },
        ui:Button{ ID = "SetFitTarget", Text = "Set Fit Target" }
    },
    ui:Label{ ID = "FitSelectionLabel", Text = "Fit selection: none" },
    ui:Label{ Text = "CREATE ROUTE FROM SELECTED LOCATIONS" },
    ui:HGroup{
        ui:Button{ ID = "UseRouteFrom", Text = "Set Start" },
        ui:Button{ ID = "UseRouteState", Text = "Set State" },
        ui:Button{ ID = "UseRouteArrival", Text = "Set Arrival" }
    },
    ui:Label{ ID = "RouteSelection", Text = "Start: —    State: —    Arrival: —" },
    ui:HGroup{
        ui:Combo{ ID = "RouteStyle" },
        ui:Button{ ID = "CreateRoute", Text = "Add Route" }
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
    ui:Button{ ID = "Delete", Text = "Delete Selected (Confirm)" },
    ui:Label{ Text = "ORGANIZE OBJECTS INTO GROUPS" },
    ui:HGroup{
        ui:Button{ ID = "StageGroup", Text = "+ Add Selected Object" },
        ui:Button{ ID = "ClearGroupStage", Text = "Clear Selection" },
        ui:Button{ ID = "Group", Text = "Create Group" }
    },
    ui:Label{ ID = "GroupSelectionLabel", Text = "Group selection: none" },
    ui:Combo{ ID = "ExistingGroups" },
    ui:Button{ ID = "Ungroup", Text = "Ungroup Chosen Group" },
    ui:Label{ Text = "ROUTE FOLLOWER — SELECT EXISTING MARKER" },
    ui:Combo{ ID = "FollowerMarker" },
    ui:HGroup{
        ui:Button{ ID = "LinkFollower", Text = "Link to Selected Route" },
        ui:Button{ ID = "UnlinkFollower", Text = "Unlink Follower" }
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
        ui:Button{ ID = "Focus", Text = "Focus Point" },
        ui:Button{ ID = "SetZoom", Text = "Set Zoom" }
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
local followerChoices = {}
local matching = {}
local catalog = nil
local geometryIndex = nil
local routeStart,routeState,routeArrival = nil,nil,nil
local fitItems,fitComp = {},nil
local groupStages,groupComp = {},nil
local groupChoices = {}
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
    local geometryPath = scriptFolder .. "CartoRigAtomic_Data" ..
        package.config:sub(1, 1) .. "geometry.tsv"
    local geometryOk, index = pcall(Shapes.from_file, geometryPath)
    if geometryOk then geometryIndex = index
    else dataIssue = tostring(index) end
else
    dataIssue = "CATALOG_PATH: Resolve did not expose an installed script directory."
end
for _, option in ipairs({ "All", "Country", "State", "City", "Continent" }) do
    items.LocationFilter:AddItem(option)
end
items.LocationFilter.CurrentIndex = 0
for _, style in ipairs({ "Straight", "Curved" }) do
    items.RouteStyle:AddItem(style)
end
items.RouteStyle.CurrentIndex = 0
for _,mode in ipairs({ "Full Map", "Transparent Overlay" }) do
    items.DisplayMode:AddItem(mode)
end
items.DisplayMode.CurrentIndex=0

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
    followerChoices = {}
    groupChoices = {}
    items.Objects:Clear()
    items.FollowerMarker:Clear()
    items.ExistingGroups:Clear()
    local active=current_comp and current_comp() or nil
    if active~=fitComp then
        fitItems={}
        fitComp=active
        items.FitSelectionLabel.Text="Fit selection: none"
    end
    if active~=groupComp then
        groupStages={}
        groupComp=active
        items.GroupSelectionLabel.Text="Group selection: none"
    end
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
    items.DisplayMode.CurrentIndex=state.displayMode=="Transparent Overlay" and 1 or 0
    items.State.Text = "State: " .. state.state
    local groups = {}
    for _,group in ipairs(state.groups or {}) do
        groups[group.id]=group.name
        groupChoices[#groupChoices+1]=group.id
        items.ExistingGroups:AddItem(group.name)
    end
    if #groupChoices==0 then
        items.ExistingGroups:AddItem("No authored Groups")
    else
        items.ExistingGroups.CurrentIndex=0
    end
    local selectIndex = 0
    for i, object in ipairs(state.objects) do
        choices[#choices+1] = object.id
        if object.kind=="Marker" then
            followerChoices[#followerChoices+1]=object.id
            items.FollowerMarker:AddItem(object.name)
        end
        local prefix = object.groupId and
            ("[" .. tostring(groups[object.groupId] or "Group") .. "] ") or ""
        local suffix = object.locked and " [Locked]" or
            (object.visible == false and " [Hidden]" or "")
        items.Objects:AddItem(prefix .. object.kind .. " — " .. object.name .. suffix)
        if object.id == selectedObjectId then selectIndex = i - 1 end
    end
    if #followerChoices==0 then
        items.FollowerMarker:AddItem("No authored Marker available")
    else
        items.FollowerMarker.CurrentIndex=0
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

function window.On.SelectBase.Clicked(_)
    handle(function(comp) return Runtime.select_system(comp,"base") end)
end
function window.On.SelectCamera.Clicked(_)
    handle(function(comp) return Runtime.select_system(comp,"camera") end)
end
function window.On.SetMode.Clicked(_)
    handle(function(comp)
        local option=tonumber(items.DisplayMode.CurrentIndex)==1 and
            "Transparent Overlay" or "Full Map"
        return Runtime.set_display_mode(comp,option)
    end)
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
            items.Latitude.Text)
    end)
end

function window.On.SetZoom.Clicked(_)
    handle(function(comp)
        return Runtime.set_zoom(comp, items.Zoom.Text)
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
                row.point.lon, row.point.lat)
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
        (geometryIndex and geometryIndex:get(row.id) and "Vector polygon (WGS84)" or
            "No usable polygon geometry in offline data")
    items.LocationDetail.Text = row.name .. " — " .. row.kind ..
        " — " .. row.country .. " — " .. geometry
end

function window.On.AddFoundRegion.Clicked(_)
    handle(function(comp)
        if not geometryIndex then
            error(dataIssue or "NO_GEOMETRY: Offline polygon pack unavailable",0)
        end
        local row=current_match()
        if row.kind~="Country" and row.kind~="State" then
            error("NO_POLYGON: Choose a Country or State, not a city point.",0)
        end
        local geometry=geometryIndex:get(row.id)
        if not geometry then
            error("NO_GEOMETRY: Geographic polygon unavailable for "..row.name,0)
        end
        return Runtime.add_region(comp,row,geometry)
    end)
end

local function route_caption()
    items.RouteSelection.Text = "Start: "..(routeStart and routeStart.name or "—")..
        "    State: "..(routeState and routeState.name or "—")..
        "    Arrival: "..(routeArrival and routeArrival.name or "—")
end
function window.On.UseRouteFrom.Clicked(_)
    local ok,row=pcall(current_match)
    if not ok then feedback(label_error(row)) return end
    if row.kind~="City" or not row.point then
        feedback("ROUTE_START: Choose a City with a WGS84 point.") return
    end
    routeStart=row
    route_caption()
end
function window.On.UseRouteState.Clicked(_)
    local ok,row=pcall(current_match)
    if not ok then feedback(label_error(row)) return end
    if row.kind~="State" then
        feedback("ROUTE_STATE: Choose a State with real polygon geometry.") return
    end
    if not geometryIndex or not geometryIndex:get(row.id) then
        feedback("NO_GEOMETRY: The selected State has no usable polygon.") return
    end
    routeState=row
    routeArrival=nil
    route_caption()
end
function window.On.UseRouteArrival.Clicked(_)
    local ok,row=pcall(current_match)
    if not ok then feedback(label_error(row)) return end
    if row.kind~="City" or not row.point then
        feedback("ROUTE_ARRIVAL: Choose an explicit City, not a State.") return
    end
    routeArrival=row
    route_caption()
end
function window.On.CreateRoute.Clicked(_)
    handle(function(comp)
        if not routeStart or not routeState or not routeArrival then
            error("ENDPOINT_REQUIRED: Choose Start, State and explicit Arrival.",0)
        end
        local polygon=geometryIndex and geometryIndex:get(routeState.id)
        if not polygon then error("NO_GEOMETRY: Route State geometry missing",0) end
        local style=tonumber(items.RouteStyle.CurrentIndex)==1 and
            "Curved" or "Straight"
        return Runtime.add_route(comp,
            {id=routeStart.id,name=routeStart.name,
             lon=routeStart.point.lon,lat=routeStart.point.lat},
            {id=routeArrival.id,name=routeArrival.name,
             lon=routeArrival.point.lon,lat=routeArrival.point.lat},
            {destinationState=routeState,destinationGeometry=polygon,
             pathType=style,
             name=routeStart.name.." → "..routeArrival.name.." ("..
                 routeState.name..")"})
    end)
end

local function show_fit_targets()
    local names={}
    for _,entry in ipairs(fitItems) do
        names[#names+1]=entry.name
    end
    items.FitSelectionLabel.Text=#names==0 and "Fit selection: none" or
        ("Fit selection ("..#names.."): "..table.concat(names,", "))
end

function window.On.AddFitSelection.Clicked(_)
    local ok,row=pcall(current_match)
    if not ok then feedback(label_error(row)) return end
    local current=current_comp()
    if not current or current~=binding then
        feedback("WRONG_CONTEXT: Refresh after switching composition.")
        return
    end
    for _,entry in ipairs(fitItems) do
        if entry.id==row.id then
            feedback("FIT_DUPLICATE: Target is already included.")
            return
        end
    end
    local target={id=row.id,name=row.name,kind=row.kind}
    if row.point then
        target.point={lon=row.point.lon,lat=row.point.lat}
    elseif row.kind=="Country" or row.kind=="State" then
        local geometry=geometryIndex and geometryIndex:get(row.id)
        if not geometry then
            feedback("NO_GEOMETRY: Selected region has no valid polygon")
            return
        end
        target.geometry=geometry
    else
        feedback("FIT_TARGET_REQUIRED: Select a City, Country or State")
        return
    end
    fitItems[#fitItems+1]=target
    show_fit_targets()
end

function window.On.ClearFitSelection.Clicked(_)
    fitItems={}
    show_fit_targets()
end

function window.On.SetFitTarget.Clicked(_)
    handle(function(comp)
        if #fitItems==0 then
            error("FIT_TARGET_REQUIRED: Add explicit places for Camera Fit",0)
        end
        return Runtime.set_fit_target(comp,fitItems,.10)
    end)
end

function window.On.SetFlyTarget.Clicked(_)
    handle(function(comp)
        local feature=current_match()
        if feature.kind~="City" or not feature.point then
            error("TARGET_REQUIRED: Choose an explicit City for Camera Fly To",0)
        end
        return Runtime.set_fly_target(comp,feature,items.Zoom.Text)
    end)
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

function window.On.LinkFollower.Clicked(_)
    handle(function(comp)
        local index=tonumber(items.FollowerMarker.CurrentIndex) or -1
        local markerId=followerChoices[index+1]
        if not markerId then
            error("FOLLOWER_REQUIRED: Create or choose an existing Marker",0)
        end
        return Runtime.link_follower(comp,selected_id(),markerId)
    end)
end
function window.On.UnlinkFollower.Clicked(_)
    handle(function(comp)
        return Runtime.unlink_follower(comp,selected_id())
    end)
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
local function show_group_stage()
    local names={}
    for _,entry in ipairs(groupStages) do
        names[#names+1]=entry.name
    end
    items.GroupSelectionLabel.Text=#names==0 and "Group selection: none"
        or ("Selected ("..#names.."): "..table.concat(names,", "))
end
function window.On.StageGroup.Clicked(_)
    local ok,selected=pcall(selected_id)
    if not ok then feedback(label_error(selected)) return end
    for _,entry in ipairs(groupStages) do
        if entry.id==selected then
            feedback("GROUP_DUPLICATE: Object is already selected.")
            return
        end
    end
    local contextOk,comp=pcall(require_current)
    if not contextOk then feedback(label_error(comp)) return end
    local stateOk,state=pcall(Runtime.inspect,comp)
    if not stateOk then feedback(label_error(state)) return end
    for _,object in ipairs(state.objects) do
        if object.id==selected then
            if object.locked or object.groupId then
                feedback("GROUP_CONFLICT: Unlock or ungroup selected object first.")
                return
            end
            groupStages[#groupStages+1]={id=selected,name=object.name}
            show_group_stage()
            return
        end
    end
    feedback("OBJECT_MISSING: Refresh Scene and select another object.")
end
function window.On.ClearGroupStage.Clicked(_)
    groupStages={}
    show_group_stage()
end
function window.On.Group.Clicked(_)
    handle(function(comp)
        if #groupStages<2 then
            error("GROUP_SELECTION: Select at least two objects for one Group",0)
        end
        local ids={}
        for _,entry in ipairs(groupStages) do ids[#ids+1]=entry.id end
        local groupId=Runtime.create_group(comp,items.Name.Text,ids)
        groupStages={}
        show_group_stage()
        return groupId
    end)
end
function window.On.Ungroup.Clicked(_)
    handle(function(comp)
        local index=tonumber(items.ExistingGroups.CurrentIndex) or -1
        local id=groupChoices[index+1]
        if not id then error("GROUP_MISSING: Select an existing Group",0) end
        return Runtime.ungroup(comp,id)
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
