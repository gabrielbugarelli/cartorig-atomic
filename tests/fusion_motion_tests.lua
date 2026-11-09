local Motion = dofile("fusion/cartorig_motion.lua")
local assertions = 0
local function yes(condition, description)
    assertions=assertions+1
    if not condition then error("FAIL: "..description,2) end
end
local function fails(action,code)
    local ok,result=pcall(action)
    yes(not ok and tostring(result):find(code,1,true)~=nil,
        code.." must be rejected: "..tostring(result))
end
local current={
    ["Object Opacity"]=.8, ["Fill Color"]={1,0,0,1},["Stroke Progress"]=0,
    ["Highlight Strength"]=0, ["Draw Progress"]=1, ["Follower Progress"]=0,
    ["Size"]=16, ["Center Lon"]=179, ["Center Lat"]=-23, ["Zoom"]=4,
    ["Layer Opacity"]=1
}
local attributes={
    compFrames=500, current=current, strokeVisible=true, routeValid=true,
    availableMarkers={["existing-marker"]=true},
    availableLayers={Ocean=true,Land=true,Coastline=true,
                     ["Country Borders"]=true,["State Borders"]=true},
    displayMode="Full Map"
}
local kinds={}
local all={}
for _,kind in ipairs({"Region","Route","Marker","Camera","Label","Base Map"}) do
    for _,entry in ipairs(Motion.list(kind)) do
        yes(entry.kind==nil,"Preset index does not duplicate object type")
        yes(not all[entry.id],"Each R1.0 preset ID is unique")
        all[entry.id]={kind=kind,duration=entry.duration}
        kinds[kind]=(kinds[kind] or 0)+1
    end
end
local n=0 for _ in pairs(all) do n=n+1 end
yes(n==16,"CR-PS-2.0 launch catalog has exactly 16 Motion contracts")
yes(kinds.Region==6 and kinds.Route==3 and kinds.Marker==2 and
    kinds.Camera==3 and kinds.Label==1 and kinds["Base Map"]==1,
    "type-specific preset inventory is complete")

local function ctx(kind)
    return setmetatable({kind=kind}, {__index=attributes})
