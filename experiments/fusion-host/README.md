# Fusion UIManager Host Probe — CR-PS-2.0

**Read-only research artifact. It is not the CartoRig product and is not a release installer.**

## Goal

Before investing in a new renderer or a polished UI, verify that DaVinci Resolve **Studio 20, Fusion page, Windows** can host one CartoRig Scene window and read the actual active composition context.

This spike tests only the **first part of HOST-01 / HOST-05**. It does **not** initialize a scene, connect MediaOut, create geographic objects, publish native Inspector pages or write Fusion BezierSpline curves. No old CartoRig code or VES templates are included.

## Research script

`CartoRig Scene - ReadOnly Host Probe.lua`

The script is designed for a developer's **disposable Fusion project** and the built-in **Fusion `Comp` scripts menu**. The standard Resolve script folders are documented in Blackmagic's scripting material; for a Windows per-user developer setup the Fusion `Scripts/Comp` folder is normally under:

`%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Comp\`

This manual step is for **host research only**. The final CartoRig must use a GUI one-click installer with no script copying or terminals for editors.

## Host test protocol

| Test | Operation | Result required for PASS |
| --- | --- | --- |
| `FUSION-P0-01` | Open a Fusion composition; invoke the script through the Fusion Script menu | One 430×640 `CartoRig — Scene (Host Probe)` window opens, native UIManager rendering |
| `FUSION-P0-02` | Inspect `ContextState` and `SelectedTool` | The correct active Fusion comp and host selected tool appear, without manually typing an ID |
| `FUSION-P0-03` | Select a different Fusion node; click `Refresh Composition` | The status reflects the active tool; no node or keyframe changes |
| `FUSION-P0-04` | Change active Fusion composition, click Refresh | The previous selection becomes invalid or the host limits are reported; no wrong-comp edits |
| `FUSION-P0-05` | Trigger the same script while the window is visible | Reuses the same window if `FindWindow` is supported, otherwise documents host limitation |
| `FUSION-P0-06` | Close Scene window; render and inspect existing unrelated nodes | Scene closing has no side effects; no CartoRig-made tools remain |
| `FUSION-P0-07` | Repeat on DPI 100/125/150% | No truncated control copy in the minimal layout |

**Evidence:** exact Resolve Studio 20 build, Windows version, screenshot of Fusion Node Editor + Scene window, before/after `GetToolList` count and observed result `PASS/FAIL/NOT TESTED`.

**Current recorded state:** all `FUSION-P0-01..07` = **NOT TESTED on the real host**. Tests in GitHub Actions only verify file integrity and read-only code structure, not Lua runtime, UIManager rendering or host event callbacks.

## If the host differs

- If `fusionApp.UIManager` is unavailable, report `FUSION-P0-01 FAIL`, resolve build number and script-console error.
- If `CurrentComp` cannot be read after switching composition, `FUSION-P0-04 FAIL`; do not silently fall back to the original comp as if it were the active one.
- If `FindWindow` fails, document `FUSION-P0-05`; the final app still requires a single Scene window by product mandate.
- If `comp:GetAttrs()` returns different names or identities on this host, record observable attrs for engineering **without sending private project paths**.
- Do not implement a second editor, switch back to Edit or modify unrelated nodes to bypass a host failure.

## After this gate

The next technical experiment must test **Scene selection → owning Fusion tool → contextual Inspector Control/Motion → independent native BezierSpline curve**, with two Regions and a shared Camera. The host must show separately editable curves and correct Save/Reopen/MediaOut without the Scene UI. Only then should large-scale renderer/data work begin.

## References

- [CR-PS-2.0 §§0, 2, 7, 8, 12 and 15](../../docs/specs/CR-PS-2.0_Fusion_2026-11-08.md)
- [Blackmagic Fusion Scripting Reference](https://documents.blackmagicdesign.com/UserManuals/Fusion8_Scripting_Guide.pdf)
- [UIManager/UIDispatcher implementation reference](https://wheheohu.github.io/bmd_doc/workflow/next/UIManager)

**Interpretation:** This is a probe of current host behavior, not a proof that the full UX contract is feasible. The final product has no mandatory manual scripting step.
