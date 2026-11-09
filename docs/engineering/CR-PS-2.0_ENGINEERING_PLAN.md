# CR-PS-2.0 — Fusion rewrite: engineering strategy and evidence plan

**Status:** executable engineering roadmap / feasibility research. **Not a release approval.**

**Normative source:** [Owner-supplied CR-PS-2.0 Fusion specification](../specs/CR-PS-2.0_Fusion_2026-11-08.md), dated 2026-11-08, 1,426 lines, SHA-256 of the supplied UTF-8 file `992c1bd04b1ac0442fe73718f37c7ec51c9e130d3cf422f81cd905c4c28fdaa6`.

## 1. Change in product contract

| Dimension | Old experiments (not reused) | CR-PS-2.0 requirement |
| --- | --- | --- |
| Authoring context | Edit page / one OpenFX effect | **Fusion composition** |
| Search + object management | Simulated through fixed OFX parameters and result numbers | **Scene** as a coherent UI Manager window with typed search, hierarchy, CRUD and context safety |
| Object properties | Global selected-object proxy controls | **Control** on actual selected **Fusion object/tool** with its own animatable channels |
| Animation | Unproven OpenFX selected-object properties | **Motion** generating genuine Fusion keys; **Spline and Keyframes** remain authoritative |
| Timeline | Edit host timeframe | Fusion composition time, integer frames; no CartoRig timeline |
| Rendering | Old OpenFX effect with black/corrupted frame regression | **MediaOut/Deliver** with Scene closed, deterministic random-frame evaluation, RGBA and alpha |
| Core projection | Legacy Mercator / simplified geometry | **Equirectangular 2D baseline proposed** for R1.0; preserve WGS84 inputs and topology |
| Product scope | A few regions and route controls | Base Map, Region, Route, Marker, Camera, Label, Group + 16 Motion presets **proposed for 1.0** |
| Licensing | Undecided | Apache-2.0 **proposed**, requires owner sign-off and dependency audit |
| Approval | Old Edit-first decision DEC-007 | Superseded by later **Fusion Scene / Control / Motion mandate** |

**Mandatory distinction:** per CR-PS-2.0 §0 and §18, `MANDATE` must be followed. `BASELINE-PROPOSED` is **not automatically APPROVED**. This plan does not grant product approval by creating implementation scaffolding. The owner must explicitly sign off on the R1.0 bundle, or request a change.

## 2. Non-negotiable engineering invariants

1. **One Fusion composition, one CartoRig Scene, one Camera.** UI references are keyed by composition + stable scene ID + stable object ID, never by visible node name.
2. **Per-object authorship, not per-geographic-feature node proliferation.** A Region can contain many polygon rings but exposes one coherent Control and Motion identity. Selecting a different object must not share an ambiguous style animation slot.
3. **Host animation is canonical.** Motion writes native curves; renderer samples native evaluated values for each frame. Nothing is animated by the Scene UI or by sequential playback state.
4. **Window independence.** Closing the UI Manager changes no render state; MediaOut must work after reopening without running the Scene script.
5. **Geographic correctness.** WGS84 source data, actual polygons for Country/State, city points only, explicitly chosen Route endpoints, islands/holes/antimeridian, synchronized geo-camera.
6. **Existing Fusion authoring is preserved.** No automatic replacement/disconnection/reordering of nodes outside CartoRig ownership. Undo and cancellation never leave orphaned tools.
7. **Output correctness.** Full Map and Transparent Overlay have explicit RGBA/premultiplication semantics, unit-scaled pixels, render scale, region/window and random seek coverage.
8. **Offline distribution.** Clean graphical installation including all data; no Python, developer tools, login or network for the editor.
9. **Evidence labeling.** Every host capability is `PASS`, `FAIL` or `NOT TESTED` with an actual Resolve Studio 20 build reference; CI is only independent evidence.
10. **Clean-room provenance.** Previous CartoRig source, scripts, macros, installers, test code, graph and assets must not be read or adapted into this rewrite. Prior failure reports may be used to define new tests.

## 3. Preferred logical architecture — subject to host proofs

