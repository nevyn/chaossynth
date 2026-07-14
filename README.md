# Chaos Synth

A three-sided collaborative synthesizer installation for [Borderland 2026](https://theborderland.se/) (July 19–26). Built by Gustav, Madde and Nevyn, camp Explorers.

Each side has its own controls (buttons, knobs, sliders). Walk up to a side, start fiddling, and you're making music. Other people take the other sides and add layers. No musical knowledge needed. No wrong notes.

## Architecture

```
┌─────────────┐     MIDI      ┌──────────────────┐
│  ESP32 (A)  │──────────────▶│                  │
│  bass drone │               │                  │──▶ Speaker
├─────────────┤     MIDI      │  Raspberry Pi 5  │
│  ESP32 (B)  │──────────────▶│  (synth engine)  │──▶ LED strips
│  melodies   │               │                  │
├─────────────┤     MIDI      │                  │
│  ESP32 (C)  │──────────────▶│                  │
│  textures   │               └──────────────────┘
└─────────────┘
```

Three ESP32 microcontrollers, one per side. Each reads its own inputs (buttons, pots, encoders, whatever weird gizmos we find) and sends MIDI over serial to a Raspberry Pi 5.

The Pi runs the synth engine (TBD: Pure Data, SuperCollider, or Sonic Pi) and also drives the addressable RGB LED strips so that light and sound react together.

Audio output through a small amplified speaker. Portable-JBL volume, not PA.

## Sides

| Side | Role | Controls (planned) |
|------|------|--------------------|
| A | Droning bass layer | Pots for pitch/timbre, buttons for root note selection |
| B | Melodic sequences | Buttons to trigger/sequence notes, knobs for tempo/feel |
| C | Texture and effects | Knobs for filter cutoff/resonance, reverb, delay |

The exact control layout is still being designed. The constraint is: every control should do something immediately audible and satisfying, with no learning curve.

## Hardware

- 3× ESP32 dev boards (Arduino framework)
- 1× Raspberry Pi 5 + audio HAT
- Addressable RGB LED strips (WS2812B or similar)
- Assorted pots, buttons, encoders, sliders
- Acrylic sheet enclosures (weather sealed)
- Membrane-style or sealed buttons for outdoor use

## Physical construction

Triangular-ish form factor. Each side is a panel with controls and LEDs behind acrylic diffusion. The whole thing is modular: breaks down into flat sections for transport.

Designed to live outdoors for a week unsupervised in Swedish summer weather.

## Repo structure

```
chaossynth/
├── README.md
├── side-a/          # ESP32 firmware for bass drone side
├── side-b/          # ESP32 firmware for melody side
├── side-c/          # ESP32 firmware for texture/effects side
└── pi/              # Synth engine and LED driver on the Pi
```

(Structure is aspirational. Code may or may not exist yet.)

## Status

Early prototyping. Cobudget dream submitted, funded. Previous wiring diagrams and initial source were in a Claude chat session that has been lost. This README exists to preserve the design intent.

## Links

- Cobudget dream: https://dreams.theborderland.se/borderland/dreams-2026/cmnw2usfj000vpnkz2hxv4bf0?s=chaos&f=OPEN_FOR_FUNDING
- Borderland: https://theborderland.se/

## People

- Gustav — hardware, LEDs, construction
- Madde — art, aesthetics, LEDs
- Nevyn — electronics, firmware, software (hello@nevyn.dev)
