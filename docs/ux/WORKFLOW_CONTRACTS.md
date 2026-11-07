# UX contracts — First three cartographic workflows

> **PROPOSED FOR OWNER REVIEW.** This document is a design artifact, not approved product behavior or an implementation specification for a particular Resolve SDK surface.
>
> **Scope:** one Map Scene in DaVinci Resolve Studio 20 (Windows), containing geographic objects with independently editable visual properties. Plugin interface copy is English; place-name search may recognize multilingual aliases where present in offline data.

## 1. The user-visible model

A **Map Scene** is the active cartographic clip. **Find** locates geographic features without mutating the scene. **Add** converts an explicitly selected result into a scene object. **Style** edits the selected object's applicable properties. **Animate** edits temporal properties using the existing Resolve timeline/keyframe mechanisms, wherever host capabilities have been proved.

A search result is not a scene object. A geographic feature ID is not a screen label. The camera is shared by all geography-anchored objects within a Map Scene.

### Candidate single-surface structure

```text
CartoRig — [active Map Scene]
┌─ Find location ──────────────────────────────────────────┐
│ [Search locations........................] [Type filter] │
│ Results: name | type | geographic parent | geometry     │
│ Actions (after selection): Focus / Fit / Add as...       │
└─────────────────────────────────────────────────────────┘
┌─ Objects ────────────────────────────────────────────────┐
│ Base Map                                                  │
│ Regions                                                   │
│ Routes                                                    │
│ Markers / Labels                                          │
│ Camera                                                    │
└─────────────────────────────────────────────────────────┘
┌─ Properties for selected object ─────────────────────────┐
│ Style | Geometry / Anchors | Animation (as applicable)    │
└─────────────────────────────────────────────────────────┘
[Resolve Viewer]  [Resolve Edit timeline and curves]
```

**Diagram status:** information architecture only. It does not assert a dockable panel can be created in Resolve 20. Alternative native surfaces must be evaluated before visual sign-off.

## 2. Workflow RJ — Highlight Rio de Janeiro state inside Brazil

**User intent:** color the administrative state independently without recoloring the country or confusing the city with the state.

**Preconditions:** a Map Scene exists; offline data contains a valid Admin 1 polygon for the state; current clip/scene is known unambiguously.

| Step | User action | Expected system feedback | Scene mutation |
| --- | --- | --- | --- |
| RJ-01 | Open CartoRig within the active Map Scene | Active scene name; its object list; no unrelated clips selected | None |
| RJ-02 | Type `Rio de Janeiro` in Find | Show typed matches such as `State — Rio de Janeiro, Brazil` and `City — Rio de Janeiro, Brazil` when present | None |
| RJ-03 | Select the `State` result | Show available actions and verified geometry; `Add as Region` is offered for a polygon | None |
| RJ-04 | Choose `Add as Region` | Region appears in Objects and Viewer; becomes selected | Create one Region referencing Admin 1 feature |
| RJ-05 | Change Fill using the shared color control | Color changes on that polygon at the current time | Update selected Region only |
| RJ-06 | Change Stroke/Opacity | Only matching geographic feature receives changes | Update selected Region only |
| RJ-07 | Select Base Map then change Land Fill | Base land changes; RJ's explicit override remains | Update base style token |
| RJ-08 | Select Brazil as another Region and style it | The country and state can overlap with understandable layer order | Update Brazil Region, not RJ |
| RJ-09 | Move camera and scrub | Both regions remain georeferenced without drift | Camera changes only |
| RJ-10 | Save, reopen, export | Matching style and geometry across viewer and exported frames | Persist & render |

**Important boundary:** choosing `City — Rio de Janeiro` must not enable a legal municipality polygon unless a real, separately approved polygon data source exists. An available city point can be used for Focus, Marker or Label.

**Failures to handle:** ambiguous results, source geometry absent, missing data pack, unlinked Map Scene, locked object, an animation at the playhead, failed Undo, overlapping Fill and Alpha. None may silently modify another object.

**Review questions:** Is `Add as Region` the right label? Should a location type filter be visible continuously or behind a filter icon? Are layer-order adjustments essential in the first usable release?

## 3. Workflow SP — Focus and animate camera to São Paulo city

**User intent:** move the shared geographic camera to a city without typing longitude/latitude or creating a highlighted region.

| Step | User action | Expected system feedback | Scene mutation |
| --- | --- | --- | --- |
| SP-01 | Search `São Paulo` | Distinguish State polygon and City point; identify parent hierarchy | None |
| SP-02 | Choose `City — São Paulo, São Paulo, Brazil` | Point destination selected; camera actions available | None |
| SP-03 | Choose `Focus Camera` | City centered in Viewer; a visible geographic focus is established | Camera pose only, no automatic animation |
| SP-04 | Adjust framing | User sees camera zoom/position, with understandable units/limits | Camera pose |
| SP-05 | Put playhead at departure frame and store departure pose | Keyframe is visibly associated with camera | Keyframe only |
| SP-06 | Put playhead at arrival frame, choose city and animate camera | Camera smoothly moves toward target; curve editable in supported Resolve host editor | Keyframes/curve |
| SP-07 | Scrub intermediate frames | Region, route and marker anchors track the same camera | No extra model mutation |
| SP-08 | Save, close, reopen and Deliver-export | Animation timing, destination, labels and highlights persist | Host persistence |