```text
Resolve Studio 20 • Fusion Composition
├── CartoRig Scene (UI Manager)          create/search/CRUD/selection/context
│     └── semantic operations → scene state / authorized host graph edits
├── Authored Fusion object tools         Region / Route / Marker / Label / Camera / Base Map
│     ├── Control (native Inspector parameters; separate per object)
│     └── Motion (preset actions → native BezierSpline/keyframes)
├── Managed composition output           preserves third-party nodes and MediaOut
└── Independent renderer & data engine   local geo feature store, projection, RGBA
      └── samples per-object host parameters at requested frame, with Scene CLOSED
```

**Not a technology commitment:** whether the author-facing tools are Fuses, macros, groups, a renderer in a C++ library, or host-native nodes is an *internal engineering decision* made after the PoCs. The crucial user-facing contract is stable object identity and independently accessible Control/Motion. Do not choose a technique because an old Edit plugin happened to compile.

### Architectural candidates to compare in host

- **FusionScript (Lua) + UIManager** for Scene, using the host's active composition and tool selection APIs.
- **Fusion Fuse** and/or **Fusion macros** for native Inspector pages, geometric control channels and host-managed animation. The official Fuse SDK documents controls and image processing, but does not itself certify the actual Resolve 20 interaction.
- **Compiled shared cartographic engine** behind a host adapter if performance tests justify it. If used, its lifetime and data access cannot depend on Scene UI or an out-of-process temporary server.
- **Host-native Fusion nodes** for Marker/Label/BezierSpline channels where that produces the most reliable editable curves.

No one solution is silently selected. A C++ library is not a substitute for a host-native Fusion tool exposing channels in Spline.

## 4. Engineering phases with test-first gates

| Stage | Test or product result | Release gate |
| --- | --- | --- |
| **E0 — Lock authority** | Preserve master specification byte-for-byte; register supersession; decision statuses; traceability | Full normative content retained, no Edit-first implementation ambiguity |
| **E1 — Fusion host PoC** | UIManager Scene window, current composition ID, selection of owned tools, native Inspector Control, independently editable BezierSpline channels, MediaOut with window closed | **HOST-01/02/03/05/08** minimal proof, or explicit FAIL with evidence and alternatives |
| **E2 — Scene graph/persistence** | Stable IDs, graph provenance, creation/duplication/rename/reorder/delete, Undo, copy recovery, no foreign node mutation | `SC-001..005`, `QA-17/18/19/20/25/26/27` |
| **E3 — Offline geography** | Admin0/Admin1/popu­lated places, typed search/aliases, parent disambiguation, source manifest, geometry/multipolygon validation | `GEO-001..004`, `QA-02/03/23/29/30` |
| **E4 — View/render engine** | Equirectangular projection, shared Camera, base styles, regions/routes/markers/labels and alpha; pixel-perfect RGBA tests | `CT-001..007`, `QA-04/06/07/08/10/21/24/33/36/41/42/56` |
| **E5 — Motion** | 16 approved presets applied through Fusion native curves; conflict fingerprints, customization, retiming, removal and Undo | `MO-CORE/MANUAL/CONFLICT`, `QA-11/12/14/15/16/35..44/46` |
| **E6 — Full host QA** | Real project Save/Reopen, render out-of-order, Spline edits, overlay above video, 1080/1440/4K, unrelated nodes retained, offline | HOST-01..10, QA-01..60 (appropriate required cases), separate measured reports |
| **E7 — Distribution** | Installer/reinstall/uninstall clean machine, open-source licensing audit and SBOM, docs, regression comps, release notes | Gates 0..5 from §§18.2–18.3 |

**Critical-path rule:** do not spend months optimizing geographic rendering before proving that object selection and independent Fusion curves are viable. If a host gate fails, document the exact limitation and propose a compatible alternative for owner review; never silently reduce R1.0 features.

## 5. The first host PoC (read-only, no product mutations)

A new, minimal Lua script under `experiments/fusion-host/` opens a native **UIManager** window in Fusion; shows the actual active-composition identity, handles a safe Refresh event, and does not create tools, modify keys, or silently initialize a scene.

