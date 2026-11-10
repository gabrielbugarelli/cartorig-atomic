-- CartoRig Atomic: read-only local polygon geometry index (Admin0/Admin1).
-- No JSON parser, network, executable data or per-frame disk reads.
-- File is a builder-generated TSV with one source feature per line.
local M = {}
local HEADER = "CARTORIG_ATOMIC_GEOMETRY_V1"

local function fail(code, message)
    error(code .. ": " .. message, 2)
end

local function decode_pair(pair)
    local x, y = pair:match("^([%+%-%.%d]+),([%+%-%.%d]+)$")
    x, y = tonumber(x), tonumber(y)
    if not x or not y or x ~= x or y ~= y or
        x < -180 or x > 180 or y < -90 or y > 90 then
        fail("GEOMETRY_COORDS", "Invalid WGS84 polygon vertex")
    end
    return { lon = x, lat = y }
end

function M.parse_record(line)
    if type(line) ~= "string" or #line > 5000000 then
        fail("GEOMETRY_FORMAT", "Oversized or invalid polygon record")
    end
    local identity, count, encoded =
        line:match("^([^\t]+)\t([^\t]+)\t(.+)$")
    if not identity or not identity:match("^ne10m:[a-z]+:") then
        fail("GEOMETRY_FORMAT", "Invalid Natural Earth feature identity")
    end
    count = tonumber(count)
    if not count or count < 1 or count > 20000 or count%1 ~= 0 then
        fail("GEOMETRY_FORMAT", "Invalid polygon ring count")
    end
    local rings = {}
    for value in (encoded.."|"):gmatch("(.-)|") do
        local kind, coords = value:match("^([OH]):(.+)$")
        if not kind then fail("GEOMETRY_FORMAT", "Invalid polygon ring type") end
        local ring = { kind=kind, vertices={} }
        for point in (coords..";"):gmatch("(.-);") do
            ring.vertices[#ring.vertices+1] = decode_pair(point)
            if #ring.vertices > 200000 then
                fail("GEOMETRY_SIZE", "Single ring exceeds safety limit")
            end
        end
        if #ring.vertices < 3 then
            fail("GEOMETRY_FORMAT", "Polygon ring has fewer than three vertices")
        end
        rings[#rings+1] = ring
    end
    if #rings ~= count or rings[1].kind ~= "O" then
        fail("GEOMETRY_TOPOLOGY", "Polygon multipart ring count or first exterior is invalid")
    end
    return { id=identity, rings=rings, ringCount=count }
end

function M.from_file(path)
    if type(path)~="string" or path=="" then
        fail("GEOMETRY_MISSING", "No installed polygon geometry path")
    end
    local file, issue=io.open(path,"rb")
    if not file then
        fail("GEOMETRY_MISSING", "Offline Natural Earth geometry is unavailable: " ..
             tostring(issue))
    end
    local header=file:read("*l")
    if header~=HEADER then
        file:close()
        fail("GEOMETRY_VERSION","Unsupported or corrupt geometry file")
    end
    local offsets, lengths={},{}
    local previous=file:seek()
    local count=0
    while true do
        local line=file:read("*l")
        if not line then break end
        count=count+1
        if count>10000 then
            file:close()
            fail("GEOMETRY_SIZE","Polygon index exceeds feature limit")
        end
        local id=line:match("^([^\t]+)\t")
        if not id or offsets[id] then
            file:close()
            fail("GEOMETRY_DUPLICATE","Invalid or repeated polygon identity")
        end
        if #line>5000000 then
            file:close()
            fail("GEOMETRY_SIZE","Polygon feature exceeds maximum size")
        end
        offsets[id]=previous
        lengths[id]=#line
        previous=file:seek()
    end
    file:close()
    if count<1 then fail("GEOMETRY_EMPTY","No polygons in offline source") end
    return {
        count=count,
        get=function(_,id)
            if not offsets[id] then return nil end
            local handle, err=io.open(path,"rb")
            if not handle then
                fail("GEOMETRY_MISSING","Cannot reopen installed polygon file: "..tostring(err))
            end
            handle:seek("set", offsets[id])
            local data=handle:read(lengths[id])
            handle:close()
            if not data then fail("GEOMETRY_READ","Truncated installed polygon file") end
            local decoded=M.parse_record(data)
            if decoded.id~=id then
                fail("GEOMETRY_INTEGRITY","Feature index points at a mismatched polygon")
            end
            return decoded
        end
    }
end

return M
