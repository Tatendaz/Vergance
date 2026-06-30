## ADDED Requirements

### Requirement: Mouth-aspect-ratio computation
The system SHALL compute a mouth-aspect-ratio (MAR) from lip landmark points as a normalized
openness value, where a closed mouth is near zero and openness increases monotonically with
vertical mouth opening. MAR SHALL be derived only as a geometric openness measure and SHALL NOT
be used to infer word content.

#### Scenario: Closed mouth yields near-zero MAR
- **WHEN** lip landmarks describe a closed mouth (small vertical lip separation relative to mouth width)
- **THEN** the computed MAR is near zero

#### Scenario: Open mouth yields larger MAR
- **WHEN** the vertical lip separation increases for the same mouth width
- **THEN** the computed MAR increases

### Requirement: Per-frame sampling
Each face frame with usable lip landmarks SHALL contribute one timestamped MAR sample to the
voice-activity stream; frames without usable landmarks SHALL contribute no sample.

#### Scenario: Usable frame produces a sample
- **WHEN** a frame yields lip landmarks above the confidence threshold
- **THEN** a `(t, mar)` sample is appended to the voice-activity stream

#### Scenario: Missing landmarks produce a gap
- **WHEN** a frame has no lip landmarks or they are below the confidence threshold
- **THEN** no sample is produced for that frame and the gap does not corrupt later window reductions

### Requirement: Window reduction to VoiceActivity
Given the MAR samples whose timestamps fall within a capture window, the system SHALL reduce them
to a `VoiceActivity` whose `jawOpenMean` is the mean openness and whose `peak` is the maximum
openness over the window.

#### Scenario: Reduction computes mean and peak
- **WHEN** a window contains MAR samples
- **THEN** the resulting `VoiceActivity.jawOpenMean` equals their mean and `VoiceActivity.peak` equals their maximum

#### Scenario: Empty window reduces to zero
- **WHEN** a window contains no MAR samples
- **THEN** the resulting `VoiceActivity` has `jawOpenMean` and `peak` equal to zero