**It is not a product Scene UI.** It verifies that UIManager is available in the target Fusion environment and that the visible composition reference can be read. Real two-way selection, persistence and BezierSpline keys are separate focused experiments; the script deliberately does not claim they pass.

PoC acceptance evidence:
- `NO_COMP`: read-only label, no project modification.
- Active Fusion composition: a read-only identity and selected host tool name.
- Switching composition then Refresh: context updates or explicit failure; never displays stale selection as editable.
- Close/reopen: one window, no node/keyframe changes.
- Record exact Resolve Studio 20 version, screenshots and a before/after graph comparison.
- If Fusion UIManager is missing, fail visibly without pretending to work.
- All editor UI copy stays in English.

The PoC is launched through a single Fusion `Comp` script menu item; neither the product nor its QA require the editor to type Lua or use a console.

## 6. Tests designed from old failures, without reusing code

- **Bad OFX pixel output:** independently test row stride (including negative), bounds origins, partial windows/tiles, float32/8-bit, alpha, caching and MediaOut on any future compiled render adapter. A solid block of cyan/black is an outright FAIL.
- **Shared proxy parameters:** test two Regions with different Fill and independent channel keys in Spline. One node changing another object's curve is a FAIL.
- **Wrong host context:** create comps A/B, switch while Scene is open and verify that A cannot be edited accidentally through B selection.
- **False search:** distinguish Rio State from Rio City; disable Add Region for point-only city, no ISO code requirement.
- **Bad routes:** Brasília→Amapá requires a user-selected point; no silent Macapá/capital default. Straight and Curved are spatial; temporal easing does not mutate route geometry.
- **Black map on missing data:** status must identify source/version and offer recovery; silent black or dummy map is FAIL.
- **Unapproved animation:** new scene contains Base Map and Camera only, with **zero automatically generated keyframes**.
- **Abandoned global timeline:** no CartoRig-owned timeline; manually edited host Spline curves and Hold/Step must remain canonical.
- **Floating-process dependency:** close Scene/UIManager, reopen comp and Deliver render; identical output required.
- **Duplicated effects:** one discoverable entry and one context per intended host placement, with explicit version identity.

## 7. Proposed R1.0 dependency ordering

`Scene discovery → reliable per-tool Inspector & Spline → durable scene/host state → geographic lookup → scene rendering → independent Control channels → 16 Motion presets → full validation → installer`.

Marker, Label, Group and all 16 Motion items are part of the **proposed** R1.0 scope. They cannot be dropped for engineering convenience, nor claimed implemented before validation. R1.1 recipe items and R2 data/terrain/globe must not appear as working features in R1.0.

## 8. Product authority and unresolved decisions

The product owner supplied CR-PS-2.0 as a new contract and asked engineering to study and develop it. That establishes the **Fusion mandate and supersedes the previous Edit plan**; it does **not** erase the source document's express `OWNER SIGN-OFF REQUIRED` status for the `BASELINE-PROPOSED` release bundle.

The engineering team can proceed immediately with **host research, technical PoCs, test infrastructure and internal implementation decisions**. The complete R1.0 visible defaults and catalog become an approved release target only after the owner explicitly homologates the proposed bundle or records requested changes.

**Engineering priority:** demonstrate host capability, maintain full traceability and ship only what passes the real Resolve test plan. Do not ask the owner to choose an internal algorithm, library or file format.

## Primary technical references

- [Blackmagic Fusion Fuse SDK (June 2023)](https://documents.blackmagicdesign.com/UserManuals/Fusion_Fuse_SDK.pdf): Fuse creation, Inspector controls, image processing.
- [Blackmagic Fusion Scripting Guide](https://documents.blackmagicdesign.com/UserManuals/Fusion8_Scripting_Guide.pdf): Composition, scripting, BezierSpline, Undo API examples (older documentation; re-verify in Resolve 20).
- [UIManager and UIDispatcher documentation](https://wheheohu.github.io/bmd_doc/workflow/next/UIManager): window/event model.
- [Natural Earth cultural vectors](https://www.naturalearthdata.com/downloads/10m-cultural-vectors/): geographic data and license provenance.
