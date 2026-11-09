> **HISTORICAL — SUPERSEDED by [CR-PS-2.0 Fusion master specification](specs/CR-PS-2.0_Fusion_2026-11-08.md).** This is an archival pre-Fusion proposal, not an authorized current implementation contract. Earlier Edit-first approaches and UI assumptions must not be used for the greenfield Fusion rewrite.

# Product specification — CartoRig Atomic

**Status:** Draft for product-owner review. **This is not an authorization to implement every item below.**

## Product goal

Help a video editor create and animate maps within DaVinci Resolve Studio, without using GIS identifiers, manually assembling Fusion nodes, running development tools or learning separate workflows for each kind of cartographic object.

## Confirmed direction from the owner

- A complete new codebase, independent of previous CartoRig repositories.
- Public GitHub repository named `cartorig-atomic`, with documentation before implementation.
- Atomic Design as the proposed system for designing and evaluating UI components.
- GEOlayers 3 as a reference for geographic authoring; the VES Map Creator Pro sample as a reference for Fusion templates and delivery—not as a code source.
- Editing-first workflow in DaVinci Resolve Studio 20 on Windows; English-language plugin UI.
- Offline geographic operation and Natural Earth as the established core geographic-data reference.
- A coherent interaction system, without duplicated color controls or fragmented scripts and menus.
- Country, state/province and city search by natural name rather than an ISO3 entry requirement.
- Independently styled geographic regions, including nested countries and states.
- Animatable camera movements and route/arrow creation between explicitly chosen locations.
- **Approval before implementing new product behavior.**

These describe product intent, not proof that all features are technically possible through the Resolve 20 SDK.

## Shared product vocabulary — proposal

- **Map Scene:** one authored cartographic composition on the Edit timeline.
- **Location:** search result with a geographic type and parent hierarchy.
- **Object:** a drawn region, marker, label, route or other approved entity.
- **Camera:** one shared geographic view per scene.
- **Style:** visual properties with consistent definitions and reusable controls.

Interaction proposal: **Find → Add → Style → Animate**. Selection and edits should be contextual, not separate entry scripts for each type of task.

## Primary acceptance scenarios

### A. Rio de Janeiro state

1. Search `Rio de Janeiro`.
2. Distinguish `State — Rio de Janeiro, Brazil` and `City — Rio de Janeiro, Brazil`.
3. Select the state, add its administrative polygon as a region and change its fill/stroke/opacity.
4. Confirm the rest of Brazil retains its independent style.
5. Move the camera, save, reopen and Deliver-export without changing the state identity or appearance.

**Data constraint:** a Natural Earth populated-place city point is not an administrative municipality polygon.

### B. São Paulo camera

1. Search `São Paulo`.
2. Choose the **city**, not the state.
3. Focus the camera and set the intended framing.
4. Create/edit the move through native Resolve animation controls where technically supported.
5. All geography-bound objects stay correctly aligned at intermediate frames.

### C. Brasília to Amapá

1. Set `Brasília — City` as a route start.
2. Select `Amapá — State` as the destination region.
3. Choose **where in Amapá** the endpoint lands: an explicitly chosen city, representative location identified as such, or an editor-selected position. Do not silently substitute Macapá.
4. Style the path and arrowhead using the same style conventions as other objects.
5. Reveal/animate the route while retaining geographic anchoring during camera movement.

## UX invariants — proposals to approve

1. Adding a location does not automatically create an animation, label or route.
2. Base map and object fill use the same visual color-picker component; each object's value remains independent.
3. `Focus Camera` is a different operation from `Animate Camera`.
4. The host's Timeline and Curve Editor remain the source of truth for supported keyframes; no parallel CartoRig animation timeline.
5. Geographic identities are not keyed solely by display names; internal IDs never become required search input.
6. Geography unavailable in the offline dataset is reported accurately, not fabricated.
7. All new workflows require explicit design approval before implementation.

## Scope remains open

The exact v1 feature set, optional datasets, label sophistication, 3D/globe, advanced route drawing, presets and external connectors have **not** been selected. Reference-feature lists from GEOlayers 3 are ideas for comparison, not an automatic parity requirement.
