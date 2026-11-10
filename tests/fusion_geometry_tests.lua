local Geometry=dofile("fusion/cartorig_geometry.lua")
local checked=0
local function test(ok,reason)
    checked=checked+1
    if not ok then error("GEOMETRY TEST FAILED: "..reason,2) end
end
local function fails(fn,code)
    local ok,issue=pcall(fn)
    test(not ok and tostring(issue):find(code,1,true),
         "expect error "..code..": "..tostring(issue))
end

local sample="ne10m:state:100\t3\t"..
    "O:-51.000000,0.000000;-50.000000,0.000000;-50.000000,1.000000;-51.000000,1.000000|"..
    "H:-50.800000,0.200000;-50.800000,0.400000;-50.600000,0.400000;-50.600000,0.200000|"..
    "O:179.000000,-1.000000;180.000000,-1.000000;180.000000,1.000000;179.000000,1.000000"
local data=Geometry.parse_record(sample)
test(data.id=="ne10m:state:100","stable geographic identity")
test(data.ringCount==3,"three rings including two independent exteriors")
test(data.rings[1].kind=="O" and data.rings[2].kind=="H" and
     data.rings[3].kind=="O","hole and island fragment must not be merged")
test(#data.rings[1].vertices==4,"linear closed path without duplicated source point")
test(data.rings[3].vertices[1].lon==179,"antimeridian longitude retained")

fails(function()Geometry.parse_record("bad")end,"GEOMETRY_FORMAT")
fails(function()Geometry.parse_record("ne10m:state:1\t1\tH:0,0;1,0;0,1")
end,"GEOMETRY_TOPOLOGY")
fails(function()Geometry.parse_record("ne10m:state:1\t2\tO:0,0;1,0;0,1")
end,"GEOMETRY_TOPOLOGY")
fails(function()Geometry.parse_record("ne10m:state:1\t1\tO:0,0;1,0;181,1")
end,"GEOMETRY_COORDS")
fails(function()Geometry.parse_record("ne10m:state:1\t1\tO:0,0;1,0")
end,"GEOMETRY_FORMAT")

local filename=os.tmpname()
local output=assert(io.open(filename,"wb"))
output:write("CARTORIG_ATOMIC_GEOMETRY_V1\n",sample,"\n")
output:write("ne10m:country:101\t1\tO:-10,0;10,0;10,10;-10,10\n")
output:close()
local index=Geometry.from_file(filename)
test(index.count==2,"lazy on-disk geometry index counts features")
test(index:get("ne10m:state:100").rings[2].kind=="H",
     "indexed read reconstructs holes")
test(index:get("ne10m:country:101").ringCount==1,
     "indexed read retrieves second region")
test(index:get("ne10m:state:other")==nil,
     "nonexistent geometry never becomes fabricated shape")
os.remove(filename)
fails(function()Geometry.from_file(filename)end,"GEOMETRY_MISSING")

local bad=os.tmpname()
local broken=assert(io.open(bad,"wb"))
broken:write("NOT_A_GEOMETRY_FILE\n")
broken:close()
fails(function()Geometry.from_file(bad)end,"GEOMETRY_VERSION")
os.remove(bad)
print("PASS: "..checked.." on-disk Natural Earth polygon / holes / bounds checks")
