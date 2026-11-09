local Geometry=dofile("fusion/cartorig_geometry.lua")
local path=assert(arg[1],"Provide official geometry.tsv built by CI")
local index=Geometry.from_file(path)
assert(index.count>4000,"Natural Earth Admin0/Admin1 geometry index is incomplete")
local exampleCountry,exampleState
local f=assert(io.open(path,"rb"))
assert(f:read("*l")=="CARTORIG_ATOMIC_GEOMETRY_V1")
for line in f:lines() do
    local id=line:match("^([^\t]+)")
    if id:match("^ne10m:country:") and not exampleCountry then exampleCountry=id end
    if id:match("^ne10m:state:") and not exampleState then exampleState=id end
end
f:close()
assert(exampleCountry and exampleState,"Country/State geometry missing")
local c=index:get(exampleCountry)
local s=index:get(exampleState)
assert(c.id==exampleCountry and #c.rings>=1,"real Country polygon decodes")
assert(s.id==exampleState and #s.rings>=1,"real State polygon decodes")
for _,obj in ipairs({c,s}) do
    assert(obj.rings[1].kind=="O","each region contains exterior")
    for _,ring in ipairs(obj.rings) do
        assert(#ring.vertices>=3,"real ring is valid")
    end
end
print("PASS: "..index.count.." real Natural Earth polygon geometries indexed and decoded")
