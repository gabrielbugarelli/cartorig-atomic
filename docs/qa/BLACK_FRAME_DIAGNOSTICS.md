# Resolve black Viewer — reproducible diagnosis (hotfix PR #5)

**Owner report, 2026-11-08:** after inserting the new `CartoRig Atomic Map` effect on the Edit timeline, the Viewer is entirely black. The screenshot confirms effect discoverability and placement, **not** whether the renderer executed or whether the data pack loaded. Multiple similar `CartoRig Atomic` / `CartoRig Native` library groups are visible, which may indicate previous installed variants; those packages must not be deleted automatically.

## Source-level defect confirmed

Previously, `src/ofx/cartorig_ofx.cpp` wrote an all-zero **transparent** RGBA frame when `getCatalog()` failed to find or parse the Natural Earth data pack. On other renderer exceptions the OFX entry returned a generic error without logging the reason. Both could appear as black/blank in the Resolve Viewer, making diagnosis impossible.

**The screenshot alone does not prove that missing data is the cause.** The hotfix differentiates failure classes without changing the approved native Inspector authoring model.

## New Info tab diagnostics

After installing this build and restarting Resolve, insert a **new** `CartoRig Atomic Map` clip on a disposable Edit timeline, then open the selected clip's Inspector and the plugin's `Info` page.

| Viewer result | Meaning |
| --- | --- |
| Normal world map with colored land and blue water | Offline data and renderer visibly work (individual UI functions still need validation) |
| **Magenta / dark purple checker** | The renderer is running but the Natural Earth catalog is missing or failed to parse. `Render / Data Status` should explain the issue. |
| **Red / orange checker** | The renderer is running but hit an exception after acquiring the output pixel buffer. Inspect the local log. |
| **Cyan / yellow / blue test pattern** after enabling `Diagnostic Color Pattern (test only)` | OpenFX output-memory writing works, even with no geographic catalog. Turn the switch off to return to map rendering. |
| **Still solid black even with Diagnostic Color Pattern enabled** | The visible host path may not be reaching the render callback, the output image allocation is failing before pixels are accessible, an older cached plugin is running, or host color/depth negotiation differs from the current tests. Check log and Inspector; **do not infer a root cause without evidence**. |

### Local diagnostic log

On Windows, failures are written locally to:

`%LOCALAPPDATA%\CartoRigAtomic\cartorig-ofx.log`

No network transmission. If needed, open the file through Windows File Explorer and share only the last few error lines. This is **diagnostic**, not part of the ordinary CartoRig editing workflow. The file is rotated at 128 KiB to avoid uncontrolled growth.

### Retest steps

1. Close Resolve.
2. Install the corrected Windows setup from the CI artifact associated with **PR #5** (not the original November 7 preview).
3. Reopen Resolve, create a new test project or add a fresh effect clip rather than relying on an old render-cache image.
4. Select the **new native OpenFX CartoRig Atomic Map** in the Effects Library. Do not confuse it with `CartoRig Atomic - Inspector Lab` or older `CartoRig Native` components.
5. On the selected clip's Inspector, open `Info`, note `Render / Data Status`, and activate `Diagnostic Color Pattern (test only)`.
6. Record whether the Viewer displays cyan/yellow/blue. Turn the toggle off, then record the final Viewer colors and the data status.

**Acceptance:** one screenshot of the Inspector's Info page and Viewer with the diagnostic pattern enabled, plus the normal Viewer with the pattern disabled. The exact Resolve Studio 20 build number should also be recorded. This evidence is required before marking the user's reported black-frame bug solved.

## CI coverage

`cartorig-openfx-binary-contract`: real compiled OpenFX binary, synthetic host, offline fixture and RGBA geographic output.

`cartorig-openfx-no-data-diagnostic`: starts a distinct host-test process with a deliberately absent data directory; asserts visible `CATALOG ERROR`, opaque magenta checker, and independently functioning cyan/yellow/blue output.

CI jobs on Windows and Linux exercise both cases. These do **not** replace actual DaVinci Resolve host acceptance.

## Release safety

The hotfix does not automatically uninstall old plugins, change the single-Inspector product requirement, infer capital/centroid endpoints for state routes, or ship data from VES or GEOlayers. It remains a **technical preview**, not full product completion.
