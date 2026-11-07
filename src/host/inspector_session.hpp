#pragma once

#include "cartorig_core.hpp"

#include <cstddef>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace cartorig {

// Testable command layer between native Inspector event handlers and the
// strictly host-independent scene model. It never opens a new UI window.
struct SearchEntry {
    std::string id;
    LocationType type;
    std::string name;
    std::string parent;
    std::string country;
    bool polygonAvailable = false;
};

class InspectorSession {
public:
    explicit InspectorSession(const Catalog& catalog);

    void restore(std::string_view sceneSnapshot);
    [[nodiscard]] const MapScene& scene() const noexcept { return scene_; }
    [[nodiscard]] std::string save() const;

    [[nodiscard]] std::vector<SearchEntry> find(
        std::string_view query, std::optional<LocationType> typeFilter) const;

    // The index identifies an explicitly selected search-result entry. It
    // does not guess whether an ambiguous place is a City or a State.
    [[nodiscard]] SceneResult addRegion(
        std::string_view query, std::optional<LocationType> filter,
        std::size_t selectedResultIndex);
    [[nodiscard]] SceneResult focusCamera(
        std::string_view query, std::optional<LocationType> filter,
        std::size_t selectedResultIndex);

    [[nodiscard]] SceneResult addRoute(
        std::string_view fromCityQuery,
        std::string_view toStateQuery,
        std::optional<GeoPoint> explicitlyChosenDestination,
        std::string_view chosenDestinationCity = {});

    [[nodiscard]] SceneResult selectObject(std::size_t index);
    [[nodiscard]] SceneResult setSelectedStyle(Style style);

    [[nodiscard]] std::size_t selectedIndex() const noexcept { return selectedIndex_; }
    [[nodiscard]] std::size_t objectCount() const noexcept;
    [[nodiscard]] std::string objectsSummary() const;
    [[nodiscard]] std::string selectedDescription() const;
    [[nodiscard]] std::optional<Style> selectedStyle() const;

private:
    const Catalog& catalog_;
    MapScene scene_;
    std::size_t selectedIndex_ = 0; // 1-based; 0 means no object.
    std::size_t nextId_ = 1;
    [[nodiscard]] std::string makeObjectId(std::string_view prefix);
    [[nodiscard]] const Feature* match(
        std::string_view query, std::optional<LocationType> filter,
        std::size_t selectedResultIndex) const;
};

} // namespace cartorig
