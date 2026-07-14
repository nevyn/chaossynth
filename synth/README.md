# synth

The SuperCollider engine: turns panel MIDI into sound, identically on a dev Mac
and the Pi. Brief: [docs/plans/synth-engine.md](../docs/plans/synth-engine.md);
the MIDI seam: [docs/midi-contract.md](../docs/midi-contract.md).

## Run it on the Mac

```sh
brew install supercollider   # once
./run.sh                     # prints CHAOSSYNTH READY; idle drone after 90 s
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
| `MASTER: cutoff/resonance/reverb mix/volume` | pot 0–3 moved a master control |
| `UNMAPPED: note/cc N (logged once)` | input not in mapping.json — a mapping bug to fix, never a crash |
| `SAFETY: max-hold release` | a NoteOff never arrived (yanked cable); voice freed after 5 min |
| `IDLE: ... drone fading in` / `... ducking` | 90 s without input brings the ambient layer; any input ducks it |
| `CHAOSSYNTH FATAL` | exiting on purpose so systemd restarts us |

Env knobs (mostly for tests): `CHAOS_PLATFORM=pi|mac`, `CHAOS_IDLE_TIMEOUT`,
`CHAOS_MAX_HOLD` (seconds), `CHAOS_ALSA_DEV` (Pi jack device, default
`hw:Headphones`).

## The one true volume knob

Panel pot 3 ("P3", CC 23) is master volume. Its floor is -35 dB, not silence,
so a camper zeroing it can't make the rig look dead. The speaker's own knob is
the ceiling: set it once at install so panel-max is loud-but-legal, then leave
it alone. (Also documented in docs/installation.md.)

## Layout

`main.scd` boots and wires everything; `lib/mapping.scd` (mapping.json +2 s
hot reload), `lib/midi.scd` (connect-by-name, retry, yank-survival),
`lib/engine.scd` (voices, pots, idle state machine), `lib/synthdefs.scd`
(placeholder sounds — real sound design is docs/plans/patch-design.md's job).
