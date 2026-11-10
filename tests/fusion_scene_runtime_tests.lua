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
    function comp:GetPrefs(key)
        if key=="Comp.FrameFormat.Width" then return 1920 end
        if key=="Comp.FrameFormat.Height" then return 1080 end
        return nil
    end
    function comp:SetActiveTool(tool)
        self.active = tool
        self.ActiveTool = tool
    end
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
            local p={}
            function p:GetConnectedOutput()
                if (t.modifiers or {})[name] then
                    local spline={ID="BezierSpline"}
                    function spline:SetKeyFrames(frames,replace)
                        if replace~=true then return false end
                        t.splineKeyframes=t.splineKeyframes or {}
                        t.splineKeyframes[name]=frames
                        t.animations[name]={}
                        for frame,description in pairs(frames) do
                            t.animations[name][frame]=description[1]
                        end
                        return true
                    end
                    function spline:GetKeyFrames()
                        local exact=(t.splineKeyframes or {})[name]
                        if exact then return exact end
                        local keys={}
                        for frame,value in pairs(t.animations[name] or {}) do
                            keys[frame]={value}
                        end
                        return keys
                    end
                    return { GetTool = function() return spline end }
                end
                return t.links[name]
            end
            function p:SetExpression(expression)
                t.expressions=t.expressions or {}
                t.expressions[name]=expression
                return true
            end
            function p:GetExpression()
                return (t.expressions or {})[name]
            end
            return p
        end
        t.Input = port("Input")
        t.Blend = port("Blend")
        t.Size = port("Size")
        t.Center = port("Center")
        t.Pivot = port("Pivot")
        t.StyledText = port("StyledText")
        t.CR2CameraLongitude = port("CR2CameraLongitude")
        t.CR2CameraLatitude = port("CR2CameraLatitude")
        t.CR2FollowerProgress = port("CR2FollowerProgress")
        t.WriteLength = port("WriteLength")
        t.Width = port("Width")
        t.Height = port("Height")
        t.TopLeftRed = port("TopLeftRed")
        t.TopLeftGreen = port("TopLeftGreen")
        t.TopLeftBlue = port("TopLeftBlue")
        t.TopLeftAlpha = port("TopLeftAlpha")
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
expect(camera.inputs.CR2CameraLongitude==0 and
       camera.inputs.CR2CameraLatitude==0,
       "Camera starts with independent zero-valued native geographic channels")
expect(camera.expressions.Center:find("CR2CameraLongitude",1,true) and
       camera.expressions.Center:find("CR2CameraLatitude",1,true),
       "Fusion evaluates Point Center from independently keyed WGS84 scalar Controls")
expect(base.ID == "Fuse.CartoRigAtomicLand",
       "Base Map is a genuine native Fusion vector renderer, not flat placeholder")
expect(runtime.select_system(comp,"base")==base and comp.active==base,
       "Base Map exposes its own Inspector Control")
expect(runtime.select_system(comp,"camera")==camera and comp.active==camera,
       "Camera exposes separate native Inspector Control")
runtime.set_display_mode(comp,"Transparent Overlay")
expect(base.inputs.TransparentOverlay==1,
       "Transparent Overlay hides only native vector base layers")
expect(runtime.inspect(comp).displayMode=="Transparent Overlay",
       "display mode stored in independent Fusion composition state")
runtime.set_display_mode(comp,"Full Map")
expect(base.inputs.TransparentOverlay==0,
       "switching back restores the original Full Map renderer")
expect_failure(function()
    runtime.set_display_mode(comp,"Invisible/Unknown")
end,"INVALID_MODE")

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
local markerScale=find(comp,marker1,"screenScale")
expect(markerScale and markerScale.ID=="Transform",
       "Marker has a real inverse-zoom Transform inside its own Fusion branch")
expect(markerScale.links.Input==control1 and
       merge1.links.Foreground==markerScale,
       "Marker inverse zoom is applied before shared geographic Camera")
expect(markerScale.expressions.Size:find("CR2_Camera.Size",1,true),
       "Marker visual size is inversely tied to shared Camera zoom")
expect(markerScale.expressions.Center:find("CR2_Mask_1.Center",1,true) and
       markerScale.expressions.Pivot:find("CR2_Mask_1.Center",1,true),
       "Inverse zoom stays around the actual geographic mask anchor")
for _, zoomValue in ipairs({.5,1,2,8,100}) do
    expect(math.abs((14/1920)*(1/zoomValue)*zoomValue-14/1920)<1e-12,
           "Marker inverse zoom preserves a constant 14-pixel width mathematically")
end
expect(control1.UserControls.CR2MotionApply.ICS_ControlPage=="Motion",
       "Marker exposes native Inspector Motion without using Scene controls")
expect(control1.UserControls.CR2MotionApply.BTNCS_Execute:find("MO-MRK-01",1,true),
       "Marker Fade In callback carries a native Fusion Spline preset")
expect(runtime.inspect(comp).objects[1].sourceRef.featureId=="ne10m:city:12345",
       "Natural Earth identity survives authored Marker creation")
expect(runtime.inspect(comp).objects[1].sourceRef.provider=="Natural Earth",
       "SourceRef carries explicit geographic provenance")
expect(control1.links.EffectMask == mask1, "Marker is actually masked")
expect(control1.inputs.TopLeftRed == 224/255 and
       control1.inputs.TopLeftGreen == 232/255 and
       control1.inputs.TopLeftBlue == 237/255,
       "Marker defaults to approved neutral #E0E8ED, not orange")
