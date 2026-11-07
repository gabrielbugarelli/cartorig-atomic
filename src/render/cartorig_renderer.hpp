#pragma once

#include "cartorig_core.hpp"

#include <array>
#include <cstdint>
#include <vector>

namespace cartorig {

// CPU RGBA pixel buffer; independent from the OpenFX/Fusion SDK and its row stride.
struct Raster {
    int width = 0;
    int height = 0;
    std::vector<std::uint8_t> rgba;

    [[nodiscard]] std::array<std::uint8_t, 4> pixel(int x, int y) const;
};

struct RenderOptions {
    Color water{0.055, 0.115, 0.165, 1.0};
    Style land{{0.35,0.44,0.39,1.0},{0.13,0.20,0.23,1.0},1.0,0.5,true};
    bool drawWorldLand = true;
    bool drawBoundaries = true;
};

// Initial CPU renderer: region fills/boundaries, shared camera, route and arrowhead.
// Does not implement scene keyframes (the native Resolve host owns those).
// Diagnostic LOD, not a performance-certified final 4K renderer.
[[nodiscard]] Raster renderMap(
    const Catalog& catalog,
    const MapScene& scene,
    int width, int height,
    const RenderOptions& options = {});

} // namespace cartorig
