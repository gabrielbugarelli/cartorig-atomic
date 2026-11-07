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
| DEC-007 | Final host UI surface (Inspector, DRFX, Viewer, UIManager or combination) | **Pending** | Requires a real Resolve 20 proof |
| DEC-008 | Backend/renderer stack and object-to-node representation | **Pending** | Needs independent per-object keyframe and camera proof |
| DEC-009 | Geographic data packs and optional sources beyond Natural Earth | **Pending** | Requires license, coverage, storage and UX review |
| DEC-010 | Product v1 scope and release milestones | **Pending** | Review the end-to-end workflows first |
| DEC-011 | Specific OSI-approved license for code | **Pending** | No license file until explicitly selected |
| DEC-012 | Product UI mockups and visual design details | **Pending** | Owner review before implementation |

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
