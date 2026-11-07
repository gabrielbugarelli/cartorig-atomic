# Inspector Lab — native Resolve Edit Inspector research spike

**Status (2026-11-07): STATIC CHECKS PASS / RESOLVE STUDIO 20 HOST NOT TESTED.**

This is the **first clean-room executable experiment** for [DEC-007](../../docs/DECISIONS.md): ordinary CartoRig authoring must be concentrated in the **native Inspector sidebar** on the **Edit** page, without a separate CartoRig window.

## What it tests

A single Fusion **Generator** macro assembled from new, conventional Fusion nodes:

- **Map:** a grouped **Base Map Fill** RGBA picker;
- **Objects:** **Region A Fill** and **Region B Fill**, each an independent grouped RGBA picker, plus independent opacity controls;
- **Camera:** shared **Camera Zoom** and **Camera Center** controls affecting both illustrative regions;
- **Probe:** **Text Entry (not a search)**, which edits the on-screen label without pretending to query any geographic data.

Two simple colored rectangles represent **Region A and Region B**. They are **not country or state polygons**, do not use geographic coordinates, and are intentionally unrelated to any historical CartoRig scene.

**Critical limitation:** `InstanceInput` exposes an existing node's static parameter. This experiment does **not** implement dynamic `Find Location`, country/state/city search results, arbitrary object selection, object creation, independent host keyframe certification, a route editor, Natural Earth, or a complete Atomic Design UI.

## Install: single file, no terminal

1. Close DaVinci Resolve Studio 20.
2. [Download the compiled-by-packager `.drfx` asset](../../dist/) from a successful GitHub Actions build (artifact named `CartoRig-Atomic-Inspector-Lab`). Alternatively, use the attached experimental `.drfx` shared alongside this PR.
3. **Double-click the `.drfx`**. Accept the DaVinci Resolve installation confirmation, if offered.
4. Launch/relaunch Resolve and open a **new, disposable test project**.
5. Edit → Effects Library → **Generators** → **Fusion Generators**: locate `CartoRig Atomic - Inspector Lab` (folder/category presentation may differ).
6. Drag the generator onto an empty test timeline, select its clip and open the **Inspector**.

**Do not install any previous CartoRig plugin or VES asset for this experiment.** The archive contains exactly one new `.setting`; it does not overwrite an old CartoRig OpenFX binary.

If the double-click install or Effects Library discovery fails, **record FAIL** and the observed behavior. Do not silently require PowerShell, Python, manual Fusion node construction or external companion windows.

## Host acceptance: manual checklist

Record exact Resolve version/build, Windows version, trial package SHA256, screenshot(s), whether you stayed in Edit, and final PASS/FAIL/NOT TESTED for each gate:

| ID | Action in Edit | PASS requires |
| --- | --- | --- |
| IL-01 | Import `.drfx`, restart Resolve, find Generator | A discoverable entry in native Effects Library |
| IL-02 | Drag generator onto Edit timeline | Visible blue/grey test canvas with two differently colored rectangular regions |
| IL-03 | Select clip and open Inspector | Distinct **Map**, **Objects**, **Camera**, **Probe** tab sections or comprehensible equivalent |
| IL-04 | Edit **Region A Fill** through **one color swatch** | Only left rectangle changes; Region B and base remain unchanged |
| IL-05 | Edit **Region B Fill** through **one color swatch** | Only right rectangle changes; left rectangle unchanged |
| IL-06 | Edit **Base Map Fill** | Only background color changes |
| IL-07 | Change **Region A Opacity** and **Region B Opacity** | Each region responds independently |
| IL-08 | Move **Camera Zoom** / **Camera Center** | Both rectangles move together; label may remain screen-fixed |
| IL-09 | Type in **Text Entry (not a search)** | On-screen label updates; **does not perform lookup** |
| IL-10 | Test visible keyframe button on Zoom and each region Opacity | Independent host keyframes can be set, scrubbed and edited from Edit **or record limitation** |
| IL-11 | Save, close/reopen Resolve and Deliver-export | All input values and render are retained |

The order matters: if IL-03 fails, color and camera behavior cannot be certified by CI alone.

## Known constraints and uncertainty

- A correct Lua-like file and ZIP archive may **still fail to load** on the host. No instrumented local Resolve 20 process is available in this environment.
- Three RGBA channels plus alpha are internally separate Fusion parameters, **published as one color picker per group**. Whether the Edit Inspector renders the grouping exactly as proposed is a host question.
- The text input is **static on-screen text**, not a real geographic search control. Native Inspector may not offer a supported dynamic result-list/selection API.
- Schematic rectangles are not attached to real longitude/latitude, so this does **not** test geographic alignment.
- Keyframe availability in the Inspector and per-object independent curves must be recorded from the real host.
- A dark-background diagram is an instructional diagnostic, not an approved CartoRig map style.
- The outcome of this spike determines the next research question; it does **not** constitute approval to implement an alternative window.

## Reporting format

```text
Experiment: INSPECTOR-LAB-01
Package sha256:
Resolve edition and exact version:
Windows version:
IL-01 ... IL-11: PASS / FAIL / NOT TESTED
Inspector screenshot:
Viewer screenshot:
Do keyframe diamonds appear for region A/B opacity and camera?:
Does the generator survive Save → Close → Reopen?:
Deliver result:
Errors/logs:
Notes:
```

## Development-only checks

The generator is a human-authored Fusion `.setting` in this repository, not adapted from a previous CartoRig codebase or from the VES sample.

```sh
python -m unittest discover -s tests -v
python tools/build_inspector_lab.py
```

Those commands are for **CI/release engineering only**. Editors should never have to run Python or terminal commands. An archive from `build_inspector_lab.py` is packaged as `dist/CartoRig-Atomic-Inspector-Lab.drfx`.

## References

- [Official Fusion 20.3 Reference Manual](https://documents.blackmagicdesign.com/UserManuals/FusionManual.pdf), chapter “Node Groups, Macros, and Fusion Templates”: export selected parameters; store Edit Generator macros in `Fusion/Templates/Edit/Generators`; restart to see them.
- [Official Fusion Scripting Guide](https://documents.blackmagicdesign.com/UserManuals/Fusion8_Scripting_Guide.pdf): custom controls and button callbacks; this spike deliberately does not use callbacks or network functions.
- [Owner-approved native Inspector direction](../../docs/DECISIONS.md).

**Do not merge as product functionality before real host results and owner review.**
