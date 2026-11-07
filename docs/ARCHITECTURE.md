# Architecture — CartoRig Atomic

**Status:** Candidate architecture and proof plan; **not approved for implementation**.

## Hard boundaries

1. **UI** — geographic search, object selection, style and animation actions. No map math in UI components.
2. **Scene domain** — Map Scene, objects, styles, stable IDs, transactions and state migration. No dependency on Resolve or Fusion.
3. **Geographic engine** — geometry, location catalog, projection, spatial indices, camera and route anchoring.
4. **Animation bridge** — binds authored object properties to host-owned keyframes where supported; avoids duplicate timelines and conflicting sources of truth.
5. **Renderer** — renders a scene snapshot at the requested frame; separate from UI and model mutation.
6. **Resolve adapter** — maps scene commands to supported Fusion/OpenFX/macros/templates and propagates persistence/frames to Edit and Deliver.
7. **Data packs** — local, versioned Natural Earth assets; no runtime geocoding/network requirement.

These are logical modules, not a prescribed code-language, library stack or directory layout.

## Evidence from prior experiments (knowledge only)

- A CartoRig OFX Generator rendered a map on Edit.
- In one Resolve Studio 20 installation, attaching Fusion to the OFX Generator via `AddFusionComp` failed.
- A Fusion Composition containing the CartoRig Overlay OFX loaded and displayed alongside Text+ and Merge nodes.
- A basic map animation survived save, close, reopen, playback and Deliver export.

**None of the previous code, graphs or scripts will be copied.** These facts do not validate new dynamic UI controls or per-object animation.

## Product constraint — native Inspector first (DEC-007)

**The owner approved the direction, not the feasibility:** the normal authoring workflow must be offered through DaVinci Resolve Studio 20's existing Edit sidebar/Inspector. This includes *search by natural place name*, *country/state/city disambiguation*, *object addition/selection*, *shared styling*, and *camera controls*. Animation must remain in host-native facilities (Edit keyframes/curves), not a second CartoRig editor. The Viewer can be used for preview and any host-validated gestures.

**Out of scope unless separately approved:** a floating CartoRig editor, a separate Workflow Integration window for routine authoring, manually assembling Fusion nodes, or scripts spread across Workspace menus.

This is a **hard UX acceptance gate**, not evidence that a published Fusion Macro or an OFX parameter hierarchy can implement arbitrary search results or object management. The first technical experiment must test these behaviors without introducing an unrelated renderer or a restricted hard-coded country list.

## Host integration mechanisms for the approved native-Inspector direction (technical decision pending)

| Candidate | Why investigate | Host proof needed |
| --- | --- | --- |
| Fusion Title/Generator `.DRFX` facade | VES sample demonstrates native Effects Library packaging and published Inspector controls | Hosting a newly written cartographic engine, Edit preview, project save and Deliver |
| Fusion Composition + custom OpenFX | Prior CartoRig integration worked on one host | Authoring multiple objects without manual node management |
| OpenFX Generator/Filter | Native image-render lifecycle | Dynamic object UI, overlay events and native independent curves |
| Fusion UIManager/Viewer interactions | Viewer gestures may complement the Inspector if verified | A UIManager **separate window** is not an acceptable default for regular authoring under DEC-007; any departure needs new owner approval |

**Native Inspector is the approved UX direction; no specific integration mechanism is approved.** A candidate that requires a separate routine authoring window fails the current product constraint until the owner changes it.

## Highest-priority integration gates

| Gate | What must be verified on the actual Resolve 20 host |
| --- | --- |
| HOST-01 | One entry point creates/selects a Map Scene in Edit |
| HOST-02 | **Inside the native Edit Inspector**, search and disambiguate country/state/city by readable names; do not assume Fusion macros support dynamic results |
| HOST-03 | **Inside the native Edit Inspector**, select and style two objects independently without fragmented controls |
| HOST-04 | Independently animate two objects and a shared geographic camera |
| HOST-05 | Camera movement causes **no object/route drift** on intermediate frames |
| HOST-06 | Use normal Resolve keyframes/curves with correct persistence |
| HOST-07 | Save/reopen/duplicate/Deliver preserve multiple authored objects |
| HOST-08 | Undo/recovery and compatibility with user-created Fusion nodes |
| HOST-09 | Render with alpha/colormanagement; playback seek out of order |
| HOST-10 | Install and work fully offline without build tools on the editor's PC |

A CI mock or off-host render does **not** substitute a host acceptance report. Record `PASS`, `FAIL` or `NOT TESTED` with evidence.

## Geographic coverage integrity

Natural Earth 1:10m Admin 1 may provide polygons of states such as Rio de Janeiro; populated places supplies **city points**, not a legal municipal boundary. A state destination in a route is not automatically a city endpoint. Data-source version, hierarchy, aliases and provenance must be retained.

## Rebuild constraints

- New source code only, including renderer, assets builder, UI, tests and installer.
- No importing or adapting old CartoRig source, even if the original used similar technologies.
- Do **not** redistribute VES templates, code, masks, fonts, style assets or other proprietary sample content.
- Third-party libraries/datasets require license and distribution review.
- No automatic addition of new features, scripts or menus without approval.

## Work order once the owner authorizes implementation

1. Approve UI workflows and critical interaction components.
2. Test the Resolve integration surface and independent curves in minimal throwaway proof-of-capability experiments.
3. Approve architecture decision records informed by host evidence.
4. Implement scene/geographic domains from scratch.
5. Implement the first complete vertical slice: Rio de Janeiro region → São Paulo camera → Brasília–Amapá route.
6. Expand only approved features, profile 1440p/4K and package for one-click installation.
