# speech-capture Specification

## Purpose
TBD - created by archiving change phase-4-voice-fusion. Update Purpose after archive.
## Requirements
### Requirement: Push-to-talk capture window
The system SHALL recognize speech only while a push-to-talk control is held, and SHALL expose
the precise time window over which audio was captured.

#### Scenario: Hold opens a window and starts recognition
- **WHEN** the user presses and holds the talk control
- **THEN** speech recognition starts and a capture window opens, its `tStart` set to the press time

#### Scenario: Release closes the window and finalizes
- **WHEN** the user releases the talk control
- **THEN** recognition stops, the window's `tEnd` is set to the release time, and a final recognized result is produced

### Requirement: On-device recognition only
The system SHALL perform speech recognition on-device and SHALL NOT transmit captured audio off
the machine.

#### Scenario: On-device flag enforced
- **WHEN** a recognition request is created
- **THEN** it requires on-device recognition, and if on-device recognition is unavailable the system reports an error rather than falling back to a network request

### Requirement: Recognized result shape
A completed capture SHALL yield recognized `text`, a `speechConfidence` in `[0, 1]`, and the
capture window `[tStart, tEnd]`.

#### Scenario: Result carries text, confidence, and window
- **WHEN** a hold-then-release captures intelligible speech
- **THEN** the result contains the transcribed text, a confidence derived from the recognizer's segment confidences, and the `tStart`/`tEnd` of the hold

### Requirement: Authorization
The system SHALL request microphone and speech-recognition authorization before capturing, and
SHALL NOT capture when authorization is denied.

#### Scenario: First use prompts for permission
- **WHEN** the user first engages push-to-talk and authorization status is undetermined
- **THEN** the system requests microphone and speech-recognition permission before starting capture

#### Scenario: Denied authorization blocks capture
- **WHEN** microphone or speech-recognition authorization is denied
- **THEN** no audio is captured, no `utterance` is emitted, and the Run screen surfaces an authorization error

### Requirement: No-speech handling
A capture window that contains no recognizable speech SHALL NOT produce an `utterance`.

#### Scenario: Silent hold produces nothing
- **WHEN** the user holds and releases the talk control without speaking
- **THEN** no `utterance` event is emitted and the user is notified that nothing was recognized

