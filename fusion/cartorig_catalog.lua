-- CartoRig Atomic / indexed offline place catalog.
-- CR-PS-2.0: no external requests, no ISO code entry, no executable data.
-- Real Natural Earth records are distributed as a UTF-8 TSV asset.
local M = {}
local MAGIC = "CARTORIG_ATOMIC_PLACES_V1"

local accents = {
    ["á"]="a",["à"]="a",["â"]="a",["ã"]="a",["ä"]="a",
    ["Á"]="a",["À"]="a",["Â"]="a",["Ã"]="a",["Ä"]="a",
    ["é"]="e",["è"]="e",["ê"]="e",["ë"]="e",
    ["É"]="e",["È"]="e",["Ê"]="e",["Ë"]="e",
    ["í"]="i",["ì"]="i",["î"]="i",["ï"]="i",
    ["Í"]="i",["Ì"]="i",["Î"]="i",["Ï"]="i",
    ["ó"]="o",["ò"]="o",["ô"]="o",["õ"]="o",["ö"]="o",
    ["Ó"]="o",["Ò"]="o",["Ô"]="o",["Õ"]="o",["Ö"]="o",
    ["ú"]="u",["ù"]="u",["û"]="u",["ü"]="u",
    ["Ú"]="u",["Ù"]="u",["Û"]="u",["Ü"]="u",
    ["ç"]="c",["Ç"]="c",["ñ"]="n",["Ñ"]="n"
}
local function normalize(text)
    text = tostring(text or "")
    for accented, plain in pairs(accents) do
        text = text:gsub(accented, plain)
    end
    return text:lower():gsub("[%s%-_]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end
M.normalize = normalize

local function columns(line)
    local result = {}
    local offset = 1
    while true do
        local index = line:find("\t", offset, true)
        if not index then
            result[#result + 1] = line:sub(offset)
            break
        end
        result[#result + 1] = line:sub(offset, index - 1)
        offset = index + 1
    end
    return result
end

local function checked_line(line, index)
    local cells = columns(line)
    if #cells ~= 9 then
        error("CATALOG_FORMAT: invalid column count at row " .. index, 0)
    end
    local id, kind, name, parent, country, continent, lon, lat, aliasText =
        table.unpack(cells)
    if id == "" or name == "" or (kind ~= "Country" and
        kind ~= "State" and kind ~= "City") then
        error("CATALOG_FORMAT: missing identity/type/name at row " .. index, 0)
    end
    local point
    if lon ~= "" or lat ~= "" then
        local x, y = tonumber(lon), tonumber(lat)
        if not x or not y or x ~= x or y ~= y or
            x < -180 or x > 180 or y < -90 or y > 90 then
            error("CATALOG_COORDS: invalid longitude/latitude at row " .. index, 0)
        end
        point = { lon = x, lat = y }
    end
    if kind == "City" and not point then
        error("CATALOG_COORDS: populated place requires a point", 0)
    end
    if kind ~= "City" and point then
        error("CATALOG_FORMAT: countries/states must not invent representative points", 0)
    end
    local aliases = {}
    local seen = {}
    for alias in (aliasText .. ";"):gmatch("(.-);") do
        if alias ~= "" and not seen[normalize(alias)] then
            aliases[#aliases + 1] = alias
            seen[normalize(alias)] = true
        end
    end
    return {
        id = id, kind = kind, name = name, parent = parent,
        country = country, continent = continent,
        point = point, aliases = aliases,
        searchName = normalize(name)
    }
end

local function sorted_matches(rows, query, filter, limit)
    query = normalize(query)
    limit = math.min(tonumber(limit) or 20, 100)
    if query == "" or limit < 1 then return {} end
    local ranked = {}
    local function rank(value)
        if value == query then return 0 end
        if value:sub(1, #query) == query then return 1 end
        if value:find(query, 1, true) then return 2 end
        return nil
    end
    for _, row in ipairs(rows) do
        if filter == nil or filter == "" or filter == "All" or
            row.kind == filter or (filter == "Continent" and
            normalize(row.continent) == query) then
            local score = rank(row.searchName)
            for _, alias in ipairs(row.aliases) do
                local aliasScore = rank(normalize(alias))
                if aliasScore and (not score or aliasScore + 1 < score) then
                    score = aliasScore + 1
                end
            end
            if score ~= nil then
                ranked[#ranked + 1] = { score = score, record = row }
            end
        end
    end
    table.sort(ranked, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.record.searchName ~= b.record.searchName then
            return a.record.searchName < b.record.searchName
        end
        if a.record.country ~= b.record.country then
            return a.record.country < b.record.country
        end
        return a.record.id < b.record.id
    end)
    local results = {}
    for i = 1, math.min(limit, #ranked) do
        results[i] = ranked[i].record
    end
    return results
end

function M.from_lines(lines)
    if type(lines) ~= "table" or lines[1] ~= MAGIC then
        error("CATALOG_VERSION: unsupported offline data pack", 0)
    end
    local places, ids = {}, {}
    if #lines > 150000 then error("CATALOG_SIZE: too many records", 0) end
    for i = 2, #lines do
        local line = lines[i]:gsub("\r$", "")
        if line ~= "" and not line:match("^#") then
            if #line > 50000 then error("CATALOG_SIZE: record too long", 0) end
            local row = checked_line(line, i)
            if ids[row.id] then error("CATALOG_DUPLICATE: repeated feature ID", 0) end
            ids[row.id] = row
            places[#places + 1] = row
        end
    end
    return {
        count = #places,
        get = function(_, id) return ids[id] end,
        search = function(_, query, filter, limit)
            return sorted_matches(places, query, filter, limit)
        end
    }
end

function M.from_file(path)
    if type(path) ~= "string" or path == "" then
        error("CATALOG_PATH: installed data path is unavailable", 0)
    end
    local input, issue = io.open(path, "rb")
    if not input then
        error("CATALOG_MISSING: offline Natural Earth file unavailable: " ..
              tostring(issue), 0)
    end
    local lines = {}
    for line in input:lines() do
        lines[#lines + 1] = line:gsub("\r$", "")
        if #lines > 150000 then
            input:close()
            error("CATALOG_SIZE: invalid offline data pack", 0)
        end
    end
    input:close()
    return M.from_lines(lines)
end

return M
