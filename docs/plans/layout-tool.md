# Plan: layout tool

A single self-contained web page for laying out the panel's controls on a photo
and assigning wiring + MIDI, writing both synth/mapping.json and
firmware/chaossynth/mapping.h on every change. This tool exists to kill "which
button did I just wire?" head-scratching — correctness and clarity over beauty.

## Context

- Read docs/midi-contract.md first — the JSON schema and header format live
  there, this plan does not restate them.
- Deliverable: layout-tool/index.html. Vanilla HTML/CSS/JS in ONE file, no build
  step, no dependencies, runs from file:// in Chrome.
- File writing via the File System Access API (Chrome-only is accepted): user
  picks the repo root once, handle persisted in IndexedDB, writes debounced
  ~500 ms after each change. Fallback for other browsers: download buttons.

## Behavior

- **Photo**: "Set photo…" copies the chosen image to layout-tool/panel.jpg and
  shows it as the canvas. Re-settable as construction progresses (positions are
  normalized 0–1, so a re-shot photo from a similar angle keeps them roughly
  right).
- **Controls**: toolbar arms button-vs-pot; click the photo to place, drag to
  move, click to select, delete key removes. Selected control gets a sidebar:
  label, wiring (source dropdown per contract + chip/pin/channel fields), midi
  type (note / cc_momentary / cc_toggle), and the `synth` object as a validated
  raw-JSON textarea (round-tripped untouched otherwise — patch design owns it).
- **Ids** auto-assign next-free per kind and are never renumbered. Show them big:
  the id IS the note/CC.
- **Validation, always visible**: duplicate wiring (same gpio / expander pin /
  mux channel twice), duplicate MIDI assignment, out-of-range values.
  mapping.json is written even with errors (it's the working document);
  mapping.h is ONLY regenerated when there are zero errors, with a banner saying
  so — a half-finished layout must never break the firmware build.
- **Hardware pane**: edit `hardware` (expander addresses, mux pins, i2c) as a
  small form — rarely touched, but it must round-trip.
- **Stretch, only when everything above works**: "simulate" mode — clicking a
  button / dragging a pot sends the mapped MIDI via WebMIDI to a selectable
  output, making the page a virtual panel for patch design.

## Acceptance

- In Chrome: pick repo, set a photo, place 2 buttons + 1 pot, fill wiring — both
  files appear with correct content; reload the page → everything restored.
- `firmware/build.sh` still compiles with the generated mapping.h.
- Wire two controls to the same pin → visible error, mapping.h not regenerated.
- Open the existing seed synth/mapping.json → renders and round-trips it.

## Guardrails

- Write only inside the user-chosen project dir, and only the two contract files
  plus layout-tool/panel.jpg.
- Don't touch firmware engine code, synth/, pi-image/. No destructive commands.