**Proposed explicit distinction:** `Focus Camera` changes the current pose, whereas `Animate Camera` produces a camera transition. Whether `Focus` writes a keyframe when Auto Key is enabled is an **open interaction decision**; no hidden auto-key choice may be implemented.

**Failure scenarios:** no city in Natural Earth, latitude/zoom outside supported projection bounds, dateline wrap, camera parameter missing from host, edited time offset/trim, frame seeks out of order.

**Review questions:** Should the editor have a persistent Camera item in Objects or a standalone Camera panel? Should `Fit to location` be separate from `Focus`? How should an existing keyed camera signal whether this action affects the current frame or the entire clip?

## 4. Workflow BA — Route/arrow Brasília city to Amapá state

**User intent:** draw and animate a visible arrow that starts at Brasília and ends at a specifically chosen location inside Amapá.

| Step | User action | Expected system feedback | Scene mutation |
| --- | --- | --- | --- |
| BA-01 | Add a Route object through the shared Add action | One context for origin, destination, path style and animation | Draft until confirmed |
| BA-02 | Search origin `Brasília` | `City — Brasília, Distrito Federal, Brazil` when present | Draft origin point |
| BA-03 | Search destination `Amapá` | `State — Amapá, Brazil` distinguished from any homonyms | Draft region |
| BA-04 | Select Amapá State | Explain that a polygon is not a single endpoint; offer explicit point selection methods | No invented endpoint |
| BA-05 | Choose endpoint within Amapá | Route preview shows exact origin/end pins | Draft destination point |
| BA-06 | Confirm route | One object appears in Objects; camera alignment preserved | Add Route with stable anchors |
| BA-07 | Set Stroke, width, Arrowhead and opacity | Shared controls; arrowhead remains attached to route tip | Update Route only |
| BA-08 | Edit spatial curvature | Path geometry changes; the *temporal* curve does not | Change path geometry |
| BA-09 | Animate Reveal at selected host frames | Length/progress changes using host keyframes | Animate Reveal |
| BA-10 | Zoom/pan during reveal and export | Both endpoints remain geographically anchored and arrowhead remains correctly oriented | None outside camera |

**Amapá endpoint options are NOT approved yet.** Candidate alternatives: choose a city in Amapá; specify a documented representative point; select a custom point using Viewer interaction if host permits. The app must never silently decide that `Amapá` means `Macapá`.

**Spatial vs temporal Bézier:** route geometry handles are spatial; easing and speed curves belong to animation. Showing them as the same control is a design error.

**Review questions:** Should a Route default to an arrowhead? Should curved or straight be default? If Viewer picking is unavailable, what acceptable alternative gives the editor explicit endpoint control?

## 5. Common interaction contract across all three

| Event | Proposed shared semantics |
| --- | --- |
| Search | Read-only query; no default geographic story or auto-created object |
| Select result | Context/actions update; no scene mutation |
| Add object | One atomic change; only selected source feature/point enters scene |
| Select object | Inspector/properties update; previous styles remain unchanged |
| Set Fill | Same color control for compatible surfaces, different object ownership |
| Set Opacity | Whole-object opacity; not equivalent to Hide |
| Focus | Camera-only action; no hidden new object or route |
| Animate | Uses supported native host frame/keyframe model; no second timeline |
| Cancel | Restores pre-action state; no orphan Fusion nodes |
| Undo/Redo | One logical authoring operation is reversible |
| Save/Open/Deliver | Pixel- and object-consistent across render and host lifecycle |

## 6. Required design states

- **No scene:** one create/open entry point and explanation.
- **Empty scene:** clean map baseline, no default Brazil/Venezuela animations or path.
- **Search empty / typing / no matches / ambiguous:** typed feedback and available actions.
- **Selected country/state/city:** actions conditioned on real geometry type.
- **Object static / animated:** property controls disclose whether editing writes keyframes.
- **Object hidden / locked / unsupported:** clear status and no destructive action.
- **Operation pending / cancelled / failed:** no partial graph or unexpected clip created.
- **Missing data pack:** provenance/error, with safe recovery rather than an empty render.
- **Host integration unavailable:** factual error; no substitute UI selected without approval.

## 7. Host truth and acceptance

These contracts are **desired user-visible behavior**, not claims of SDK availability. Each becomes an implementation candidate only after the owner approves the interaction AND a real Resolve Studio 20 proof establishes its host mechanism.

**Required evidence:** screenshots/video of the Editor + Viewer, clip selection handling, keyframe curves, Undo and reopening, plus a Deliver output. Unit tests and simulated Fusion tests are separate evidence classes.

## 8. Review checklist — all pending

- [ ] The Find → Add → Style → Animate model reflects actual editorial work.
- [ ] RJ state workflow is correct and unambiguous.
- [ ] São Paulo camera flow matches expected focus/animation behavior.
- [ ] Brasília → Amapá endpoint selection is clear enough to use quickly.
- [ ] All objects expose the same applicable style conventions.
- [ ] No menus or hidden animations have been added without approval.
- [ ] Host-specific UI constraints remain explicitly unresolved.

**This document must be reviewed before design becomes implementation.**
