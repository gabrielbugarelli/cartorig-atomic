local Catalog = dofile("fusion/cartorig_catalog.lua")
local checks = 0
local function check(condition, description)
    checks = checks + 1
    if not condition then error("FAIL: " .. description, 2) end
end
local function fails(action, code)
    local ok, issue = pcall(action)
    check(not ok and tostring(issue):find(code, 1, true),
          "expected rejection " .. code)
end

local rows = {
    "CARTORIG_ATOMIC_PLACES_V1",
    "ne10m:country:1\tCountry\tBrazil\t\tBrazil\tSouth America\t\t\tBrasil",
    "ne10m:state:rj\tState\tRio de Janeiro\tBrazil\tBrazil\tSouth America\t\t\t",
    "ne10m:city:rj\tCity\tRio de Janeiro\tRio de Janeiro\tBrazil\tSouth America\t-43.2\t-22.9\tRio",
    "ne10m:state:sp\tState\tSão Paulo\tBrazil\tBrazil\tSouth America\t\t\tSao Paulo",
    "ne10m:city:sp\tCity\tSão Paulo\tSão Paulo\tBrazil\tSouth America\t-46.6333\t-23.5505\tSao Paulo",
    "ne10m:state:ap\tState\tAmapá\tBrazil\tBrazil\tSouth America\t\t\tAmapa",
    "ne10m:city:bsb\tCity\tBrasília\tDistrito Federal\tBrazil\tSouth America\t-47.8825\t-15.7942\tBrasilia",
    "ne10m:city:macapa\tCity\tMacapá\tAmapá\tBrazil\tSouth America\t-51.05\t0.1\tMacapa",
}
local catalog = Catalog.from_lines(rows)
check(catalog.count == 8, "all typed geographic records loaded")
check(catalog:get("ne10m:city:sp").point.lon == -46.6333, "WGS84 coordinates survive")
check(catalog:get("ne10m:state:sp").point == nil,
      "State region never silently receives synthetic centroid")
check(#catalog:search("rio de janeiro") == 2, "Rio city and state remain independent")
check(#catalog:search("rio de janeiro", "State") == 1, "typed region disambiguation")
check(#catalog:search("rio de janeiro", "City") == 1, "typed city disambiguation")
check(#catalog:search("SAO PAULO") == 2, "accent/case folding for São Paulo")
check(#catalog:search("amapa") == 1, "accent folding for Amapá")
check(#catalog:search("brasilia", "City") == 1, "accent folding for Brasília")
check(#catalog:search("brasil", "Country") == 1, "Portuguese alias for Brazil")
check(#catalog:search("") == 0, "blank queries do not dump full index")
check(#catalog:search("unknown-place-39999") == 0, "no hallucinated results")
check(#catalog:search("Rio", nil, 1) == 1, "per-query search result limit")
check(catalog:search("Sao Paulo")[1].id ~= "",
      "every place result carries a stable Natural Earth reference")
check(catalog:search("Macapá", "City")[1].point.lat == 0.1,
      "named explicit route arrival city has real coordinates")

fails(function()
    Catalog.from_lines({ "WRONG_VERSION" })
end, "CATALOG_VERSION")
fails(function()
    Catalog.from_lines({ rows[1], rows[2], rows[2] })
end, "CATALOG_DUPLICATE")
fails(function()
    Catalog.from_lines({ rows[1],
        "id\tCity\tUnknown\tState\tCountry\tEurope\t-\t91\t" })
end, "CATALOG_COORDS")
fails(function()
    Catalog.from_lines({ rows[1],
        "id\tState\tUnknown\tCountry\tCountry\tEurope\t-45\t-20\t" })
end, "CATALOG_FORMAT")
fails(function()
    Catalog.from_lines({ rows[1], "id\tState\tNo columns" })
end, "CATALOG_FORMAT")

local tempfile = os.tmpname()
local file = assert(io.open(tempfile, "wb"))
file:write(table.concat(rows, "\n") .. "\n")
file:close()
local disk = Catalog.from_file(tempfile)
check(disk.count == 8, "offline file loading works without runtime network")
os.remove(tempfile)
fails(function()
    Catalog.from_file(tempfile)
end, "CATALOG_MISSING")

print("PASS: " .. checks .. " Fusion offline geographic search assertions")
