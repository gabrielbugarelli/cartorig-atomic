-- CartoRig Atomic CR-PS-2.0 Motion contract / deterministic frame planner.
-- Provides all 16 R1.0 preset specifications without a custom timeline.
-- A plan is NOT a substitute for native Fusion keyframe host adapter.
local M = {}

local specs = {
    ["MO-REG-01"] = { kind="Region", name="Fade In", duration=24, channels={"Object Opacity"} },
    ["MO-REG-02"] = { kind="Region", name="Fade Out", duration=24, channels={"Object Opacity"} },
    ["MO-REG-03"] = { kind="Region", name="Color Transition", duration=24, channels={"Fill Color"} },
    ["MO-REG-04"] = { kind="Region", name="Instant Color Change", duration=0, channels={"Fill Color"} },
    ["MO-REG-05"] = { kind="Region", name="Border Draw", duration=36, channels={"Stroke Progress"} },
    ["MO-REG-06"] = { kind="Region", name="Highlight Pulse", duration=36, channels={"Highlight Strength"} },
    ["MO-RTE-01"] = { kind="Route", name="Draw Path", duration=30, channels={"Draw Progress"} },
    ["MO-RTE-02"] = { kind="Route", name="Erase Path", duration=30, channels={"Draw Progress"} },
    ["MO-RTE-03"] = { kind="Route", name="Follow Path", duration=60, channels={"Follower Progress"} },
    ["MO-MRK-01"] = { kind="Marker", name="Fade In", duration=18, channels={"Object Opacity"} },
    ["MO-MRK-02"] = { kind="Marker", name="Pop In", duration=18, channels={"Size"} },
    ["MO-CAM-01"] = { kind="Camera", name="Fly To Location", duration=45, channels={"Center Lon","Center Lat","Zoom"} },
    ["MO-CAM-02"] = { kind="Camera", name="Zoom To", duration=30, channels={"Zoom"} },
    ["MO-CAM-03"] = { kind="Camera", name="Fit Transition", duration=45, channels={"Center Lon","Center Lat","Zoom"} },
    ["MO-LBL-01"] = { kind="Label", name="Fade In", duration=18, channels={"Object Opacity"} },
    ["MO-MAP-01"] = { kind="Base Map", name="Layer Fade", duration=18, channels={"Layer Opacity"} },
}
M.PRESETS = specs

local function fail(code, detail)
    error(code .. ": " .. detail, 2)
end

local function finite(value, label)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        fail("INVALID_MOTION", label .. " must be a finite number")
    end
    return value
end

local function frame(value, label)
    value = finite(value, label)
    if value % 1 ~= 0 or value < 0 then
        fail("INVALID_FRAME", label .. " must be a nonnegative integer frame")
    end
    return value
end

local function color(value, label)
    if type(value) ~= "table" or #value ~= 4 then
        fail("TARGET_REQUIRED", label .. " must be RGBA")
    end
    local result = {}
    for i=1,4 do
        result[i] = finite(value[i], label .. " component")
        if result[i] < 0 or result[i] > 1 then
            fail("INVALID_MOTION", "RGBA components must be 0..1")
        end
    end
    return result
end

local function value_at(ctx, channel)
    local values = ctx.current or {}
    if values[channel] == nil then
        fail("CHANNEL_UNAVAILABLE", "Missing Control value for " .. channel)
    end
    return values[channel]
end

local function temporal(ctx, spec, args)
    local start = frame(args.startFrame, "Start Frame")
    local delay = frame(args.delay or 0, "Delay")
    local duration = args.duration == nil and spec.duration or
        frame(args.duration, "Duration")
    if spec.duration == 0 then
        duration = 0
    elseif duration < 1 then
        fail("INVALID_DURATION", "Duration must be at least one frame")
    end
    local compFrames = frame(ctx.compFrames, "Fusion composition frame count")
    if compFrames < 1 then fail("INVALID_FRAME", "Composition has no frames") end
    local first, last = start + delay, start + delay + duration
    if last > compFrames - 1 then
        fail("FRAME_OUT_OF_RANGE", "Preset ends after the Fusion composition")
    end
    return first, last, duration
