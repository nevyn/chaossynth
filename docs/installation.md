# On-site installation & operations runbook

From packed parts to a running installation at Borderland, and how to operate it
there. Agents: keep this in sync when you change service names, paths, or
commands — this doc gets read in a field, on a phone, with a hangover.

## Before you leave home (order matters)

The last two steps of bench prep, in this exact order — both need network and a
read-write SD, so they must happen before lockdown:

1. **RTC first.** With the DS3231 HAT seated (CR1220 battery in!) and the Pi still
   on wifi so its clock is NTP-correct: `pi-image/rtc.sh` → `ssh chaos@chaossynth.local
   'sudo reboot'` → `pi-image/rtc.sh` again. The second pass writes the true time
   into the battery and verifies. Without this, a power cut at the festival (no
   network there) rewinds the clock, and any time-of-day behaviour — e.g. quiet
   hours so the 4am beats don't wake the field — runs on a wrong clock.
2. **Overlayfs last.** `pi-image/overlayfs.sh on` is the final bench step before
   packing. It makes the root read-only, so nothing after it persists — including
   the RTC overlay line and a fresh clock write. That's why RTC comes first. The
   battery-backed clock keeps working read-only (it only ever sets the system time
   at boot, no writes needed).

To change either later: `overlayfs.sh off`, do the thing, `overlayfs.sh on` again.

## Assembly (order matters)

1. Structure up, anchored, rain cover on.
2. **Retighten every screw-terminal on the proto board** (transport vibration
   loosens them; small screwdriver is in the kit). Tug-test each wire.
3. Panel + brain box mounted; USB (panel → Pi) and audio (Pi → speaker) connected.
4. Power LAST: speaker on first, then the Pi. Synth autostarts ~40 s after power.

## Is it working?

- Idle drone from the speaker within a minute of power: yes.
- Press any button → immediate sound: fully yes.
- Neither: troubleshooting below.

## Getting a shell

1. Start the phone hotspot (its creds are provisioned on the Pi).
2. Laptop on the same hotspot: `ssh chaos@chaossynth.local`
   (fallback: the IP from the hotspot's client list).

## Common operations

| Do | How |
|---|---|
| Restart the synth | `sudo systemctl restart chaossynth` |
| Watch logs | `journalctl -u chaossynth -f` |
| Try a remap | edit synth/mapping.json on the laptop (layout tool), then `pi-image/deploy.sh --ephemeral` — hot-reloads in ~2 s, sound keeps running; reverts on reboot, so a power cycle = undo |
| Keep a remap | same edit, then `pi-image/overlayfs.sh off` (reboots, ~1 min), `pi-image/deploy.sh`, `pi-image/overlayfs.sh on` (reboots again) |
| Volume | the speaker/amp's own knob — master volume is deliberately not a panel control. Set it once at install to loud-but-legal; software sits at a fixed -6 dB under a limiter |
| Full reset | power-cycle everything; it is designed to boot into working |

## Troubleshooting

| Symptom | Check, in order |
|---|---|
| No drone at all | speaker powered + cable seated → `systemctl status chaossynth` → journal |
| Drone but controls dead | USB cable panel→Pi → does `aconnect -l` list "Chaossynth"? → RP2350 status LED: dark = no power, orange = USB not mounted, red = expander wiring, green = panel-side fine |
| One control flaky/dead | its screw terminal first (retighten, reseat wire), THEN mapping vs reality: layout tool, fix, deploy |
| Pi unreachable over SSH | hotspot actually on? give it 2 min; worst case power-cycle |
| Everything cursed | swap in the cloned SD card; still cursed → swap the spare RP2350 |

## Teardown

Power off (just cut it — overlayfs makes that safe), unplug, unbolt, done.
