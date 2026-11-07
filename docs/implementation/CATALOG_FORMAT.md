# CartoRig Atomic — offline catalog format v1

**Implementation document.** This format is an internal data transport contract for the native C++ core, not an approved Editor UI, GIS source substitution, or a final release asset.

## File structure

- UTF-8 text, **LF** line endings.
- First line exact magic string: `CARTORIG_ATOMIC_GEO_V1`.
- Remaining non-comment rows: nine tab-separated fields.
- Columns in order:

| Index | Name | Semantics |
| --- | --- | --- |
| 0 | feature ID | Stable Natural Earth ID, such as `ne:state:<id>`; never requires an editor to type this |
| 1 | type | `country`, `state`, or `city` |
| 2 | name | Human-readable natural feature name |
| 3 | parent | Country name for state, administrative state for populated place |
| 4 | country | Full human-readable country |
| 5 | aliases | Semicolon-delimited localized/alternate names; may be empty |
| 6 | longitude | City point longitude, or `.` for polygons |
| 7 | latitude | City point latitude, or `.` for polygons |
| 8 | geometry | For polygons: `Polygon|Polygon`; within polygon `Ring~HoleRing`; within ring `lon,lat;lon,lat;...`. Empty for cities. |

The format is designed to be read entirely offline, without a JSON library dependency in the C++ runtime. It preserves geographic object identity separately from display names and models point geometry separately from admin-region polygon geometry.

## Source provenance

The builder `tools/build_natural_earth.py` downloads **only at build time**, from the official Natural Earth S3:
- `ne_10m_admin_0_countries`
- `ne_10m_admin_1_states_provinces`
- `ne_10m_populated_places`

It writes `dist/data/cartorig-natural-earth-10m.catalog` and `natural-earth-manifest.json` with SHA256 of each source archive, source identity, feature counts, and output hash. These datasets are documented as **public domain by Natural Earth**; source attribution still travels with artifacts.

**Data resolution warning:** The current builder uses a **0.015° RDP simplification** to bound catalog size. That is a development baseline, not a claim of survey-level accuracy or adequate high-zoom boundary detail. A final product needs approved LOD strategy and topology review. Polygon point-inclusion near the antimeridian and boundary ownership remain open issues.

## Scope and license boundary

- Source data is from **Natural Earth**, not GEOlayers 3, Map Creator Pro, or previous CartoRig repositories.
- `NAME` and `NAME_ALT` from Natural Earth supply a useful base but not universal address or municipal polygon coverage.
- City search matches points, not municipality polygons. State route endpoints require explicit geographic coordinates.
- The data file format is internal and subject to versioning; it is **not** yet connected to the DaVinci Resolve Inspector.
- Python and `pyshp` exist **only on the CI/developer machine** that produces the data pack. Editing clients must never install either.
