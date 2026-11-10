-- Exercise the *real downloaded* Natural Earth index in the same Lua
-- module the Windows installed Scene uses. No Resolve host is simulated here.
local Catalog = dofile("fusion/cartorig_catalog.lua")
local path = assert(arg[1], "expected official offline places.tsv")
local catalog = Catalog.from_file(path)
assert(catalog.count >= 10000, "too few offline Natural Earth features")
local function exact(name, kind)
    local normalized = Catalog.normalize(name)
    for _, row in ipairs(catalog:search(name, kind, 80)) do
        if row.kind == kind and Catalog.normalize(row.name) == normalized then
            return row
        end
    end
    error("Missing real Natural Earth feature: " .. kind .. "/" .. name)
end
local rjState = exact("Rio de Janeiro", "State")
local rjCity = exact("Rio de Janeiro", "City")
assert(rjState.id ~= rjCity.id, "Rio State and City must not alias")
assert(not rjState.point and rjCity.point, "City is a point; State is a polygon")
local spState = exact("São Paulo", "State")
local spCity = exact("São Paulo", "City")
assert(spState.id ~= spCity.id and not spState.point and spCity.point,
       "Sao Paulo State and City must differ")
local brazil = exact("Brazil", "Country")
assert(brazil.id == catalog:search("Brasil", "Country")[1].id,
       "localized Brazil alias must resolve same country")
local brasilia = exact("Brasília", "City")
local amapa = exact("Amapá", "State")
local macapa = exact("Macapá", "City")
assert(brasilia.point and macapa.point and not amapa.point,
       "Brasília and Macapá are geographic points; Amapá is a region")
assert(math.abs(macapa.point.lon) > 45 and macapa.point.lat > -1,
       "Macapá WGS84 source coordinate must be real")
assert(#catalog:search("New Zork XXZ", nil, 20) == 0,
       "offline search must never invent a result")
print("PASS: " .. catalog.count ..
      " official Natural Earth entries; countries, states, cities, aliases, WGS84")
