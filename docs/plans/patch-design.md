# Plan: patch design

What the installation sounds like. Brainstormed 2026-07-14 (Nevyn + agent, input
from Gustav & Madde); buildable now that the synth engine skeleton has landed.
Builder: read docs/midi-contract.md first. This doc pins the `synth{}` schema the
contract left open, and it feeds tomorrow's physical panel build (see "Informs
the button build").

## Fixed goals (from the vision)

- **Idle**: ambient, warm, alive — you'd happily camp next to it for a week.
- **Interacting**: immediately audible response to EVERY control; playful, never
  harsh.
- **No wrong notes** — and no wrong *timing*: rhythmic sounds quantize to the
  grid so any mash sounds intentional.
- **Neighbors**: volume + low-end capped, hardest at night. Master volume is NOT
  a panel control — it lives on the amp/speaker or a pot off the main surface.

## Sound identity

- **Base, all day:** Boards of Canada — warm detuned pads, tape wow/flutter, a
  whisper of hiss/crackle. The lo-fi warmth doubles as armor: it masks the Pi
  headphone jack's noise floor.
- **Golden hour:** dub techno (Quantec) — deep chords, cavernous tempo-synced
  echo, soft 4/4 heartbeat.
- **Evening until midnight:** chill atmospheric breakcore — chopped amen,
  wobble bass. Beaty but friendly.
- **Anti-reference:** Andy Stott — too dark/unsettling here. (The chaos pot at
  max may *gesture* at his arrhythmia, tastefully.)

## Architecture: three orthogonal axes

1. **Harmonic brain** — one global `root + mode`. Every sound source quantizes
   through it; nobody can play outside it. Root changes retune the arp
   immediately and the drone glides over ~2 bars. Mode changes apply to new
   notes only.
2. **Energy** — a leaky integrator of input events (decay ~60 s) replacing the
   engine's binary idle/active flag (keep `CHAOS_IDLE_TIMEOUT` as the
   energy-zero point). Drives arp density, beat presence, drone duck. The arp
   *winds down* like a music box after the last touch rather than cutting.
   **Idle is always beatless** — the beat only exists while humans are playing,
   arming after sustained interaction (not the first touch) and fading out
   within ~90 s of the last.
3. **Atmosphere** — a wall-clock preset (Pi local time). Same controls, same
   roles; different tempo, palette, sample bank, energy ceiling, EQ tilt,
   volume cap. Crossfade ~10 min at boundaries; sample banks swap on next
   trigger. A regular discovers the panel changes with the day.

### Atmospheres (first guess — tune on site)

| Name | Hours | Character | BPM | Beat when active | One-shot bank |
|---|---|---|---|---|---|
| Dawn | 06–10 | sparsest warm pad, slow arp | 72 | none | hushed bells |
| Day | 10–17 | playful toybox, bright plucks | 96 | soft percussion | bells, whale, water |
| Golden | 17–20 | dub techno, deep chords | 122 | 4/4 kick + skank | dub stabs, sirens |
| Night | 20–24 | chill breakcore, wobble bass | 170 (half-time feel) | chopped breaks | amen slices, sub drops |
| Afterhours | 00–06 | darkest quiet ambient, low shelf down | 60 | none | soft crackle swells |

Afterhours volume/low-end caps are the sound-policy answer; verify the actual
Borderland quiet hours and adjust boundaries (TBD).

## Button roles

