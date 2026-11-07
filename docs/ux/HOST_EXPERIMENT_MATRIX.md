# Resolve 20 UI and animation feasibility — Experiment matrix

> **RESEARCH PROTOCOL, NOT A HOST CERTIFICATION.** No results have been collected for CartoRig Atomic yet. A historical success in an earlier repository may motivate a test but is not proof that this new implementation passes it.

## Purpose

Compare candidate delivery surfaces **against the same approved interaction requirements** before choosing an engine, toolchain or menu system. The goal is a single coherent map-authoring experience on Edit with native timeline and Deliver, not implementation parity with After Effects.

## Candidate approaches (all undecided)

| ID | Integration candidate | Potential strength | Critical unknown |
| --- | --- | --- | --- |
| C-A | Fusion Title / Generator template distributed as `.drfx` | Native Effects Library insertion and published Inspector controls, demonstrated by VES sample | Dynamic search/list editing, independent objects and camera controls without opening Fusion |
| C-B | Fusion Composition + native custom OpenFX inside | Known feasible container in earlier CartoRig proof | Unified authoring UX and scalable independent object animation |
| C-C | OpenFX effect with supported overlay/interacts | Native render pipeline and some on-image controls | Availability of pen/drag/picking events in Resolve 20 Edit/Fusion, dynamic values |
| C-D | Fusion UIManager-based editor | List/search/custom widgets may be more flexible | Window and focus management, Edit selection, persistence and Undo |
| C-E | Hybrid of published Inspector controls + one complementary editor | Could combine native keyframes and object discovery | Synchronization and risk of two contradictory states |

**Do not choose C-A just because the VES sample installed cleanly. Do not choose C-B just because the old proof rendered.**

## Host evidence minimum

For every test, capture:

```text
Experiment ID:
Repository commit / prototype build:
DaVinci Resolve full version / edition:
Windows version and GPU:
Installation method:
Exact user actions:
What visibly happened:
Host project/clip identifier:
Observed result: PASS / FAIL / PARTIAL / NOT TESTED
Logs / exported frame / screenshot links:
Host API or manual section:
Known limitations:
Product implication:
Owner decision (when applicable):
```

A CI-only test is labeled **SIMULATED**, never PASS on the real host.

## Experiments

| ID | Concrete action | Pass criterion | Decision affected |
| --- | --- | --- | --- |
| EX-01 | Insert a Map Scene using a single visible CartoRig entry point from Edit | Correct active timeline/clip and live Viewer output; no manual node assembly | Entry surface |
| EX-02 | Search Rio de Janeiro and disambiguate State vs City | Natural-name search, type and parent are visible; no ISO3 entry required | Search UI |
| EX-03 | Add RJ State Region, then change only its Fill | Independent target and color controls; no global RGB workaround | Scene object binding |
| EX-04 | Add Brazil Country as second Region; change Base Map color | Country/state/base have independent overrides and shared color semantics | Atomic style controls |
| EX-05 | Add two distinct keyframes of opacity to RJ, a different curve to Brazil | Both editable in genuine Resolve host keyframes; no shared animated slot | Animation adapter |
| EX-06 | Animate shared camera toward São Paulo City across at least three sample frames | No drifting of any region, marker, route or label | Camera binding |
| EX-07 | Create route Brasília → explicit location inside Amapá State | No invented Macapá default; editable arrow geometry and Reveal curve | Route endpoint UI |
| EX-08 | Change the active CartoRig clip while editor is open | No edits applied to wrong clip/project or other timeline | Context synchronization |
| EX-09 | Cancel new object halfway; then Undo/Redo completed add | No orphan/partial Fusion nodes; reversibility preserved | Scene transactions |
| EX-10 | Save, close Resolve, reopen, duplicate a clip, change only copy | Both source and duplicate retain identity with no cross-scene mutation | Persistence |
| EX-11 | Deliver-export project with animated color, camera and route | Exported frames match Viewer for audited frames at 1440p and 4K | Rendering host |
| EX-12 | Run with internet disabled and on a clean Windows account | No geocode network, login, Python, external terminal or manual GIS install | Packaging/data |
| EX-13 | Try map Viewer mouse click and drag on a region/path control | Pointer events, scaling, values, Undo verified; else mark unsupported | Viewer interact |
| EX-14 | Reorder object layers with country/state overlapping | Render reflects order; no unexpected loss of borders/labels | Scene graph |
| EX-15 | Edit 25 independent objects and scrub repeatedly | No unexpected freeze or crashes; record latency/memory rather than inventing targets | Render scaling |

## Prioritization and fail-fast rules

- **Priority 0:** EX-01, EX-02, EX-03, EX-05 and EX-08. These decide whether the product can offer unified authoring.
- **Priority 1:** EX-06, EX-07, EX-09, EX-10 and EX-11. These decide whether a usable integration is reliable.
- **Priority 2:** EX-04, EX-12, EX-13, EX-14 and EX-15. These harden styling, interaction and performance.

**Fail-fast:** if a candidate cannot offer native independent curves for selected objects without a second confusing editing system, document the failure, compare an alternative, and request owner approval for any UX change. Do not bury the failure under more code.

## Product-vs-host boundary

The owner approves what the interface should do. The lab proves how a candidate host technology can do it. Source code for a throwaway prototype is new and disposable; the product stack is chosen only after reviewing its evidence. A parameter-limited Inspector is not permission to reduce the product to five hard-coded countries.

## Required comparisons

For each feasible surface, measure the same three tasks:
- RJ State selected, Fill changed, Brazil unaffected.
- São Paulo City focused and animated, with two anchored objects.
- Brasília → Amapá route added, endpoint disambiguated and reveal animated.

Record usability problems (number of unnecessary panels/dialogs, context switching, confusion), reliability (wrong-clip modifications, failed curves, orphan nodes) and performance. **No arbitrary numerical score or winner should be published without observed test data.**

## Open owner decisions

1. Does a separate in-process window count as acceptable Edit-first authoring, or must all normal editing stay in native Inspector/Viewer?
2. Is on-map picking required for the first release, or can a reviewed search/list alternative pass?
3. Which animation behavior is required if the Resolve Inspector cannot expose a keyframe control for newly added objects?
4. Can the UI show one dedicated contextual editor plus a small set of published Inspector properties, or must there be exactly one surface?

No answers are presumed in this document.

## Implementation rule

Until the experiments have evidence and the interaction contract is approved, this matrix does **not** authorize an OpenFX framework, a template packaging strategy, a UIManager window or a final language stack.
