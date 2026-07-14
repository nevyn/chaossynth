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
   pots vertically.

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
The firmware workstream should diff it against its checked-in
`firmware/chaossynth/mapping.h` - they must match semantically.

Convergence note for firmware: special buttons are emitted as
`Button::onPico(gpio, cc, ButtonType::CCMomentary)` /
`ButtonType::CCToggle` (third arg defaulting to `ButtonType::Note`), guessing
at firmware.md's "type field on Button, constexpr factory style". The seed has
no special buttons so the golden diff is unaffected - sync the spelling when
firmware's Button struct lands.

## Hardware checklist (Nevyn)

- [ ] Real Chrome, real repo: pick repo, set photo, place 2 buttons + 1 pot,
      fill wiring -> `git diff` shows sane mapping.json + mapping.h; reload the
      page -> everything restored. NOTE: a clean save overwrites
      `firmware/chaossynth/mapping.h` - diff, don't commit blindly, while the
      firmware workstream is still landing.
- [ ] Simulate mode against the IAC bus: buttons send notes, pots sweep CCs
      (WebMIDI was permission-blocked in the embedded test browser, so this is
      unverified).
- [ ] `firmware/build.sh` compiles with a tool-generated mapping.h (blocked on
      the firmware workstream shipping build.sh).
