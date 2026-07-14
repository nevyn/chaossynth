# pi-image — reproducible headless Pi 4 setup

Flash a stock image, run two scripts, end with the synth auto-starting on
boot. No keyboard or monitor, ever. Nothing is hand-configured on the Pi:
a from-scratch re-flash takes ~15 minutes and loses nothing, because
everything comes from this repo.

| Script | What |
|---|---|
| `prepare-sd.sh` | inject first-boot setup onto a freshly flashed SD (run on the Mac) |
| `provision.sh` | install + configure everything on the Pi, over SSH, idempotent |
| `deploy.sh` | daily driver: rsync `synth/` to the Pi, restart, tail logs |
| `overlayfs.sh` | festival lockdown switch (read-only SD), on/off/status |
| `check.sh` | lints all scripts + exercises prepare-sd.sh against a fake bootfs |

## Runbook: card to drone

**0. Secrets.** `cp secrets.env.example secrets.env`, fill it in (wifi,
password, pubkey path). Never committed. Note: these values end up on the
SD card, so anyone holding the card can read them — don't reuse precious
passwords.

**1. Flash.** Raspberry Pi Imager → **Raspberry Pi OS (Legacy, 64-bit)
Lite** — that's Bookworm; the non-legacy Lite is Trixie and this setup
targets Bookworm. Say **NO** to the Imager's own customization ("Would you
like to apply OS customisation settings?" → No) — this repo IS the
customization.

**2. Prepare.** With the card still mounted:

    ./prepare-sd.sh /Volumes/bootfs

It refuses anything that doesn't look like a Pi 4 boot partition, writes a
generated `firstrun.sh` (hostname, user, ssh key, wifi — the same
mechanism rpi-imager uses) and hooks it into `cmdline.txt`. Then eject.

**3. First boot.** SD into the Pi, power on, and be patient: it resizes
the filesystem, runs firstrun, and reboots twice — **2–3 minutes** before
it's on wifi. Then:

    ssh chaos@chaossynth.local

If it never shows up: SD card back into the Mac and read `firstrun.log`
on the boot partition — every firstrun step is traced there.

**4. Provision.**

    ./provision.sh

Idempotent, re-run whenever. Installs SuperCollider + sc3-plugins, points
ALSA at the headphone jack, installs the always-restarting
`chaossynth.service`, arms the hardware watchdog, caps journald at 50M,
sets the timezone.

**5. Deploy.**

    ./deploy.sh

Rsyncs `../synth/` to the Pi (repo is truth — deletions propagate),
restarts the service, tails 20 log lines. You should hear the idle drone.
This is the loop during patch development: edit on the Mac, `./deploy.sh`,
listen. Expect a few seconds of silence around each deploy (it restarts
the synth).

## Audio device

The device name lives in ONE place: `AUDIO_CARD` at the top of
`provision.sh` (currently `Headphones`, the 3.5 mm jack). Swapping to a
USB DAC later = change that name (`aplay -l` on the Pi lists cards),
re-run `./provision.sh`. It lands in two spots on the Pi: `/etc/asound.conf`
(ALSA default) and `/etc/default/chaossynth`, which the service passes to
`synth/run.sh` as `$CHAOS_AUDIO_CARD`.

## Festival lockdown

The LAST step before packing, after checkpoint D:

    ./overlayfs.sh on

Root filesystem goes read-only with writes to RAM: rude power cuts can't
corrupt the SD. **Nothing persists while it's on** — `deploy.sh` knows and
refuses. To change anything later: `./overlayfs.sh off`, wait for the
reboot, deploy, `./overlayfs.sh on` again. Check with `./overlayfs.sh
status`.

## Recovery

- **Pi unreachable:** power-cycle it and the hotspot; give it 2 min.
  Fallback: ssh to the IP from the hotspot's client list.
- **Anything deeper cursed:** re-flash from scratch (steps 1–5, ~15 min,
  loses nothing). After a re-flash the host key changes:
  `ssh-keygen -R chaossynth.local` on the Mac.
- On-site operations live in [docs/installation.md](../docs/installation.md).

## Hardware checklist (Nevyn, per plan acceptance)

Agents can't flash or boot hardware; this is the human half. Run the
runbook top-to-bottom on the real Pi, then:

- [ ] idle drone within ~1 min of power-on
- [ ] `sudo reboot` → drone comes back on its own
- [ ] rude power cut (yank the plug) → drone comes back on its own
- [ ] `journalctl -u chaossynth` shows the synth's logs
- [ ] phone hotspot on → Pi appears on it (`ssh chaos@chaossynth.local`)
- [ ] `./overlayfs.sh on` → reboot → still plays; `off` again for development
- [ ] any command in docs/installation.md that behaved differently: fix the doc
