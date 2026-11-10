-- Run the *packaged* Fusion Scene entry against a minimal UIManager simulator.
-- This executes the actual window layout and events; it is not Resolve QA.
local file = arg[1] or "dist/CartoRig Scene.lua"
local widgets, window, dispatcher = {}, nil, nil
local ui = {}

local function constructor(name)
    return function(_, properties)
        local item = properties or {}
        item._kind = name
        item._items = {}
        function item:AddItem(label)
            self._items[#self._items + 1] = label
        end
        function item:AddTab(label)
            self._items[#self._items + 1] = label
            return #self._items - 1
        end
        function item:Clear()
            self._items = {}
            self.CurrentIndex = -1
        end
        return item
    end
end
setmetatable(ui, {__index=function(_,key)
    local method = constructor(key)
    rawset(ui,key,method)
    return method
end})

local function collect(item)
    if type(item)~="table" then return end
    if item.ID then
        assert(not widgets[item.ID],"Duplicate UIManager widget ID: "..item.ID)
        widgets[item.ID]=item
    end
    for _,child in ipairs(item) do collect(child) end
end
local function auto_events()
    return setmetatable({},{__index=function(tbl,key)
        local value={}
        rawset(tbl,key,value)
        return value
    end})
end
dispatcher = {
    loops=0,
    AddWindow=function(self,attributes,children)
        collect(children)
        local win={On=auto_events(),attributes=attributes}
        function win:GetItems()return widgets end
        function win:Show()self.visible=true end
        function win:Hide()self.visible=false end
        window=win
        return win
    end,
    RunLoop=function(self) self.loops=self.loops+1 end,
    ExitLoop=function(self)self.closed=true end,
}
_G.fu={UIManager=ui,CurrentComp=nil}
_G.bmd={UIDispatcher=function(_)return dispatcher end}

dofile(file)

assert(window,"Packaged Scene did not create a native UI Manager window")
assert(dispatcher.loops==1,"Scene should enter one native UIManager event loop")
assert(not window.visible,"Scene closed cleanly after the simulated event loop")
assert(widgets.SceneTabs._kind=="TabBar","Native TabBar missing")
assert(widgets.ScenePages._kind=="Stack","Native page stack missing")
assert(#widgets.SceneTabs._items==5,"Scene must expose exactly five navigation tabs")
for index,label in ipairs({"Objects","Find","Routes","Camera","Groups"}) do
    assert(widgets.SceneTabs._items[index]==label,
           "Wrong navigation order at tab "..index)
    assert(widgets["ScenePage"..label],
           "Missing native Scene page "..label)
end
assert(widgets.ScenePages.CurrentIndex==0,"Scene must open in Objects tab")
for i=0,4 do
    widgets.SceneTabs.CurrentIndex=i
    window.On.SceneTabs.CurrentChanged({Index=i})
    assert(widgets.ScenePages.CurrentIndex==i,
           "Native tab event did not navigate to page "..i)
end
assert(widgets.State.Text:find("NO_COMP",1,true),
       "No-composition state must be visible and non-mutating")
assert(widgets.Feedback.Text:find("Select",1,true),
       "Editor must receive a readable state and recovery action")
assert(type(window.On.Objects.CurrentIndexChanged)=="function",
       "Scene list must select its Fusion Inspector object on change")
assert(type(window.On.Refresh.Clicked)=="function",
       "Refresh action must be available")
assert(type(window.On.Create.Clicked)=="function",
       "Create Scene must remain an explicit click")
-- Unsupported external windows and a missing composition never create
-- tools, datasets, keys, or a phantom CartoRig Scene.
widgets.Objects.CurrentIndex=-1
window.On.Objects.CurrentIndexChanged({})
window.On.Refresh.Clicked({})
assert(widgets.State.Text:find("NO_COMP",1,true),
       "Refresh with no comp is safe and remains blocked")
window.On.Close.Clicked({})
assert(dispatcher.closed,"Scene close must release native dispatch loop")
print("PASS: packaged Fusion UIManager Scene, five tabs, events and no-comp state")
