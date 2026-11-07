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

## Acceptance matrix based only on the screenshot

| ID | Status | What the screenshot actually supports | What remains unknown |
| --- | --- | --- | --- |
| IL-01 | **PARTIAL** | Generator is discoverable inside the native Effects Library under Fusion Generators → CartoRig Atomic | Whether installation was double-click, any prompts, restart/reload, or exact corrected bundle hash |
| IL-02 | **PASS (visible frame)** | Generator is on the Edit timeline and the expected two-rectangle schematic renders in the Viewer | Scrubbing, rendering consistency, transparent output, frame-range behavior |
| IL-03 | **PASS (visible Inspector layout)** | A selected CartoRig Generator exposes the specified group tabs in the native Inspector | Whether every published property renders and accepts edits |
| IL-04 | **NOT TESTED** | Only the Map tab is open; Region A color response cannot be judged | Change Region A Fill and inspect Region B/base independence |
| IL-05 | **NOT TESTED** | Region B color field is not displayed | Change Region B Fill and confirm independence |
| IL-06 | **NOT TESTED** | Base Map Fill picker exists | Change it and verify only background changes |
| IL-07 | **NOT TESTED** | Object opacity inputs not shown | Confirm both regions respond independently |
| IL-08 | **NOT TESTED** | Camera tab is visible but not open | Zoom/Center must update both shapes together |
| IL-09 | **NOT TESTED** | Probe tab is visible but not open | Text changes only the label |
| IL-10 | **NOT TESTED** | No visible independent opacity/zoom curves or keyframe interactions | Create and inspect native keyframes in Edit |
| IL-11 | **NOT TESTED** | No save/reopen or Deliver evidence | Confirm persistence and output |

## New conclusion permitted by the evidence

The **static Fusion Generator + native Inspector + schematic Viewer** integration is feasible in the user's Resolve installation. This is meaningful progress for **DEC-007**, but **dynamic location search, arbitrary object creation/selection, a scalable list, per-object animations, and one seamless Atomic Design interface are still completely unverified**.

## Next minimal evidence request

1. Open the **Objects** tab and capture it (expect two object color groups and independent opacity controls).
2. Change **Region A Fill** to a distinctive color and verify that only the left rectangle responds.
3. Open the **Camera** tab, change **Camera Zoom**, and verify that both rectangles change together.
4. If available, try setting independent Edit keyframes for Region A Opacity and Camera Zoom and report whether the diamond/keyframe controls work.

Do not merge the experimental macro or claim a full map editor on the basis of one screenshot. Keep PR draft; obtain the remaining evidence before advancing to the dynamic UI problem.
