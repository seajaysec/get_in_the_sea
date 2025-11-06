# Get in the Sea — In C ensemble for norns

## Overview

- 8-player performance of In C with three ensemble modes and optional pulse voice
- Agent-based progression with repetition ranges, rests, and ensemble separation rules
- Works with audio engines (PolyPerc, FM7, Passersby, Odashodasho, MxSamples) and/or MIDI/crow

## Requirements

- norns
- optional: MIDI
- optional: crow / ii JF
- optional: MxSamples (installs and sample packs; missing packs may log warnings)

## Quick start

1) Load the script
2) Params → AUDIO ENGINE SETTINGS: activate an engine (e.g., PolyPerc) and set any engine params
3) Params → ENSEMBLE: set mode, tempo, pulse
4) K2 to Start/Stop; K1+K3 to Reset

## Front-panel controls

- K2: Start/Stop (all modes)
- K3: Reset (all seafarers)
- E1: Switch focus (Header ↔ Seafarers)
- E2: Move selection
  - Header focus: select Mode / Pulse / Tempo / Median
  - Seafarers focus: select seafarer 1–8
- E3: Adjust selected
  - Mode: change ensemble mode
  - Pulse: toggle on/off
  - Tempo: adjust BPM
  - Median: read-only
  - Seafarers focus:
    - Semi-autonomous: advance all (Next Pattern)
    - Manual: advance selected seafarer

## On-screen UI

- Header: Mode, Tempo, Median pattern, Pulse on/off; “Ending…” appears during ending protocol
- Players: two rows of four (1–4, 5–8)
  - Selected player shown in brackets, e.g., [06]
  - Ready indicator after sufficient time in pattern: trailing “*”, e.g., 06*

## Modes

- Autonomous: Players progress using agent rules; separation constrained to [median-2, median+3]
- Semi-autonomous: Players loop current pattern until you press Next (K3)
- Manual: Players loop their pattern; K3 advances only the selected player; optional auto catch-up if >3 behind

## Pulse (optional)

- Eighth-note metronome using the current audio engine (no MIDI/crow/JF)
- Starts ~5s after Start; continues through to the end; fades last in ending
- When using MxSamples, reuses any currently selected player instrument

## Parameters (Params)

### ENSEMBLE

- mode: autonomous | semi-autonomous | manual
- tempo (bpm): 69–132
- pulse enabled: off/on
- pulse volume: 0–1
- min active players: ensures density
- rest probability %: chance to rest between patterns
- octave displacement %: chance to enter a pattern up/down an octave
- auto catch-up: for manual mode; auto-jump if >3 behind median
- selected player (manual): used by K3 advance

### HUMANIZATION

- timing offset (ms): 0–30, gaussian delay per note
- volume drift ±%: 0–10, small random-walk velocity drift
- advance delay (ms): 0–500, extra hold after finishing a pattern
- skip pattern %: 0–5, rare skip at boundary

### SEAFARER (per-player)

- output: audio | midi | audio + midi | crow out 1+2 | crow ii JF
- octave: -3..+3
- midi device: device id
- midi channel: 1–16

### AUDIO ENGINE SETTINGS

- PolyPerc: activation + parameters
- FM7: activation (if available)
- Passersby: activation + parameters
- Odashodasho: activation + parameters
- MxSamples (if installed): client + instrument list per player; Randomize instruments trigger

## Score & behavior

- 53 patterns taken from the included score; grace notes supported
- Agent rules enforce max separation of 3 patterns; players too far ahead wait; too far behind jump to median−1
- Repetition counts scale by pattern length and tempo to target ~45–90 seconds per pattern
- Convergence/ending: when all reach 53, brief cycles of rise/fall, then players fade out; pulse fades last

## MIDI transport

- Incoming MIDI start/stop/continue controls Start/Stop for all players

## Presets (pset)

- To save: Params → Save → choose a slot
- On load, if a slot has no preset saved you may see “pset … not read.” This is informational only

## Notes

- MxSamples may log missing folder warnings if sample packs are not installed; this is non-fatal
- Legacy params (max phrase drift, repeat probability) are retained for compatibility but not used by the new agent logic

## Credits

- Original idea and score transcription by @tomw; expanded agent system and modes per In C guidelines
