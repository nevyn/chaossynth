# Plan v1 — Borderland 2026

What must be true on 2026-07-19: a one-sided panel of buttons and pots that plays
a lovely ambient drone when idle and responds musically to every control, running
unattended off festival power for a week. LEDs run separately (shinycore).

Signal chain: panel (RP2350-Zero) → USB MIDI → Pi 4 (SuperCollider) → speaker.

## Workstreams

| # | Plan | Builds | Parallel? | Status |
|---|------|--------|-----------|--------|
| 1 | [plans/firmware.md](plans/firmware.md) | firmware/ | yes | done 07-14 (hardware checklist pending, see firmware/README.md) |
| 2 | [plans/layout-tool.md](plans/layout-tool.md) | layout-tool/ | yes | done 07-14 (Chrome FS round-trip + simulate on Nevyn's bench, see layout-tool/README.md) |
| 3 | [plans/pi-image.md](plans/pi-image.md) | pi-image/ | yes | done 07-14 (hardware runbook pending, see pi-image/README.md) |
| 4 | [plans/synth-engine.md](plans/synth-engine.md) | synth/ | yes | in progress 07-14 |
| 5 | [plans/patch-design.md](plans/patch-design.md) | synth sounds | after brainstorm + #4 | brainstorm in progress 07-14 |
| 6 | [plans/led-sync.md](plans/led-sync.md) | — | PARKED | stretch |

1–4 are independent BECAUSE they all build against
[midi-contract.md](midi-contract.md). The contract is frozen; only Nevyn changes
it, updating every consumer in the same pass.

## How to spawn a builder

Fresh session in this repo. Prompt: `Build docs/plans/<name>.md.` — AGENTS.md
auto-loads the contract and house rules; each plan carries its own acceptance
criteria and guardrails. Update the Status column here as things land.

## Integration checkpoints (these find the real bugs)

- **A** — firmware + synth on the Mac: real panel plays real sound. (After 1 + 4.)
- **B** — the same on the Pi, deployed via deploy.sh. (After 3.)
- **C** — layout-tool round-trip: remap a button, redeploy, behavior changes,
  no reflash. (After 2.)
- **D** — soak test: runs overnight at home, gets power-cycled rudely a few
  times, comes back alone every time. (Before packing.)

## Rough schedule (2 build days + buffer)

- Day 1: spawn 1–4 in parallel; patch-design brainstorm; checkpoint A.
- Day 2: patch design build; checkpoints B + C; construction continues in
  parallel ([construction-plan.md](construction-plan.md)).
- Buffer: checkpoint D, overlayfs ON, SD clone + spares, packing
  ([installation.md](installation.md) becomes the on-site truth).

## Definition of done

All checkpoints green · construction-plan checklist done · installation.md
accurate · spare SD cloned + spare RP2350 flashed.
