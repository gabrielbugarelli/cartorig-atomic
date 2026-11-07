# Inspector Lab — Host observations from owner screenshot

**Observed:** 2026-11-07, user-provided screenshot of the DaVinci Resolve **Edit** page.  
**Screenshot location:** attached to the project conversation; **not copied into this public repository**.  
**Build identity:** screenshot shows `CartoRig Atomic - Inspector Lab` (version/file hash not independently verifiable from the pixels).  
**Host version:** DaVinci Resolve Studio 20 was the requested test target, but exact build number and installation edition are **not visible** in the capture.

## Direct evidence visible

- The Effects Library sidebar has a **Fusion Generators** section containing the **CartoRig Atomic** group and `CartoRig Atomic - Inspector Lab` item.
- The Edit timeline has a selected blue `CartoRig Atomic - Inspector Lab` clip.
- The Viewer shows the intended diagnostic geometry: colored background, orange left rectangle, green right rectangle, and small label.
- The native Inspector, under the selected Fusion Generator, shows tabs `Controls`, `Map`, `Objects`, `Camera`, `Probe`, and another tab beginning with `Setti...`.
- The `Map` tab shows `Base Map Fill` with a color swatch and **individual Red, Green, Blue, Alpha channel fields/sliders**.
- This proves a **host-rendered color control grouping with exposed channels**, not the final proposed simplified one-control UX. We must evaluate the complexity of visible per-channel fields before approving design-system behavior.
- The user's screenshot established the actual discoverable library grouping in their installation. Earlier assistance incorrectly described `Generators → Fusion Generators` as if it were a universal menu hierarchy. The corrected instructions remain in this branch's README.

## Acceptance matrix — screenshot plus subsequent owner confirmation

| ID | Status | What the screenshot actually supports | What remains unknown |
| --- | --- | --- | --- |
| IL-01 | **PARTIAL** | Generator is discoverable inside the native Effects Library under Fusion Generators → CartoRig Atomic | Whether installation was double-click, any prompts, restart/reload, or exact corrected bundle hash |
| IL-02 | **PASS (visible frame)** | Generator is on the Edit timeline and the expected two-rectangle schematic renders in the Viewer | Scrubbing, rendering consistency, transparent output, frame-range behavior |
| IL-03 | **PASS (visible Inspector layout)** | A selected CartoRig Generator exposes the specified group tabs in the native Inspector | Whether every published property renders and accepts edits |
| IL-04 | **PASS — owner-reported** | After the request to change Region A Fill and check Region B, the owner confirmed: **“Sim, A e B são independentes.”** This supports independent Region A/Region B controls in the tested Inspector setup. | No subsequent screenshot of edited values; independence from Base Map was not separately confirmed |
| IL-05 | **PARTIAL — owner-reported** | Owner confirms Region A and Region B are independent. | A separate reverse-direction test (change B, verify A unchanged) was not described explicitly |
| IL-06 | **NOT TESTED** | Base Map Fill picker exists | Change it and verify only background changes |
| IL-07 | **NOT TESTED** | Object opacity inputs not shown | Confirm both regions respond independently |
| IL-08 | **NOT TESTED** | Camera tab is visible but not open | Zoom/Center must update both shapes together |
| IL-09 | **NOT TESTED** | Probe tab is visible but not open | Text changes only the label |
| IL-10 | **NOT TESTED** | No visible independent opacity/zoom curves or keyframe interactions | Create and inspect native keyframes in Edit |
| IL-11 | **NOT TESTED** | No save/reopen or Deliver evidence | Confirm persistence and output |

## Owner follow-up evidence — 2026-11-07

After the screenshot, the owner explicitly confirmed **“Sim, A e B são independentes”** in response to the request to edit Region A's Fill and verify that Region B remains unchanged. This is **direct user-reported host feedback**, distinct from the visual evidence captured in the first screenshot; it must not be mislabeled as a newly captured screenshot or a CI result.

- **Supported:** two schematic region controls can be edited independently within the native Inspector in this test.
- **Not yet supported:** independence of region Opacity curves, Base Map overrides, camera zoom/center behavior, native keyframes, save/reopen/Deliver, or dynamic geolocation search.

## New conclusion permitted by the evidence

The **static Fusion Generator + native Inspector + schematic Viewer** integration is feasible in the user's Resolve installation. This is meaningful progress for **DEC-007**, but **dynamic location search, arbitrary object creation/selection, a scalable list, per-object animations, and one seamless Atomic Design interface are still completely unverified**.

## Next minimal evidence request

1. Open the **Camera** tab, change **Camera Zoom**, and confirm whether **both regions move/scale together** while their relative positions remain unchanged.
2. If available, test independent Edit keyframes for Region A Opacity and Camera Zoom; report whether diamond/keyframe controls work.
3. Later, test Base Map Fill separately to confirm region overrides persist.

Do not merge the experimental macro or claim a full map editor on the basis of one screenshot. Keep PR draft; obtain the remaining evidence before advancing to the dynamic UI problem.
