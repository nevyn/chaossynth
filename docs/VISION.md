# Chaos Synth — the vision

A collaborative synthesizer installation for [Borderland](https://theborderland.se/),
by Gustav, Madde and Nevyn (camp Explorers). Walk up, start fiddling, and you're
making music. No musical knowledge needed, no wrong notes — and strangers end up
jamming together.

## The full dream

A three-sided (pyramidal) structure. Each side is its own instrument with its own
character and role in a shared soundscape:

| Side | Role | Controls |
|------|------|----------|
| A | Droning bass layer | pots for pitch/timbre, buttons for root selection |
| B | Melodic sequences | buttons to trigger/sequence notes, knobs for tempo/feel |
| C | Texture & effects | knobs for filter cutoff/resonance, reverb, delay |

Each side has its own microcontroller sending MIDI over USB to a shared Raspberry
Pi running the synth engine. Addressable RGB LEDs react to the music so light and
sound move together. Audio through an amplified speaker at friendly-camp volume,
not PA. Weatherproof enough to live outdoors for a Swedish-summer week, modular
enough to flat-pack for transport.

The bar for every control: immediately audible, satisfying, zero learning curve.
The idle state is a lovely ambient thing you'd want in your camp even when nobody
touches it.

## v1 — Borderland 2026 (what we're actually shipping)

One side: a single big pane of chaotic buttons and pots (no theme — chaos). One
RP2350-Zero scanning them, one Pi 4 making sound, LEDs handled by a separate
shinycore controller (a cheap sync path exists later:
[plans/led-sync.md](plans/led-sync.md)). The concrete plan: [plan-v1.md](plan-v1.md).

Parked for v2+: the other two sides (the architecture already scales — each panel
is just another USB MIDI device named into the same Pi), sound-reactive LEDs,
side-vs-side musical interplay.

## Links & people

- Cobudget dream: <https://dreams.theborderland.se/borderland/dreams-2026/cmnw2usfj000vpnkz2hxv4bf0?s=chaos&f=OPEN_FOR_FUNDING>
- Gustav — hardware, LEDs, construction
- Madde — art, aesthetics, LEDs
- Nevyn — electronics, firmware, software (hello@nevyn.dev)
