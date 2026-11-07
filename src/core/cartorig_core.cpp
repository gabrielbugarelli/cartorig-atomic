#include "cartorig_core.hpp"

#include <algorithm>
#include <cmath>
#include <cctype>
#include <limits>
#include <iomanip>
#include <sstream>
#include <stdexcept>
#include <tuple>
#include <utility>

namespace cartorig {
namespace {

constexpr double kPi = 3.1415926535897932384626433832795;
constexpr double kMercatorLatitude = 85.0511287798066;

[[nodiscard]] bool finite(double value) {
    return std::isfinite(value);
}

[[nodiscard]] bool validPoint(GeoPoint p) {
    return finite(p.longitude) && finite(p.latitude) &&
           p.longitude >= -180.0 && p.longitude <= 180.0 &&
           p.latitude >= -90.0 && p.latitude <= 90.0;
}

[[nodiscard]] bool validStyle(const Style& style) {
    const Color colors[] = {style.fill, style.stroke};
    for (const auto& c : colors) {
        for (double n : {c.red, c.green, c.blue, c.alpha}) {
            if (!finite(n) || n < 0.0 || n > 1.0) return false;
        }
    }
    return finite(style.opacity) && style.opacity >= 0.0 && style.opacity <= 1.0 &&
           finite(style.strokeWidthPixels) && style.strokeWidthPixels >= 0.0 &&
           style.strokeWidthPixels <= 1000.0;
}

[[nodiscard]] std::vector<std::string> split(std::string_view text, char delimiter) {
    std::vector<std::string> result;
    std::size_t begin = 0;
    do {
        auto end = text.find(delimiter, begin);
        result.emplace_back(text.substr(begin, end == std::string_view::npos ? end : end - begin));
        if (end == std::string_view::npos) break;
        begin = end + 1;
    } while (true);
    return result;
}

[[nodiscard]] double number(const std::string& text) {
    std::size_t parsed = 0;
    double value = std::stod(text, &parsed);
    if (parsed != text.size() || !finite(value)) throw std::invalid_argument("invalid coordinate");
    return value;
}

[[nodiscard]] GeoPoint parsePoint(const std::string& text) {
    const auto values = split(text, ',');
    if (values.size() != 2) throw std::invalid_argument("coordinate needs lon,lat");
    const GeoPoint p{number(values[0]), number(values[1])};
    if (!validPoint(p)) throw std::invalid_argument("longitude/latitude out of bounds");
    return p;
}

[[nodiscard]] std::vector<Polygon> parsePolygons(const std::string& text) {
    std::vector<Polygon> polygons;
    if (text.empty()) return polygons;
    // Multipolygon: polygons separated by '|'; rings by '~'; vertices by ';'.
    for (const auto& polygonText : split(text, '|')) {
        Polygon polygon;
        for (const auto& ringText : split(polygonText, '~')) {
            Ring ring;
            for (const auto& pointText : split(ringText, ';')) {
                ring.push_back(parsePoint(pointText));
            }
            if (ring.size() < 4 ||
                std::abs(ring.front().longitude - ring.back().longitude) > 1e-8 ||
                std::abs(ring.front().latitude - ring.back().latitude) > 1e-8) {
                throw std::invalid_argument("polygon ring must be closed and contain 4+ vertices");
            }
            polygon.rings.push_back(std::move(ring));
        }
        if (polygon.rings.empty()) throw std::invalid_argument("empty polygon");
        polygons.push_back(std::move(polygon));
    }
    return polygons;
}

[[nodiscard]] bool onSegment(GeoPoint a, GeoPoint b, GeoPoint p) {
    const double cross = (b.longitude - a.longitude) * (p.latitude - a.latitude) -
                         (b.latitude - a.latitude) * (p.longitude - a.longitude);
    if (std::abs(cross) > 1e-10) return false;
    const double minX = std::min(a.longitude, b.longitude) - 1e-10;
    const double maxX = std::max(a.longitude, b.longitude) + 1e-10;
    const double minY = std::min(a.latitude, b.latitude) - 1e-10;
    const double maxY = std::max(a.latitude, b.latitude) + 1e-10;
    return p.longitude >= minX && p.longitude <= maxX &&
           p.latitude >= minY && p.latitude <= maxY;
}

[[nodiscard]] bool inRing(const Ring& ring, GeoPoint p) {
    bool inside = false;
    for (std::size_t i = 0, j = ring.size() - 1; i < ring.size(); j = i++) {
        const auto a = ring[i], b = ring[j];
        if (onSegment(a, b, p)) return true;
        const bool crosses = (a.latitude > p.latitude) != (b.latitude > p.latitude);
        if (crosses) {
            const double x = (b.longitude - a.longitude) *
                            (p.latitude - a.latitude) / (b.latitude - a.latitude) +
                             a.longitude;
            if (p.longitude < x) inside = !inside;
        }
    }
    return inside;
}

[[nodiscard]] bool prefix(std::string_view candidate, std::string_view text) {
    return candidate.size() >= text.size() &&
           candidate.compare(0, text.size(), text) == 0;
}

[[nodiscard]] int rank(std::string_view candidate, std::string_view text, bool alias) {
    if (candidate == text) return alias ? 1 : 0;
    if (prefix(candidate, text)) return alias ? 3 : 2;
    if (candidate.find(text) != std::string_view::npos) return alias ? 5 : 4;
    return 100;
}

[[nodiscard]] std::optional<int> matchScore(const Feature& feature, std::string_view query) {
    int score = rank(normalizeSearch(feature.name), query, false);
    for (const auto& alias : feature.aliases) {
        score = std::min(score, rank(normalizeSearch(alias), query, true));
    }
    return score == 100 ? std::nullopt : std::optional<int>{score};
}

[[nodiscard]] bool allAsciiSpaceOrDelimiter(unsigned char c) {
    return c == ' ' || c == '\t' || c == '\r' || c == '\n' ||
           c == '_' || c == '-';
}

} // namespace

std::string normalizeSearch(std::string_view input) {
    // Deliberately small portable accent fold for common European/Portuguese
    // names. Preserve unknown UTF-8 code points verbatim for exact Unicode search.
    static const std::unordered_map<std::string, std::string> accents = {
        {"á","a"},{"à","a"},{"â","a"},{"ã","a"},{"ä","a"},{"å","a"},
        {"Á","a"},{"À","a"},{"Â","a"},{"Ã","a"},{"Ä","a"},{"Å","a"},
        {"é","e"},{"è","e"},{"ê","e"},{"ë","e"},
        {"É","e"},{"È","e"},{"Ê","e"},{"Ë","e"},
        {"í","i"},{"ì","i"},{"î","i"},{"ï","i"},
        {"Í","i"},{"Ì","i"},{"Î","i"},{"Ï","i"},
        {"ó","o"},{"ò","o"},{"ô","o"},{"õ","o"},{"ö","o"},{"ø","o"},
        {"Ó","o"},{"Ò","o"},{"Ô","o"},{"Õ","o"},{"Ö","o"},{"Ø","o"},
        {"ú","u"},{"ù","u"},{"û","u"},{"ü","u"},
        {"Ú","u"},{"Ù","u"},{"Û","u"},{"Ü","u"},
        {"ç","c"},{"Ç","c"},{"ñ","n"},{"Ñ","n"},
        {"ý","y"},{"ÿ","y"},{"Ý","y"},{"ß","ss"},
        {"æ","ae"},{"Æ","ae"},{"œ","oe"},{"Œ","oe"},
        {"ł","l"},{"Ł","l"}
    };
    std::string folded;
    bool previousSpace = true;
    for (std::size_t i = 0; i < input.size();) {
        const unsigned char first = static_cast<unsigned char>(input[i]);
        if (first < 128) {
            const char c = static_cast<char>(first);
            if (allAsciiSpaceOrDelimiter(first)) {
                if (!previousSpace) folded += ' ';
                previousSpace = true;
            } else {
                folded += static_cast<char>(std::tolower(first));
                previousSpace = false;
            }
            ++i;
            continue;
        }
        std::size_t count = (first & 0xE0) == 0xC0 ? 2 :
                            (first & 0xF0) == 0xE0 ? 3 :
                            (first & 0xF8) == 0xF0 ? 4 : 1;
        if (i + count > input.size()) count = 1;
        auto sequence = std::string(input.substr(i, count));
        if (const auto it = accents.find(sequence); it != accents.end()) folded += it->second;
        else folded += sequence;
        previousSpace = false;
        i += count;
    }
    if (!folded.empty() && folded.back() == ' ') folded.pop_back();
    return folded;
}

void Catalog::add(Feature feature) {
    if (feature.id.empty() || feature.name.empty()) {
        throw std::invalid_argument("feature id/name cannot be blank");
    }
    if (byId_.find(feature.id) != byId_.end()) {
        throw std::invalid_argument("duplicate geographic feature id: " + feature.id);
    }
    if (feature.type == LocationType::City && !feature.point.has_value()) {
        throw std::invalid_argument("city must have real coordinates");
    }
    if (feature.point && !validPoint(*feature.point)) {
        throw std::invalid_argument("feature point has invalid coordinates");
    }
    byId_.emplace(feature.id, features_.size());
    features_.push_back(std::move(feature));
}

const Feature* Catalog::find(std::string_view id) const noexcept {
    const auto it = byId_.find(std::string(id));
    return it == byId_.end() ? nullptr : &features_[it->second];
}

std::vector<const Feature*> Catalog::search(
    std::string_view text, std::optional<LocationType> filter, std::size_t limit) const {
    const auto query = normalizeSearch(text);
    if (query.empty() || limit == 0) return {};
    std::vector<std::pair<int, const Feature*>> matches;
    for (const auto& item : features_) {
        if (filter && item.type != *filter) continue;
        if (auto score = matchScore(item, query)) matches.emplace_back(*score, &item);
    }
    std::sort(matches.begin(), matches.end(), [](const auto& a, const auto& b) {
        return std::tuple(a.first, normalizeSearch(a.second->name),
                          normalizeSearch(a.second->country), a.second->id) <
               std::tuple(b.first, normalizeSearch(b.second->name),
                          normalizeSearch(b.second->country), b.second->id);
    });
    std::vector<const Feature*> out;
    for (const auto& match : matches) {
        if (out.size() >= limit) break;
        out.push_back(match.second);
    }
    return out;
}

Catalog Catalog::load(std::istream& stream) {
    Catalog catalog;
    std::string line;
    if (!std::getline(stream, line) || line != "CARTORIG_ATOMIC_GEO_V1") {
        throw std::invalid_argument("unsupported/offline catalog format");
    }
    std::size_t lineNumber = 1;
    while (std::getline(stream, line)) {
        ++lineNumber;
        if (line.empty() || line.front() == '#') continue;
        const auto fields = split(line, '\t');
        if (fields.size() != 9) {
            throw std::invalid_argument("catalog row " + std::to_string(lineNumber) +
                                        " must have 9 columns");
        }
        Feature f;
        f.id = fields[0];
        if (fields[1] == "country") f.type = LocationType::Country;
        else if (fields[1] == "state") f.type = LocationType::State;
        else if (fields[1] == "city") f.type = LocationType::City;
        else throw std::invalid_argument("unknown geographic type");
        f.name = fields[2];
        f.parent = fields[3];
        f.country = fields[4];
        if (!fields[5].empty()) f.aliases = split(fields[5], ';');
        const bool longitudePresent = fields[6] != ".";
        const bool latitudePresent = fields[7] != ".";
        if (longitudePresent != latitudePresent) throw std::invalid_argument("incomplete point");
        if (longitudePresent) f.point = GeoPoint{number(fields[6]), number(fields[7])};
        f.polygons = parsePolygons(fields[8]);
        catalog.add(std::move(f));
    }
    return catalog;
}

bool contains(const Polygon& polygon, GeoPoint p) {
    if (polygon.rings.empty() || !validPoint(p)) return false;
    if (!inRing(polygon.rings[0], p)) return false;
    for (std::size_t i = 1; i < polygon.rings.size(); ++i)
        if (inRing(polygon.rings[i], p)) return false;
    return true;
}

bool contains(const Feature& feature, GeoPoint p) {
    for (const auto& polygon : feature.polygons) {
        if (contains(polygon, p)) return true;
    }
    return false;
}

ScreenPoint projectMercator(GeoPoint point) {
    if (!validPoint(point)) throw std::invalid_argument("invalid geographic coordinate");
    const double lat = std::clamp(point.latitude, -kMercatorLatitude, kMercatorLatitude);
    const double phi = lat * kPi / 180.0;
    return {(point.longitude + 180.0) / 360.0,
            (1.0 - std::log(std::tan(kPi / 4.0 + phi / 2.0)) / kPi) / 2.0};
}

ScreenPoint viewPosition(GeoPoint p, CameraPose camera, double width, double height) {
    if (!finite(camera.scale) || camera.scale <= 0 || !finite(width) ||
        !finite(height) || width <= 0 || height <= 0)
        throw std::invalid_argument("invalid camera or viewport size");
    const auto mapped = projectMercator(p);
    const auto focus = projectMercator(camera.center);
    double dx = mapped.x - focus.x;
    // Smallest longitudinal distance across the ±180° antimeridian.
    if (dx > 0.5) dx -= 1.0;
    if (dx < -0.5) dx += 1.0;
    const double pixelsPerWorld = width * camera.scale;
    return {width / 2.0 + dx * pixelsPerWorld,
            height / 2.0 + (mapped.y - focus.y) * pixelsPerWorld};
}

bool MapScene::objectIdExists(std::string_view id) const noexcept {
    for (const auto& r : regions_) if (r.objectId == id) return true;
    for (const auto& r : routes_) if (r.objectId == id) return true;
    return false;
}

SceneResult MapScene::addRegion(const Catalog& catalog,
                                std::string objectId, std::string featureId) {
    const auto* f = catalog.find(featureId);
    if (!f) return {SceneError::MissingFeature, ""};
    if (f->type == LocationType::City || f->polygons.empty())
        return {SceneError::WrongGeometryType, ""};
    if (objectId.empty() || objectIdExists(objectId))
        return {SceneError::DuplicateObject, ""};
    regions_.push_back({std::move(objectId), std::move(featureId), {}});
    return {SceneError::None, regions_.back().objectId};
}

SceneResult MapScene::setRegionStyle(std::string_view objectId, Style style) {
    if (!validStyle(style)) return {SceneError::InvalidValue, ""};
    for (auto& region : regions_) {
        if (region.objectId == objectId) {
            region.style = style;
            return {SceneError::None, region.objectId};
        }
    }
    return {SceneError::MissingFeature, ""};
}

SceneResult MapScene::focusCamera(const Catalog& catalog, std::string_view featureId) {
    const auto* feature = catalog.find(featureId);
    if (!feature) return {SceneError::MissingFeature, ""};
    if (!feature->point) return {SceneError::WrongGeometryType, ""};
    camera_.center = *feature->point; // Static focus only; never creates a keyframe.
    return {SceneError::None, ""};
}

SceneResult MapScene::setCamera(CameraPose pose) {
    if (!validPoint(pose.center) || !finite(pose.scale) || pose.scale <= 0.0 ||
        pose.scale > 100000.0)
        return {SceneError::InvalidValue, ""};
    camera_ = pose;
    return {SceneError::None, ""};
}

SceneResult MapScene::addRoute(const Catalog& catalog,
                               std::string objectId, std::string originCityId,
                               std::string destinationRegionId,
                               std::optional<GeoPoint> explicitEndpoint) {
    const auto* from = catalog.find(originCityId);
    const auto* destination = catalog.find(destinationRegionId);
    if (!from || !destination) return {SceneError::MissingFeature, ""};
    if (from->type != LocationType::City || !from->point ||
        destination->type == LocationType::City || destination->polygons.empty())
        return {SceneError::WrongGeometryType, ""};
    if (!explicitEndpoint) return {SceneError::MissingExplicitEndpoint, ""};
    if (!validPoint(*explicitEndpoint) || !contains(*destination, *explicitEndpoint))
        return {SceneError::EndpointOutsideRegion, ""};
    if (objectId.empty() || objectIdExists(objectId))
        return {SceneError::DuplicateObject, ""};
    Route route;
    route.objectId = std::move(objectId);
    route.originFeatureId = std::move(originCityId);
    route.destinationRegionId = std::move(destinationRegionId);
    route.from = *from->point;
    route.to = *explicitEndpoint;
    routes_.push_back(std::move(route));
    return {SceneError::None, routes_.back().objectId};
}

SceneResult MapScene::setRouteStyle(std::string_view objectId, Style style) {
    if (!validStyle(style)) return {SceneError::InvalidValue, ""};
    for (auto& route : routes_) {
        if (route.objectId == objectId) {
            route.style = style;
            return {SceneError::None, route.objectId};
        }
    }
    return {SceneError::MissingFeature, ""};
}


SceneResult MapScene::setRouteReveal(std::string_view objectId, double progress) {
    if (!finite(progress) || progress < 0.0 || progress > 1.0)
        return {SceneError::InvalidValue, ""};
    for (auto& route : routes_) {
        if (route.objectId == objectId) {
            route.reveal = progress;
            return {SceneError::None, route.objectId};
        }
    }
    return {SceneError::MissingFeature, ""};
}


namespace {

[[nodiscard]] bool safeId(std::string_view id) {
    if (id.empty()) return false;
    for (unsigned char ch : id) {
        if (!(std::isalnum(ch) || ch == '_' || ch == '-' ||
              ch == ':' || ch == '.')) return false;
    }
    return true;
}

void serializeStyle(std::ostream& output, const Style& s) {
    for (double value : {s.fill.red,s.fill.green,s.fill.blue,s.fill.alpha,
                         s.stroke.red,s.stroke.green,s.stroke.blue,s.stroke.alpha,
                         s.opacity,s.strokeWidthPixels})
        output << '\t' << value;
    output << '\t' << (s.visible ? 1 : 0);
}

[[nodiscard]] Style readStyle(const std::vector<std::string>& fields, std::size_t offset) {
    if (fields.size() != offset + 11)
        throw std::invalid_argument("corrupt style fields in scene snapshot");
    Style s;
    s.fill = {number(fields[offset]),number(fields[offset+1]),
              number(fields[offset+2]),number(fields[offset+3])};
    s.stroke = {number(fields[offset+4]),number(fields[offset+5]),
                number(fields[offset+6]),number(fields[offset+7])};
    s.opacity = number(fields[offset+8]);
    s.strokeWidthPixels = number(fields[offset+9]);
    if (fields[offset+10] == "1") s.visible=true;
    else if (fields[offset+10] == "0") s.visible=false;
    else throw std::invalid_argument("invalid visibility flag");
    if (!validStyle(s)) throw std::invalid_argument("invalid scene style");
    return s;
}

} // namespace

std::string encodeScene(const MapScene& scene) {
    std::ostringstream out;
    out << std::setprecision(17);
    out << "CARTORIG_ATOMIC_SCENE_V1\n";
    const auto& camera = scene.camera();
    out << "CAMERA\t" << camera.center.longitude << '\t'
        << camera.center.latitude << '\t' << camera.scale << '\n';
    for (const auto& region : scene.regions()) {
        if (!safeId(region.objectId) || !safeId(region.featureId))
            throw std::invalid_argument("unsafe region id in scene");
        out << "REGION\t" << region.objectId << '\t' << region.featureId;
        serializeStyle(out,region.style);
        out << '\n';
    }
    for (const auto& route : scene.routes()) {
        if (!safeId(route.objectId) || !safeId(route.originFeatureId) ||
            !safeId(route.destinationRegionId))
            throw std::invalid_argument("unsafe route id in scene");
        out << "ROUTE\t" << route.objectId << '\t'
            << route.originFeatureId << '\t' << route.destinationRegionId
            << '\t' << route.to.longitude << '\t' << route.to.latitude;
        serializeStyle(out,route.style);
        out << '\t' << route.reveal << '\n';
    }
    return out.str();
}

MapScene decodeScene(std::string_view snapshot, const Catalog& catalog) {
    std::istringstream in(std::string{snapshot});
    std::string line;
    if (!std::getline(in,line) || line != "CARTORIG_ATOMIC_SCENE_V1")
        throw std::invalid_argument("unsupported scene format");
    MapScene scene;
    bool cameraSeen=false;
    while (std::getline(in,line)) {
        if (line.empty()) continue;
        const auto f=split(line,'\t');
        if (f.empty()) continue;
        if (f[0] == "CAMERA") {
            if (f.size()!=4 || cameraSeen)
                throw std::invalid_argument("invalid or duplicate camera");
            const auto state=scene.setCamera({{number(f[1]),number(f[2])},number(f[3])});
            if (!state) throw std::invalid_argument("invalid camera pose");
            cameraSeen=true;
        } else if (f[0] == "REGION") {
            if (f.size()!=14 || !safeId(f[1]) || !safeId(f[2]))
                throw std::invalid_argument("corrupt region record");
            const auto style=readStyle(f,3);
            if (!scene.addRegion(catalog,f[1],f[2]) ||
                !scene.setRegionStyle(f[1],style))
                throw std::invalid_argument("invalid geographic region in snapshot");
        } else if (f[0] == "ROUTE") {
            if (f.size()!=18 || !safeId(f[1]) ||
                !safeId(f[2]) || !safeId(f[3]))
                throw std::invalid_argument("corrupt route record");
            const GeoPoint to{number(f[4]),number(f[5])};
            const auto style=readStyle(
                std::vector<std::string>(f.begin(),f.end()-1),6);
            const double reveal=number(f[17]);
            if (!scene.addRoute(catalog,f[1],f[2],f[3],to) ||
                !scene.setRouteStyle(f[1],style) ||
                !scene.setRouteReveal(f[1],reveal))
                throw std::invalid_argument("invalid route/endpoint in snapshot");
        } else {
            throw std::invalid_argument("unknown scene record");
        }
    }
    if (!cameraSeen) throw std::invalid_argument("missing camera in scene snapshot");
    return scene; // A failed read never mutates an existing MapScene.
}

} // namespace cartorig
