# Construction plan

Physical build tracker. Nevyn owns this doc — agents: update checkboxes only when
told, otherwise hands off.

Deadline: depart for Borderland **2026-07-19**.

## Panel electronics

- [ ] Mount remaining buttons (18 planned total)
- [ ] Second MCP23017 if buttons exceed 18 — decide BEFORE final wiring
      (addr 0x21: tie A0 high; firmware already supports it as config)
- [ ] Mount + wire pots to the 4051 (8 max — accepted limit, the 4051 was
      annoying enough for one)
- [ ] Strain-relieve every off-board wire
- [ ] Write control ids on the panel back in marker (match layout-tool ids)
- [ ] Final panel photo into the layout tool once controls are mounted

## Brain box

- [ ] Mount RP2350-Zero + Pi 4 in enclosure
- [ ] USB: RP2350 → Pi
- [ ] Audio: Pi headphone jack → speaker (cable + strain relief)
- [ ] Power: Pi PSU + speaker from camp grid
- [ ] **Test at home: does the speaker power back ON by itself after an
      outage?** Festival power WILL cycle; if the speaker stays off, the whole
      installation is dead until someone notices. Solve before packing.

## LEDs (separate system)

- [ ] Mount LED strips + shinycore
- [ ] Pick an idle preset that matches the vibe
- [ ] (stretch, parked: [plans/led-sync.md](plans/led-sync.md))

## Structure & weather

- [ ] Ground mount + anchors (stands in grass, survives wind and drunk leaning)
- [ ] Rain protection (parasol / roof) — electronics survive a week of Swedish
      summer
- [ ] Cable runs protected enough to not trip anyone

## Survivability kit (pack list)

- [ ] Cloned spare SD card (clone AFTER final provision + patch are on it)
- [ ] Spare RP2350-Zero, flashed with final firmware
- [ ] Spare USB + audio cables, tape, zip ties, multitool
- [ ] Laptop with this repo + Chrome (layout tool) for on-site remapping
- [ ] Phone hotspot creds already provisioned on the Pi (SSH lifeline)

## Software survivability (tracked in plans, listed for the overview)

- systemd `Restart=always` + hardware watchdog (pi-image)
- overlayfs read-only root — flip ON as the very last step
  (`pi-image/overlayfs.sh`)
- CC 123 all-notes-off on firmware boot — no stuck notes after power blips
