## MODIFIED Requirements

### Requirement: Fuse speech window with gaze into an Utterance
The system SHALL produce a single `Utterance` from a recognized speech result, its capture
window, the fixation stream, the voice-activity samples, **and the active surface's `ElementMap`** —
carrying the recognized `text`, `speechConfidence`, the window `tStart`/`tEnd`, a ranked
`gazeTargets` list **whose ids are resolved to named elements via element-resolution**, a
`primaryTarget` best-guess, and the window's `VoiceActivity`. When the `ElementMap` is empty or an
overlapping fixation hits no element, that target SHALL fall back to its geometric region id, so
the output with an empty map is identical to the pre-element-resolution behavior. Overlap
classification, per-id aggregation, score-based ranking, and the `primaryTarget` heuristic are
unchanged — only the identity assigned to a target changes.

#### Scenario: Utterance assembled from inputs
- **WHEN** a speech result, fixation stream, voice-activity samples, and an `ElementMap` are passed to the fuser
- **THEN** it returns an `Utterance` whose `tStart`/`tEnd` match the speech window and whose `voiceActivity` is the window reduction

#### Scenario: Overlapping fixation resolves to a named element
- **WHEN** an overlapping fixation's centroid falls inside a registered element's rect
- **THEN** the matching `gazeTarget`'s `id` is that element's id, carrying its `role`/`label`, rather than a region cell

#### Scenario: Empty map preserves region behavior
- **WHEN** the `ElementMap` passed to the fuser is empty
- **THEN** each `gazeTarget` id is the geometric region id, identical to the pre-element-resolution output