end
local args={
    startFrame=100, targetRGBA={0,1,0,1}, targetZoom=8,
    targetPose={lon=-179,lat=-22,zoom=6}, followerObjectId="existing-marker",
    layer="Ocean"
}
for id,descriptor in pairs(all) do
    local plan=Motion.plan(id,ctx(descriptor.kind),args)
    yes(plan.presetId==id and plan.kind==descriptor.kind,
        "Preset identity retained in plan")
    yes(not plan.hostKeysWritten and plan.state=="PLANNED_NOT_APPLIED",
        "Planner cannot claim host Spline keys were written")
    yes(#plan.channels>=1,"every preset owns an explicitly named channel")
    yes(plan.startFrame==100 and plan.endFrame<=499,
        "actual Fusion-frame key windows must be finite and valid")
    for _,channel in ipairs(plan.channels) do
        yes(channel.keys[1].frame==plan.startFrame or
            (id=="MO-REG-04" and channel.keys[1].frame==plan.startFrame-1),
            "first key lands at requested frame or intentional prior Hold frame")
        yes(channel.keys[#channel.keys].frame==plan.endFrame,
            "last key lands on expected integer frame")
    end
end

local fade=Motion.plan("MO-REG-01",ctx("Region"),args)
yes(fade.endFrame==124 and fade.channels[1].keys[1].value==0 and
    fade.channels[1].keys[2].value==.8,"Region Fade In exactly 100..124 0→target")
local fadeOut=Motion.plan("MO-REG-02",ctx("Region"),args)
yes(fadeOut.channels[1].keys[1].value==.8 and
    fadeOut.channels[1].keys[2].value==0,"Region Fade Out preserves fill color")
local color=Motion.plan("MO-REG-03",ctx("Region"),args)
yes(color.channels[1].easing=="Linear" and
    color.channels[1].keys[2].value[2]==1,"RGBA change uses explicit target")
local instant=Motion.plan("MO-REG-04",ctx("Region"),{startFrame=330,targetRGBA={0,1,0,1}})
yes(instant.channels[1].easing=="Hold" and
    instant.channels[1].keys[1].frame==329 and
    instant.channels[1].keys[2].frame==330,
    "Instant Color Change must change at frame 330 with frame 329 held")
local border=Motion.plan("MO-REG-05",ctx("Region"),args)
yes(border.channels[1].channel=="Stroke Progress" and
    border.endFrame==136,"Border Draw affects stroke progress only")
local pulse=Motion.plan("MO-REG-06",ctx("Region"),args)
yes(#pulse.channels[1].keys==5 and pulse.channels[1].keys[5].value==0,
    "Highlight pulse has exactly two clean rise/fall cycles")
yes(pulse.channels[1].keys[2].frame==109,
    "Pulse midpoint respects 18-frame cycle")
local draw=Motion.plan("MO-RTE-01",ctx("Route"),args)
local erase=Motion.plan("MO-RTE-02",ctx("Route"),args)
yes(draw.channels[1].keys[1].value==0 and
    erase.channels[1].keys[1].value==1,
    "Draw and Erase are temporal opposites, not reversed spatial paths")
local follower=Motion.plan("MO-RTE-03",ctx("Route"),args)
yes(follower.bindings.followerObjectId=="existing-marker" and
    follower.endFrame==160,"Follow Path requires an authored Marker")
local pop=Motion.plan("MO-MRK-02",ctx("Marker"),args)
yes(pop.channels[1].keys[2].frame==113 and
    pop.channels[1].keys[2].value==16*1.15,
    "Pop peak at approx 70% and returns to original size at end")
local fly=Motion.plan("MO-CAM-01",ctx("Camera"),args)
yes(fly.channels[1].keys[2].value==181,
    "Camera longitude crosses ±180 using shortest motion")
local zoom=Motion.plan("MO-CAM-02",ctx("Camera"),args)
yes(zoom.channels[1].channel=="Zoom" and #zoom.channels==1,
    "Zoom To cannot animate Center automatically")
local map=Motion.plan("MO-MAP-01",ctx("Base Map"),args)
yes(map.bindings.layer=="Ocean" and map.channels[1].easing=="Ease Out",
    "Layer Fade targets only chosen base-map layer")

fails(function()Motion.plan("MO-MRK-01",ctx("Region"),args)end,
      "INCOMPATIBLE_OBJECT")
fails(function()Motion.plan("MO-REG-01",setmetatable(
      {kind="Region",animated={["Object Opacity"]=true}},
      {__index=attributes}),args)end,"MOTION_CONFLICT")
fails(function()Motion.plan("MO-REG-01",ctx("Region"),
      {startFrame=490})end,"FRAME_OUT_OF_RANGE")
fails(function()Motion.plan("MO-REG-03",ctx("Region"),
      {startFrame=1})end,"TARGET_REQUIRED")
fails(function()Motion.plan("MO-RTE-03",ctx("Route"),
      {startFrame=1})end,"TARGET_REQUIRED")
fails(function()Motion.plan("MO-CAM-02",ctx("Camera"),
      {startFrame=1})end,"TARGET_REQUIRED")
fails(function()Motion.plan("MO-REG-05",setmetatable(
      {kind="Region",strokeVisible=false},
      {__index=attributes}),args)end,"GEOMETRY_REQUIRED")
fails(function()Motion.plan("MO-MAP-01",setmetatable(
      {kind="Base Map",displayMode="Transparent Overlay"},
      {__index=attributes}),args)end,"UNSUPPORTED_MODE")
fails(function()Motion.plan("MO-RTE-01",setmetatable(
      {kind="Route",routeValid=false},
      {__index=attributes}),args)end,"GEOMETRY_REQUIRED")
fails(function()Motion.plan("MO-REG-01",ctx("Region"),
      {startFrame=2,duration=0})end,"INVALID_DURATION")
fails(function()Motion.plan("MO-REG-01",ctx("Region"),
      {startFrame=2,delay=-1})end,"INVALID_FRAME")
fails(function()Motion.plan("NOT-A-PRESET",ctx("Region"),args)end,"UNKNOWN_PRESET")
yes(#Motion.list("Group")==0,"Group has no unauthorized Motion presets")
print("PASS: "..assertions.." CR-PS-2.0 Motion planner and conflict assertions")
