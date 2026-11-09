-- CartoRig Atomic / CR-PS-2.0
-- FUSION HOST PROBE ONLY: read-only UIManager and active composition context.
-- This is not a product Scene editor, no map data, no Fusion graph mutations.
-- The script must run in the Fusion page as a Comp script.
-- No files, network, subprocesses, or global project state are modified.

local fusionApp = rawget(_G, "fu") or rawget(_G, "fusion")
local bmdApi = rawget(_G, "bmd")
if not fusionApp or not bmdApi then
    print("CartoRig Host Probe: Fusion scripting globals unavailable.")
    return
end

local ui = fusionApp.UIManager
if not ui then
    print("CartoRig Host Probe: UIManager is unavailable in this Fusion host.")
    return
end

local dispatcher = bmdApi.UIDispatcher(ui)
if not dispatcher then
    print("CartoRig Host Probe: UIDispatcher initialization failed.")
    return
end

local windowId = "CartoRigSceneHostProbeV2"

-- If the host supports FindWindow, bring the existing probe to the front.
-- A missing method does not create a second UI implementation.
local lookupOk, existing = pcall(function()
    return ui:FindWindow(windowId)
end)
if lookupOk and existing then
    existing:Show()
    return
end

local window = dispatcher:AddWindow({
    ID = windowId,
    WindowTitle = "CartoRig — Scene (Host Probe)",
    Geometry = { 120, 120, 430, 640 },
    Spacing = 8
}, ui:VGroup{
    ID = "CartoRigRoot",
    Spacing = 8,
    ui:Label{
        ID = "Title",
        Text = "CARTORIG  /  SCENE  /  HOST PROBE"
    },
    ui:Label{
        ID = "Safety",
        Text = "Read-only Fusion API test. No objects, keyframes or nodes are created."
    },
    ui:HGroup{
        ui:Button{ ID = "Refresh", Text = "Refresh Composition" },
        ui:Button{ ID = "CloseProbe", Text = "Close" }
    },
    ui:Label{
        ID = "ContextState",
        Text = "Checking active Fusion composition..."
    },
    ui:Label{
        ID = "CompIdentity",
        Text = ""
    },
    ui:Label{
        ID = "SelectedTool",
        Text = "Selected Fusion tool: none"
    },
    ui:Label{
        ID = "InspectorHint",
        Text = "The product Inspector, Motion and Spline bindings are NOT TESTED."
    }
})

if not window then
    print("CartoRig Host Probe: UIManager window could not be created.")
    return
end

local items = window:GetItems()

local function currentComposition()
    local appComp
    local ok = pcall(function() appComp = fusionApp.CurrentComp end)
    if ok and appComp then
        return appComp
    end
    -- The Comp script's initial comp is a fallback, NOT evidence that a
    -- composition switch has been detected. Explicitly label this situation.
    return rawget(_G, "comp")
end

local initialComp = rawget(_G, "comp")

local function currentToolName(active)
    local tool
    local ok = pcall(function() tool = active.ActiveTool end)
    if not ok or not tool then
        return "none"
    end
    local attrs
    ok = pcall(function() attrs = tool:GetAttrs() end)
    if ok and type(attrs) == "table" then
        return tostring(attrs.TOOLS_Name or attrs.TOOLN_Name or tool)
    end
    return tostring(tool)
end

local function refresh()
    local active = currentComposition()
    if not active then
        items.ContextState.Text = "NO_COMP — No Fusion composition selected"
        items.CompIdentity.Text = "No scene was initialized."
        items.SelectedTool.Text = "Selected Fusion tool: none"
        return
    end

    local attrs
    local attrsOk = pcall(function() attrs = active:GetAttrs() end)
    local name = "Unnamed Fusion composition"
    if attrsOk and type(attrs) == "table" then
        local candidate = attrs.COMPS_Name or attrs.COMPS_FileName
        if candidate and tostring(candidate) ~= "" then
            name = tostring(candidate)
        end
    end

    if initialComp and active ~= initialComp then
        items.ContextState.Text = "WRONG_CONTEXT — Active composition changed"
        items.CompIdentity.Text = name .. " (read-only; old selection invalid)"
        items.SelectedTool.Text = "Selected Fusion tool: invalidated"
    else
        items.ContextState.Text = "COMP_WITHOUT_CARTORIG — Host context readable"
        items.CompIdentity.Text = name
        items.SelectedTool.Text = "Selected Fusion tool: " .. currentToolName(active)
    end
end

function window.On.Refresh.Clicked(_)
    refresh()
end

function window.On.CloseProbe.Clicked(_)
    dispatcher:ExitLoop()
end

function window.On.CartoRigSceneHostProbeV2.Close(_)
    dispatcher:ExitLoop()
end

refresh()
window:Show()
dispatcher:RunLoop()
window:Hide()
