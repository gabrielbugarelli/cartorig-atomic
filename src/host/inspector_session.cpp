#include "inspector_session.hpp"

#include <algorithm>
#include <sstream>
#include <stdexcept>
#include <utility>

namespace cartorig {
namespace {
const char* typeLabel(LocationType type) {
    switch (type) {
        case LocationType::Country: return "Country";
        case LocationType::State: return "State";
        case LocationType::City: return "City";
    }
    return "Unknown";
}
}

InspectorSession::InspectorSession(const Catalog& catalog) : catalog_(catalog) {}

void InspectorSession::restore(std::string_view snapshot) {
    if (snapshot.empty()) {
        scene_ = MapScene{};
        selectedIndex_ = 0;
        nextId_ = 1;
        return;
    }
    MapScene restored = decodeScene(snapshot, catalog_);
    // Validate before modifying the currently active scene.
    scene_ = std::move(restored);
    selectedIndex_ = 0;
    nextId_ = scene_.regions().size() + scene_.routes().size() + 1;
}

std::string InspectorSession::save() const { return encodeScene(scene_); }

std::vector<SearchEntry> InspectorSession::find(
    std::string_view query, std::optional<LocationType> typeFilter) const {
    const auto items = catalog_.search(query, typeFilter, 20);
    std::vector<SearchEntry> result;
    result.reserve(items.size());
    for (const auto* f : items) {
        result.push_back({f->id, f->type, f->name, f->parent,
                          f->country, !f->polygons.empty()});
    }
    return result;
}

const Feature* InspectorSession::match(
    std::string_view query, std::optional<LocationType> filter, std::size_t index) const {
    const auto results = find(query, filter);
    if (index >= results.size()) return nullptr;
    return catalog_.find(results[index].id);
}

std::string InspectorSession::makeObjectId(std::string_view prefix) {
    return std::string(prefix) + "-" + std::to_string(nextId_++);
}

SceneResult InspectorSession::addRegion(
    std::string_view query, std::optional<LocationType> filter, std::size_t index) {
    const auto* feature = match(query, filter, index);
    if (!feature) return {SceneError::MissingFeature, ""};
    if (feature->type == LocationType::City || feature->polygons.empty())
        return {SceneError::WrongGeometryType, ""};
    auto result = scene_.addRegion(catalog_,makeObjectId("region"),feature->id);
    if (result) selectedIndex_ = scene_.regions().size();
    return result;
}

SceneResult InspectorSession::focusCamera(
    std::string_view query, std::optional<LocationType> filter, std::size_t index) {
    const auto* feature = match(query, filter, index);
    if (!feature) return {SceneError::MissingFeature, ""};
    return scene_.focusCamera(catalog_, feature->id);
}

SceneResult InspectorSession::addRoute(
    std::string_view originQuery,
    std::string_view destinationQuery,
    std::optional<GeoPoint> explicitEndpoint,
    std::string_view selectedDestinationCity) {
    // A route endpoint must be an explicitly selected city or confirmed
    // manual point. State names never imply capital, centroid or 0,0.
    auto originResults = catalog_.search(originQuery, LocationType::City, 20);
    auto destinationResults = catalog_.search(destinationQuery, LocationType::State, 20);
    const auto exact = [](const std::vector<const Feature*>& items, std::string_view name) {
        const auto normalized = normalizeSearch(name);
        const Feature* matching = nullptr;
        for (const auto* f : items) {
            if (normalizeSearch(f->name) != normalized) continue;
            if (matching) return static_cast<const Feature*>(nullptr);
            matching = f;
        }
        return matching;
    };
    const auto* origin = exact(originResults, originQuery);
    const auto* destination = exact(destinationResults, destinationQuery);
    if (!origin || !destination) return {SceneError::MissingFeature, ""};

    if (!selectedDestinationCity.empty()) {
        auto cityResults = catalog_.search(selectedDestinationCity, LocationType::City, 20);
        const Feature* point = nullptr;
        const auto wanted = normalizeSearch(selectedDestinationCity);
        for (const auto* candidate:cityResults) {
            if (normalizeSearch(candidate->name) != wanted || !candidate->point ||
                !contains(*destination, *candidate->point)) continue;
            if (point) return {SceneError::MissingFeature, ""}; // Ambiguous inside region.
            point = candidate;
        }
        if (!point) return {SceneError::MissingFeature, ""};
        explicitEndpoint = point->point;
    }
    if (!explicitEndpoint) return {SceneError::MissingExplicitEndpoint, ""};
    auto result = scene_.addRoute(catalog_,makeObjectId("route"),
                                  origin->id,destination->id,explicitEndpoint);
    if (result) selectedIndex_=objectCount();
    return result;
}

std::size_t InspectorSession::objectCount() const noexcept {
    return scene_.regions().size() + scene_.routes().size();
}

SceneResult InspectorSession::selectObject(std::size_t index) {
    if (index > objectCount()) return {SceneError::MissingFeature, ""};
    selectedIndex_=index;
    return {SceneError::None, ""};
}

std::optional<Style> InspectorSession::selectedStyle() const {
    if (selectedIndex_==0) return std::nullopt;
    if (selectedIndex_<=scene_.regions().size())
        return scene_.regions()[selectedIndex_-1].style;
    const auto routeIndex=selectedIndex_-scene_.regions().size()-1;
    if (routeIndex<scene_.routes().size()) return scene_.routes()[routeIndex].style;
    return std::nullopt;
}

SceneResult InspectorSession::setSelectedStyle(Style style) {
    if (selectedIndex_==0) return {SceneError::MissingFeature,""};
    if (selectedIndex_<=scene_.regions().size())
        return scene_.setRegionStyle(scene_.regions()[selectedIndex_-1].objectId,style);
    const auto index=selectedIndex_-scene_.regions().size()-1;
    if (index>=scene_.routes().size()) return {SceneError::MissingFeature,""};
    return scene_.setRouteStyle(scene_.routes()[index].objectId,style);
}

std::string InspectorSession::objectsSummary() const {
    std::ostringstream text;
    std::size_t index=0;
    for(const auto& obj : scene_.regions()) {
        const auto* feature=catalog_.find(obj.featureId);
        text << ++index << ". Region: "
             << (feature ? feature->name : obj.featureId) << '\n';
    }
    for(const auto& obj : scene_.routes()) {
        const auto* origin=catalog_.find(obj.originFeatureId);
        const auto* destination=catalog_.find(obj.destinationRegionId);
        text << ++index << ". Route: "
             << (origin ? origin->name : obj.originFeatureId) << " -> "
             << (destination ? destination->name : obj.destinationRegionId) << '\n';
    }
    if(!index) text<<"No objects — use Find and Add Region / Add Route";
    return text.str();
}

std::string InspectorSession::selectedDescription() const {
    if (selectedIndex_==0) return "Select an object to edit its style";
    if (selectedIndex_<=scene_.regions().size()) {
        const auto& obj=scene_.regions()[selectedIndex_-1];
        const auto* feature=catalog_.find(obj.featureId);
        if(feature) return std::string("Region — ")+feature->name+" — "+typeLabel(feature->type);
    } else {
        const auto index=selectedIndex_-scene_.regions().size()-1;
        if(index<scene_.routes().size())return "Route — explicitly anchored";
    }
    return "Unknown selection";
}

} // namespace cartorig
