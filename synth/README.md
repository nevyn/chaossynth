# synth

The SuperCollider engine: turns panel MIDI into sound, identically on a dev Mac
and the Pi. Brief: [docs/plans/synth-engine.md](../docs/plans/synth-engine.md);
the MIDI seam: [docs/midi-contract.md](../docs/midi-contract.md).

## Run it on the Mac

```sh
brew install supercollider   # once
./run.sh                     # prints CHAOSSYNTH READY; idle drone fades in ~10 s
tools/setup.sh               # once — venv for the virtual panel
```

## Test without hardware

In a second terminal:

```sh
tools/.venv/bin/python tools/virtual-panel.py     # interactive fake panel
```

Then `press 0`, `pot 0 127`, `chaos 10`, etc. It enumerates as a MIDI source
named "Chaossynth", so the synth treats it exactly like the real panel.
One-shots (`... virtual-panel.py press 0 1`) and timed scripts
(`... virtual-panel.py scenario tools/smoke-scenario.json`) also work.

The whole engine's acceptance test in one command (~40 s, audible):

```sh
tools/smoke-test.sh
```

## What the log lines mean

| Line | Meaning |
|---|---|
| `CHAOSSYNTH READY` | engine fully up — this is the systemd-journal heartbeat |
| `MIDI: connected to 'Chaossynth'` / `... LOST` | panel (or virtual panel) appeared / was yanked; it keeps watching either way |
| `MAPPING: loaded N controls` | mapping.json (re)parsed; follows `change detected` on hot reload (~2 s poll) |
| `MAPPING: REFUSED / FAILED` | bad or unknown-version mapping.json — old mapping stays live |
| `VOICE: button N down -> midinote M` | a button made a sound |
| `MASTER: cutoff/resonance/reverb mix` | pot 0–2 moved a master control (pot 3 is unassigned pending the sound build) |
| `UNMAPPED: note/cc N (logged once)` | input not in mapping.json — a mapping bug to fix, never a crash |
| `SAFETY: max-hold release` | a NoteOff never arrived (yanked cable); voice freed after 5 min |
| `IDLE: ... drone fading in` / `... ducking` | boots straight into the ambient layer; back 90 s after the last input; any input ducks it |
| `ATMOSPHERE: day/golden/night/deep (pad ...)` | wall-clock slot changed (09/17/20/01); drone crossfades to that slot's pad. Night borrows Deep's pad for now |
| `DRIFT: chord -> A/C/G/D` | harmonic drift, every 2.5 min — the drone re-voices so nearby camps never hear the same minute twice |
| `CLOCK: untrusted` | `CHAOS_CLOCK_UNTRUSTED=1` set (no-RTC power-cut fallback): Day palette at reduced volume |
| `CHAOSSYNTH FATAL` | exiting on purpose so systemd restarts us |

Env knobs (mostly for tests): `CHAOS_PLATFORM=pi|mac`, `CHAOS_IDLE_TIMEOUT`,
`CHAOS_MAX_HOLD` (seconds), `CHAOS_ALSA_DEV` (Pi jack device, default
`hw:Headphones`), `CHAOS_MIDI_SOURCE` (accept one extra MIDI source name
besides "Chaossynth"), `CHAOS_FAKE_HOUR` (0-23, pin the atmosphere clock),
`CHAOS_CLOCK_UNTRUSTED=1` (force the no-RTC safe fallback).

## Simulate mode / IAC

The layout tool's simulate mode speaks WebMIDI, which cannot create virtual
ports — it can only send to an existing IAC bus, and the engine only listens
to sources named "Chaossynth". Two ways in: rename the IAC bus to `Chaossynth`
in Audio MIDI Setup (zero config, contract-clean), or run
`CHAOS_MIDI_SOURCE="IAC Driver Bus 1" ./run.sh`.

## Volume

Master volume is deliberately NOT a user control (patch-design decision): the
speaker/amp's own knob is the ceiling, set once at install; software sits at
\chaosMaster's fixed -6 dB under the limiter. Pot 3 is unassigned until the
sound build gives it its real role. (Also documented in docs/installation.md.)

## Layout

`main.scd` boots and wires everything; `lib/mapping.scd` (mapping.json +2 s
hot reload), `lib/midi.scd` (connect-by-name, retry, yank-survival),
`lib/engine.scd` (voices, pots, idle state machine), `lib/synthdefs.scd`
(placeholder sounds — real sound design is docs/plans/patch-design.md's job).
