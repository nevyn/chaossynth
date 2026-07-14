# Chaos Synth

A panel of chaotic buttons and knobs that anyone can walk up to and make music
with. Built for [Borderland 2026](https://theborderland.se/). The bigger dream
(three collaborating sides) lives in [docs/VISION.md](docs/VISION.md) — this repo
is currently laser-focused on shipping v1: **one panel, five days**.

## How it works

```
buttons ─┬─ MCP23017 ──┐
         └─ direct gpio ┤    USB MIDI     ┌───────────────┐
                        ├───────────────▶ │ Raspberry Pi 4 │──▶ speaker
pots ───── TMUX4051 ────┘                 │ SuperCollider  │
       (RP2350-Zero)                      └───────────────┘

RGB LEDs: separate shinycore controller, not in this repo.
```

Ambient drone when idle; every control makes an immediately audible, never-wrong
sound when touched. All musical meaning lives on the Pi — remap by editing a
JSON file, never by reflashing firmware (hot-reload in development,
`pi-image/deploy.sh --ephemeral` in the field). The firmware just reports stable
control ids. The seam between the parts is pinned in
[docs/midi-contract.md](docs/midi-contract.md).

## Repo map

| Path | What |
|---|---|
| [firmware/chaossynth/](firmware/chaossynth/) | RP2350-Zero sketch: scans controls, emits USB MIDI |
| [synth/](synth/) | SuperCollider engine — runs identically on a dev Mac and the Pi |
| [layout-tool/](layout-tool/) | one-file web app: place controls on a panel photo, assign wiring + MIDI, generates mapping.json + mapping.h |
| [pi-image/](pi-image/) | reproducible headless Pi setup: prepare-sd / provision / deploy |
| [docs/](docs/) | [plan-v1](docs/plan-v1.md) · [midi-contract](docs/midi-contract.md) · [plans/](docs/plans/) · [construction-plan](docs/construction-plan.md) · [installation](docs/installation.md) · [VISION](docs/VISION.md) · [wiring.svg](docs/wiring.svg) |

## Status

Scaffolded and planned 2026-07-14; firmware scan engine already hardware-verified.
Workstreams, spawn instructions and integration checkpoints:
[docs/plan-v1.md](docs/plan-v1.md).
