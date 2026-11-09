-- Synthetic Fuse SDK contract. Tests the *actual Fuse source* with deterministic
-- stand-ins for Fusion Image, Shape, ChannelStyle and Output APIs. No test
-- doubles masquerade as pixel renders in real DaVinci Resolve Studio.
local checks=0
local function check(ok,message)
    checks=checks+1
    if not ok then error("FUSE CONTRACT FAIL: "..message,2) end
end
local registered
CT_SourceTool="CT_SourceTool"
function FuRegisterClass(name,typ,config)
    registered={name=name,typ=typ,config=config}
end
local imageOps={}
local fakeImage
function Pixel(data) return data end
function Image(attrs)
    fakeImage={width=attrs.IMG_Width,height=attrs.IMG_Height,
        xscale=attrs.IMG_XScale,yscale=attrs.IMG_YScale,draws={},attrs=attrs}
    function fakeImage:Fill(pixel)
        self.fill=pixel
    end
    return fakeImage
end
function Shape()
    local outline={steps={},closed=0}
    function outline:MoveTo(x,y)
        self.steps[#self.steps+1]={mode="M",x=x,y=y}
    end
    function outline:LineTo(x,y)
        self.steps[#self.steps+1]={mode="L",x=x,y=y}
    end
    function outline:Close() self.closed=self.closed+1 end
    function outline:OutlineOfShape(width,kind)
        return {stroke=true,width=width,kind=kind,closed=self.closed}
    end
    return outline
end
function ImageChannel(image,quality)
    local channel={}
    function channel:ShapeFill(shape) self.shape=shape end
    function channel:PutToImage(mode,style)
        image.draws[#image.draws+1]={shape=self.shape,mode=mode,
                                     color=style.Color,quality=quality}
    end
    return channel
end
function ChannelStyle() return {} end
local inputs={}
local output
self={Comp={}}
function self:AddInput(name,id,meta)
    local input={name=name,id=id,metadata=meta,value=meta.INP_Default}
    function input:GetValue(req)
        return {Value=self.value}
    end
    inputs[id]=input
    return input
end
function self:AddOutput(name,id,meta)
    output={}
    function output:Set(req,image)
        self.last=image
    end
    return output
end

Width,Height,Scale,XAspect,YAspect=1920,1080,1,1,1
dofile("fusion/fuses/CartoRigAtomicLand.fuse")
check(registered.name=="CartoRigAtomicLand","Fuse registered with unique CartoRig native ID")
check(registered.typ==CT_SourceTool,"world land is a native Fusion source")
Create()
check(inputs.LandRed.metadata.INPID_InputControl=="ColorControl",
      "Base Map exposes native colour picker, not four unrelated UI sliders")
check(inputs.OceanRed.metadata.IC_ControlGroup ~= inputs.LandRed.metadata.IC_ControlGroup,
      "Land and ocean have independent colour selectors")
check(inputs.BorderRed.metadata.IC_ControlGroup ~= inputs.OceanRed.metadata.IC_ControlGroup,
      "Border uses an independent native colour selector")
check(inputs.TransparentOverlay.metadata.INPID_InputControl=="CheckboxControl",
      "native overlay mode is explicit and editable")
local req={}
function req:IsQuick() return false end
function req:IsNoMotionBlur() return true end
Process(req)
check(output.last ~= nil,"Fuse delivered RGBA source to Fusion output")
check(output.last.width==1920 and output.last.height==1080,
      "native source dimensions follow composition resolution")
local hasData=os.getenv("CARTORIG_ATOMIC_DATA_DIR")
if not hasData or hasData=="" or hasData:find("does-not-exist",1,true) then
    check(output.last.fill.R==1 and output.last.fill.G==0 and
          output.last.fill.B==.85,
          "missing Natural Earth data is explicit opaque magenta, never black")
else
    check(output.last.fill.A==1 and output.last.fill.R==16/255,
          "world starts with correct opaque ocean pixel")
    check(#output.last.draws>=2,
          "real Natural Earth land shape and country-border shape both rasterized")
    local filled=output.last.draws[1]
    check(filled.shape.closed>=200,
          "renderer constructed real independent closed country polygons")
    check(filled.shape.steps[1].mode=="M" and
          filled.shape.steps[2].mode=="L",
          "renderer projected real WGS84 vertices as native vector line geometry")
    check(filled.color.A==1 and filled.color.R==57/255,
          "land layer uses expected neutral default colour and alpha")
    check(output.last.draws[2].shape.stroke==true,
          "country borders are separate stroked vectors")
    check(output.last.draws[2].shape.width==1/1920,
          "1px border is resolution-aware at 1920 width")
    inputs.TransparentOverlay.value=1
    Process(req)
    check(output.last.fill.A==0 and #output.last.draws==0,
          "Transparent Overlay removes base layers without hiding authored layers")
    inputs.TransparentOverlay.value=0
    inputs.LandOpacity.value=0
    Process(req)
    check(#output.last.draws==1,
          "land opacity can be animated without modifying borders")
end

-- Execute the installed Inspector button's source under a mock Fusion host.
-- This verifies keyframe calls and guards; it does NOT claim real Resolve certification.
check(inputs.CR2LayerFadeApply.metadata.ICS_ControlPage=="Motion",
      "Base Map has a persistent native Inspector Motion page")
local btnSource=inputs.CR2LayerFadeApply.metadata.BTNCS_Execute
check(type(btnSource)=="string" and btnSource:find("MO-MAP-01",1,true),
      "native button carries a self-contained Layer Fade callback")
local toolData={["CartoRigAtomic.IdentityV2"]={role="base"}}
local keys={}
local host={CurrentTime=90,started=false,accepted=false}
function host:GetAttrs()return {COMPN_RenderEnd=300}end
function host:StartUndo(label)self.started=label end
function host:EndUndo(ok)self.accepted=ok end
local motionTool={Comp=host,inputs={TransparentOverlay=0,
    CR2LayerFadeLayer=1,CR2LayerFadeDuration=18},ports={}}
function motionTool:GetData(name)return toolData[name]end
function motionTool:SetData(name,value)toolData[name]=value end
function motionTool:GetInput(name)return self.inputs[name]end
function motionTool:AddModifier(channel,kind)
    if kind~="BezierSpline" then return false end
    self.animated=self.animated or {}
    self.animated[channel]=true
    return true
end
function motionTool:SetInput(name,value,frame)
    keys[name]=keys[name] or {}
    keys[name][frame]=value
    return true
end
for _,channel in ipairs({"OceanOpacity","LandOpacity","BorderOpacity"}) do
    motionTool.ports[channel]={GetConnectedOutput=function()
        if motionTool.animated and motionTool.animated[channel] then return {} end
        return nil
    end}
    motionTool[channel]=motionTool.ports[channel]
end
local previousTool,previousComp=_G.tool,_G.comp
_G.tool,_G.comp=motionTool,host
local button=assert((loadstring or load)(btnSource))
button()
check(keys.LandOpacity[90]==0 and keys.LandOpacity[108]==1,
      "Land Layer Fade writes 0..1 native Spline keys on exact composition frames")
check(keys.OceanOpacity==nil and keys.BorderOpacity==nil,
      "Layer Fade does not animate unrelated Base Map layers")
check(toolData["CartoRigAtomic.MotionLayerFadeV2"].presetId=="MO-MAP-01" and
      host.accepted==true,"native Layer Fade stores motion identity and commits Undo")
_G.tool,_G.comp=previousTool,previousComp
print("PASS: "..checks.." actual Fusion Base Map Fuse / offline vector source assertions")
