# Plan: pi image

Reproducible, headless Raspberry Pi 4 setup: flash a stock image, run two
scripts, end with the synth auto-starting on boot. No keyboard/monitor ever
attached; no incremental hand-state on the Pi — everything re-runnable from this
repo (IaC).

## Context

- Pi 4, Raspberry Pi OS Lite 64-bit (Bookworm). Audio: the 3.5 mm headphone jack
  via ALSA — keep the device name in ONE configurable place, a USB DAC may
  replace it later.
- Nevyn runs these scripts; agents can't test on hardware. Compensate with
  defensive scripts (`set -euo pipefail`, idempotent steps, loud echo of every
  action) and a precise runbook.
- macOS can only mount the FAT boot partition — everything ext4 happens over SSH
  after first boot.

## Deliverables

1. **secrets.env.example** (committed; real secrets.env is gitignored, scripts
   fail loudly when it's missing): wifi networks (home + phone hotspot), user
   password, SSH pubkey path. Already scaffolded — extend as needed.
2. **prepare-sd.sh** (macOS): run after flashing stock Pi OS Lite with Raspberry
   Pi Imager (Imager's own customization OFF — this repo is the customization).
   Takes the mounted bootfs volume path; injects: ssh enable, user `chaos`
   (hashed password), hostname `chaossynth`, wifi country SE + NetworkManager
   connections for every network in secrets.env, authorized_keys. Crib the
   firstrun.sh mechanism rpi-imager itself generates (cmdline.txt systemd.run) —
   it's the documented Bookworm pattern. The script must refuse a volume that
   doesn't look like a Pi bootfs, and must only ever write to that mounted
   volume — flashing itself stays in the Imager.
3. **provision.sh** (run from the Mac, executes over SSH, idempotent):
   apt install supercollider + sc3-plugins; force audio to the headphone jack;
   install + enable `chaossynth.service` (User=chaos,
   ExecStart=/home/chaos/chaossynth/synth/run.sh, Restart=always, RestartSec=3,
   After=sound.target); hardware watchdog on; journald capped
   (SystemMaxUse=50M); timezone Europe/Stockholm.
4. **deploy.sh**: rsync ../synth/ to the Pi, restart the service, tail 20 log
   lines. This is the daily driver during patch development.
5. **overlayfs.sh on|off**: wraps raspi-config's overlay-filesystem toggle. OFF
   by default; ON is the LAST step before the festival.
6. **pi-image/README.md** — the runbook: flash → prepare → first boot (patience:
   2–3 min) → `ssh chaos@chaossynth.local` → provision → deploy → hear the idle
   drone. Plus recovery: a from-scratch re-flash takes ~15 min and loses nothing,
   because everything is in the repo.

## Acceptance

- All scripts shellcheck-clean.
- Sanity guards demonstrated (prepare-sd.sh refuses a non-bootfs path; scripts
  refuse to run without secrets.env).
- Nevyn executes the runbook top-to-bottom on the real Pi; the service survives
  `sudo reboot` and a rude power-cycle. Update docs/installation.md if any
  command there turned out different.

## Guardrails

- NEVER run dd / diskutil eraseDisk / mkfs — not in the session, not in the
  scripts. The Imager flashes; the scripts only touch a mounted volume or SSH.
- Secrets only in secrets.env; never commit it, never echo its values into logs.
- Work only in pi-image/ (+ this doc + installation.md TBDs you can now fill).
