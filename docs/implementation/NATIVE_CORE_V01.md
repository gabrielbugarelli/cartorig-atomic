# Native implementation v0.1 — Actual status

**This is real code, not a visual mock.** It is also **not yet a functioning DaVinci Resolve plugin**. The approved Edit Inspector remains the intended everyday UI (DEC-007); a future host adapter must connect it to this code.

## Implemented (new C++17 source)

| Module | Code | Supported behavior |
| --- | --- | --- |
| Offline catalog | `src/core/cartorig_core.*` | Country/State/City types, names/aliases, stable source IDs, UTF-8 Portuguese accent-fold search, true city points vs region polygons |
| Geographic topology | `src/core/cartorig_core.*` | Polygon/multipolygon with holes, point-in-region checks for route endpoints |
| Scene model | `src/core/cartorig_core.*` | Independently styled regions, typed errors, one shared geographic camera, route objects with **explicit** state endpoint |
| Projection | `src/core/cartorig_core.*` | Web Mercator, latitude clamp, dateline shortest-distance wrap for point anchors |
| Native frame renderer | `src/render/cartorig_renderer.*` | CPU RGBA buffer, base-country land, independent region fill/stroke/opacity, route line + arrowhead, reveal value |
| Persistence | `encodeScene/decodeScene` | Versioned camera/object/style/route snapshot, strict reference validation, no partial mutation on failed load |
| Source data builder | `tools/build_natural_earth.py` | Official Natural Earth 1:10m Admin0, Admin1 and populated-place sources, locally generated catalog + SHA256 provenance |
| Tests | `tests/core_tests.cpp`, `tests/renderer_tests.cpp` | Real expected behavior of Rio/SP/Brasília→Amapá, geographic pixel changes, shared camera, roundtrip scene state |
| Cross-platform build | `CMakeLists.txt`, `geo-core.yml` | Windows/Linux native builds, CTest, and CI-only data packaging |

## Deliberately unimplemented (must not be presented as a finished feature)

- A Resolve-native dynamic `Find Location` field, typed results or dynamic list of authored objects.
- The bridge from Fusion/OpenFX Inspector controls to C++ scene commands.
- Reading/writing a scene snapshot **inside a real Resolve project**.
- Native time-based object/camera keyframes and independent curves (timeline belongs to Resolve).
- Installable `.DRFX` or `.OFX` **product release** with actual offline catalog and live map rendering.
- Performance-certified 4K production output, topology repair, full cartographic LOD and all edge cases at the antimeridian.

## What is and isn't verified

- The user has **visually verified the separate Inspector Lab** in PR #2: Generator appears on the Edit timeline, renders two rectangles, and publishes controls. The owner confirmed independently editable A/B regions and zooming both regions together.
- That Inspector Lab is a disposable host research template, **not** this core or its renderer.
- The new core's C++ tests can pass on CI without proving integration in DaVinci Resolve. Do not conflate these results.

## Development-only commands

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
ctest --test-dir build -C Release --output-on-failure
```

On a CI/developer computer only:

```sh
python -m pip install -r tools/requirements-build.txt
python tools/build_natural_earth.py --output dist/data/cartorig-natural-earth-10m.catalog
./build/cartorig_catalog_probe --catalog dist/data/cartorig-natural-earth-10m.catalog --smoke
```

**The editor/end user must not be instructed to install a compiler, Python, GIS tools or run any of these commands.** The builder's output will be included in a one-click install package once the host bridge is implemented and validated.

## Data limitations

Official Natural Earth Admin1 geometry is a generalized cartographic source and may have disputed/de facto boundaries. Municipal legal boundaries are not inferred from city points. This initial catalog uses **0.015° simplification** to keep processing manageable; it is **not high-resolution cadastral data**.

## Next implementation gate

Build a **new** adapter whose parameters and renderer are attached to a single native CartoRig Generator on the Resolve Edit Inspector. It must use this native C++ catalog and scene model rather than create a second bespoke geographic logic layer in Fusion. Investigate dynamic Inspector input/list behavior as a technical constraint: if unsupported, report evidence to the owner before changing DEC-007. No separate routine authoring window is approved.

The product's OpenFX/Fusion packaging strategy and license are still subject to approval and real host validation.
