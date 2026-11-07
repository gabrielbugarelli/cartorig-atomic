# Atomic component catalog — Design proposals

> **DRAFT.** This is a vocabulary and interaction-contract inventory; not a library of implemented widgets, not pixel-perfect visuals, and not a commitment to any host UI technology.

## 1. Rules of the design system

1. A reusable component is defined by **user meaning and behavior**, not by an available OpenFX input.
2. The same semantic property uses the same control, terminology, units, feedback and keyboard behavior across compatible objects.
3. Contextual editing does **not** mean showing irrelevant inputs on every entity.
4. A visual selection component must not be the same object as the geographic model's feature ID.
5. An animatable property can be displayed as static or keyed, but must have a clear source of truth in Resolve.
6. A new object type only adds specific fields; it does not create a new competing way to edit Fill, Stroke or Opacity.
7. Every component must support missing-data, invalid, disabled and asynchronous states wherever applicable.
8. The component system must not dictate whether the host uses Inspector, UIManager, macros or a hybrid; adapter binding follows real SDK tests.

## 2. Atoms

| ID | Name | Required purpose | Important states | Usage |
| --- | --- | --- | --- | --- |
| AT-01 | Button | Invoke a clear single action | enabled, disabled, busy, focused | Add, Apply, Cancel |
| AT-02 | Text Field | Edit human-readable strings | blank, typing, invalid, disabled | Location search, labels |
| AT-03 | Field Label | Identify value and units | default, required, disabled | Every property |
| AT-04 | Icon | Consistent semantic cue, with accessible text | selected, unselected, disabled | Lock, visibility, keyframe |
| AT-05 | Color Swatch | Display and open a consistent color selector | inherited, overridden, animated, disabled | Fill/Stroke/Text Color |
| AT-06 | Numeric Field | Enter precise numeric value without changing unit semantics | static, keyed, invalid, mixed | Width, Opacity, Zoom |
| AT-07 | Slider | Adjust bounded visual properties | static, keyed, disabled | Opacity/Width where meaningful |
| AT-08 | Choice Control | Select among comprehensible options | chosen, unavailable, disabled | Place type, line style |
| AT-09 | Toggle | Set a clear boolean state | on, off, disabled | Visibility, Lock |
| AT-10 | Property Keyframe Marker | Indicate/modify host-controlled temporal state | no key, at key, between keys, unsupported | Animate properties |
| AT-11 | Geometry Availability Indicator | Tell whether result supports point/line/polygon operations | point-only, polygon, unavailable | Search results |
| AT-12 | Status Text | Explain warning without leaking implementation details | note, error, recovery available | Missing source/host |

### Atom-level invariants

- AT-05 must never become a separately named country-specific set of R/G/B sliders.
- AT-10 is not a private CartoRig timeline or an unverified promise of keyframe host API access.
- AT-06 must disclose whether a width is screen pixels, degrees or a geometric world unit.
- AT-02 accepts native place names, not backend IDs as the mandatory search syntax.
- Keyboard focus, display scaling and accessibility are part of each component's review.

## 3. Molecules

| ID | Name | Constituent atoms | Meaning and accepted action |
| --- | --- | --- | --- |
| MO-01 | Location Search | Text Field + results status + optional filter | Query places; does not mutate the scene |
| MO-02 | Location Result | Label + type + parent + availability + select | Disambiguate Rio state/city and São Paulo state/city |
| MO-03 | Fill Control | Label + Color Swatch + optional opacity detail + keyframe state | Set Fill of selected compatible object |
| MO-04 | Stroke Control | Label + Color Swatch + Numeric Width + optional style | Set path/border appearance |
| MO-05 | Opacity Control | Numeric/Slider + Property Keyframe Marker | Whole-object opacity (0–100% display candidate) |
| MO-06 | Object List Row | Object name + type + Visibility + Lock + selection | Select/rename/hide/lock one object |
| MO-07 | Route Endpoint | Location Search + point/multipolygon constraint feedback | Resolve one route anchor without guessing |
| MO-08 | Keyed Property | Any editable value + keyframe state + time awareness | Modify an approved animatable host property |
| MO-09 | Camera Destination | Location result + Focus/Fit/Animate choice | Navigate without typing coordinates |
| MO-10 | Property Override Indicator | Color/other value + inherited/overridden state + reset | Preserve custom style when preset changes |
| MO-11 | Inline Error & Recovery | Status Text + recovery action | Surface missing dataset, unsupported action or host failure |

### Molecule-level behavior examples

**MO-03 Fill Control:** whether a user selects `Base Map / Land`, `Brazil`, or `Rio de Janeiro — State`, the control retains the same appearance, label and operation. It receives a different target object ID and applies a change only to that target.

**MO-07 Route Endpoint:** `Amapá — State` is a region, not a point. The molecule cannot silently choose an invented center; it must offer an explicit endpoint resolution strategy approved by the owner.

**MO-08 Keyed Property:** on a keyed property, the UI must disclose whether the current edit writes/replaces a keyframe or changes an initial constant. Until Resolve-specific behavior is proven, this control is a design requirement, not executable UI.

## 4. Organisms

