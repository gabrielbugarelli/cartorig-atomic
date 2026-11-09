-- CartoRig Atomic Scene (Fusion 20) — first operational implementation.
-- Menu entry lives in Fusion Scripts > Comp after installation.
-- The build system embeds the original cartorig_scene_runtime.lua at this marker.
local Runtime = @@EMBED_RUNTIME@@

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
    ui:Label{ Text = "SCENE OBJECTS" },
    ui:Combo{ ID = "Objects" },
    ui:HGroup{
        ui:Button{ ID = "Reveal", Text = "Reveal in Fusion Inspector" },
        ui:Button{ ID = "FadeIn", Text = "Motion: Fade In" }
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
    ui:Label{ Text = "MOTION" },
    ui:HGroup{
        ui:Label{ Text = "Start frame" },
        ui:LineEdit{ ID = "StartFrame", Text = "0" },
        ui:Label{ Text = "Duration" },
        ui:LineEdit{ ID = "Duration", Text = "20" }
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
    for _, object in ipairs(state.objects) do
        choices[#choices+1] = object.id
        items.Objects:AddItem(object.kind .. " — " .. object.name)
    end
    if #choices == 0 then
        items.Objects:AddItem("No authored objects")
    end
    feedback("Scene synchronized. Select a CartoRig object to edit.")
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

function window.On.FadeIn.Clicked(_)
    handle(function(comp)
        return Runtime.fade_in(comp, selected_id(),
            items.StartFrame.Text, items.Duration.Text)
    end)
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
