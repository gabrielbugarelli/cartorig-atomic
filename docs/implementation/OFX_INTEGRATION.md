# CartoRig Atomic — Native OpenFX preview for Windows

**Status:** technical preview, **not the completed CartoRig product**.
**Target:** DaVinci Resolve Studio 20, Windows, Edit-page Inspector.
**Install:** one graphical Windows setup executable; no end-user Python, PowerShell, compiler or GIS preparation.

## Installer and installation

A successful run of the **CartoRig Atomic - OpenFX native adapter** GitHub Actions workflow generates the artifact **CartoRig-Atomic-Windows-Installer**. Download that artifact, extract the setup executable and double-click it. Close Resolve first, approve Windows administrator permission, then relaunch Resolve.

The setup installs a standard Windows OpenFX bundle under the shared Common Files / OFX / Plugins folder. It contains the C++ OpenFX binary, offline Natural Earth country/state/city catalog and SHA256 source-provenance manifest.

**Important:** whether Resolve 20 exposes the native OFX Generator as a clip in the Edit effects library, or only its Filter context on another clip, is still **NOT TESTED** on the owner's host. Do not confuse the earlier verified Fusion Generator Inspector Lab with this new OFX module.

## The Inspector controls in this build

**Find:** Enter an ordinary place name. Use Country / State / City to disambiguate. Matching Places lists numbered results with type and geographic parent. Select a Result Number, then Add Region or Focus Camera. A City point is never silently converted to a municipality polygon.

**Objects:** Map Objects lists authored Region and Route objects. Selected Object Number chooses the object. Fill, Stroke, Opacity, Stroke Width and Visibility edit the selected object's independent style. State is stored in a versioned host parameter so it can be persisted with the clip where the host supports this.

**Camera:** Camera Center and Camera Zoom are animatable native OFX parameters; all regions and routes render through the same geographic camera. Ocean Fill and Land Fill use standard RGBA pickers.

**Route:** Type Brasília as Route From City and Amapá as Route To State. Explicitly type Macapá as Arrival City, or enable Use Manual Coordinates Instead and enter a point inside Amapá. Choose Add Route. There is no implicit endpoint. A route whose arrival is missing, outside the state or ambiguous is rejected.

## Confirmed by automated tests

- Native C++ scene, geometry, search, styling, route and renderer tests on Windows and Ubuntu.
- Actual OpenFX binary ABI loaded by a **synthetic host** in CI, including native parameter definition, search, Add Region, Focus Camera, Add Route, RGBA rendering and instance re-creation.
- Offline catalog generated only from official Natural Earth sources. Hash and feature-count checks are built into packaging.
- One-click Windows installer created by CI, containing the native module and its offline catalog.
- Earlier standalone Fusion Inspector Lab (separate PR): the owner confirmed independent A/B colors and shared zoom.

These results are **not equivalent to actual DaVinci Resolve Studio 20 runtime certification**.

## Blockers before claiming a completed product

- Real Resolve 20 OFX discovery, all Inspector interactions, project save/reopen, Undo/Redo and Deliver have **not been tested**.
- A numbered-result field is a functional fallback, **not an approved polished dynamic location picker**. Native Inspector support for dynamic lists remains unresolved.
- Editing the selected object's style is independent in stored scene state, but the current fields do **not** provide independent native keyframe curves for an arbitrary number of objects; OpenFX parameters are fixed during descriptor creation.
- Route Reveal is implemented in the core renderer but not independently exposed as host-native curves for every Route.
- City Marker/Label editing and advanced annotation/route features remain unimplemented. No second window will be added without product-owner approval.
- Geographic topology and performance at extreme 4K zoom, dateline/cross-polygon cases, text placement and full color-management must be tested in the host.
- The project's open-source license has **not** been chosen by the owner.

## What this means

This installer is the first integrated native-code **preview** of CartoRig Atomic, not a release candidate. Code can be reviewed in PR #4, based on PR #3. The actual UI must still be validated in Resolve 20 and architectural blockers must be resolved before it can be described as the complete product.

## Rights

Data: Natural Earth public domain, with manifests and source hashes. OpenFX SDK: ASWF-maintained separately licensed compile-time headers. No legacy CartoRig C++/Lua, GEOlayers 3 implementation, VES sample templates, masks, presets, graphics or fonts are bundled.
