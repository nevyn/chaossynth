# layout-tool

One-file web app ([index.html](index.html)): place controls on a panel photo,
assign wiring + MIDI per [docs/midi-contract.md](../docs/midi-contract.md), and
it live-writes both `synth/mapping.json` and `firmware/chaossynth/mapping.h`.
Exists to kill "which button did I just wire?" - ids are shown big, wiring
conflicts scream in red.

## Use (Chrome)

1. Open `index.html` (file:// works).
2. **Pick repo...** -> choose the chaossynth checkout, allow read+write. The
   handle is remembered; after a browser restart click **Reconnect repo**.
3. **Set photo...** -> copies your panel photo to `layout-tool/panel.jpg`.
   Positions are normalized 0-1, so a re-shot photo keeps them roughly right.
4. Arm **+ Button** / **+ Pot** and click the photo to place. Drag to move,
   click to select, Delete key removes. Ids auto-assign lowest-free per kind
   and are never renumbered.
5. Saves land ~0.5 s after each change. `mapping.json` is always written (it
   is the working document); `mapping.h` is regenerated ONLY while the error
   banner is empty, so a half-finished layout never breaks the firmware build.
6. **Simulate** sends the mapped MIDI via WebMIDI to a selectable output (on a
   Mac: enable the IAC Driver bus in Audio MIDI Setup) - click buttons, drag
   pots vertically. NOTE: the synth only listens to sources named
   "Chaossynth", and WebMIDI can't create virtual ports - so either rename
   the IAC bus to `Chaossynth` (Audio MIDI Setup > IAC Driver > bus name), or
   start the synth with `CHAOS_MIDI_SOURCE="IAC Driver Bus 1" ./run.sh`.

Other browsers: no live writing (no File System Access API); use the download
buttons for both files.

Demo mode (read-only, no repo hookup): serve the repo root over http
(`python3 -m http.server`) and open `layout-tool/index.html?demo=1`.

## Checks

```
node check.mjs            # validation, round-trip, id assignment, header gen
node check.mjs --update   # regenerate golden-mapping.h after generator changes
```

`golden-mapping.h` is the header generated from the seed `synth/mapping.json`.
Verified 2026-07-14 against the firmware workstream's deliverables: it matches
the checked-in `firmware/chaossynth/mapping.h` semantically (comments and
whitespace differ), and `firmware/build.sh` compiles clean with a
tool-generated header that includes a `BTN_CC_TOGGLE` special button. If the
Button/Pot/Mux structs in chaossynth.ino ever change shape, change
`generateHeader()` with them and re-run `--update`.

## Hardware checklist (Nevyn)

- [ ] Real Chrome, real repo: pick repo, set photo, place 2 buttons + 1 pot,
      fill wiring -> `git diff` shows sane mapping.json + mapping.h; reload the
      page -> everything restored. NOTE: a clean save rewrites
      `firmware/chaossynth/mapping.h` (same content, different comments) -
      that first cosmetic diff is expected.
- [ ] Simulate mode against the IAC bus: buttons send notes, pots sweep CCs
      (WebMIDI was permission-blocked in the embedded test browser, so this is
      unverified).