| Role | Count | Behavior |
|---|---|---|
| `root` (piano row) | 5–6 | Moves harmonic center to that degree; arp re-roots now, drone glides. Last press wins. |
| `hold_fx` | 2 | Hold-for-dub-delay-throw, hold-for-reverb-swell. Affects the whole mix — collaborative by nature. |
| `chop` cluster | 3–4 | Rhythm slices, 16th-quantized (max ~90 ms wait — reads as tight). Bank per atmosphere: bongo rolls by day, amen slices at night. |
| `bass` | 1 (big) | Bass gesture in current root: LFO wobble stab in Golden/Night, soft sub swell in gentle atmospheres. |
| `voice` | fill | Direct plucks/keys on degrees of the current scale across octaves. Immediate, never quantized. Empty `synth{}` defaults here (today's behavior). |
| `oneshot` | 2–3 | Rare-feeling events from the atmosphere's bank (thunder, whale, bell swell). |
| `mode` | 0 or 3–5 | Scale flavor switch (rotary as n button ids). OPTIONAL — without it each atmosphere sets its own mode. |
| `phone_hook` | 0–1 | Stretch, see below. |

**Priority if the build yields fewer buttons:** roots > hold_fx > chops > bass >
voices > oneshots > mode.

## Pots — build all 8

| # | Role | Feel |
|---|---|---|
| 1 | `filter` | whole-mix brighten/darken — the instant-wow sweep |
| 2 | `space` | reverb size + mix on one knob |
| 3 | `echo` | delay mix/feedback, tempo-synced — dub throws |
| 4 | `phaser` | depth + rate |
| 5 | `energy` | bias added to the activity integrator: sparse pings → cascades (density, NOT raw tempo — groove stays locked) |
| 6 | `wobble` | bass/LFO rate in synced divisions (1/4 → 1/16) |
| 7 | `timbre` | pluck morph: soft keys → glassy bells |
| 8 | `chaos` | humanize: pitch drift, tape warble, timing slop, slice shuffle |

**Relaxation (all pots):** ~10 min after last touch, the *effective* value eases
back to the atmosphere's default over ~2 min — the panel self-heals; nobody's
3 a.m. filter-closed prank lasts until morning. Next physical movement glides
to the pot's real position over ~1 s: always audible, never a click.

Master volume is NOT one of the 8 (evict the placeholder on pot 3).

## Timing & mix hygiene

- One global clock at the atmosphere's tempo. Chops + beat quantize to 16ths;
  melodic voices and hold-FX respond immediately. Delay times are synced.
- ONE master reverb + ONE master delay bus (Pi 4 CPU); never per-voice reverbs.
- Sidechain: drone/pad lows duck under bass + kick (dub techno pumps anyway).
- The existing `\chaosMaster` limiter stays non-negotiable.

## Sound sources

- **Synthesize everything synthesizable** (pads, plucks, bells via Klank,
  thunder, whale, subs, dub stabs): zero assets, zero licensing, fits the
  aesthetic.
- **Sample files only for breaks** (amen etc.): `synth/samples/<bank>/`, short
  mono WAVs, loaded into slots alphabetically. Nevyn sources the break.

## mapping.json `synth{}` schema (pinning the contract's free-form object)

```json
{ "role": "root",   "degree": 4 }
{ "role": "mode",   "index": 2 }
{ "role": "voice",  "degree": 9 }
{ "role": "chop",   "slot": 1 }
{ "role": "bass" }
{ "role": "hold_fx", "fx": "delay" }
{ "role": "oneshot", "slot": 0 }
{ "role": "macro",  "param": "filter" }
{ "role": "phone_hook" }
```

Buttons: all roles except `macro`. Pots: `macro` only, `param` one of
`filter | space | echo | phaser | energy | wobble | timbre | chaos`.
Unknown role or param: log once, ignore (contract rule). Empty `synth{}`:
buttons act as `voice` with `degree = id`; pots log once and do nothing.
Extra per-role fields are allowed; consumers ignore what they don't know.

## Stretch: the telephone

Old handset as a mic: lift off the hook (a `phone_hook` button — on-hook =
deaf), talk/sing, and the engine loops it back chopped, echoed, and reverbed in
tempo. Never live-through (kills feedback risk). Needs hardware the panel
doesn't: a USB audio dongle for the Pi (it has NO audio in) and likely an
electret capsule swap in the handset. Build the `SoundIn` synthdef seam
whenever; ship it only if the hardware materializes.

## Informs the button build (tomorrow)

- **8 pots** — the mux has exactly 8 channels and all 8 roles above earn their
  spot. If cut: keep them in table order.
- Piano row of 5–6, visually distinct (ice cream sticks ✓).
- 2 chunky *hold-able* buttons for the FX throws — arcade-size.
- 3–4 chop buttons clustered like a drum pad.
- 1 physically BIG button for the bass.
- Mode rotary optional; skip it without guilt.
- If the phone happens: hook switch wires as a normal button.

## Will produce

- Real synthdefs replacing the placeholders in synth/lib/synthdefs.scd.
- The energy integrator + atmosphere clock + relaxation logic in engine.scd
  (keep the `~chaos*` conventions and entry points).
- `synth/samples/` + bank loading.
- mapping.json `synth{}` blobs for the real panel (with the layout tool).
- Engine tuning: wind-down curve, crossfades, voice caps.

## Acceptance (agent-verifiable on the Mac)

- A `CHAOS_FAKE_HOUR` (or similar) env override exists so every atmosphere is
  testable at any wall-clock time; virtual-panel scenarios exercise each one.
- virtual-panel `chaos 30` sounds *intentional* in every atmosphere — in key,
  on grid, under the volume cap.
- Mashing raises energy → beat rises; stopping → wind-down to beatless drone
  within ~2 min. Idle NEVER has a beat.
- Pot relaxation observable in logs + audibly (set phaser max, wait, hear it
  ease home).
- Every root/mode change keeps all sounding layers consonant.
- Pi CPU headroom: `s.avgCPU` comfortably under ~60% while mashing.

## Constraint

Iterate against virtual-panel + a real speaker. Verify on the Pi's headphone
jack too — it is hissier and thinner than the Mac's DAC, and the patch must
sound good THERE.
