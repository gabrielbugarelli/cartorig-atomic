# Design system — Atomic Design for CartoRig

**Status:** Structural proposal awaiting owner approval. No UI framework or host surface has been chosen.

## Principle

Atomic Design is used to organize **interface design and interaction contracts**, not geographic source code or Fusion nodes. Start with complete user journeys, identify reusable controls inside them, and then standardize the components. Do not build a library of unused widgets first.

## Levels

| Level | Proposed examples | Responsibility |
| --- | --- | --- |
| Atoms | Button, Input, Label, Color Swatch, Slider, Keyframe Indicator, Icon | Predictable atomic UI behavior |
| Molecules | Location Search Field, Fill Control, Stroke Control, Route Endpoint, Animatable Property | Combine controls around one task |
| Organisms | Location Browser, Object Tree, Style Inspector, Camera Panel, Route Editor | Feature-level editing surfaces |
| Templates | Map Editor, Region Editing, Route Editing | Layout and state composition, not proprietary Fusion templates |
| Pages | Highlight Rio de Janeiro; Focus São Paulo; Brasília → Amapá | Real scenario instances for usability evaluation |

`Templates` here means an **Atomic Design UI template**, not a DaVinci Resolve `.setting` or `.drfx` file. They are different concepts and should remain explicitly named.

## Proposed semantic property contracts

- **Fill:** the color and alpha of an applicable polygon/surface.
- **Stroke:** color, width and rendering style of a line/boundary.
- **Opacity:** whole-object opacity, with a consistent unit/display.
- **Visibility:** hide/show without changing saved colors or keyframes.
- **Animation:** an indication that the property is static or animated and an action to edit compatible host keyframes.

The same property must use the same component and units across base-map and region editing when semantically equivalent. Showing different properties for a text label versus a polygon is legitimate **contextual editing**, not inconsistency.

## State ownership

- UI selection is not the persistent geographic feature ID.
- Each region/route owns its own explicit style overrides.
- Changing a map preset must not silently overwrite an object's override.
- Animatable values must not use one shared "selected object" keyframe slot that rewrites other objects' animation curves.
- Cancellation and undo must not leave behind partial nodes or orphaned objects.

## Component definition template

Every approved component should document:

- `Purpose` and corresponding user task.
- `Props` and allowed values/units.
- `States`: idle, focused, disabled, missing-data, invalid, loading, animated, mixed selection where relevant.
- `Events` and expected scene-model commands.
- `Keyboard/accessibility` and Windows scaling behavior.
- `Resolve binding`: Inspector, Viewer or supplemental UI **only after host test**.
- `Acceptance scenarios` and interaction evidence.
- `Owner approval` with date and decision ID.

## Unapproved technical choices

It has **not** been decided whether the UI is drawn through the Inspector, Fusion UIManager, a Viewer Interact, a `.DRFX` template facade or a combination. Atomic Design does not guarantee any of these APIs will support arbitrary docked panels in Resolve 20.
