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


-- A Fusion UserControl button owns its callback.  Unlike UIManager callbacks,
-- it remains available on the saved tool after CartoRig Scene has been closed.
-- It writes the host's native BezierSpline.  No external runtime, server or
-- simulated keyframe timeline is involved.
local function inspector_motion_callback(kind)
    local selectedKind = kind
    local code = [==[
local function cartorig_apply()
    local selected = tool
    if not selected then error("HOST_TOOL: selected Fusion tool unavailable") end
    local host = selected.Comp or
        (rawget(_G, "fu") and fu.CurrentComp) or rawget(_G, "comp")
    if not host then error("HOST_COMP: active Fusion comp unavailable") end
    local identity = selected:GetData("CartoRigAtomic.IdentityV2")
    if type(identity) ~= "table" or identity.role ~= "control" and
        identity.role ~= "camera" then
        error("OBJECT_ID: selected tool is not an authored CartoRig object")
    end
    local requestedKind = "%%KIND%%"
    local kind = requestedKind == "RegionFadeOut" and "Region" or
        requestedKind == "RouteErase" and "Route" or requestedKind
    local scene=host:GetData("CartoRigAtomic.SceneV2")
    if type(scene)~="table" or scene.sceneId~=identity.sceneId then
        error("SCENE_CONTEXT: Authored scene does not match selected Fusion tool")
    end
    if kind~="Camera" then
        local found=false
        for _,obj in ipairs(scene.objects or {}) do
            if obj.id==identity.objectId then
                found=true
                if obj.locked then
                    error("LOCKED: Unlock this object in Scene before applying Motion")
                end
                if obj.visible==false then
                    error("HIDDEN: Show this object before applying Motion")
                end
                break
            end
        end
        if not found then
            error("OBJECT_ID: Selected object was removed from CartoRig Scene")
        end
    end
    local duration = tonumber(selected:GetInput("CR2MotionDuration"))
    local now = tonumber(host.CurrentTime)
    if not now or now%1~=0 or now<0 then
        error("FRAME_INVALID: select a valid integer Fusion playhead frame")
    end
    if not duration or duration%1~=0 or duration<1 or duration>10000 then
        error("DURATION_INVALID: choose an integer duration 1..10000")
    end
    local attrs = host:GetAttrs()
    local last = attrs and tonumber(attrs.COMPN_RenderEnd)
    if not last or now+duration>last then
        error("FRAME_OUT_OF_RANGE: Motion extends past Fusion render range")
    end
    local actor
    local routeActors
    local propertyName
    local preset
    if kind=="Camera" then
        actor=selected
        propertyName="Size"
        preset="MO-CAM-02"
    elseif kind=="Route" then
        preset=requestedKind=="RouteErase" and "MO-RTE-02" or "MO-RTE-01"
        propertyName="WriteLength"
        local segments=selected:GetData("CartoRigAtomic.RouteSegmentsV2")
        if type(segments)~="table" or #segments<1 then
            error("ROUTE_GEOMETRY: Route has no resolved vector segments")
        end
        routeActors={}
        for _,part in ipairs(segments) do
            local found
            for _,candidate in pairs(host:GetToolList(false) or {}) do
                local ok,tag=pcall(function()
                    return candidate:GetData("CartoRigAtomic.IdentityV2")
                end)
                if ok and type(tag)=="table" and
                    tag.sceneId==identity.sceneId and
                    tag.objectId==identity.objectId and
                    tag.role==part.role then
                    found=candidate
                    break
                end
            end
            if not found or not found.WriteLength then
                error("ROUTE_GEOMETRY: Route path mask is missing or disconnected")
            end
            local ok,existing=pcall(function()
                return found.WriteLength:GetConnectedOutput()
            end)
            if not ok or existing then
                error("MOTION_CONFLICT: Route Write Length is already animated")
            end
            routeActors[#routeActors+1]={
                tool=found, length=tonumber(part.length) or 0
            }
        end
        actor=routeActors[1].tool
    else
        preset=kind=="Marker" and "MO-MRK-01" or
               kind=="Region" and (requestedKind=="RegionFadeOut" and
                   "MO-REG-02" or "MO-REG-01") or "MO-LBL-01"
        propertyName="Blend"
        for _,candidate in pairs(host:GetToolList(false) or {}) do
            local ok, tag=pcall(function()
                return candidate:GetData("CartoRigAtomic.IdentityV2")
            end)
            if ok and type(tag)=="table" and
                tag.sceneId==identity.sceneId and
                tag.objectId==identity.objectId and tag.role=="merge" then
                actor=candidate
                break
            end
        end
    end
    if not actor then error("HOST_GRAPH: authored Motion target is missing") end
    local link=actor[propertyName]
    if not link then error("HOST_CHANNEL: Fusion input is unavailable") end
    local ok, existing=pcall(function()return link:GetConnectedOutput()end)
    if not ok then error("HOST_CHANNEL: cannot inspect native animation") end
    if existing then
        error("MOTION_CONFLICT: channel already has animation. Review in Spline.")
    end
    local current=tonumber(actor:GetInput(propertyName))
    if not current then error("HOST_VALUE: channel value unavailable") end
    local target, startValue
    if kind=="Camera" then
        target=tonumber(selected:GetInput("CR2TargetZoom"))
        if not target or target<=0 or target>100 then
            error("TARGET_REQUIRED: Camera Zoom must be 0..100")
        end
        startValue=current
    elseif kind=="Route" then
        startValue=requestedKind=="RouteErase" and 1 or 0
        target=1-startValue
    else
        if current<=0 then error("TARGET_REQUIRED: opacity must be positive") end
        startValue=requestedKind=="RegionFadeOut" and current or 0
        target=requestedKind=="RegionFadeOut" and 0 or current
    end
    host:StartUndo("CartoRig: "..preset)
    local applied, reason=pcall(function()
        if kind=="Route" then
            local total=0
            for _,part in ipairs(routeActors) do total=total+part.length end
            if total<=0 then error("GEOMETRY_FORMAT: Empty route path") end
            local consumed=0
            local reversing=requestedKind=="RouteErase"
            for index=1,#routeActors do
                local part=routeActors[reversing and (#routeActors-index+1) or index]
                local first=now+math.floor(duration*(consumed/total)+.5)
                consumed=consumed+part.length
                local lastFrame=now+math.floor(duration*(consumed/total)+.5)
                if lastFrame<=first then
                    error("FRAME_COLLISION: Too little duration for multipart Route")
                end
                if not part.tool:AddModifier("WriteLength","BezierSpline") then
                    error("HOST_ANIMATION: Fusion rejected Route progress Spline")
                end
                local beginning=reversing and 1 or 0
                local ending=1-beginning
                part.tool:SetInput("WriteLength",beginning,now)
                if first>now then
                    part.tool:SetInput("WriteLength",beginning,first)
                end
                part.tool:SetInput("WriteLength",ending,lastFrame)
                if lastFrame<now+duration then
                    part.tool:SetInput("WriteLength",ending,now+duration)
                end
            end
        else
            if not actor:AddModifier(propertyName,"BezierSpline") then
                error("HOST_ANIMATION: Fusion rejected BezierSpline")
            end
            actor:SetInput(propertyName,startValue,now)
            actor:SetInput(propertyName,target,now+duration)
        end
        selected:SetData("CartoRigAtomic.MotionBindingV2",{
            presetId=preset,channel=propertyName,
            startFrame=now,endFrame=now+duration,
            schemaVersion=2,state="ANIMATED_PRESET"
        })
    end)
    host:EndUndo(applied)
    if not applied then error(reason) end
end
local ok,err=pcall(cartorig_apply)
if not ok then print("CartoRig Motion: "..tostring(err)) end
]==]
    return code:gsub("%%%%KIND%%%%", selectedKind)
end

-- A Region's fill RGBA channels are actual native Background inputs. These
-- callbacks make no style edits outside this object's Fill Color.
local function region_color_callback(instant)
    local text=[==[
local function cartorig_color()
    local obj=tool
    local host=obj and (obj.Comp or (rawget(_G,"fu") and fu.CurrentComp)
        or rawget(_G,"comp"))
    if not host then error("HOST_COMP: Fusion composition unavailable") end
    local tag=obj:GetData("CartoRigAtomic.IdentityV2")
    if type(tag)~="table" or tag.role~="control" then
        error("OBJECT_ID: Region Control identity not found")
    end
    local scene=host:GetData("CartoRigAtomic.SceneV2")
    if type(scene)~="table" or scene.sceneId~=tag.sceneId then
        error("SCENE_CONTEXT: Fusion composition changed")
    end
    local owned=false
    for _,entry in ipairs(scene.objects or {}) do
        if entry.id==tag.objectId then
            owned=true
            if entry.kind~="Region" then error("INCOMPATIBLE_OBJECT: Not a Region") end
            if entry.locked or entry.visible==false then
                error("LOCKED: Region must be visible and unlocked")
            end
            break
        end
    end
    if not owned then error("OBJECT_MISSING: Region no longer belongs to Scene") end
    if tonumber(obj:GetInput("CR2ColorChosen"))~=1 then
        error("TARGET_REQUIRED: Choose and confirm a target RGBA fill")
    end
    local isInstant=%%INSTANT%%
    local now=tonumber(host.CurrentTime)
    local duration=tonumber(obj:GetInput("CR2MotionDuration"))
    local endFrame=isInstant and now or now+duration
    local attrs=host:GetAttrs()
    if not now or now%1~=0 or now<0 or
        not duration or duration%1~=0 or duration<1 or
        not attrs or not tonumber(attrs.COMPN_RenderEnd) or
        endFrame>tonumber(attrs.COMPN_RenderEnd) then
        error("FRAME_OUT_OF_RANGE: Motion must stay within the Fusion composition")
    end
    local channels={"TopLeftRed","TopLeftGreen","TopLeftBlue","TopLeftAlpha"}
    local targetNames={"CR2TargetRed","CR2TargetGreen","CR2TargetBlue","CR2TargetAlpha"}
    local source,target={},{}
    for i,channel in ipairs(channels) do
        local port=obj[channel]
        if not port then error("HOST_CHANNEL: Missing Fill Color component") end
        local ok,connected=pcall(function()return port:GetConnectedOutput()end)
        if not ok or connected then
            error("MOTION_CONFLICT: Fill Color channel is already animated")
        end
        source[i]=tonumber(obj:GetInput(channel))
        target[i]=tonumber(obj:GetInput(targetNames[i]))
        if not source[i] or not target[i] or target[i]<0 or target[i]>1 then
            error("INVALID_COLOR: RGBA must be within 0..1")
        end
    end
    local preset=isInstant and "MO-REG-04" or "MO-REG-03"
    host:StartUndo("CartoRig: "..preset)
    local completed,reason=pcall(function()
        for i,channel in ipairs(channels) do
            if not obj:AddModifier(channel,"BezierSpline") then
                error("HOST_ANIMATION: Cannot animate Region Fill Color")
            end
            if isInstant then
                if now>0 then obj:SetInput(channel,source[i],now-1) end
                obj:SetInput(channel,target[i],now)
            else
                obj:SetInput(channel,source[i],now)
                obj:SetInput(channel,target[i],endFrame)
            end
        end
        local binding={
            presetId=preset,channels=channels,
            startFrame=now,endFrame=endFrame,
            schemaVersion=2,state="ANIMATED_PRESET"
        }
        obj:SetData("CartoRigAtomic.MotionBindingV2",binding)
    end)
    host:EndUndo(completed)
    if not completed then error(reason) end
end
local ok,why=pcall(cartorig_color)
if not ok then print("CartoRig Region Color: "..tostring(why)) end
]==]
    return text:gsub("%%%%INSTANT%%%%",instant and "true" or "false")
end

-- Border Draw owns only vector stroke WriteLength curves. Fill Color,
-- Fill Alpha, Stroke Width and existing Object Opacity curves remain untouched.
local function region_border_callback()
    return [==[
local function apply()
    local selected=tool
    local host=selected and (selected.Comp or
        (rawget(_G,"fu") and fu.CurrentComp) or rawget(_G,"comp"))
    if not host then error("HOST_COMP: Fusion composition unavailable") end
    local tag=selected:GetData("CartoRigAtomic.IdentityV2")
    if type(tag)~="table" or tag.role~="control" then
        error("OBJECT_ID: Region Control is unavailable")
    end
    local scene=host:GetData("CartoRigAtomic.SceneV2")
    if type(scene)~="table" or scene.sceneId~=tag.sceneId then
        error("SCENE_CONTEXT: Current Fusion composition changed")
    end
    local valid=false
    for _,obj in ipairs(scene.objects or {}) do
        if obj.id==tag.objectId then
            if obj.kind~="Region" then
                error("INCOMPATIBLE_OBJECT: Border Draw applies only to Region")
            end
            if obj.locked or obj.visible==false then
                error("LOCKED: Region must be visible and unlocked")
            end
            valid=true
            break
        end
    end
    if not valid then error("OBJECT_MISSING: Region was deleted") end
    local items=selected:GetData("CartoRigAtomic.RegionStrokeSegmentsV2")
    if type(items)~="table" or #items<1 then
        error("GEOMETRY_REQUIRED: No visible Region contour segments")
    end
    local now=tonumber(host.CurrentTime)
    local duration=tonumber(selected:GetInput("CR2BorderDuration"))
    local attrs=host:GetAttrs()
    if not now or now<0 or now%1~=0 or not duration or
       duration<1 or duration>10000 or duration%1~=0 or
       not attrs or not tonumber(attrs.COMPN_RenderEnd) or
       now+duration>tonumber(attrs.COMPN_RenderEnd) then
        error("FRAME_OUT_OF_RANGE: Invalid Region Border Draw interval")
    end
    local total=0
    local parts={}
    for _,entry in ipairs(items) do
        local length=tonumber(entry.length)
        if not length or length<=0 then
            error("GEOMETRY_REQUIRED: Empty Region polygon contour")
        end
        local found
        for _,candidate in pairs(host:GetToolList(false) or {}) do
            local ok,identity=pcall(function()
                return candidate:GetData("CartoRigAtomic.IdentityV2")
            end)
            if ok and type(identity)=="table" and
               identity.sceneId==tag.sceneId and
               identity.objectId==tag.objectId and
               identity.role==entry.role then
                found=candidate
                break
            end
        end
        if not found or not found.WriteLength then
            error("HOST_GRAPH: Region contour mask is unavailable")
        end
        local ok,connected=pcall(function()
            return found.WriteLength:GetConnectedOutput()
        end)
        if not ok or connected then
            error("MOTION_CONFLICT: Stroke Progress already animated")
        end
        parts[#parts+1]={tool=found,length=length}
        total=total+length
    end
    host:StartUndo("CartoRig: MO-REG-05 Border Draw")
    local success,reason=pcall(function()
        local consumed=0
        for _,entry in ipairs(parts) do
            local first=now+math.floor(duration*(consumed/total)+.5)
            consumed=consumed+entry.length
            local last=now+math.floor(duration*(consumed/total)+.5)
            if not entry.tool:AddModifier("WriteLength","BezierSpline") then
                error("HOST_ANIMATION: Region contour cannot be animated")
            end
            -- For a ring shorter than one output frame, use adjacent integer
            -- samples; never collapse two different keys onto one frame.
            if last<=first then
                last=math.min(now+duration,first+1)
                first=math.max(now,last-1)
            end
            entry.tool:SetInput("WriteLength",0,now)
            if first>now then entry.tool:SetInput("WriteLength",0,first) end
            entry.tool:SetInput("WriteLength",1,last)
            if last<now+duration then
                entry.tool:SetInput("WriteLength",1,now+duration)
            end
        end
        selected:SetData("CartoRigAtomic.MotionBorderV2",{
            schemaVersion=2,presetId="MO-REG-05",channel="Stroke Progress",
            startFrame=now,endFrame=now+duration,state="ANIMATED_PRESET"
        })
    end)
    host:EndUndo(success)
    if not success then error(reason) end
end
local ok,reason=pcall(apply)
if not ok then print("CartoRig Border Draw: "..tostring(reason)) end
]==]
end

-- Region Highlight Pulse is a self-contained Inspector action. Its
-- BezierSpline belongs to the optional highlight Merge's Blend, *never* to
-- the Region's Fill, Border, or outer Object Opacity channels.
local function region_highlight_callback()
    return [==[
local function pulse()
    local selected=tool
    local host=selected and (selected.Comp or
        (rawget(_G,"fu") and fu.CurrentComp) or rawget(_G,"comp"))
    if not host then error("HOST_COMP: Fusion composition unavailable") end
    local tag=selected:GetData("CartoRigAtomic.IdentityV2")
    if type(tag)~="table" or tag.role~="control" then
        error("OBJECT_ID: Region Control was not selected")
    end
    local scene=host:GetData("CartoRigAtomic.SceneV2")
    if type(scene)~="table" or scene.sceneId~=tag.sceneId then
        error("SCENE_CONTEXT: Wrong Fusion composition")
    end
    local owned=false
    for _,entry in ipairs(scene.objects or {}) do
        if entry.id==tag.objectId then
            owned=true
            if entry.kind~="Region" then
                error("INCOMPATIBLE_OBJECT: Highlight Pulse requires Region")
            end
            if entry.locked or entry.visible==false then
                error("LOCKED: Region must be visible and unlocked")
            end
            break
        end
    end
    if not owned then error("OBJECT_MISSING: Region no longer exists") end
    local cycles=tonumber(selected:GetInput("CR2PulseCount"))
    local cycle=tonumber(selected:GetInput("CR2PulseCycle"))
    local peak=tonumber(selected:GetInput("CR2PulseStrength"))
    local start=tonumber(host.CurrentTime)
    local attrs=host:GetAttrs()
    local finish=start and cycles and cycle and start+cycles*cycle or nil
    if not start or start<0 or start%1~=0 or
       not cycles or cycles%1~=0 or cycles<1 or cycles>8 or
       not cycle or cycle%1~=0 or cycle<2 or cycle>120 or
       not peak or peak<=0 or peak>1 or not finish or
       not attrs or not tonumber(attrs.COMPN_RenderEnd) or
       finish>tonumber(attrs.COMPN_RenderEnd) then
        error("INVALID_PULSE: Check Count, Cycle, Strength and Fusion end frame")
    end
    local highlight
    for _,candidate in pairs(host:GetToolList(false) or {}) do
        local ok,id=pcall(function()
            return candidate:GetData("CartoRigAtomic.IdentityV2")
        end)
        if ok and type(id)=="table" and id.sceneId==tag.sceneId and
           id.objectId==tag.objectId and id.role=="render" then
            highlight=candidate
            break
        end
    end
    if not highlight or not highlight.Blend then
        error("HOST_HIGHLIGHT: Region highlight layer is missing")
    end
    local ok,connection=pcall(function()
        return highlight.Blend:GetConnectedOutput()
    end)
    if not ok or connection then
        error("MOTION_CONFLICT: Highlight Strength is already animated")
    end
    host:StartUndo("CartoRig: MO-REG-06 Highlight Pulse")
    local success,problem=pcall(function()
        if not highlight:AddModifier("Blend","BezierSpline") then
            error("HOST_ANIMATION: Highlight Blend cannot have a Spline")
        end
        highlight:SetInput("Blend",0,start)
        for index=0,cycles-1 do
            local from=start+index*cycle
            local middle=from+math.floor(cycle/2)
            local last=from+cycle
            highlight:SetInput("Blend",peak,middle)
            highlight:SetInput("Blend",0,last)
        end
        selected:SetData("CartoRigAtomic.MotionHighlightV2",{
            presetId="MO-REG-06",channel="Highlight Strength",
            schemaVersion=2,startFrame=start,endFrame=finish,
            pulseCount=cycles,cycleFrames=cycle,peak=peak,
            state="ANIMATED_PRESET"
        })
    end)
    host:EndUndo(success)
    if not success then error(problem) end
end
local ok,problem=pcall(pulse)
if not ok then print("CartoRig Highlight Pulse: "..tostring(problem)) end
]==]
end

-- Pop In acts on the Marker-owned EllipseMask dimensions, never on Center,
-- geoanchor coordinates, Fill Color, or the outer object opacity.
local function marker_pop_callback()
    return [==[
local function pop()
    local selected=tool
    local host=selected and (selected.Comp or
        (rawget(_G,"fu") and fu.CurrentComp) or rawget(_G,"comp"))
    if not host then error("HOST_COMP: Fusion composition unavailable") end
    local tag=selected:GetData("CartoRigAtomic.IdentityV2")
    if type(tag)~="table" or tag.role~="control" then
        error("OBJECT_ID: Marker Control was not selected")
    end
    local scene=host:GetData("CartoRigAtomic.SceneV2")
    if type(scene)~="table" or scene.sceneId~=tag.sceneId then
        error("SCENE_CONTEXT: Wrong Fusion composition")
    end
    local owned=false
    for _,entry in ipairs(scene.objects or {}) do
        if entry.id==tag.objectId then
            owned=true
            if entry.kind~="Marker" then
                error("INCOMPATIBLE_OBJECT: Pop In requires Marker")
            end
            if entry.locked or entry.visible==false then
                error("LOCKED: Marker must be visible and unlocked")
            end
            break
        end
    end
    if not owned then error("OBJECT_MISSING: Marker no longer exists") end
    local duration=tonumber(selected:GetInput("CR2PopDuration"))
    local pixels=tonumber(selected:GetInput("CR2PopSizePixels"))
    local now=tonumber(host.CurrentTime)
    local attrs=host:GetAttrs()
    if not duration or duration%1~=0 or duration<2 or duration>10000 or
       not pixels or pixels<=0 or pixels>500 or
       not now or now%1~=0 or now<0 or
       not attrs or not tonumber(attrs.COMPN_RenderEnd) or
       now+duration>tonumber(attrs.COMPN_RenderEnd) then
        error("INVALID_POP: Check target pixels, duration and Fusion timeline")
    end
    local width,height
    local ok=pcall(function()
        width=tonumber(host:GetPrefs("Comp.FrameFormat.Width"))
        height=tonumber(host:GetPrefs("Comp.FrameFormat.Height"))
    end)
    if not ok or not width or not height or width<1 or height<1 then
        error("FRAME_FORMAT: Fusion output dimensions are unavailable")
    end
    local mask
    for _,candidate in pairs(host:GetToolList(false) or {}) do
        local hit,id=pcall(function()
            return candidate:GetData("CartoRigAtomic.IdentityV2")
        end)
        if hit and type(id)=="table" and id.sceneId==tag.sceneId and
           id.objectId==tag.objectId and id.role=="mask" then
            mask=candidate
            break
        end
    end
    if not mask or not mask.Width or not mask.Height then
        error("HOST_MASK: Marker EllipseMask is unavailable")
    end
    for _,channel in ipairs({"Width","Height"}) do
        local port=mask[channel]
        local hit,connected=pcall(function() return port:GetConnectedOutput() end)
        if not hit or connected then
            error("MOTION_CONFLICT: Marker Size channel is already animated")
        end
    end
    local peakFrame=now+math.floor(duration*.70+.5)
    local endFrame=now+duration
    if peakFrame<=now or peakFrame>=endFrame then
        error("FRAME_COLLISION: Pop peak collides with start/end")
    end
    local targetWidth=pixels/width
    local targetHeight=pixels/height
    host:StartUndo("CartoRig: MO-MRK-02 Pop In")
    local success,problem=pcall(function()
        if not mask:AddModifier("Width","BezierSpline") or
           not mask:AddModifier("Height","BezierSpline") then
            error("HOST_ANIMATION: Marker Size cannot have native curves")
        end
        for _,component in ipairs({
            {"Width",targetWidth},{"Height",targetHeight}
        }) do
            mask:SetInput(component[1],0,now)
            mask:SetInput(component[1],1.15*component[2],peakFrame)
            mask:SetInput(component[1],component[2],endFrame)
        end
        selected:SetData("CartoRigAtomic.MotionPopV2",{
            presetId="MO-MRK-02",channel="Size",
            schemaVersion=2,startFrame=now,endFrame=endFrame,
            targetPixels=pixels,peakPercent=115,peakFrame=peakFrame,
            state="ANIMATED_PRESET"
        })
    end)
    host:EndUndo(success)
    if not success then error(problem) end
end
local ok,problem=pcall(pop)
if not ok then print("CartoRig Marker Pop: "..tostring(problem)) end
]==]
end

-- Fly To animates three true numeric host channels. UIManager only sets
-- the explicit geographic target; the camera owns the persistent curves.
local function camera_fly_callback()
    return [==[
local function fly()
    local camera=tool
    local host=camera and (camera.Comp or
        (rawget(_G,"fu") and fu.CurrentComp) or rawget(_G,"comp"))
    if not host then error("HOST_COMP: No Fusion composition") end
    local tag=camera:GetData("CartoRigAtomic.IdentityV2")
    if type(tag)~="table" or tag.role~="camera" then
        error("OBJECT_ID: Select the CartoRig Camera")
    end
    local scene=host:GetData("CartoRigAtomic.SceneV2")
    if type(scene)~="table" or scene.sceneId~=tag.sceneId or
       scene.cameraId~=tag.objectId then
        error("SCENE_CONTEXT: Invalid Camera scene identity")
    end
    local target=camera:GetData("CartoRigAtomic.CameraFlyTargetV2")
    if type(target)~="table" or target.schemaVersion~=2 or
       target.featureType~="City" or not target.featureId then
        error("TARGET_REQUIRED: Select a City in Scene and Set Fly Target")
    end
    local duration=tonumber(camera:GetInput("CR2FlyDuration"))
    local now=tonumber(host.CurrentTime)
    local attrs=host:GetAttrs()
    if not duration or duration%1~=0 or duration<1 or duration>10000 or
       not now or now%1~=0 or now<0 or
       not attrs or not tonumber(attrs.COMPN_RenderEnd) or
       now+duration>tonumber(attrs.COMPN_RenderEnd) then
        error("FRAME_OUT_OF_RANGE: Fly To exceeds Fusion render interval")
    end
    local columns={"CR2CameraLongitude","CR2CameraLatitude","Size"}
    local source={}
    for i,name in ipairs(columns) do
        local port=camera[name]
        if not port then error("HOST_CHANNEL: Missing native Camera "..name) end
        local ok,existing=pcall(function()return port:GetConnectedOutput()end)
        if not ok or existing then
            error("MOTION_CONFLICT: Camera "..name.." is already animated")
        end
        source[i]=tonumber(camera:GetInput(name))
        if not source[i] then error("HOST_VALUE: Missing Camera pose") end
    end
    local lon=tonumber(target.longitude)
    local lat=tonumber(target.latitude)
    local zoom=tonumber(target.zoom)
    if not lon or lon < -180 or lon>180 or
       not lat or lat < -90 or lat > 90 or
       not zoom or zoom<.25 or zoom>100 then
        error("TARGET_REQUIRED: Invalid WGS84 target pose")
    end
    local delta=lon-source[1]
    if delta>180 then delta=delta-360 end
    if delta< -180 then delta=delta+360 end
    local destination={source[1]+delta,lat,zoom}
    host:StartUndo("CartoRig: MO-CAM-01 Fly To Location")
    local ok,issue=pcall(function()
        for i,name in ipairs(columns) do
            if not camera:AddModifier(name,"BezierSpline") then
                error("HOST_ANIMATION: Cannot create native Camera Spline")
            end
            camera:SetInput(name,source[i],now)
            camera:SetInput(name,destination[i],now+duration)
        end
        camera:SetData("CartoRigAtomic.MotionFlyV2",{
            presetId="MO-CAM-01",schemaVersion=2,
            featureId=target.featureId,
            channels=columns,startFrame=now,endFrame=now+duration,
            unwrappedTargetLongitude=destination[1],state="ANIMATED_PRESET"
        })
    end)
    host:EndUndo(ok)
    if not ok then error(issue) end
end
local ok,issue=pcall(fly)
if not ok then print("CartoRig Fly To: "..tostring(issue)) end
]==]
end

local function attach_inspector_motion(tool, kind)
    if kind~="Marker" and kind~="Label" and kind~="Camera" and
        kind~="Region" and kind~="Route" then
        return
    end
    local preset=kind=="Marker" and "MO-MRK-01" or
        kind=="Label" and "MO-LBL-01" or
        kind=="Region" and "MO-REG-01" or
        kind=="Route" and "MO-RTE-01" or "MO-CAM-02"
    local controls={
        CR2MotionDuration={
            LINKS_Name="Duration (Frames)", LINKID_DataType="Number",
            INPID_InputControl="SliderControl",
            ICS_ControlPage="Motion",
            INP_Default=kind=="Camera" and 30 or
                kind=="Region" and 24 or kind=="Route" and 30 or 18,
            INP_MinScale=1,INP_MaxScale=180,INP_Integer=true,
            INP_External=false
        },
        CR2MotionApply={
            LINKS_Name="Apply "..preset,
            LINKID_DataType="Number",INPID_InputControl="ButtonControl",
            ICS_ControlPage="Motion",INP_External=false,
            BTNCS_Execute=inspector_motion_callback(kind)
        }
    }
    if kind=="Region" then
        -- Target is only acted upon when the editor explicitly opts in.
        controls.CR2ColorChosen={
            LINKS_Name="Use Target Fill Color",
            LINKID_DataType="Number",INPID_InputControl="CheckboxControl",
            ICS_ControlPage="Motion",INP_Integer=true,
            INP_Default=0,INP_External=false
        }
        for index,channel in ipairs({"Red","Green","Blue","Alpha"}) do
            controls["CR2Target"..channel]={
                LINKS_Name=index==1 and "Target Fill RGBA" or
                    ("Target "..channel),
                LINKID_DataType="Number",INPID_InputControl="ColorControl",
                ICS_ControlPage="Motion",
                IC_ControlGroup=4,IC_ControlID=index-1,
                INP_Default=index==4 and 1 or 0,
                INP_External=false
            }
        end
        controls.CR2MotionColorChange={
            LINKS_Name="Apply MO-REG-03 Color Transition",
            LINKID_DataType="Number",INPID_InputControl="ButtonControl",
            ICS_ControlPage="Motion",INP_External=false,
            BTNCS_Execute=region_color_callback(false)
        }
        controls.CR2MotionInstantColor={
            LINKS_Name="Apply MO-REG-04 Instant Color",
            LINKID_DataType="Number",INPID_InputControl="ButtonControl",
            ICS_ControlPage="Motion",INP_External=false,
            BTNCS_Execute=region_color_callback(true)
        }
        controls.CR2BorderDuration={
            LINKS_Name="Border Draw Duration (Frames)",
            LINKID_DataType="Number",INPID_InputControl="SliderControl",
            ICS_ControlPage="Motion",INP_Integer=true,
            INP_Default=36,INP_MinScale=1,INP_MaxScale=300,
            INP_External=false
        }
        controls.CR2MotionBorderDraw={
            LINKS_Name="Apply MO-REG-05 Border Draw",
            LINKID_DataType="Number",INPID_InputControl="ButtonControl",
            ICS_ControlPage="Motion",INP_External=false,
            BTNCS_Execute=region_border_callback()
        }
        controls.CR2PulseCount={
            LINKS_Name="Highlight Pulses",
            LINKID_DataType="Number",INPID_InputControl="SliderControl",
            ICS_ControlPage="Motion",INP_Integer=true,INP_Default=2,
            INP_MinScale=1,INP_MaxScale=8,INP_External=false
        }
        controls.CR2PulseCycle={
            LINKS_Name="Pulse Cycle (Frames)",
            LINKID_DataType="Number",INPID_InputControl="SliderControl",
            ICS_ControlPage="Motion",INP_Integer=true,INP_Default=18,
            INP_MinScale=2,INP_MaxScale=120,INP_External=false
        }
        controls.CR2PulseStrength={
            LINKS_Name="Highlight Strength",
            LINKID_DataType="Number",INPID_InputControl="SliderControl",
            ICS_ControlPage="Motion",INP_Default=.35,
            INP_MinScale=0,INP_MaxScale=1,INP_External=false
        }
        controls.CR2MotionPulse={
            LINKS_Name="Apply MO-REG-06 Highlight Pulse",
            LINKID_DataType="Number",INPID_InputControl="ButtonControl",
            ICS_ControlPage="Motion",INP_External=false,
            BTNCS_Execute=region_highlight_callback()
        }
        controls.CR2MotionFadeOut={
            LINKS_Name="Apply MO-REG-02 Fade Out",
            LINKID_DataType="Number",INPID_InputControl="ButtonControl",
            ICS_ControlPage="Motion",INP_External=false,
            BTNCS_Execute=inspector_motion_callback("RegionFadeOut")
        }
    elseif kind=="Marker" then
        controls.CR2PopDuration={
            LINKS_Name="Pop In Duration (Frames)",
            LINKID_DataType="Number",INPID_InputControl="SliderControl",
            ICS_ControlPage="Motion",INP_Integer=true,INP_Default=18,
            INP_MinScale=2,INP_MaxScale=180,INP_External=false
        }
        controls.CR2PopSizePixels={
            LINKS_Name="Marker Target Size (px)",
            LINKID_DataType="Number",INPID_InputControl="SliderControl",
            ICS_ControlPage="Motion",INP_Default=14,
            INP_MinScale=1,INP_MaxScale=200,INP_External=false
        }
        controls.CR2MotionPop={
            LINKS_Name="Apply MO-MRK-02 Pop In",
            LINKID_DataType="Number",INPID_InputControl="ButtonControl",
            ICS_ControlPage="Motion",INP_External=false,
            BTNCS_Execute=marker_pop_callback()
        }
    elseif kind=="Route" then
        controls.CR2MotionErase={
            LINKS_Name="Apply MO-RTE-02 Erase Path",
            LINKID_DataType="Number",INPID_InputControl="ButtonControl",
            ICS_ControlPage="Motion",INP_External=false,
            BTNCS_Execute=inspector_motion_callback("RouteErase")
        }
    end
    if kind=="Camera" then
        -- Longitude/Latitude are independent native Number channels.
        -- Center is an expression of geo pose and Zoom, evaluated by
        -- Fusion at every requested frame, never by UIManager playback.
        controls.CR2CameraLongitude={
            LINKS_Name="Center Longitude (°)",
            LINKID_DataType="Number",INPID_InputControl="SliderControl",
            ICS_ControlPage="Control",INP_Default=0,
            INP_MinScale=-180,INP_MaxScale=180,INP_External=false
        }
        controls.CR2CameraLatitude={
            LINKS_Name="Center Latitude (°)",
            LINKID_DataType="Number",INPID_InputControl="SliderControl",
            ICS_ControlPage="Control",INP_Default=0,
            INP_MinScale=-90,INP_MaxScale=90,INP_External=false
        }
        controls.CR2FlyDuration={
            LINKS_Name="Fly To Duration (Frames)",
            LINKID_DataType="Number",INPID_InputControl="SliderControl",
            ICS_ControlPage="Motion",INP_Integer=true,INP_Default=45,
            INP_MinScale=1,INP_MaxScale=300,INP_External=false
        }
        controls.CR2MotionFly={
            LINKS_Name="Apply MO-CAM-01 Fly To Location",
            LINKID_DataType="Number",INPID_InputControl="ButtonControl",
            ICS_ControlPage="Motion",INP_External=false,
            BTNCS_Execute=camera_fly_callback()
        }
        controls.CR2TargetZoom={
            LINKS_Name="Target Zoom", LINKID_DataType="Number",
            INPID_InputControl="SliderControl",ICS_ControlPage="Motion",
            INP_Default=4,INP_MinScale=.25,INP_MaxScale=100,
            INP_External=false
        }
    end
    local ok,issue=pcall(function()
        tool.UserControls=controls
        tool:Refresh()
    end)
    if not ok then
        fail("HOST_INSPECTOR", "Cannot publish native Motion controls: "..tostring(issue))
    end
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

local function visible_source(comp, scene, object)
    return object_tool(comp, scene, object.id, "render")
        or object_tool(comp, scene, object.id, "control")
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
            visible_source(comp, scene, obj)) then
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
            locked = obj.locked == true, groupId = obj.groupId,
            sourceRef = copy_table(obj.sourceRef)
        }
    end
    return { state = #objects == 0 and "SCENE_EMPTY" or "SCENE_READY",
        sceneId = scene.sceneId, objects = objects,
        displayMode = scene.displayMode,
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
        -- This is a real Fusion-native rasterizer of *vector* Natural Earth
        -- geometries, not a flat color or 8K PNG. The separate Fuse is shipped
        -- with the Windows installer and runs while Scene UIManager is closed.
        local background = add_tool(comp,"Fuse.CartoRigAtomicLand",
            "CR2_Base_Map",-5,0,sceneId,sceneId,"base")
        if background:SetInput("TransparentOverlay",0)==false then
            fail("HOST_BASE_MAP","Fusion vector map controls are unavailable")
        end

        local camera = add_tool(comp, "Transform", "CR2_Camera", 5, 0,
            sceneId, scene.cameraId, "camera")
        attach_inspector_motion(camera, "Camera")
        camera:SetInput("CR2CameraLongitude",0)
        camera:SetInput("CR2CameraLatitude",0)
        camera:SetInput("Size", 1.0)
        -- SetExpression is documented for native Fusion PlainInput.
        -- Keep all animation on scalar host inputs; the Point expression
        -- re-evaluates the shared map-camera transform on random seeks.
        local centerFormula="Point(0.5+(0.5-(CR2CameraLongitude+180)/360)*Size,"..
            "0.5+(0.5-(CR2CameraLatitude+90)/180)*Size)"
        if not camera.Center or
           camera.Center:SetExpression(centerFormula)==false then
            fail("HOST_CAMERA","Native Center expression is unavailable")
        end
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

local function source_ref(source)
    if source == nil then
        return { provider = "User", featureType = "Custom Point" }
    end
    if type(source) ~= "table" or type(source.id) ~= "string" or
        not source.id:match("^ne10m:") or source.kind ~= "City" or
        type(source.name) ~= "string" then
        fail("INVALID_SOURCE", "Selected location must be an installed Natural Earth city")
    end
    return {
        provider = "Natural Earth",
        dataset = "ne_10m_populated_places",
        datasetVersion = "1:10m",
        featureId = source.id,
        featureType = "City",
        name = source.name,
        country = tostring(source.country or ""),
        parent = tostring(source.parent or ""),
        worldview = "Natural Earth"
    }
end

local function add_object(comp, kind, name, lon, lat, source)
    name = safe_name(name)
    lon, lat = validate_position(lon, lat)
    local provenance = source_ref(source)
    if source and source.point and
       (math.abs(lon-source.point.lon)>1e-6 or
        math.abs(lat-source.point.lat)>1e-6) then
        fail("SOURCE_MISMATCH", "Selected feature coordinates do not match offline data")
    end
    local scene = require_scene(comp)
    local _, camera, tail = validate_graph(comp, scene)
    return undo(comp, "CartoRig: Add " .. kind, function()
        local id = next_id(scene)
        local n = #scene.objects + 1
        local source
        if kind == "Marker" then
            source = add_tool(comp, "Background", "CR2_Marker_" .. n,
                -4, n * 2, scene.sceneId, id, "control")
            -- CR-PS-2.0 Neutral Dark: marker.fill = #E0E8ED.
            source:SetInput("TopLeftRed", 224/255)
            source:SetInput("TopLeftGreen", 232/255)
            source:SetInput("TopLeftBlue", 237/255)
            source:SetInput("TopLeftAlpha", 1.0)
            local mask = add_tool(comp, "EllipseMask", "CR2_Mask_" .. n,
                -6, n * 2, scene.sceneId, id, "mask")
            local c = coords(lon, lat)
            mask:SetInput("Center", point(c[1], c[2]))
            local renderW,renderH
            local dimsOk=pcall(function()
                renderW=tonumber(comp:GetPrefs("Comp.FrameFormat.Width"))
                renderH=tonumber(comp:GetPrefs("Comp.FrameFormat.Height"))
            end)
            if not dimsOk or not renderW or renderW<1 or
               not renderH or renderH<1 then
                fail("FRAME_FORMAT","Cannot resolve native Fusion output dimensions")
            end
            -- Use a 14px circle in the current output format; editing
            -- the resolution afterward requires size re-evaluation.
            mask:SetInput("Width", 14/renderW)
            mask:SetInput("Height", 14/renderH)
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

        attach_inspector_motion(source, kind)

        local merge = add_tool(comp, "Merge", "CR2_Merge_" .. n,
            2, n * 2, scene.sceneId, id, "merge")
        checked_link(merge, "Background", tail)
        checked_link(merge, "Foreground", source)
        checked_link(camera, "Input", merge)

        scene.tailId = id
        scene.objects[#scene.objects + 1] = {
            id = id, kind = kind, name = name, lon = lon, lat = lat,
            visible = true, locked = false, sourceRef = provenance
        }
        comp:SetData(SCENE_KEY, scene)
        return id
    end)
end

function M.select_system(comp, role)
    if role~="base" and role~="camera" then
        fail("INVALID_SELECTION","Only Base Map and Camera are system objects")
    end
    local scene=require_scene(comp)
    local base,camera=validate_graph(comp,scene)
    local tool=(role=="base") and base or camera
    local flow=comp.CurrentFrame and comp.CurrentFrame.FlowView
    if flow and flow.Select then flow:Select() flow:Select(tool,true) end
    comp:SetActiveTool(tool)
    return tool
end

function M.set_display_mode(comp,mode)
    if mode~="Full Map" and mode~="Transparent Overlay" then
        fail("INVALID_MODE","Use Full Map or Transparent Overlay")
    end
    local scene=require_scene(comp)
    local base=validate_graph(comp,scene)
    return undo(comp,"CartoRig: Display Mode",function()
        if base:SetInput("TransparentOverlay",
           mode=="Transparent Overlay" and 1 or 0)==false then
            fail("HOST_BASE_MAP","Fusion refused the native base opacity mode")
        end
        scene.displayMode=mode
        comp:SetData(SCENE_KEY,scene)
        return mode
    end)
end

function M.add_marker(comp, name, lon, lat, source)
    return add_object(comp, "Marker", name, lon, lat, source)
end

function M.add_label(comp, name, lon, lat, source)
    return add_object(comp, "Label", name, lon, lat, source)
end

-- Geographic shape authoring. Native Fusion polylines remain vector paths
-- at any output resolution. No image assets are baked for any zoom value.
local function host_polyline(vertices, closed)
    local constructor=rawget(_G,"Polyline")
    if not constructor then
        fail("HOST_POLYLINE", "Fusion Polyline constructor is unavailable")
    end
    local points={}
    for _,v in ipairs(vertices) do
        local x,y=validate_position(v.lon,v.lat)
        -- PolylineMask control points are relative to Center = (0.5,0.5).
        points[#points+1]={Linear=true,X=x/360,Y=y/180}
    end
    if #points < (closed and 3 or 2) then
        fail("GEOMETRY_FORMAT","Insufficient geographic vertices for Fusion mask")
    end
    local ok,result=pcall(constructor,{Closed=closed,Points=points})
    if not ok or result==nil then
        fail("HOST_POLYLINE","Fusion refused geographic polygon construction")
    end
    return result
end

local function make_mask(comp, scene, objectId, index, ring, closed, width, paint)
    local mask=add_tool(comp,"PolylineMask","CR2_Path_" .. index,
        -7,index*2,scene.sceneId,objectId,"shape"..index)
    if mask:SetInput("Polyline",host_polyline(ring,closed))==false then
        fail("HOST_POLYLINE","Unable to assign Fusion vector geometry")
    end
    if not closed then
        if mask:SetInput("Solid",0)==false or
           mask:SetInput("BorderWidth",width or .0016)==false then
            fail("HOST_MASK","Fusion could not configure path stroke")
        end
    end
    if paint=="Subtract" then
        local ctor=rawget(_G,"FuID")
        if not ctor then fail("HOST_MASK","Fusion FuID constructor is unavailable") end
        local ok,mode=pcall(ctor,{"Subtract"})
        if not ok or mode==nil or mask:SetInput("PaintMode",mode)==false then
            fail("HOST_MASK","Fusion could not subtract the polygon hole")
        end
    end
    return mask
end

local function set_background_rgb(source,r,g,b)
    if source:SetInput("TopLeftRed",r)==false or
       source:SetInput("TopLeftGreen",g)==false or
       source:SetInput("TopLeftBlue",b)==false or
       source:SetInput("TopLeftAlpha",1)==false then
        fail("HOST_COLOR","Cannot set native Fusion Background color")
    end
end

local function add_composite(comp,scene,id,source,n)
    local _,camera,previous=validate_graph(comp,scene)
    local merge=add_tool(comp,"Merge","CR2_ObjectMerge_"..n,
        3,n*2,scene.sceneId,id,"merge")
    checked_link(merge,"Background",previous)
    checked_link(merge,"Foreground",source)
    checked_link(camera,"Input",merge)
    scene.tailId=id
    return merge
end

function M.add_region(comp, feature, geometry)
    if type(feature)~="table" or type(feature.id)~="string" or
       (feature.kind~="Country" and feature.kind~="State") then
        fail("INVALID_REGION","Choose a country or state with real polygon geometry")
    end
    if type(geometry)~="table" or geometry.id~=feature.id or
       type(geometry.rings)~="table" or #geometry.rings<1 then
        fail("NO_GEOMETRY","Region polygon is absent or does not match source")
    end
    if #geometry.rings>4096 then
        fail("GEOMETRY_SIZE","Region exceeds managed Fusion polygon limit")
    end
    local name=safe_name(feature.name)
    local scene=require_scene(comp)
    validate_graph(comp,scene)
    return undo(comp,"CartoRig: Add Region",function()
        local id=next_id(scene)
        local n=#scene.objects+1
        local fill=add_tool(comp,"Background","CR2_Region_"..n,
            -3,n*2,scene.sceneId,id,"control")
        set_background_rgb(fill,130/255,150/255,164/255)
        attach_inspector_motion(fill,"Region")
        local previousMask
        local previousStroke
        local strokeSegments={}
        for i,ring in ipairs(geometry.rings) do
            if type(ring.vertices)~="table" then
                fail("GEOMETRY_FORMAT","Polygon has no vertices")
            end
            local mask=make_mask(comp,scene,id,i,ring.vertices,true,nil,
                ring.kind=="H" and "Subtract" or "Add")
            if previousMask then checked_link(mask,"EffectMask",previousMask) end
            previousMask=mask
            local stroke=make_mask(comp,scene,id,#geometry.rings+i,
                ring.vertices,true,1.5/1920,"Add")
            if stroke:SetInput("Solid",0)==false or
               stroke:SetInput("BorderWidth",1.5/1920)==false or
               stroke:SetInput("WriteLength",1)==false then
                fail("HOST_MASK","Region stroke width/progress is unavailable")
            end
            local length=0
            for p=1,#ring.vertices do
                local a=ring.vertices[p]
                local b=ring.vertices[p % #ring.vertices+1]
                local dx,dy=(b.lon-a.lon)/360,(b.lat-a.lat)/180
                length=length+math.sqrt(dx*dx+dy*dy)
            end
            strokeSegments[#strokeSegments+1]={
                role="shape"..tostring(#geometry.rings+i),
                length=length,kind=ring.kind
            }
            if previousStroke then
                checked_link(stroke,"EffectMask",previousStroke)
            end
            previousStroke=stroke
        end
        fill:SetData("CartoRigAtomic.RegionStrokeSegmentsV2",strokeSegments)
        checked_link(fill,"EffectMask",previousMask)
        local border=add_tool(comp,"Background","CR2_RegionBorder_"..n,
            -2,n*2,scene.sceneId,id,"border")
        set_background_rgb(border,215/255,224/255,231/255)
        checked_link(border,"EffectMask",previousStroke)
        local inner=add_tool(comp,"Merge","CR2_RegionStroke_"..n,
            0,n*2,scene.sceneId,id,"stroke_composite")
        checked_link(inner,"Background",fill)
        checked_link(inner,"Foreground",border)
        -- Own highlight surface, own Blend channel and Spline. No author
        -- action may key the source Fill RGBA or Stroke while pulsing.
        local light=add_tool(comp,"Background","CR2_HighlightColor_"..n,
            -1,n*2,scene.sceneId,id,"highlight_color")
        set_background_rgb(light,245/255,194/255,61/255)
        checked_link(light,"EffectMask",previousMask)
        local highlight=add_tool(comp,"Merge","CR2_Highlight_"..n,
            1,n*2,scene.sceneId,id,"render")
        checked_link(highlight,"Background",inner)
        checked_link(highlight,"Foreground",light)
        if highlight:SetInput("Blend",0)==false then
            fail("HOST_HIGHLIGHT","Fusion cannot initialize independent strength")
        end
        add_composite(comp,scene,id,highlight,n)
        scene.objects[#scene.objects+1]={
            id=id,kind="Region",name=name,
            visible=true,locked=false,polygonRings=#geometry.rings,
            sourceRef={
                provider="Natural Earth",dataset=feature.kind=="Country"
                    and "ne_10m_admin_0_countries"
                    or "ne_10m_admin_1_states_provinces",
                datasetVersion="1:10m",featureId=feature.id,
                featureType=feature.kind,country=feature.country,
                parent=feature.parent,
                worldview="Natural Earth"
            }
        }
        comp:SetData(SCENE_KEY,scene)
        return id
    end)
end

local function contains_ring(vertices,lon,lat)
    local inside=false
    local previous=vertices[#vertices]
    for _,v in ipairs(vertices) do
        local x1,y1=previous.lon,previous.lat
        local x2,y2=v.lon,v.lat
        if (y1>lat)~=(y2>lat) then
            local at=x1+(lat-y1)*(x2-x1)/(y2-y1)
            if lon<at then inside=not inside end
        end
        previous=v
    end
    return inside
end

function M.contains_point(geometry,lon,lat)
    lon,lat=validate_position(lon,lat)
    if not geometry or type(geometry.rings)~="table" then
        fail("NO_GEOMETRY","Cannot test containment without polygon rings")
    end
    local result=false
    for _,ring in ipairs(geometry.rings) do
        if ring.kind=="O" then
            if contains_ring(ring.vertices,lon,lat) then result=true end
        elseif ring.kind=="H" and contains_ring(ring.vertices,lon,lat) then
            result=false
        end
    end
    return result
end

local function route_vertices(origin,destination,style,curvature)
    local x1,y1=validate_position(origin.lon,origin.lat)
    local x2,y2=validate_position(destination.lon,destination.lat)
    if style~="Straight" and style~="Curved" then
        fail("INVALID_ROUTE","Route must be Straight or Curved")
    end
    curvature=tonumber(curvature) or .2
    if curvature~=curvature or curvature < -2 or curvature > 2 then
        fail("INVALID_ROUTE","Route curvature must be -2..2")
    end
    local delta=x2-x1
    if delta>180 then x2=x2-360 end
    if delta< -180 then x2=x2+360 end
    local dx,dy=x2-x1,y2-y1
    local curve=(style=="Curved") and curvature or 0
    local controlX=(x1+x2)/2-dy*curve
    local controlY=(y1+y2)/2+dx*curve
    local unwrapped={}
    local steps=style=="Straight" and 1 or 32
    for i=0,steps do
        local t=i/steps
        unwrapped[#unwrapped+1]={
            lon=(1-t)*(1-t)*x1+2*(1-t)*t*controlX+t*t*x2,
            lat=(1-t)*(1-t)*y1+2*(1-t)*t*controlY+t*t*y2
        }
    end
    -- Split the line precisely on +/-180; a 179->-179 route must never
    -- produce a 358-degree diagonal across the world canvas.
    local segments={{unwrapped[1]}}
    for i=2,#unwrapped do
        local previous=unwrapped[i-1]
        local current=unwrapped[i]
        local seam=(previous.lon<=180 and current.lon>180) and 180 or
                   (previous.lon>= -180 and current.lon< -180) and -180 or nil
        if seam then
            local fraction=(seam-previous.lon)/(current.lon-previous.lon)
            local latitude=previous.lat+fraction*(current.lat-previous.lat)
            segments[#segments][#segments[#segments]+1]={lon=seam,lat=latitude}
            local shift=seam==180 and -360 or 360
            local another={{lon=seam+shift,lat=latitude}}
            for j=i,#unwrapped do
                unwrapped[j].lon=unwrapped[j].lon+shift
            end
            segments[#segments+1]=another
            current=unwrapped[i]
        end
        segments[#segments][#segments[#segments]+1]=current
    end
    for _,segment in ipairs(segments) do
        if #segment<2 then fail("GEOMETRY_FORMAT","Degenerate antimeridian segment") end
        for _,v in ipairs(segment) do validate_position(v.lon,v.lat) end
    end
    return segments
end

function M.add_route(comp,origin,arrival,details)
    details=details or {}
    if type(origin)~="table" or type(arrival)~="table" then
        fail("ENDPOINT_REQUIRED","Select an origin and an explicit arrival point")
    end
    local ox,oy=validate_position(origin.lon,origin.lat)
    local tx,ty=validate_position(arrival.lon,arrival.lat)
    if details.destinationState then
        if not M.contains_point(details.destinationGeometry,tx,ty) then
            fail("ENDPOINT_OUTSIDE_STATE",
                "The selected arrival point is not inside the selected State")
        end
    end
    local style=details.pathType or "Straight"
    local segments=route_vertices(
        {lon=ox,lat=oy},{lon=tx,lat=ty},style,details.curvature)
    local name=safe_name(details.name or
        ((origin.name or "Origin").." → "..(arrival.name or "Destination")))
    local scene=require_scene(comp)
    validate_graph(comp,scene)
    return undo(comp,"CartoRig: Add Route",function()
        local id=next_id(scene)
        local n=#scene.objects+1
        local source=add_tool(comp,"Background","CR2_Route_"..n,
            -3,n*2,scene.sceneId,id,"control")
        set_background_rgb(source,214/255,223/255,230/255)
        attach_inspector_motion(source,"Route")
        local previousMask
        local lengths={}
        for i,segment in ipairs(segments) do
            local role="shape"..tostring(n*100+i)
            local mask=make_mask(comp,scene,id,n*100+i,segment,false,3/1920,"Add")
            if mask:SetInput("WriteLength",1)==false then
                fail("HOST_MASK","Route mask has no native Write Length control")
            end
            if previousMask then checked_link(mask,"EffectMask",previousMask) end
            previousMask=mask
            local length=0
            for p=2,#segment do
                local a,b=segment[p-1],segment[p]
                local dx,dy=(b.lon-a.lon)/360,(b.lat-a.lat)/180
                length=length+math.sqrt(dx*dx+dy*dy)
            end
            lengths[#lengths+1]={role=role,length=length}
        end
        source:SetData("CartoRigAtomic.RouteSegmentsV2",lengths)
        checked_link(source,"EffectMask",previousMask)
        add_composite(comp,scene,id,source,n)
        scene.objects[#scene.objects+1]={
            id=id,kind="Route",name=name,visible=true,locked=false,
            route={ from={lon=ox,lat=oy,sourceId=origin.id},
                    to={lon=tx,lat=ty,sourceId=arrival.id},
                    pathType=style,curvature=details.curvature or .2,
                    segments=#segments,
                    destinationStateId=details.destinationState and
                        details.destinationState.id or nil },
        }
        comp:SetData(SCENE_KEY,scene)
        return id
    end)
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
    local extra = {}
    for _, tool in pairs(comp:GetToolList(false) or {}) do
        local ok, tag = pcall(function()
            return tool:GetData(TOOL_KEY)
        end)
        if ok and type(tag) == "table" and tag.sceneId == scene.sceneId and
            tag.objectId == objectId and tag.role ~= "control" and
            tag.role ~= "merge" then
            extra[#extra + 1] = tool
        end
    end
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
        -- Other render subtools include polygons, route masks and strokes.
        -- Delete only nodes tagged with this exact scene and object ID.
        for _, managed in ipairs(extra) do
            if not managed:Delete() then
                fail("HOST_DELETE", "Fusion could not delete owned subtool")
            end
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
    lon,lat=validate_position(lon,lat)
    if zoom~=nil then
        zoom=tonumber(zoom)
        if not zoom or zoom<.25 or zoom>100 or zoom~=zoom then
            fail("INVALID_ZOOM","Camera Zoom must be 0.25..100")
        end
    end
    local scene=require_scene(comp)
    local _,camera=validate_graph(comp,scene)
    -- Static Focus may never silently replace a manually edited Spline
    -- or an authored Fly To / Fit Transition curve.
    local channels={"CR2CameraLongitude","CR2CameraLatitude"}
    if zoom~=nil then channels[#channels+1]="Size" end
    for _,name in ipairs(channels) do
        local input=camera[name]
        if not input then
            fail("HOST_CAMERA","Missing native geographic Camera input "..name)
        end
        local ok,connected=pcall(function()
            return input:GetConnectedOutput()
        end)
        if not ok then
            fail("HOST_CAMERA","Cannot inspect existing "..name.." animation")
        end
        if connected~=nil then
            fail("MOTION_CONFLICT","Camera "..name..
                " is already animated; edit keys in the Fusion Spline")
        end
    end
    return undo(comp,"CartoRig: Focus Camera",function()
        -- Center is derived by its host-owned Point Expression. No script
        -- iterates frames or moves map objects individually.
        camera:SetInput("CR2CameraLongitude",lon)
        camera:SetInput("CR2CameraLatitude",lat)
        if zoom~=nil then camera:SetInput("Size",zoom) end
        return true
    end)
end


function M.set_fly_target(comp,feature,zoom)
    if type(feature)~="table" or feature.kind~="City" or
       type(feature.id)~="string" or not feature.id:match("^ne10m:city:") or
       type(feature.point)~="table" then
        fail("TARGET_REQUIRED","Fly To requires an explicitly selected real City")
    end
    local lon,lat=validate_position(feature.point.lon,feature.point.lat)
    zoom=tonumber(zoom)
    if not zoom or zoom~=zoom or zoom<.25 or zoom>100 then
        fail("INVALID_ZOOM","Choose explicit target Camera Zoom 0.25..100")
    end
    local scene=require_scene(comp)
    local _,camera=validate_graph(comp,scene)
    return undo(comp,"CartoRig: Choose Fly To Target",function()
        camera:SetData("CartoRigAtomic.CameraFlyTargetV2",{
            schemaVersion=2,featureId=feature.id,featureType="City",
            name=tostring(feature.name or ""),country=tostring(feature.country or ""),
            longitude=lon,latitude=lat,zoom=zoom
        })
        return true
    end)
end

function M.set_zoom(comp, zoom)
    zoom=tonumber(zoom)
    if not zoom or zoom~=zoom or zoom<.25 or zoom>100 then
        fail("INVALID_ZOOM","Camera Zoom must be 0.25..100")
    end
    local scene=require_scene(comp)
    local _,camera=validate_graph(comp,scene)
    if not camera.Size then fail("HOST_CAMERA","Zoom control is missing") end
    local ok,connected=pcall(function()
        return camera.Size:GetConnectedOutput()
    end)
    if not ok then fail("HOST_CAMERA","Cannot inspect Zoom animation") end
    if connected then
        fail("MOTION_CONFLICT","Zoom already contains keys; use Fusion Spline")
    end
    return undo(comp,"CartoRig: Set Zoom",function()
        camera:SetInput("Size",zoom)
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