| ID | Name | Responsibilities | Core molecules |
| --- | --- | --- | --- |
| OR-01 | Location Browser | Search, filter, disambiguate, inspect actions, source integrity | MO-01, MO-02, MO-11 |
| OR-02 | Object Collection | Select, order, hide, lock and identify authored objects in the active Map Scene | MO-06, MO-11 |
| OR-03 | Contextual Style Inspector | Edit Fill, Stroke, Opacity and inherited/overridden style | MO-03, MO-04, MO-05, MO-10 |
| OR-04 | Camera Controls | Focus/Fit, frame pose and animate shared view | MO-09, MO-08 |
| OR-05 | Route Builder | Select from/to; resolve polygon endpoint; adjust geometry; style/reveal | MO-07, MO-04, MO-08 |
| OR-06 | Map Scene Context | Confirm active scene/clip, create new Map Scene, handle missing host context | MO-11 and scene name/actions |

### Organism invariants

- OR-01 and OR-02 never interpret the same selection differently: a location search result does not automatically become a persistent scene object.
- OR-03 edits only properties applicable to the selected object. An editable text label should not expose polygon Fill unless it has a fillable background.
- OR-04 owns one shared camera per Map Scene; object geographic anchors follow its view.
- OR-05 is one route workflow, not separate menu commands for arrow creation, animation, reveal and endpoint selection.
- The organization must be usable without manually connecting or renaming Fusion nodes.

## 5. Templates (Atomic Design, not DRFX)

| ID | Name | Arranges | Scope |
| --- | --- | --- | --- |
| TP-01 | Map Editor | Scene Context + Location Browser + Object Collection + Contextual Inspector | Normal editing |
| TP-02 | Region Editing | Location results + region object selection + style controls | Countries/states |
| TP-03 | Camera Editing | Location results + shared camera + native keyframe feedback | City focus/movement |
| TP-04 | Route Editing | Route Builder + object selection + style/animation | Origin-to-destination visual |

An Atomic Design `Template` is an interface arrangement; a Resolve `.drfx` or Fusion `.setting` is a **technical distribution format**. They must never be conflated.

## 6. Pages — real states, not additional screens

| ID | Scenario instance | Why it exists |
| --- | --- | --- |
| PG-01 | Rio de Janeiro State highlighted over Brazil | Tests object identity, polygon geometry, color consistency |
| PG-02 | São Paulo City selected as camera target | Tests city/state disambiguation, camera pose and curves |
| PG-03 | Brasília → Amapá Route with chosen endpoint | Tests explicit anchors, Arrowhead, Reveal and camera alignment |
| PG-04 | Active Map Scene with no authored objects | Tests empty state without default animations |
| PG-05 | Location with only a point, no polygon | Tests honest capability disclosure and disabled actions |

## 7. Binding contract (technology neutral)

A user interaction should emit a **semantic operation**, not node manipulation. Examples in specification notation only:

```text
FindLocation(query, typeFilter?) → SearchResults
SelectLocation(featureRef) → SelectionContext
AddRegion(featureRef) → RegionObjectId
SetStyle(objectId, property, value) → ChangeResult
FocusCamera(featureRef) → CameraResult
CreateRoute(fromAnchor, toAnchor) → RouteObjectId
SetKeyframe(objectId, property, frame, value) → HostAnimationResult
```

These are **not implemented APIs**. Source code is forbidden until both interaction approval and host proof. The ownership of host keys vs scene constants and the number of Fusion nodes remain open architectural questions.

## 8. Required acceptance examples

- **Color reuse:** same Fill interaction on Base Land, Brazil and RJ state; each target has its own value.
- **Result selection:** Rio state, Rio city, São Paulo state and São Paulo city can be distinguished without codes.
- **Object independence:** two regions retain color, opacity and animation separately; no shared slider that overwrites another object.
- **Camera tracking:** scene objects remain geographically aligned at every intermediate animation frame.
- **Route endpoint:** choosing Amapá state triggers explicit point selection; never substitutes Macapá without a user choice.
- **No duplicate timeline:** a property can only claim native keyframe/curve editing after the Resolve 20 host test succeeds.
- **Cancellation:** closing a dialog or canceling route creation leaves no orphaned nodes or half-finished scene mutation.
- **Missing geometry:** impossible Fill/Stroke actions are disabled and explained; not silently performed on city points.

## 9. Decisions required from owner

- Preferred screen hierarchy and whether Location Browser is always visible.
- Placement and navigation of Camera vs Object properties.
- Whether geographic type filtering uses a persistent dropdown, in-search result chips or both.
- User-visible operation names and selection gestures.
- Route line/arrow defaults and endpoint-point selection.
- Visual tokens, typography, dark/light design, interaction density and empty states.
- Any claim to docked layout, Viewer picking or keyframe publishing after tests on Resolve 20.

## 10. Component review template

```text
Component ID:
Problem solved:
Owner-facing label:
Allowed object types:
Inputs, units and validation:
States:
Keyboard and accessibility:
Semantic command:
Host rendering/binding option:
Host proof (PASS / FAIL / NOT TESTED):
Reviewed alternatives:
Owner decision and date:
```

**Review gate:** Components in this file remain `PROPOSED` until the owner approves interaction behavior. This file creates no new user-facing commands.
