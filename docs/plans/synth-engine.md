# Plan: synth engine

The SuperCollider skeleton that turns panel MIDI into sound — identical behavior
on the dev Mac and the Pi. Correct architecture with tasteful placeholder sounds;
the actual musicality lands later via docs/plans/patch-design.md.

## Context

- Read docs/midi-contract.md first.
- SuperCollider ~3.13, sclang from the terminal, NO GUI classes anywhere — the
  Pi is headless, and `sclang main.scd` must behave identically on both
  platforms. Mac install: `brew install supercollider` (run.sh should also find
  the .app bundle's sclang).

## Deliverables

1. **synth/run.sh** — starts the engine on either platform: locates sclang,
   picks the audio device (Pi: headphone jack via ALSA; Mac: default output),
   execs `sclang main.scd`. `CHAOS_PLATFORM=pi|mac` override, auto-detected via
   uname.
2. **synth/main.scd** — boots the server, loads lib/, loads synth/mapping.json,
   connects MIDI, prints one unambiguous `CHAOSSYNTH READY` line (the
   systemd-journal heartbeat).
3. **synth/lib/**
   - `mapping.scd` — parse mapping.json; poll mtime every ~2 s and hot-reload on
     change, sound uninterrupted. This is how we remap live at the burn — in the
     field it's fed by `pi-image/deploy.sh --ephemeral`, which works under
     overlayfs (RAM-only, reverts on reboot).
   - `midi.scd` — connect to the source named "Chaossynth", retrying until it
     appears (the panel may enumerate after boot) and surviving re-appearance
     after a cable yank. Dispatch note/CC per mapping; CC 123 releases
     everything; unmapped note/CC logs once per id and never crashes.
   - `engine.scd` — voice management + the idle/active state machine: track
     time-since-last-event; after the idle timeout (constant up top, default
     90 s) the idle layer crossfades in over ~10 s; any input ducks it back
     down over ~1 s.
   - `synthdefs.scd` — placeholders with the right SHAPE: a warm evolving pad
     drone (idle); a soft keys/pluck voice per button where button id maps to a
     degree of a pentatonic scale across octaves (musical enough to demo, no
     wrong notes even now); pots 0–3 provisionally wired to master filter
     cutoff / resonance / reverb mix / volume.
4. **synth/tools/virtual-panel.py** — python3 + mido + python-rtmidi
   (tools/setup.sh creates a venv). Creates a virtual MIDI source named
   "Chaossynth" and offers: `press <id> [seconds]`, `pot <id> <0-127>`,
   `chaos [seconds]` (random mashing), `scenario <file.json>` (timed event list)
   for repeatable tests.
5. **synth/README.md** — run it on the Mac in 3 commands; test without hardware;
   what the log lines mean. Document the one true volume knob here AND in
   docs/installation.md (there's a TBD waiting).

## Acceptance (agent-verifiable on the Mac)

- run.sh reaches CHAOSSYNTH READY with no MIDI source present, and connects when
  one appears later.
- virtual-panel `press 0` → voice + log line; all 18 seed buttons distinct;
  `pot 0` sweep audibly changes its placeholder role; CC 123 releases a held
  chord.
- No events for the idle timeout → drone fades in; one press → ducks away.
- Editing mapping.json (change a label) hot-reloads within ~3 s, uninterrupted.
- A NoteOn whose NoteOff never arrives (yanked cable) can't wedge the engine:
  voice cap + a max-hold sanity release (~5 min) exist.

## Guardrails

- Work only in synth/ (+ this doc + the installation.md volume TBD).
- No GUI classes. No destructive commands.
- Placeholders should already not be ugly — but do NOT spend the session on
  sound design; that is patch-design's whole job.
