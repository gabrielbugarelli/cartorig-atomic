# Product and architecture decision register

Only explicit choices by the CartoRig owner are **Approved**. Research, prototype results, and this documentation do **not** constitute implicit approval.

| ID | Decision | State | Evidence / next action |
| --- | --- | --- | --- |
| DEC-001 | Start a new repository named `cartorig-atomic` rather than continue the old codebase | **Approved** | Owner explicitly approved a new public, documentation-first repository |
| DEC-002 | Make the new repository public | **Approved** | Explicit approval in the conversation |
| DEC-003 | Begin with docs only, before implementation | **Approved** | Explicit approval in the conversation |
| DEC-004 | Do not reuse earlier CartoRig source code, scripts, assets or internals | **Approved** | Requested greenfield rewrite |
| DEC-005 | Use Atomic Design to structure UI research and component proposals | **Direction supported; specific system pending review** | Owner proposed it, then requested the new repository |
| DEC-006 | Reference GEOlayers 3 for geographic UX, VES for Resolve integration learnings | **Reference approved; implementation undecided** | Research and discussion |
| DEC-007 | Edit-page Inspector as sole authoring surface | **SUPERSEDED by later CR-PS-2.0 Fusion mandate** | The owner supplied a new master product specification explicitly establishing Fusion Scene / Control / Motion. The prior host plan is archival only. |
| DEC-008 | Backend/renderer stack and object-to-node representation | **Pending** | Needs independent per-object keyframe and camera proof |
| DEC-009 | Geographic data packs and optional sources beyond Natural Earth | **Pending** | Requires license, coverage, storage and UX review |
| DEC-010 | Product v1 scope and release milestones | **Pending** | Review the end-to-end workflows first |
| DEC-011 | Specific OSI-approved license for code | **Pending** | No license file until explicitly selected |
| DEC-012 | Product UI mockups and visual design details | **Pending** | Owner review before implementation |

## DEC-013 — CR-PS-2.0 Fusion replacement baseline (2026-11-09)

**Newer mandate from the product owner:** CartoRig is authored within **Fusion**, with **Scene** via UI Manager, **Control** via the selected Fusion object's Inspector and **Motion** applying true Fusion curves editable in native Spline. The user supplied the master document [CR-PS-2.0](specs/CR-PS-2.0_Fusion_2026-11-08.md) and requested professional study and development from this new contract.

**Normative supersession:** DEC-007's Edit-first approach is obsolete for this rewrite. The old Fusion Generator/OpenFX previews, branches, code, installer and macros must not be reused; only research observations may inform independent technical decisions. Keep historical PRs unmerged until separately triaged.

**Decision statuses preserved verbatim from the source:** `MANDATE` is binding; `BASELINE-PROPOSED` (including the full R1.0 scope, 16 presets, UI defaults, initial Equirectangular projection, and Apache-2.0 recommendation) remains **awaiting explicit owner sign-off**. `LATER-PROPOSED` and `RESEARCH` are not release features. Engineering may run throwaway host feasibility experiments without treating product UX proposals as approved.

**Acceptance:** HOST-01 through HOST-10 and the applicable QA matrix from CR-PS-2.0 require real Resolve 20 evidence. Unit and CI results are not host certification. A missing feature may not be hidden, silently removed or presented as complete.

## Template for future decisions

```text
ID:
Problem / user outcome:
Alternatives evaluated:
Evidence (host test, user study, or authoritative docs):
Chosen behavior:
Owner approval and date:
Affected modules:
Acceptance tests:
Status: Proposed / Approved / Rejected / Superseded
```

**Not allowed:** adding unapproved UI commands or automatically generating sample animations for a new scene.
