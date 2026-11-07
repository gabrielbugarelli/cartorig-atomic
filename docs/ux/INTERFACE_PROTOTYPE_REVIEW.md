# CartoRig Atomic — Interactive UX review v0.1

> **PRODUCT PROPOSAL / NOT APPROVED.** This review artifact is a standalone offline HTML mock, not a DaVinci Resolve plugin, Fusion template or renderer. It is deliberately excluded from the plugin source and build system.

## Open the prototype

1. Open [Interactive prototype](../prototypes/cartorig-atomic-ux-v0.1.html) via **Download raw file** from GitHub and open it in a modern browser.
2. The left panel contains `Find location` and `Objects`, the central schematic canvas represents the Resolve Viewer, and the right panel contains contextual `Properties`.
3. The bottom strip is a **label describing Resolve's real timeline**, not a second interactive CartoRig timeline.
4. Click `Reset demo` to return to the initial empty Map Scene.

> The hand-drawn illustration is intentionally *not* real Natural Earth data and is not intended for cartographic/geographic accuracy or export. The mock's built-in catalog is deliberately tiny; it is not a replacement for the offline geographic database.

## Scenario A — Rio de Janeiro State inside Brazil

1. Search `Rio de Janeiro`.
2. Confirm the results separately identify **State** and **City**.
3. Select the **State** result and choose `Add as Region`.
4. Change `Fill`, `Stroke`, and `Opacity` in the right-hand contextual inspector.
5. Select `Base Map`; change `Land · Fill`; confirm RJ keeps its independently chosen color.
6. Confirm the search action alone did not add a region automatically.

**Review questions:** Do the search-result cards clearly distinguish City from State? Does the selected object have a natural and predictable place to change color? Is the object list understandable without needing a Fusion node graph?

## Scenario B — Camera to São Paulo

1. Search `São Paulo`.
2. Confirm **State** and **City** are separate results.
3. Select **City** and choose `Focus camera`.
4. Confirm the central schematic map changes its view, without creating a region or automatic animation.
5. Use `Fit view` to return to the overview.
6. The `Animation` section must remain **disabled**, explicitly requiring Resolve 20 host validation.

**Review questions:** Is `Focus camera` clearly distinct from animating the camera? Should Camera appear as an item in the object list or as a persistent tool? Is there a more intuitive way to establish a beginning and destination frame without a second timeline?

## Scenario C — Brasília to Amapá

1. Click `+ Route` in the Objects section (or the `Brasília → Amapá` review shortcut).
2. Choose `Brasília — City` as the **From** location.
3. Choose `Amapá — State` as the **To** location.
4. Try to press `Add Route` **without choosing an endpoint**: the form should refuse and explain the ambiguity.
5. Explicitly choose `Macapá — City` or the indicated approximate representative point.
6. Add the Route. Select it in Objects and modify `Stroke`, `Width`, `Opacity`, and `Arrowhead` from one contextual inspector.

**Review questions:** Does the required endpoint selection feel reasonable and clear? Should a route always have an arrowhead, or should it default to a line? Should spatial route editing happen directly in the Viewer if the SDK supports it?

## What the prototype exercises

| UX behavior | Demonstrated in the standalone browser mock | Real Resolve 20 validation |
| --- | --- | --- |
| Search by name, with typed State/City results | Yes — limited fixture catalog | NOT TESTED |
| Search without adding an object | Yes | NOT TESTED |
| Region object, style selection, independent color | Yes — only supported schematic regions | NOT TESTED |
| Base Map color vs RJ Region override | Yes | NOT TESTED |
| Static camera focus / fit | Yes — illustrative transform | NOT TESTED |
| Route dialog with explicit endpoint requirement | Yes | NOT TESTED |
| Route style controls and arrowhead | Yes — illustrative path | NOT TESTED |
| Persisted Map Scene in a real project | No | NOT TESTED |
| Native Resolve keyframes / curves | No; deliberately disabled | NOT TESTED |
| Real Natural Earth polygons and city coordinates | No; illustration only | NOT TESTED |
| Mouse picking in Resolve Viewer | No; browser mock interaction differs from host | NOT TESTED |
| Real Fusion/OpenFX/DRFX pipeline and Deliver | No | NOT TESTED |
| Accessibility, keyboard focus, small screens | Preliminary browser smoke-check | NOT TESTED on Resolve |

## Design alternatives and open decisions

1. **Layout density:** is the three-column arrangement too dense, or should Search and Objects share collapsible panels?
2. **Scene access:** what is the single discoverable entry point inside Resolve?
3. **Object categorization:** is a single object list preferable to separate sections for Regions, Routes, Markers and Camera?
4. **Contextual Properties:** should Camera be an object or a globally available panel?
5. **Selection:** should search results have a dedicated `Add` action or a more contextual single click?
6. **Route dialog:** do the From/To and endpoint controls match the desired way of working?
7. **Colors:** are `Fill`, `Stroke`, `Opacity` and inherited overrides sufficiently intuitive?
8. **Animation:** how should the UI signal a property can be keyframed while not promising a host API we haven't tested?
9. **Viewer interaction:** is mouse positioning of route endpoints a release requirement or a later enhancement?

Nothing in this list is silently approved by the appearance of the HTML mock.

## Implementation and legal boundaries

- All presentation geometry, sample content and code in this standalone mock were authored anew solely to explore the interface.
- No prior CartoRig source files, GEOlayers 3 source, VES templates/assets or geographic data were copied or imported.
- The `docs/prototypes/` path is **not an approved architecture or host integration layer**. It holds a disposable review artifact only.
- A browser mock is **not evidence** that Resolve Studio 20 supports dynamic panels, Viewer mouse events or independent keyframes.
- The owner's approval is required before turning these interactions into plugin code, choosing UI technology or merging a final design specification.

## Review outcome

```text
Prototype version: v0.1
Product owner feedback:
Approved interactions:
Changes requested:
Rejected interactions:
Unresolved decisions:
Approval date:
Permission to implement product UI: NO (until explicitly approved)
```
