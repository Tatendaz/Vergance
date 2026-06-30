## ADDED Requirements

### Requirement: Extract labeled elements from the page DOM
The system SHALL extract from the active web page's DOM a set of hit-test-worthy elements, each
carrying a stable id (the element's DOM `id` when present, else a generated CSS selector), an
optional role and label (from `role` / `aria-label` / visible text), and its bounding rectangle from
`getBoundingClientRect`. Hidden, zero-area, or off-viewport elements SHALL be excluded.

#### Scenario: Labeled element is extracted
- **WHEN** the page contains a visible element with an `id` and non-zero bounds
- **THEN** it appears in the extracted set with that id, its role/label, and its viewport rect

#### Scenario: Element without an id gets a generated selector
- **WHEN** an extracted element has no DOM `id`
- **THEN** it is given a stable generated CSS-selector id

#### Scenario: Hidden element is excluded
- **WHEN** an element is `display:none`, zero-area, or fully outside the viewport
- **THEN** it does not appear in the extracted set

### Requirement: Map DOM rects to normalized surface rects
The system SHALL map each extracted element's viewport-pixel rectangle to a normalized `Rect` in the
surface's `[0, 1]` coordinate space (origin top-left) — the same space as the gaze cursor —
accounting for the viewport size and the web view's frame within the surface, so the resulting
`ElementMap` resolves correctly against gaze points.

#### Scenario: A viewport rect maps into the surface frame
- **WHEN** a DOM element's rect is given in viewport pixels and the web view occupies a known normalized frame within the surface
- **THEN** the element's normalized `Rect` is its fractional position within that frame, scaled by the viewport size

### Requirement: Feed the shared element-resolution path
The extracted, normalized elements SHALL be assembled into an `ElementMap` and resolved through the
existing element-resolution path (`ElementMap.resolve`), so DOM-sourced gaze targets carry named ids
and the geometric region fallback still applies when a gaze hits no element.

#### Scenario: Gaze on a page element resolves to its id
- **WHEN** a fixation centroid falls inside an extracted element's normalized rect
- **THEN** resolution returns that element's id (carrying its role/label)

#### Scenario: Gaze on blank page area falls back to a region
- **WHEN** a fixation centroid hits no extracted element
- **THEN** resolution returns a geometric region id

### Requirement: Re-extract on page change
The system SHALL re-extract the DOM element set when the page scrolls, resizes, or navigates, so the
`ElementMap` tracks the live page. Re-extraction SHALL be debounced so rapid changes do not thrash
resolution.

#### Scenario: Scrolling refreshes element rects
- **WHEN** the page scrolls
- **THEN** the element rects are re-extracted (debounced) and the active `ElementMap` is updated

#### Scenario: Navigation rebuilds the map
- **WHEN** the web view navigates to a new page
- **THEN** the element set is rebuilt from the new DOM
