# Plan: patch design (awaiting brainstorm)

The musical heart: what the installation actually sounds like. Placeholder until
the brainstorming session happens — capture its output here, then this becomes a
buildable brief on top of the synth-engine skeleton.

## Fixed goals (from the vision)

- **Idle**: ambient, warm, alive — something you'd happily camp next to for a
  week. Never fully silent; invites approach.
- **Interacting**: immediately audible response to EVERY control; playful and
  energetic but not harsh — "actiony but not too much so".
- **No wrong notes**: everything quantized to a scale/chord world; any mash
  sounds intentional. Zero musical knowledge required.
- **Neighbors**: it lives in a camp. Cap volume, tame the low end at night if
  needed. (Check Borderland's sound policy.)

## Brainstorm agenda

- Mood references: 2–3 tracks/artists for idle, 2–3 for active.
- Harmony: one key/scale forever, a slowly drifting one, or button-selectable
  roots?
- What do ~18 buttons DO — a note grid for one voice? several voices? chord
  stabs? a few one-shot "events" (bell, thunder, whale)?
- The pots (max 8): which macro parameters feel most satisfying to a passerby?
  (filter, space/reverb, tempo/density, timbre morph, pitch spread…)
- Generative behavior when active: arps/echoes riffing on what you play, or
  strictly direct response?
- Does idle evolve over hours? React to time of day?

## Will produce

- The `synth` object schema in mapping.json — finally pinning the free-form
  section left open in docs/midi-contract.md.
- Real synthdefs replacing the placeholders in synth/lib/synthdefs.scd.
- Engine tuning: idle timeout, crossfade times, voice caps.

## Constraint

Iterate against virtual-panel + a real speaker. Verify on the Pi's headphone
jack too — it is hissier and thinner than the Mac's DAC, and the patch must
sound good THERE.
