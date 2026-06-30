# utterance-fusion Specification

## Purpose
Fuse a speech window with the fixation stream and voice-activity into a ranked `Utterance` event — overlap-classified gaze targets with a `primaryTarget` best-guess — so a consumer can disambiguate when the top candidates are close.
## Requirements
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

### Requirement: Overlap classification
The fuser SHALL classify each candidate fixation relative to the speech window as `during`
(its dwell interval intersects the window), `leading` (it ended before the window start but
within a lead margin), or `trailing` (it started after the window end but within a trail margin).
Fixations outside all three are excluded.

#### Scenario: Concurrent fixation is "during"
- **WHEN** a fixation's dwell interval intersects the speech window
- **THEN** its `GazeTarget.overlap` is `"during"`

#### Scenario: Just-before fixation is "leading"
- **WHEN** a fixation ends shortly before the window start, within the lead margin
- **THEN** its `GazeTarget.overlap` is `"leading"`

#### Scenario: Far-away fixation is excluded
- **WHEN** a fixation ends long before the window start, beyond the lead margin
- **THEN** it does not appear in `gazeTargets`

### Requirement: Ranking
The fuser SHALL rank `gazeTargets` by a score that weights overlap class (`during` above
`leading` above `trailing`) and dwell duration, with the highest score first.

#### Scenario: During outranks leading
- **WHEN** one candidate overlaps `during` and another is `leading`, with comparable dwell
- **THEN** the `during` target is ordered before the `leading` target

#### Scenario: Longer dwell breaks ties within a class
- **WHEN** two candidates share the same overlap class
- **THEN** the one with the longer dwell is ranked first

### Requirement: primaryTarget heuristic
When there are multiple candidate targets, the fuser SHALL set `primaryTarget` to the top-ranked
target's id only when its score exceeds the runner-up's by a configured margin; otherwise
`primaryTarget` SHALL be nil while the ranked alternatives remain available for Claude to
disambiguate. When there is exactly one candidate target, the fuser SHALL set `primaryTarget` to
its id (a lone candidate is unambiguous).

#### Scenario: Clear winner sets primaryTarget
- **WHEN** the top target's score exceeds the runner-up by more than the margin
- **THEN** `primaryTarget` is the top target's id

#### Scenario: Near tie leaves primaryTarget nil
- **WHEN** the top two targets are within the margin
- **THEN** `primaryTarget` is nil and both appear in `gazeTargets`

#### Scenario: Sole candidate is primary
- **WHEN** exactly one candidate target overlaps the window
- **THEN** `primaryTarget` is that target's id

### Requirement: Speech without gaze still emits
When no fixation overlaps the window or its lead/trail margins, the fuser SHALL still emit the
`Utterance` with an empty `gazeTargets` list and a nil `primaryTarget`, so the recognized text
is never dropped.

#### Scenario: Text-only utterance
- **WHEN** there are no candidate fixations for the window
- **THEN** an `Utterance` is emitted with the recognized text, empty `gazeTargets`, and nil `primaryTarget`