expect(math.abs(mask1.inputs.Width-14/1920)<1e-10 and
       math.abs(mask1.inputs.Height-14/1080)<1e-10,
       "Marker initializes a 14px circle under both output dimensions")
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
local labelScale=find(comp,label,"screenScale")
expect(labelScale and labelScale.ID=="Transform" and
       labelScale.links.Input==labelControl and
       find(comp,label,"merge").links.Foreground==labelScale,
       "Label has a separate inverse-zoom node before the common Camera")
expect(labelScale.expressions.Size:find("CR2_Camera.Size",1,true) and
       labelScale.expressions.Pivot:find("CR2_Label_3.Center",1,true),
       "Label inverse zoom keeps text fixed in screen pixels about text geoanchor")
expect(labelControl.UserControls.CR2MotionApply.ICS_ControlPage=="Motion",
       "Label has native Motion page on its selected TextPlus tool")
expect(labelControl.inputs.StyledText == "São Paulo", "Unicode label preserved")
expect(#runtime.inspect(comp).objects == 3, "Scene tree reconstructs from comp state")

-- Tool names must never be the canonical object identity.
control1:SetAttrs({ TOOLS_Name = "Renamed by user" })
expect(runtime.select(comp, marker1) == control1,
       "select object by stable metadata after manual tool rename")
expect(comp.active == control1, "native Fusion tool becomes Inspector selection")
expect(runtime.active_selection(comp).state=="OBJECT" and
       runtime.active_selection(comp).objectId==marker1,
       "active native Fusion Control resolves to stable CartoRig object ID")
local foreignTool=comp:AddTool("BrightnessContrast",false,13,7)
comp:SetActiveTool(foreignTool)
expect(runtime.active_selection(comp).state=="NON_CARTORIG",
       "foreign Fusion selection must never be confused with CartoRig object")
runtime.select_system(comp,"camera")
expect(runtime.active_selection(comp).state=="SYSTEM" and
       runtime.active_selection(comp).role=="camera",
       "native shared Camera selection remains distinct from authored object")
runtime.select(comp,marker1)


-- Same camera applied to every geoanchored layer, all keys in native host.
runtime.focus(comp, -46.6333, -23.5505, 2)
expect(camera.inputs.Size == 2, "native Transform Size carries zoom")
expect(camera.inputs.CR2CameraLongitude == -46.6333 and
       camera.inputs.CR2CameraLatitude == -23.5505,
       "Focus changes only native geographic longitude and latitude")
runtime.focus(comp, -46.6333, -23.5505)
expect(camera.inputs.Size == 2, "Focus without zoom leaves camera scale untouched")
runtime.set_zoom(comp,3)
expect(camera.inputs.Size==3, "Set Zoom explicitly changes shared Fusion scale")
runtime.set_zoom(comp,2)
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
expect_failure(function()
    runtime.create_group(comp,"Do not silently regroup",{marker1,label})
end,"GROUP_CONFLICT")
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
expect(#comp:GetToolList() == priorCount - 4,
       "deletion removes marker control, mask, inverse zoom and Merge")
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
expect(find(comp,regionId,"highlight_color")~=nil and
    find(comp,regionId,"stroke_composite")~=nil,
    "Region has independent optional highlight color and contour composite")
expect(regionRender.links.Background==find(comp,regionId,"stroke_composite") and
    regionRender.links.Foreground==find(comp,regionId,"highlight_color"),
    "Highlight overlays the region with separate Fusion nodes")
expect(regionRender.inputs.Blend==0,
    "Region highlight starts at zero strength; no keys are generated")
local highlightBackground=find(comp,regionId,"highlight_color")
expect(highlightBackground.inputs.TopLeftRed==230/255 and
       highlightBackground.inputs.TopLeftGreen==198/255 and
       highlightBackground.inputs.TopLeftBlue==107/255,
       "Region Highlight Pulse uses specification tint #E6C66B")
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
expect(#comp.list==regionNodeCount-12,
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



-- The native Route Inspector's Draw Path must evaluate the full path,
-- including seam splits, rather than reveal two halves simultaneously.
comp.CurrentTime=200
routeControl.inputs.CR2MotionDuration=30
local beforeTool,beforeComp=_G.tool,_G.comp
_G.tool,_G.comp=routeControl,comp
local routeButton=assert((loadstring or load)(
    routeControl.UserControls.CR2MotionApply.BTNCS_Execute))
routeButton()
local firstPart=assert(routeControl:GetData("CartoRigAtomic.RouteSegmentsV2"))[1]
local firstRouteMask=find(comp,routeId,firstPart.role)
expect(firstRouteMask.animations.WriteLength[200]==0 and
       firstRouteMask.animations.WriteLength[230]==1,
       "native Route Draw Path keys animate the entire single-segment route")
expect(routeControl:GetData("CartoRigAtomic.MotionBindingV2").presetId=="MO-RTE-01",
       "Route Control preserves native Motion binding without Scene UIManager")
local datelineControl=find(comp,antimeridianId,"control")
local dataSegments=datelineControl:GetData("CartoRigAtomic.RouteSegmentsV2")
expect(#dataSegments==2 and dataSegments[1].length>0 and
       dataSegments[2].length>0,"multipart Route stores projected segment lengths")
comp.CurrentTime=250
datelineControl.inputs.CR2MotionDuration=30
_G.tool=datelineControl
local seamButton=assert((loadstring or load)(
    datelineControl.UserControls.CR2MotionApply.BTNCS_Execute))
seamButton()
local left=find(comp,antimeridianId,dataSegments[1].role)
local right=find(comp,antimeridianId,dataSegments[2].role)
local ratio=dataSegments[1].length/(dataSegments[1].length+dataSegments[2].length)
local seamFrame=250+math.floor(30*ratio+.5)
expect(left.animations.WriteLength[250]==0 and
       left.animations.WriteLength[seamFrame]==1,
       "east-side segment finishes at its proportional keyframe")
expect(right.animations.WriteLength[seamFrame]==0 and
       right.animations.WriteLength[280]==1,
       "west-side segment starts only when east-side segment finishes")
_G.tool,_G.comp=beforeTool,beforeComp


-- Scene lock is enforced by self-contained Inspector Motion callbacks too:
-- a locked object cannot be animated by bypassing the Scene UI.
local lockedId=runtime.add_marker(comp,"Locked Motion QA",0,0)
local lockedControl=find(comp,lockedId,"control")
local lockedMerge=find(comp,lockedId,"merge")
lockedControl.inputs.CR2MotionDuration=18
runtime.set_lock(comp,lockedId,true)
local savedTool,savedComp=_G.tool,_G.comp
_G.tool,_G.comp=lockedControl,comp
comp.CurrentTime=290
local lockedApply=assert((loadstring or load)(
    lockedControl.UserControls.CR2MotionApply.BTNCS_Execute))
lockedApply()
expect(next(lockedMerge.animations)==nil,
       "Inspector Motion must refuse locked authored object without writing keys")
runtime.set_lock(comp,lockedId,false)
lockedApply()
expect(lockedMerge.animations.Blend[290]==0 and
       lockedMerge.animations.Blend[308]==1,
       "Unlock restores independent native Inspector Motion on owned marker")
_G.tool,_G.comp=savedTool,savedComp


-- Additional Inspector-native presets: Region Fade Out and Route Erase.
local fadeRegionId=runtime.add_region(comp,state,statePolygon)
local fadeRegionControl=find(comp,fadeRegionId,"control")
local fadeRegionMerge=find(comp,fadeRegionId,"merge")
comp.CurrentTime=310
fadeRegionControl.inputs.CR2MotionDuration=24
local savedVariantTool,savedVariantComp=_G.tool,_G.comp
_G.tool,_G.comp=fadeRegionControl,comp
local fadeOutButton=assert((loadstring or load)(
    fadeRegionControl.UserControls.CR2MotionFadeOut.BTNCS_Execute))
fadeOutButton()
expect(fadeRegionMerge.animations.Blend[310]==1 and
       fadeRegionMerge.animations.Blend[334]==0,
       "Region Fade Out generates native keys from current opacity to zero")
expect(fadeRegionControl:GetData("CartoRigAtomic.MotionBindingV2").presetId==
       "MO-REG-02","Region Fade Out persists correct independent Motion ID")
local regionFadeInButton=assert((loadstring or load)(
    fadeRegionControl.UserControls.CR2MotionApply.BTNCS_Execute))
regionFadeInButton()
expect(fadeRegionMerge.animations.Blend[334]==0,
       "Second preset on animated Region opacity must not overwrite Spline")

local eraseRouteId=runtime.add_route(comp,origin,arrival,
    {destinationState=state,destinationGeometry=statePolygon,
     pathType="Straight",name="Erase Route"})
local eraseControl=find(comp,eraseRouteId,"control")
local eraseParts=eraseControl:GetData("CartoRigAtomic.RouteSegmentsV2")
local eraseMask=find(comp,eraseRouteId,eraseParts[1].role)
comp.CurrentTime=345
eraseControl.inputs.CR2MotionDuration=30
_G.tool=eraseControl
local eraseButton=assert((loadstring or load)(
    eraseControl.UserControls.CR2MotionErase.BTNCS_Execute))
eraseButton()
expect(eraseMask.animations.WriteLength[345]==1 and
       eraseMask.animations.WriteLength[375]==0,
       "Route Erase is the reverse temporal motion, not reversed geometry")
expect(eraseControl:GetData("CartoRigAtomic.MotionBindingV2").presetId==
       "MO-RTE-02","Route Erase carries its own persistent native Motion ID")
_G.tool,_G.comp=savedVariantTool,savedVariantComp


-- Region Fill Color changes target independent native channels, not Blend.
-- A Region can retain opacity fade while its Fill RGBA is separately animated.
local changedFillControl=fadeRegionControl
changedFillControl.inputs.CR2MotionDuration=24
changedFillControl.inputs.CR2ColorChosen=0
changedFillControl.inputs.CR2TargetRed=0
changedFillControl.inputs.CR2TargetGreen=1
changedFillControl.inputs.CR2TargetBlue=0
changedFillControl.inputs.CR2TargetAlpha=1
comp.CurrentTime=360
local saveColorTool,saveColorComp=_G.tool,_G.comp
_G.tool,_G.comp=changedFillControl,comp
local colorButton=assert((loadstring or load)(
    changedFillControl.UserControls.CR2MotionColorChange.BTNCS_Execute))
colorButton()
expect(changedFillControl.animations.TopLeftRed==nil,
       "Region Color Transition requires an explicitly confirmed target RGBA")
changedFillControl.inputs.CR2ColorChosen=1
colorButton()
expect(changedFillControl.animations.TopLeftRed[360]==130/255 and
       changedFillControl.animations.TopLeftRed[384]==0,
       "Region Color Transition animates only its own Red component")
expect(changedFillControl.animations.TopLeftGreen[360]==150/255 and
       changedFillControl.animations.TopLeftGreen[384]==1,
       "Green component retains correct source and target frames")
expect(changedFillControl.splineKeyframes.TopLeftRed[360].Flags.Linear==true,
       "Region Color Transition writes genuine native Linear interpolation")
expect(changedFillControl.animations.TopLeftAlpha[384]==1,
       "Color Transition preserves independent Fill Alpha")
local regionBindings=changedFillControl:GetData("CartoRigAtomic.MotionBindingsV2")
expect(regionBindings["Object Opacity"].presetId=="MO-REG-02" and
       regionBindings["Fill Color"].presetId=="MO-REG-03",
       "per-channel Motion binding registry preserves simultaneous Opacity and Fill presets")
expect(fadeRegionMerge.animations.Blend[334]==0,
       "Region Fill Color animation does not overwrite an existing Opacity Fade")
local instantId=runtime.add_region(comp,state,statePolygon)
local instantControl=find(comp,instantId,"control")
instantControl.inputs.CR2MotionDuration=24
instantControl.inputs.CR2ColorChosen=1
instantControl.inputs.CR2TargetRed=0
instantControl.inputs.CR2TargetGreen=1
instantControl.inputs.CR2TargetBlue=0
instantControl.inputs.CR2TargetAlpha=1
comp.CurrentTime=390
_G.tool=instantControl
local instantButton=assert((loadstring or load)(
    instantControl.UserControls.CR2MotionInstantColor.BTNCS_Execute))
instantButton()
expect(instantControl.animations.TopLeftRed[389]==130/255 and
       instantControl.animations.TopLeftRed[390]==0,
       "Instant Color Change uses source at frame 389 and target at frame 390")
expect(instantControl.animations.TopLeftGreen[389]==150/255 and
       instantControl.animations.TopLeftGreen[390]==1,
       "Instant Color Change respects discrete integer-frame switch")
expect(instantControl.splineKeyframes.TopLeftRed[389].Flags.StepIn==true,
       "Instant Color Change uses native StepIn hold rather than subframe blending")
expect(find(comp,instantId,"merge").animations.Blend==nil,
       "Instant Color Change never creates an opacity keyframe")
_G.tool,_G.comp=saveColorTool,saveColorComp


-- Region Border Draw reveals physical contour length, not RGBA or Blend.
local regionControlForBorder=instantControl
local borderParts=regionControlForBorder:GetData(
    "CartoRigAtomic.RegionStrokeSegmentsV2")
expect(type(borderParts)=="table" and #borderParts==3,
       "three independent Region rings have deterministic contour identities")
comp.CurrentTime=150
regionControlForBorder.inputs.CR2BorderDuration=36
local oldBorderTool,oldBorderComp=_G.tool,_G.comp
_G.tool,_G.comp=regionControlForBorder,comp
local borderButton=assert((loadstring or load)(
    regionControlForBorder.UserControls.CR2MotionBorderDraw.BTNCS_Execute))
borderButton()
local borderFirst=find(comp,instantId,borderParts[1].role)
local borderLast=find(comp,instantId,borderParts[#borderParts].role)
expect(borderFirst.animations.WriteLength[150]==0,
       "Region Border Draw starts at zero progress")
expect(borderLast.animations.WriteLength[186]==1,
       "Region Border Draw completes all rings at the exact final frame")
expect(regionControlForBorder:GetData("CartoRigAtomic.MotionBorderV2").presetId==
       "MO-REG-05","Border Draw owns independent native Spline provenance")
expect(regionControlForBorder.animations.TopLeftRed[390]==0,
       "Border Draw leaves existing independent Fill Color animation intact")
expect(find(comp,instantId,"merge").animations.Blend==nil,
       "Border Draw does not accidentally animate Object Opacity")
_G.tool,_G.comp=oldBorderTool,oldBorderComp


-- Highlight Pulse is isolated from the Region's Fill, border and outer Blend:
-- this Region already has both Color and Border Draw Spline keys.
local pulseControl=instantControl
local pulseLayer=find(comp,instantId,"render")
local previousTool,previousComp=_G.tool,_G.comp
_G.tool,_G.comp=pulseControl,comp
comp.CurrentTime=200
pulseControl.inputs.CR2PulseCount=2
pulseControl.inputs.CR2PulseCycle=18
pulseControl.inputs.CR2PulseStrength=.35
local pulseButton=assert((loadstring or load)(
    pulseControl.UserControls.CR2MotionPulse.BTNCS_Execute))
pulseButton()
expect(pulseLayer.animations.Blend[200]==0,
    "Highlight Pulse begins at zero independently of Region opacity")
expect(pulseLayer.animations.Blend[209]==.35 and
       pulseLayer.animations.Blend[218]==0,
    "first 18-frame pulse rises to peak and returns to zero")
expect(pulseLayer.animations.Blend[227]==.35 and
       pulseLayer.animations.Blend[236]==0,
    "second 18-frame pulse rises to peak and returns to zero")
expect(pulseControl:GetData("CartoRigAtomic.MotionHighlightV2").presetId==
       "MO-REG-06","Highlight Pulse has separate per-object native motion identity")
expect(pulseControl.animations.TopLeftRed[390]==0,
    "Highlight Pulse does not alter previously customized Region Fill")
expect(borderLast.animations.WriteLength[186]==1,
    "Highlight Pulse does not modify an independently animated Border Draw")
expect(find(comp,instantId,"merge").animations.Blend==nil,
    "Highlight Strength is independent of object opacity")
pulseButton()
expect(pulseLayer.animations.Blend[236]==0,
    "re-applying Highlight Pulse rejects existing Spline without overwriting")
_G.tool,_G.comp=previousTool,previousComp


-- Marker Pop In must be independent from existing Object Opacity Fade,
-- preserve geographic center, and use separate native Width/Height curves.
local prePopCenterX,prePopCenterY=mask1.inputs.Center[1],mask1.inputs.Center[2]
local prePopColor=control1.inputs.TopLeftRed
local savePopTool,savePopComp=_G.tool,_G.comp
_G.tool,_G.comp=control1,comp
comp.CurrentTime=250
control1.inputs.CR2PopDuration=18
control1.inputs.CR2PopSizePixels=14
local popButton=assert((loadstring or load)(
    control1.UserControls.CR2MotionPop.BTNCS_Execute))
popButton()
expect(mask1.animations.Width[250]==0 and
       mask1.animations.Height[250]==0,
       "Pop starts at zero size without changing geoanchor")
expect(math.abs(mask1.animations.Width[263]-
       1.15*14/1920)<1e-10 and
       math.abs(mask1.animations.Height[263]-
       1.15*14/1080)<1e-10,
       "Pop reaches 115 percent at the 70-percent integer frame")
expect(math.abs(mask1.animations.Width[268]-14/1920)<1e-10 and
       math.abs(mask1.animations.Height[268]-14/1080)<1e-10,
       "Pop settles to requested output-pixel dimensions")
expect(mask1.inputs.Center[1]==prePopCenterX and
       mask1.inputs.Center[2]==prePopCenterY,
       "Pop never moves author geographic coordinates")
expect(control1.inputs.TopLeftRed==prePopColor and
       merge1.animations.Blend[124]==1,
       "Marker Pop does not overwrite Color or independent Fade In")
expect(control1:GetData("CartoRigAtomic.MotionPopV2").presetId=="MO-MRK-02",
       "Pop native curves are identified on the authored Marker Control")
popButton()
expect(mask1.animations.Width[268]==14/1920,
       "Pop conflict prevents destructive overwrite of existing Size curves")
_G.tool,_G.comp=savePopTool,savePopComp


-- Fly To is separate from static Focus. The selected real city is stored
-- on the camera; keyframes are generated only when Motion is clicked.
local flyComp=new_comp()
flyComp:AddTool("MediaOut")
runtime.create(flyComp)
local flyScene=flyComp:GetData("CartoRigAtomic.SceneV2")
local flyCamera=find(flyComp,flyScene.cameraId,"camera")
runtime.focus(flyComp,179,0,2)
expect(flyCamera.inputs.CR2CameraLongitude==179 and
       flyCamera.inputs.CR2CameraLatitude==0,
       "static Camera Focus retains correct WGS84 longitude and latitude")
expect_failure(function()
    runtime.set_fly_target(flyComp,
        {id="ne10m:state:xx",kind="State",name="Amapá"},4)
end,"TARGET_REQUIRED")
expect_failure(function()
    runtime.set_fly_target(flyComp,
        {id="ne10m:city:xx",kind="City",point={lon=-179,lat=1}},0)
end,"INVALID_ZOOM")
local flyFeature={
    id="ne10m:city:west",kind="City",name="Dateline West",
    country="Test",point={lon=-179,lat=1}
}
runtime.set_fly_target(flyComp,flyFeature,4)
expect(next(flyCamera.animations)==nil,
       "choosing Fly Target never adds implicit keyframes")
expect(flyCamera:GetData("CartoRigAtomic.CameraFlyTargetV2").featureId==
       flyFeature.id,"explicit City sourceRef persists with camera")
flyComp.CurrentTime=100
function flyComp:GetAttrs()return {COMPN_RenderEnd=400}end
flyCamera.inputs.CR2FlyDuration=45
local savedFlyTool,savedFlyComp=_G.tool,_G.comp
_G.tool,_G.comp=flyCamera,flyComp
local flyApply=assert((loadstring or load)(
    flyCamera.UserControls.CR2MotionFly.BTNCS_Execute))
flyApply()
expect(flyCamera.animations.CR2CameraLongitude[100]==179 and
       flyCamera.animations.CR2CameraLongitude[145]==181,
       "Fly To traverses 179 to -179 by the shortest 2 degree arc")
expect(flyCamera.animations.CR2CameraLatitude[100]==0 and
       flyCamera.animations.CR2CameraLatitude[145]==1,
       "Fly To owns a separate latitude Spline")
expect(flyCamera.animations.Size[100]==2 and
       flyCamera.animations.Size[145]==4,
       "Fly To owns a separate native Zoom Spline")
expect(flyCamera:GetData("CartoRigAtomic.MotionFlyV2").presetId=="MO-CAM-01",
       "native Fly To binding survives closing UIManager")
expect(flyCamera.expressions.Center:find("CR2CameraLongitude",1,true),
       "Fusion Center expression remains active under native Camera animation")
expect_failure(function()runtime.focus(flyComp,0,0)end,
       "MOTION_CONFLICT")
expect_failure(function()runtime.set_zoom(flyComp,3)end,
       "MOTION_CONFLICT")
flyApply()
expect(flyCamera.animations.Size[145]==4,
       "re-applying Fly To does not overwrite existing Zoom/position keys")
_G.tool,_G.comp=savedFlyTool,savedFlyComp


-- Fit uses the minimum circular longitude interval and explicit WGS84
-- extents; no auto marker, centroid or motion is introduced.
local fitPoint=runtime.compute_fit({
    {id="ne10m:city:sp",kind="City",
     point={lon=-46.6333,lat=-23.5505}}
},.1)
expect(math.abs(fitPoint.longitude+46.6333)<1e-7 and
       math.abs(fitPoint.latitude+23.5505)<1e-7 and
       fitPoint.zoom==4,
       "single City uses source geoanchor and documented 4x point reference")
local fitCross=runtime.compute_fit({
    {id="ne10m:city:east",kind="City",point={lon=179,lat=0}},
    {id="ne10m:city:west",kind="City",point={lon=-179,lat=1}}
},.1)
expect(math.abs(fitCross.longitude-180)<1e-7 and
       math.abs(fitCross.longitudeSpanDegrees-2)<1e-7,
       "Fit treats dateline cities as two degrees apart, not 358")
local islandFit=runtime.compute_fit({
    {id="ne10m:state:dateline",kind="State",
     geometry={id="ne10m:state:dateline",rings={
         {kind="O",vertices={
             {lon=179,lat=0},{lon=180,lat=0},{lon=180,lat=1}}},
         {kind="O",vertices={
             {lon=-180,lat=0},{lon=-179,lat=0},{lon=-179,lat=1}}}
     }}}
},.1)
expect(islandFit.longitudeSpanDegrees<=2.01 and
       islandFit.latitudeSpanDegrees==1,
       "multipart Region Fit includes both dateline islands without world-spanning bounds")
local wideFit=runtime.compute_fit({
    {id="ne10m:country:west",kind="Country",
     geometry={id="ne10m:country:west",rings={
         {kind="O",vertices={
             {lon=-80,lat=-40},{lon=-20,lat=-40},{lon=-20,lat=10}}}
     }}},
    {id="ne10m:country:east",kind="Country",
     geometry={id="ne10m:country:east",rings={
         {kind="O",vertices={
             {lon=0,lat=-5},{lon=80,lat=-5},{lon=80,lat=45}}}
     }}}
},.1)
expect(wideFit.longitudeSpanDegrees==160 and
       wideFit.latitudeSpanDegrees==85 and
       wideFit.zoom>1 and wideFit.zoom<3,
       "Fit across multiple countries respects full extent and padding")
expect_failure(function()runtime.compute_fit({},.1)end,"FIT_TARGET_REQUIRED")
expect_failure(function()runtime.compute_fit({
    {id="ne10m:city:sp",point={lon=-46,lat=-23}}},.5)
end,"INVALID_PADDING")
expect_failure(function()runtime.compute_fit({
    {id="ne10m:state:missing",kind="State"}
},.1)end,"FIT_TARGET_REQUIRED")
expect_failure(function()runtime.compute_fit({
    {id="ne10m:state:one",kind="State",
     geometry={id="ne10m:state:two",rings=statePolygon.rings}}
},.1)end,"NO_GEOMETRY")

local fitComp=new_comp()
fitComp:AddTool("MediaOut")
runtime.create(fitComp)
local fitScene=fitComp:GetData("CartoRigAtomic.SceneV2")
local fitCamera=find(fitComp,fitScene.cameraId,"camera")
runtime.set_fit_target(fitComp,{
    {id="ne10m:city:east",kind="City",point={lon=179,lat=0}},
    {id="ne10m:city:west",kind="City",point={lon=-179,lat=1}}
},.1)
local targetPose=fitCamera:GetData("CartoRigAtomic.CameraFitTargetV2")
expect(#targetPose.featureIds==2 and
       targetPose.projection=="Equirectangular",
       "Fit Target persists explicit source identities and projection")
expect(next(fitCamera.animations)==nil,
       "choosing Fit Targets does not generate any automatic keyframes")
fitComp.CurrentTime=100
function fitComp:GetAttrs()return {COMPN_RenderEnd=400}end
fitCamera.inputs.CR2FitDuration=45
local savedFitTool,savedFitComp=_G.tool,_G.comp
_G.tool,_G.comp=fitCamera,fitComp
local fitApply=assert((loadstring or load)(
    fitCamera.UserControls.CR2MotionFit.BTNCS_Execute))
fitApply()
expect(fitCamera.animations.CR2CameraLongitude[100]==0 and
       fitCamera.animations.CR2CameraLongitude[145]==180,
       "Fit Transition animates independent longitude to the selected dateline extent")
expect(fitCamera.animations.CR2CameraLatitude[100]==0 and
       fitCamera.animations.CR2CameraLatitude[145]==.5,
       "Fit Transition animates independent latitude to geographic bbox center")
expect(fitCamera.animations.Size[100]==1 and
       fitCamera.animations.Size[145]==targetPose.zoom,
       "Fit Transition animates native Zoom to precomputed padded target pose")
expect(fitCamera:GetData("CartoRigAtomic.MotionFitV2").presetId=="MO-CAM-03",
       "Fit Transition persists genuine Fusion Spline motion identity")
expect(#fitCamera:GetData("CartoRigAtomic.MotionFitV2").sourceIds==2,
       "Fit retains explicitly chosen multi-object target identities")
fitApply()
expect(fitCamera.animations.Size[145]==targetPose.zoom,
       "re-applying Fit Transition refuses to overwrite native Spline curves")
_G.tool,_G.comp=savedFitTool,savedFitComp



-- Route Follow Path uses route-space cumulative lengths and one native
-- Progress curve while the Marker position is driven by a persistent Fusion
-- expression. No marker is created implicitly and its original anchor stays
-- recoverable if the follower is explicitly unlinked.
local followRoute=find(comp,routeId,"control")
local followSamples=followRoute:GetData("CartoRigAtomic.RoutePolylineV2")
local p0=runtime.route_point_at(followSamples,0)
local p25=runtime.route_point_at(followSamples,.25)
local p50=runtime.route_point_at(followSamples,.5)
local p75=runtime.route_point_at(followSamples,.75)
local p100=runtime.route_point_at(followSamples,1)
expect(math.abs(p0.lon-origin.lon)<1e-10 and
       math.abs(p0.lat-origin.lat)<1e-10,
       "Follow Path 0% corresponds to explicitly chosen origin")
expect(math.abs(p100.lon-arrival.lon)<1e-10 and
       math.abs(p100.lat-arrival.lat)<1e-10,
       "Follow Path 100% corresponds to explicitly chosen destination")
expect(p25.lat>p0.lat and p50.lat>p25.lat and
       p75.lat>p50.lat and p100.lat>p75.lat,
       "0/25/50/75/100% follower samples move monotonically along route")
expect_failure(function()
    runtime.route_point_at(followSamples,1.5)
end,"INVALID_PROGRESS")
local beforeFollowCenter={mask1.inputs.Center[1],mask1.inputs.Center[2]}
expect(runtime.link_follower(comp,routeId,marker1)==true,
       "Link follower chooses existing authored Marker explicitly")
expect(mask1.expressions.Center:find("CR2FollowerProgress",1,true)~=nil,
       "Marker Center reacts to the Route's native Follower Progress")
expect(markerScale.expressions.Center:find("CR2_Mask_1.Center",1,true) and
       markerScale.expressions.Pivot:find("CR2_Mask_1.Center",1,true),
       "route follower moves the constant-pixel Marker together with its anchor")
expect(mask1:GetData("CartoRigAtomic.FollowerLinkV2").routeId==routeId,
       "Follower preserves the original anchor and its source Route ID")
expect(followRoute:GetData("CartoRigAtomic.RouteFollowerV2").markerId==marker1,
       "Route stores explicit existing follower identity")
expect_failure(function()runtime.link_follower(comp,antimeridianId,marker1)end,
       "FOLLOWER_CONFLICT")
expect_failure(function()runtime.remove(comp,marker1)end,
       "FOLLOWER_LINK_ACTIVE")
expect_failure(function()runtime.remove(comp,routeId)end,
       "FOLLOWER_LINK_ACTIVE")
comp.CurrentTime=100
followRoute.inputs.CR2FollowDuration=60
local savedFollowTool,savedFollowComp=_G.tool,_G.comp
_G.tool,_G.comp=followRoute,comp
local followApply=assert((loadstring or load)(
    followRoute.UserControls.CR2MotionFollow.BTNCS_Execute))
followApply()
expect(followRoute.animations.CR2FollowerProgress[100]==0 and
       followRoute.animations.CR2FollowerProgress[160]==1,
       "Route Follow Path creates native Spline progress 0 to 1 in 60 frames")
expect(followRoute.splineKeyframes.CR2FollowerProgress[100].Flags.Linear==true,
       "Follow Path uses native Linear interpolation for arc-length progress")
expect(followRoute:GetData("CartoRigAtomic.MotionFollowerV2").presetId==
       "MO-RTE-03","route owns separate persistent native Motion identity")
expect(mask1.animations.Width[268]==14/1920 and
       merge1.animations.Blend[124]==1,
       "Follower Progress never modifies Marker Size or Fade In")
followApply()
expect(followRoute.animations.CR2FollowerProgress[160]==1,
       "Follower Progress conflict preserves existing Spline")
_G.tool,_G.comp=savedFollowTool,savedFollowComp
expect(runtime.unlink_follower(comp,routeId)==true,
       "Unlink follower is an explicit independent Undo action")
expect(mask1.expressions.Center==nil,
       "Unlink removes only the generated native Center expression")
expect(mask1.inputs.Center[1]==beforeFollowCenter[1] and
       mask1.inputs.Center[2]==beforeFollowCenter[2],
       "Unlink restores the authored Marker WGS84 anchor")
expect(followRoute.animations.CR2FollowerProgress[160]==1,
       "Unlink preserves customized timeline progress as manual animation")
expect(followRoute:GetData("CartoRigAtomic.MotionFollowerV2").state==
       "KEPT_AS_MANUAL",
       "Unlinked follower retains native keys explicitly labelled manual")
expect(runtime.inspect(comp).objects[1].followingRouteId==nil,
       "scene no longer contains a stale follower marker reference")


-- Duplicate creates an independently authored Fusion object, preserving
-- its original source reference, style, and native BezierSpline keys.
local copyComp=new_comp()
copyComp:AddTool("MediaOut")
runtime.create(copyComp)
local originalId=runtime.add_marker(copyComp,"São Paulo",-46.6333,-23.5505)
local originalControl=find(copyComp,originalId,"control")
local originalMask=find(copyComp,originalId,"mask")
local originalMerge=find(copyComp,originalId,"merge")
originalControl:SetInput("TopLeftRed",.125)
originalMask:AddModifier("Width","BezierSpline")
originalMask:SetInput("Width",0,20)
originalMask:SetInput("Width",.018,40)
runtime.fade_in(copyComp,originalId,20,20)
originalControl:SetData("CartoRigAtomic.MotionBindingsV2",{
    ["Object Opacity"]={presetId="MO-MRK-01"}
})
local beforeCopyUndo=#copyComp.undo
local duplicatedId=runtime.duplicate(copyComp,originalId)
expect(duplicatedId~=originalId,
       "duplicate receives a fresh authored object ID")
expect(#copyComp.undo==beforeCopyUndo+1 and
       copyComp.undo[#copyComp.undo].label=="CartoRig: Duplicate Object",
       "cloning all subtools and their curves is ONE Fusion Undo step")
local dupeCtrl=find(copyComp,duplicatedId,"control")
local duplicatedScale=find(copyComp,duplicatedId,"screenScale")
expect(duplicatedScale and duplicatedScale.ID=="Transform" and
       duplicatedScale.expressions.Size:find("CR2_Camera.Size",1,true),
       "Duplicated Marker recreates independent screen-size compensation")
expect(duplicatedScale~=find(copyComp,originalId,"screenScale"),
       "cloned screen-size compensation does not reuse the source node")
local dupeMask=find(copyComp,duplicatedId,"mask")
local dupeMerge=find(copyComp,duplicatedId,"merge")
expect(dupeCtrl.inputs.TopLeftRed==.125,
       "duplicate copies the actual overridden Fill Color")
expect(dupeMask.animations.Width[20]==0 and
       dupeMask.animations.Width[40]==.018,
       "duplicate preserves independent native Marker Size keys")
expect(dupeMerge.animations.Blend[20]==0 and
       dupeMerge.animations.Blend[40]==1,
       "duplicate preserves native Fade In keys at original frames")
expect(find(copyComp,originalId,"merge")==originalMerge,
       "original Fusion tool remains independently authored")
local snapshot=runtime.inspect(copyComp)
expect(#snapshot.objects==2 and snapshot.objects[2].id==duplicatedId,
       "duplicate is separately listed in Scene order")
expect(dupeCtrl:GetData("CartoRigAtomic.MotionBindingsV2")["Object Opacity"]
       .presetId=="MO-MRK-01",
       "duplicate persists independent Motion provenance")
dupeCtrl:GetData("CartoRigAtomic.MotionBindingsV2")["Object Opacity"]
    .presetId="MO-MRK-99"
expect(originalControl:GetData("CartoRigAtomic.MotionBindingsV2")
       ["Object Opacity"].presetId=="MO-MRK-01",
       "Motion metadata tables are deep copied, never shared by reference")
dupeMerge.animations.Blend[20]=.3
expect(originalMerge.animations.Blend[20]==0,
       "editing duplicated Spline cannot change the original animation")
runtime.set_lock(copyComp,originalId,true)
expect_failure(function()runtime.duplicate(copyComp,originalId)end,"LOCKED")
runtime.set_lock(copyComp,originalId,false)

local labelOriginal=runtime.add_label(copyComp,"Brasília",-47.88,-15.8)
local labelDuplicate=runtime.duplicate(copyComp,labelOriginal)
expect(labelDuplicate~=labelOriginal and
       find(copyComp,labelDuplicate,"control").inputs.StyledText=="Brasília",
       "Label duplicates visible text and obtains independent geoanchor")

local geometryProvider={
    get=function(_,id)
        if id==statePolygon.id then return statePolygon end
        return nil
    end
}
local regionOriginal=runtime.add_region(copyComp,state,statePolygon)
local regionSource=find(copyComp,regionOriginal,"control")
regionSource:SetInput("TopLeftBlue",.33)
local regionDuplicate=runtime.duplicate(copyComp,regionOriginal,geometryProvider)
expect(regionDuplicate~=regionOriginal and
       find(copyComp,regionDuplicate,"control").inputs.TopLeftBlue==.33,
       "Region duplicates original geographic polygon and Fill override")
expect(find(copyComp,regionDuplicate,"shape1") and
       find(copyComp,regionDuplicate,"shape6"),
       "Region duplicates exterior, holes and independent stroke subtools")

local routeOriginal=runtime.add_route(copyComp,origin,arrival,{
    destinationState=state,destinationGeometry=statePolygon,
    pathType="Straight",name="Brasília to Macapá"
})
local routeDuplicate=runtime.duplicate(copyComp,routeOriginal,geometryProvider)
expect(routeDuplicate~=routeOriginal and
       find(copyComp,routeDuplicate,"control")~=nil,
       "Route duplicate reconstructs real endpoints and native path")
local clonedRoute=copyComp:GetData("CartoRigAtomic.SceneV2").objects[
    #copyComp:GetData("CartoRigAtomic.SceneV2").objects].route
expect(clonedRoute.to.sourceId==arrival.id and
       clonedRoute.destinationStateId==state.id,
       "Route duplicate preserves explicit arrival and state provenance")
expect(#runtime.inspect(copyComp).objects==8,
       "four originals and four clones remain independent Scene objects")

print("PASS: " .. checks .. " original Fusion graph / Control / Motion assertions")
