## ADDED Requirements

### Requirement: Resolve a gaze point to the containing element
The system SHALL resolve a gaze `ScreenPoint` to the named `Element` whose normalized rect
contains it on the active surface's `ElementMap`. When the point falls inside more than one
element's rect, the **topmost (last-registered)** element SHALL win, matching paint order.

#### Scenario: Point inside one element
- **WHEN** a point falls inside exactly one registered element's rect
- **THEN** resolution returns that element (carrying its `id`, `role`, and `label`)

#### Scenario: Overlapping elements — topmost wins
- **WHEN** a point falls inside two overlapping element rects
- **THEN** resolution returns the last-registered (topmost) element

### Requirement: Geometric region-id fallback when nothing is hit
The system SHALL fall back to the geometric region id (the 3×3 screen cell, `r{row}c{col}`, origin
top-left) when no element on the active surface contains the point — including an empty
`ElementMap` — so a candidate target is **never dropped** for lack of a named element.

#### Scenario: Point on bare canvas
- **WHEN** a point lands inside no registered element's rect
- **THEN** resolution returns a geometric region id (e.g. `r1c1`), not nil

#### Scenario: Empty map reproduces region behavior
- **WHEN** the `ElementMap` has no elements
- **THEN** every point resolves to its geometric region id

### Requirement: Resolution yields a GazeTarget carrying the resolved identity
Resolution SHALL produce a `GazeTarget` whose `id`/`role`/`label` are the resolved element's when
an element is hit, and whose `id` is the region id with a `region` role when it falls back. This is
the single resolution path consumed by both fixation events (`FixationEvent.target`) and the
utterance fuser, so the two agree on element identity.

#### Scenario: Hit yields named target
- **WHEN** a fixation centroid resolves to a registered element
- **THEN** the produced `GazeTarget` carries that element's `id`, `role`, and `label`

#### Scenario: Miss yields region target
- **WHEN** a fixation centroid hits no element
- **THEN** the produced `GazeTarget` carries the region id and a `region` role
