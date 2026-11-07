#pragma once

#include <cstddef>
#include <istream>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace cartorig {

enum class LocationType { Country, State, City };

struct GeoPoint {
    double longitude = 0.0;
    double latitude = 0.0;
};

using Ring = std::vector<GeoPoint>;

struct Polygon {
    // GeoJSON convention: outer ring first; subsequent rings are holes.
    std::vector<Ring> rings;
};

struct Feature {
    std::string id;                 // Stable data ID: never a display-name lookup key.
    LocationType type = LocationType::City;
    std::string name;
    std::string parent;             // Admin 1 for cities; country for states.
    std::string country;
    std::vector<std::string> aliases;
    std::optional<GeoPoint> point;  // Natural Earth populated places are points.
    std::vector<Polygon> polygons;  // Admin 0 / Admin 1 only.
};

class Catalog {
public:
    void add(Feature feature);
    [[nodiscard]] const Feature* find(std::string_view id) const noexcept;
    [[nodiscard]] std::vector<const Feature*> search(
        std::string_view text,
        std::optional<LocationType> typeFilter = std::nullopt,
        std::size_t limit = 20) const;

    // UTF-8 tab-delimited CARTORIG_ATOMIC_GEO_V1. See docs/implementation/CATALOG_FORMAT.md.
    static Catalog load(std::istream& stream);
    [[nodiscard]] std::size_t size() const noexcept { return features_.size(); }
    [[nodiscard]] const std::vector<Feature>& features() const noexcept { return features_; }

private:
    std::vector<Feature> features_;
    std::unordered_map<std::string, std::size_t> byId_;
};

[[nodiscard]] std::string normalizeSearch(std::string_view input);
[[nodiscard]] bool contains(const Polygon& polygon, GeoPoint point);
[[nodiscard]] bool contains(const Feature& feature, GeoPoint point);

struct Color {
    double red = 0.0;
    double green = 0.0;
    double blue = 0.0;
    double alpha = 1.0;
};

struct Style {
    Color fill{0.85, 0.45, 0.20, 1.0};
    Color stroke{0.15, 0.20, 0.24, 1.0};
    double opacity = 1.0;          // Whole-object opacity, independent of fill alpha.
    double strokeWidthPixels = 2.0;
    bool visible = true;
};

struct CameraPose {
    GeoPoint center;
    double scale = 1.0;            // Multiplicative camera zoom; not a map tile level.
};

struct ScreenPoint {
    double x = 0.0;
    double y = 0.0;
};

[[nodiscard]] ScreenPoint projectMercator(GeoPoint point);
[[nodiscard]] ScreenPoint viewPosition(
    GeoPoint point, CameraPose pose, double viewportWidth, double viewportHeight);

struct Region {
    std::string objectId;
    std::string featureId;
    Style style;
};

struct Route {
    std::string objectId;
    std::string originFeatureId;
    std::string destinationRegionId;
    GeoPoint from;
    GeoPoint to; // Editor explicitly chose this point; never a guessed capital/centroid.
    Style style;
    double reveal = 1.0;
};

enum class SceneError {
    None, MissingFeature, WrongGeometryType, MissingExplicitEndpoint,
    EndpointOutsideRegion, DuplicateObject, InvalidValue
};

struct SceneResult {
    SceneError error = SceneError::None;
    std::string objectId;
    [[nodiscard]] explicit operator bool() const noexcept { return error == SceneError::None; }
};

class MapScene {
public:
    explicit MapScene(CameraPose pose = {}) : camera_(pose) {}

    [[nodiscard]] SceneResult addRegion(
        const Catalog& catalog, std::string objectId, std::string featureId);
    [[nodiscard]] SceneResult setRegionStyle(std::string_view objectId, Style style);
    [[nodiscard]] SceneResult focusCamera(const Catalog& catalog, std::string_view featureId);
    [[nodiscard]] SceneResult setCamera(CameraPose pose);
    [[nodiscard]] SceneResult addRoute(
        const Catalog& catalog,
        std::string objectId,
        std::string originCityId,
        std::string destinationRegionId,
        std::optional<GeoPoint> explicitEndpoint);
    [[nodiscard]] SceneResult setRouteStyle(std::string_view objectId, Style style);
    [[nodiscard]] SceneResult setRouteReveal(std::string_view objectId, double progress);

    [[nodiscard]] const CameraPose& camera() const noexcept { return camera_; }
    [[nodiscard]] const std::vector<Region>& regions() const noexcept { return regions_; }
    [[nodiscard]] const std::vector<Route>& routes() const noexcept { return routes_; }

private:
    [[nodiscard]] bool objectIdExists(std::string_view objectId) const noexcept;

    CameraPose camera_;
    std::vector<Region> regions_;
    std::vector<Route> routes_;
};

// Native Resolve timeline/keyframe ownership remains in a future host adapter.
// The core intentionally contains no duplicate CartoRig keyframe timeline.

} // namespace cartorig
