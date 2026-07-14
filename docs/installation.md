# On-site installation & operations runbook

From packed parts to a running installation at Borderland, and how to operate it
there. Agents: keep this in sync when you change service names, paths, or
commands — this doc gets read in a field, on a phone, with a hangover.

## Assembly (order matters)

1. Structure up, anchored, rain cover on.
2. Panel + brain box mounted; USB (panel → Pi) and audio (Pi → speaker) connected.
3. Power LAST: speaker on first, then the Pi. Synth autostarts ~40 s after power.

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
| Change the mapping | edit synth/mapping.json on the laptop (layout tool), then `pi-image/overlayfs.sh off` (reboots, ~1 min), `pi-image/deploy.sh` (restarts synth, seconds of silence), `pi-image/overlayfs.sh on` (reboots again) |
| Volume | panel pot 3 ("P3") is master volume (floor is -35 dB, never fully silent). The speaker's own knob is the ceiling: set it once at install so panel-max = loud-but-legal, then leave it |
| Full reset | power-cycle everything; it is designed to boot into working |

## Troubleshooting

| Symptom | Check, in order |
|---|---|
| No drone at all | speaker powered + cable seated → `systemctl status chaossynth` → journal |
| Drone but controls dead | USB cable panel→Pi → does `aconnect -l` list "Chaossynth"? → RP2350 power LED |
| One control does the wrong thing | mapping vs reality: layout tool, fix, deploy |
| Pi unreachable over SSH | hotspot actually on? give it 2 min; worst case power-cycle |
| Everything cursed | swap in the cloned SD card; still cursed → swap the spare RP2350 |

## Teardown

Power off (just cut it — overlayfs makes that safe), unplug, unbolt, done.
