> **HISTORICAL — SUPERSEDED by [CR-PS-2.0 Fusion master specification](specs/CR-PS-2.0_Fusion_2026-11-08.md).** This is an archival pre-Fusion proposal, not an authorized current implementation contract. Earlier Edit-first approaches and UI assumptions must not be used for the greenfield Fusion rewrite.

# Research inputs and intellectual-property boundaries

This repository is a **fresh implementation project**, not a fork. Research observations are informative, **never copied code or assets**.

## Product and interaction references

- **GEOlayers 3:** geographic feature search, Mapcomps, drawing, labels, routes, and compositing integration in Adobe After Effects. Reference: <https://aescripts.com/geolayers/> and <https://github.com/GEOlayers/Help>.
- **Atomic Design — Brad Frost:** atoms, molecules, organisms, templates and pages as a method for reusable UI systems. Reference: <https://atomicdesign.bradfrost.com/table-of-contents/>.
- **Map Creator Pro by Video Editor Studio (VES):** supplied sample was analyzed offline. Its `.DRFX` includes multiple `.setting` Fusion Title templates plus pre-rendered map components, masks and graphic assets. This demonstrates native Edit/Inspector distribution choices, not general geographic search. Reference: <https://videoeditorstudio.com/products/map-creator-pro>.

## Data and host references

- **Natural Earth:** official public-domain geographic data at <https://www.naturalearthdata.com/downloads/>. Includes Admin 0, Admin 1 and populated-place points; it is not a universal municipality/address database.
- **DaVinci Resolve Studio / Fusion 20:** official manuals and local Developer documentation take precedence for host capabilities.
- **OpenFX:** <https://openfx.readthedocs.io/>. A published API capability is not evidence that Resolve 20 supports the corresponding interaction.

## Rights and restrictions

- Do not copy GEOlayers or VES implementation, settings, scripts, masks, artwork, fonts or proprietary presets.
- The VES sample license restricts redistribution/incorporation into competing products; references here describe findings, not a grant to reuse the assets.
- Do not bundle third-party fonts, imagery, tiles or source data without reviewing their exact redistribution and audiovisual rights.
- This repository's own open-source license has not been chosen yet.

## Evidence classification

- **Observed:** directly inspected in supplied files or demonstrated in the Resolve installation.
- **Documented:** stated in official vendor/API materials, but not verified in this host.
- **Proposed:** design or architecture option awaiting approval.
- **Unverified:** must be tested before describing as implemented.
