# 👁️ Vergance

Look at it. Say what you want. **Claude knows what "this" means.**

Phases 0–4 done · Phase 5 underway

[GitHub →](https://github.com/Tatendaz/Vergance) [Roadmap & spec](https://github.com/Tatendaz/Vergance/blob/main/ROADMAP.md)

Example event:

```text
the user looked at cta-primary for 620 ms
while saying "make this bigger"
```

## What it is

**Gaze + voice as a multimodal input layer.** The camera watches your eyes and mouth. You look at a UI element, say a command, and Vergance emits a small, semantic event that an agent like Claude can act on.

The point is *deixis* — the pointing part of language. "Make **this** bigger" is the most natural way to ask for a change and the least useful thing to type, because the word `this` carries no information without a gesture. Gaze supplies the gesture. Voice alone can't.

**Raw camera frames never leave the device — only semantic events do.**

## Two surfaces, one capture layer

- **🎯 Live pointer** Gaze + voice → a resolved intent event, in real time. The flagship interaction. Today those events land in the app; handing them to an agent, as a Claude Code skill (`/vergance`) that streams gaze-resolved intent into your session, is Phase 6.

- **🔥 Post-hoc heatmap** Record a session and analyse where attention actually went — the UX-research use case, from the same capture pipeline. Phase 8: the `session_summary` event type exists, the aggregation and the viz don't.

## The honest accuracy bar

Eye tracking attracts overclaiming, so this is stated up front:

- **Webcam (v1) — region-level.** A 2×2 quadrant split is reliable. 3×3 works with a still head and good light. Enough to drive the interaction, **not** enough to distinguish adjacent buttons.

- **iPhone TrueDepth (v2) — materially better.** Real gaze vectors plus depth.

## What's in the core

- **Sensor-agnostic core** Every sensor collapses to the same `GazeSample`, so backends are interchangeable by design. One exists today — the macOS webcam; the iPhone is Phase 7.

- **Calibration** Nine-point red-dot routine, quadratic least-squares with ridge regularization, reporting RMS error in pixels so the agent knows how far to trust a spatial claim.

- **One Euro filter** Adaptive smoothing — low latency on saccades, heavy smoothing on fixations — instead of a fixed EMA.

- **Fixation detection** A dwell / dispersion detector that turns a raw gaze stream into discrete fixations.

- **Element resolution** A fixation resolves to a *named* element on Vergance's own canvas today; browser-DOM and Accessibility-API surfaces are staged after it.

- **Portable event schema** Debounced, element-resolved `Codable` events (`session_start`, `fixation`, `utterance`, `session_summary`) rather than raw 60 Hz samples. These are the types the Phase 6 hand-off will carry; today they stay in-process.

- **Drift handling** A large head-pose delta from the calibration baseline prompts a recalibration.

## Explicit non-goals

- **Silent lipreading.** Visual speech recognition is unreliable. Vergance uses *audio for words* and *lips for timing* — mouth openness as voice-activity detection and emphasis.

- **Pixel-precise gaze.** Region- and element-level is the target.

- **Cloud video.** On-device only.

## Status

Phases 0–4 done and Phase 5(a) validated on-device — 48 green tests and a working macOS app; the agent hand-off (Phase 6), the iPhone sensor (Phase 7) and the heatmap (Phase 8) are still ahead. [`ROADMAP.md`](https://github.com/Tatendaz/Vergance/blob/main/ROADMAP.md) is the source of truth — it holds the full spec, architecture, event schema, and the phased plan. Swift 5.9, macOS 14+ / iOS 17+, Apache 2.0.

## FAQ

### Can I use it today?

Not as a finished product. The sensor-agnostic core, calibration, filtering, fixation detection, voice fusion and element resolution on the app's own canvas are in place; the agent hand-off, the iPhone sensor and the heatmap are on the roadmap. It's Apache 2.0, so you can read it, build on it, and contribute now.

### Does any video leave my machine?

No. Frames are processed on-device and discarded. Only the small semantic events are emitted — that's the whole design, not a setting you have to find.

### Why gaze instead of a mouse?

You're already looking at the thing you're talking about. A mouse makes you say it twice — once with your eyes, once with your hand — and neither survives into the prompt you eventually type.

### Does it need an iPhone?

No. A webcam works today at region-level accuracy; the iPhone's TrueDepth camera is the v2 path to real gaze vectors and depth. Because everything collapses to one `GazeSample`, adding the phone later doesn't mean rewriting anything.

---

HTML version: https://tatendaz.github.io/Vergance/ · Source: https://github.com/Tatendaz/Vergance · More work: https://tatendaz.github.io/ · Agent guide: https://tatendaz.github.io/llms.txt
