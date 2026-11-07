# CartoRig Atomic

> **Status: specification and research only — no implementation has begun.**

CartoRig Atomic is a proposed **free, open-source, Edit-first cartographic animation system for DaVinci Resolve Studio**, rebuilt from scratch around a consistent product interaction model.

This repository is intended to start with **documentation only**. It does **not** reuse the source code, scripts, installer, OFX binaries, scene graphs, tests, raster assets, or proprietary sample assets from prior CartoRig implementations or third-party plugins.

## Intended user experience

The product direction is **Find → Add → Style → Animate**:

- Find a place by its natural name, with clear distinctions between countries, states/provinces and cities.
- Add a geographic object to a map scene.
- Edit map-base and object properties using one consistent system for fill, stroke and opacity.
- Animate camera movements, territory highlights, and routes within DaVinci Resolve's existing editing workflow.

**Reference use cases**

1. Highlight **Rio de Janeiro (state)** within Brazil.
2. Focus or animate the map camera to **São Paulo (city)**.
3. Draw and animate an arrow from **Brasília (city)** to an explicitly selected point in **Amapá (state)**.

The project targets an English-language interface and offline geographic data workflows. These are product requirements; their implementation in a particular Resolve 20 UI surface has **not yet been verified or approved**.

## Project documents

- [Product specification](docs/PRODUCT_SPEC.md) — intended outcomes, scope and acceptance cases.
- [Design system](docs/DESIGN_SYSTEM.md) — Atomic Design structure and UI consistency contracts.
- [Architecture](docs/ARCHITECTURE.md) — candidate technical boundaries and host validation gates.
- [Decisions](docs/DECISIONS.md) — explicit approvals and outstanding decisions.
- [Research and attribution](docs/RESEARCH.md) — lessons learned from GEOlayers 3, the VES sample, Natural Earth, and Resolve.

## Working agreement

- **No feature, menu, UI workflow, data-source change, automatic behavior or architectural commitment is approved by appearing in a draft.**
- Product interaction is approved before implementation; technical feasibility is verified on the real Resolve host.
- Do not import or adapt code or assets from previous CartoRig repositories.
- Research and empirical findings from earlier work are permitted as evidence; source code is not.
- Tests must distinguish simulations/CI from observation on DaVinci Resolve Studio 20.
- The open-source license is **pending owner approval**; this repository is intended to become open source, but no license grant should be inferred from an empty license file or this README.

## Current status

**Proposed documentation baseline.** Nothing in this repository is a completed or certified DaVinci Resolve plugin.
