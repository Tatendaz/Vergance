## ADDED Requirements

### Requirement: Fuse speech window with gaze into an Utterance
The system SHALL produce a single `Utterance` from a recognized speech result, its capture
window, the fixation stream, and the voice-activity samples — carrying the recognized `text`,
`speechConfidence`, the window `tStart`/`tEnd`, a ranked `gazeTargets` list, a `primaryTarget`
best-guess, and the window's `VoiceActivity`.

#### Scenario: Utterance assembled from inputs
- **WHEN** a speech result, fixation stream, and voice-activity samples are passed to the fuser
- **THEN** it returns an `Utterance` whose `tStart`/`tEnd` match the speech window and whose `voiceActivity` is the window reduction

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
The fuser SHALL set `primaryTarget` to the top-ranked target's id only when its score exceeds the
runner-up's by a configured margin; otherwise `primaryTarget` SHALL be nil while the ranked
alternatives remain available for Claude to disambiguate.

#### Scenario: Clear winner sets primaryTarget
- **WHEN** the top target's score exceeds the runner-up by more than the margin
- **THEN** `primaryTarget` is the top target's id

#### Scenario: Near tie leaves primaryTarget nil
- **WHEN** the top two targets are within the margin
- **THEN** `primaryTarget` is nil and both appear in `gazeTargets`

### Requirement: Speech without gaze still emits
When no fixation overlaps the window or its lead/trail margins, the fuser SHALL still emit the
`Utterance` with an empty `gazeTargets` list and a nil `primaryTarget`, so the recognized text
is never dropped.

#### Scenario: Text-only utterance
- **WHEN** there are no candidate fixations for the window
- **THEN** an `Utterance` is emitted with the recognized text, empty `gazeTargets`, and nil `primaryTarget`