end

local function key(channel, sequence, easing)
    return { channel = channel, keys = sequence, easing = easing or "Ease In/Out" }
end

local function keys(first, last, source, dest)
    return {{frame=first, value=source},{frame=last,value=dest}}
end

local function explicit(args, field)
    if args[field] == nil then
        fail("TARGET_REQUIRED", field .. " must be chosen explicitly")
    end
    return args[field]
end

local function normalize_longitude(x)
    while x > 180 do x = x - 360 end
    while x < -180 do x = x + 360 end
    return x
end

function M.list(kind)
    local entries = {}
    for id, p in pairs(specs) do
        if p.kind == kind then
            entries[#entries + 1] = {id=id, name=p.name, duration=p.duration}
        end
    end
    table.sort(entries, function(a,b) return a.id < b.id end)
    return entries
end

function M.plan(id, ctx, args)
    ctx, args = ctx or {}, args or {}
    local spec = specs[id]
    if not spec then fail("UNKNOWN_PRESET", "No such release-1.0 Motion preset") end
    if ctx.kind ~= spec.kind then
        fail("INCOMPATIBLE_OBJECT", id .. " applies only to " .. spec.kind)
    end
    if ctx.locked or ctx.visible == false then
        fail("LOCKED", "Target object is not available for Motion")
    end
    for _, channel in ipairs(spec.channels) do
        if ctx.animated and ctx.animated[channel] then
            fail("MOTION_CONFLICT", channel .. " already contains host animation")
        end
    end
    local first,last,duration = temporal(ctx,spec,args)
    local easing = args.easing or "Ease In/Out"
    local affected, bindings = {}, {}
    local function add(channel, sequence, curve)
        affected[#affected+1] = key(channel, sequence, curve or easing)
    end

    if id=="MO-REG-01" or id=="MO-MRK-01" or id=="MO-LBL-01" then
        local target=finite(value_at(ctx,"Object Opacity"),"target opacity")
        if target<=0 then fail("INVALID_MOTION","Target opacity must exceed zero") end
        add("Object Opacity", keys(first,last,0,target))
    elseif id=="MO-REG-02" then
        local source=finite(value_at(ctx,"Object Opacity"),"source opacity")
        if source<=0 then fail("INVALID_MOTION","Initial opacity must exceed zero") end
        add("Object Opacity", keys(first,last,source,0))
    elseif id=="MO-REG-03" or id=="MO-REG-04" then
        local source=color(value_at(ctx,"Fill Color"),"source fill")
        local target=color(explicit(args,"targetRGBA"),"target fill")
        if id=="MO-REG-03" then
            add("Fill Color", keys(first,last,source,target),"Linear")
        else
            local sequence={{frame=first,value=target}}
            if first>0 then
                table.insert(sequence,1,{frame=first-1,value=source})
            end
            add("Fill Color",sequence,"Hold")
        end
    elseif id=="MO-REG-05" then
        if not ctx.strokeVisible then
            fail("GEOMETRY_REQUIRED","Region needs visible polygon stroke")
        end
        add("Stroke Progress", keys(first,last,0,1))
    elseif id=="MO-REG-06" then
        local count=frame(args.pulseCount or 2,"Pulse Count")
        local cycle=frame(args.cycle or 18,"Cycle")
        local peak=finite(args.peakStrength or .35,"Peak Strength")
        if count<1 or count>8 or cycle<2 or cycle>120 or peak<0 or peak>1 then
            fail("INVALID_MOTION","Pulse parameters out of range")
        end
        last=first+count*cycle
        if last>=ctx.compFrames then fail("FRAME_OUT_OF_RANGE","Pulse exceeds comp") end
        local sequence={{frame=first,value=0}}
        for n=0,count-1 do
            sequence[#sequence+1]={frame=first+n*cycle+math.floor(cycle/2),value=peak}
            sequence[#sequence+1]={frame=first+(n+1)*cycle,value=0}
        end
        add("Highlight Strength",sequence,"Smooth")
    elseif id=="MO-RTE-01" or id=="MO-RTE-02" then
        if not ctx.routeValid then fail("GEOMETRY_REQUIRED","Route geometry is required") end
        local source=id=="MO-RTE-01" and 0 or 1
        add("Draw Progress",keys(first,last,source,1-source))
    elseif id=="MO-RTE-03" then
        if not ctx.routeValid then fail("GEOMETRY_REQUIRED","Route geometry is required") end
        local follower=explicit(args,"followerObjectId")
        if not ctx.availableMarkers or not ctx.availableMarkers[follower] then
            fail("FOLLOWER_REQUIRED","Choose an existing Marker in this Scene")
        end
        bindings.followerObjectId=follower
        add("Follower Progress",keys(first,last,0,1),"Linear")
    elseif id=="MO-MRK-02" then
        local target=finite(value_at(ctx,"Size"),"Marker Size")
        if target<=0 then fail("INVALID_MOTION","Marker Size must be positive") end
        local middle=first+math.floor(duration*.70+.5)
        add("Size",{{frame=first,value=0},
                    {frame=middle,value=target*1.15},
                    {frame=last,value=target}},"Bezier")
    elseif id=="MO-CAM-01" or id=="MO-CAM-03" then
        local target=explicit(args,"targetPose")
        if type(target)~="table" then
            fail("TARGET_REQUIRED","Camera pose must be explicitly resolved")
        end
        local lon=finite(target.lon,"target longitude")
        local lat=finite(target.lat,"target latitude")
        local zoom=finite(target.zoom,"target zoom")
        if lon < -180 or lon > 180 or lat < -90 or lat > 90 or zoom <= 0 then
            fail("INVALID_MOTION","Invalid target camera pose")
        end
        local originLon=finite(value_at(ctx,"Center Lon"),"camera longitude")
        local delta=lon-originLon
        if delta>180 then delta=delta-360 end
        if delta < -180 then delta=delta+360 end
        bindings.wrapLongitude=true
        bindings.targetOriginalLon=lon
        add("Center Lon",keys(first,last,originLon,originLon+delta))
        add("Center Lat",keys(first,last,
            finite(value_at(ctx,"Center Lat"),"camera latitude"),lat))
        add("Zoom",keys(first,last,finite(value_at(ctx,"Zoom"),"camera zoom"),zoom))
    elseif id=="MO-CAM-02" then
        local zoom=finite(explicit(args,"targetZoom"),"target Zoom")
        if zoom <= 0 then fail("INVALID_MOTION","Zoom must be >0") end
        add("Zoom",keys(first,last,finite(value_at(ctx,"Zoom"),"source Zoom"),zoom))
    elseif id=="MO-MAP-01" then
        if ctx.displayMode~="Full Map" then
            fail("UNSUPPORTED_MODE","Layer Fade requires Full Map")
        end
        local layer=explicit(args,"layer")
        local available={
            Ocean=true, Land=true, Coastline=true,
            ["Country Borders"]=true,["State Borders"]=true
        }
        if not available[layer] or not(ctx.availableLayers and ctx.availableLayers[layer]) then
            fail("LAYER_REQUIRED","Choose an active base-map layer")
        end
        bindings.layer=layer
        add("Layer Opacity",keys(first,last,0,1),"Ease Out")
    else
        fail("UNKNOWN_PRESET","Preset implementation missing")
    end

    return {
        presetId=id, kind=ctx.kind, startFrame=first,
        endFrame=last, durationFrames=last-first,
        channels=affected, bindings=bindings, state="PLANNED_NOT_APPLIED",
        hostKeysWritten=false,
    }
end

return M
