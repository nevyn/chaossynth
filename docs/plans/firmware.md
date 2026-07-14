# Plan: firmware

Bring firmware/chaossynth/chaossynth.ino in line with docs/midi-contract.md and
make it agent-buildable. The scan engine already works (hardware-verified) — this
is a refactor + polish pass, not a rewrite. Work only in firmware/ (plus this doc
and firmware/README.md).

## Context

- Read docs/midi-contract.md first. It wins over this file if they disagree.
- Board: Waveshare RP2350-Zero, arduino-pico core (Earle Philhower), Adafruit
  TinyUSB stack. Libraries are listed in the sketch header comment.
- The panel: up to 2 MCP23017s on I2C (0x20, 0x21), one TMUX4051 for pots, a few
  direct GPIOs. Wiring diagram: docs/wiring.svg.

## Tasks

1. **build.sh first**, so every later step is verifiable:
   - Installs/pins the core (`rp2040:rp2040` from the Philhower package index URL)
     and the three libraries. Pin exact versions in the script for
     reproducibility.
   - Find the exact FQBN with `arduino-cli board listall | grep -i 2350` (expect a
     Waveshare RP2350-Zero entry) and select the TinyUSB USB stack via board
     options (`arduino-cli board details` shows the option name). Verify, don't
     guess.
   - `./build.sh` compiles; `./build.sh --flash` uploads (for Nevyn — agents don't
     have the hardware).
2. **Split config from engine** — move `expanderAddresses[]`, `muxes[]`,
   `buttons[]`, `pots[]` and the I2C pin constants into
   `firmware/chaossynth/mapping.h`, included by the sketch. Generate its content
   by hand this once from synth/mapping.json (notes become 0–17, CCs stay 20–23
   per contract), with the GENERATED banner. The layout tool overwrites it from
   here on — so match the contract's description of the file exactly.
3. **Contract compliance** — CC 123 (value 0) once at boot after MIDI.begin;
   support `cc_momentary` and `cc_toggle` button types (a type field on Button;
   keep the constexpr factory style so the generated table stays readable).
4. **Debounce** — one physical press must never double-trigger. Per-button
   "ignore transitions within ~10 ms of the last one" is enough.
5. **Pot hysteresis** — a pot at rest must not emit CCs, even when its ADC value
   sits exactly on a 7-bit boundary (the existing EMA alone doesn't stop that).
   Deadband on the 12-bit value before the 7-bit conversion; a full physical
   sweep must still reach both 0 and 127.

## Acceptance

- `./build.sh` exits 0 from a clean checkout — the agent-verifiable gate.
- You own mapping.h and build.sh; the layout-tool workstream diffs its generated
  header against yours and runs your build script. Commit both EARLY, and flip
  your row to done in docs/plan-v1.md when finished — that's their green light.
- Code review against the contract: every MIDI byte the firmware can emit is
  listed there, nothing else.
- firmware/README.md contains Nevyn's hardware checklist: flash, then
  `receivemidi dev Chaossynth` (`brew install receivemidi`) — every button
  exactly one note 0–17 with no doubles, every pot a clean 0–127 sweep, zero CC
  chatter hands-off, CC 123 visible on boot.

## Guardrails

- Don't touch synth/, layout-tool/, pi-image/.
- No destructive commands, ever. Commit as you go, rationale in the message.
