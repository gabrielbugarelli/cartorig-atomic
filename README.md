# CartoRig Atomic — Fusion rewrite

> **Current design authority:** [CR-PS-2.0, Fusion master specification](docs/specs/CR-PS-2.0_Fusion_2026-11-08.md), received from the product owner on 2026-11-09. **Product Design Complete / Owner Sign-off Required** for the `BASELINE-PROPOSED` release contract.

CartoRig Atomic is a **greenfield, offline, open-source-intended cartographic animation authoring system for the Fusion page of DaVinci Resolve Studio 20 on Windows**.

The previous **Edit-first / single OpenFX Inspector** direction is **superseded by the newer CR-PS-2.0 Fusion mandate**. The older documents under `docs/PRODUCT_SPEC.md`, `docs/DESIGN_SYSTEM.md` and `docs/ARCHITECTURE.md` are **historical drafts, not current implementation requirements**; the master specification takes precedence on disagreement. Previous experimental PRs remain unmerged and must **not** be copied or silently adapted into the rewrite.

## Product organization

- **Scene** — Fusion UI Manager window: search, add, select, reorder, duplicate, group, hide/lock, delete and recover authored map objects.
- **Control** — the selected cartographic **Fusion tool** exposes contextual, independently animatable properties in its native Inspector.
- **Motion** — contextual presets write genuine Fusion keys and curves that remain editable in the host's Spline/Keyframes editors.
- **Render** — composition output must work with Scene closed, offline, under random seeks and after Save/Reopen/MediaOut/Deliver.

The planned 1.0 scope in CR-PS-2.0 includes Base Map, Region, Route, Marker, Camera, Label, Group and 16 Motion presets. This complete `BASELINE-PROPOSED` scope **has not been unilaterally reclassified as approved**.

## Engineering workflow

1. Read the [complete normative specification](docs/specs/CR-PS-2.0_Fusion_2026-11-08.md), including chapter 0 decision statuses and chapter 18 release gates.
2. Read the [Fusion rewrite execution plan](docs/engineering/CR-PS-2.0_ENGINEERING_PLAN.md).
3. Validate real Resolve Studio 20 Fusion APIs **before** implementing large geographic/render subsystems: UI Manager/comp identity, object → selected tool/Inspector, separate BezierSpline curves, MediaOut and persistence.
4. Implement host-independent geography, topology, renderer and persistence **from scratch**, after the integration contract is demonstrated.
5. Add only approved user-facing release behavior and test every feature against its `SC/CT/MO/HOST/QA` identifiers.
6. Package all runtime dependencies and offline geography for graphical Windows installation; do not require terminal, Python or SDK tools on editor machines.

## Provenance and status

This branch contains the owner's specification and new research scaffolding, **not a certified Fusion product**. Host evidence from the earlier Edit prototype does not certify Fusion-specific operations. No code from older CartoRig branches or proprietary GEOlayers/VES components is reused.

The eventual code license is an owner-approved decision after dependency review; **Apache-2.0 is proposed in the specification, not granted by this repository alone**.
