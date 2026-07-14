#!/usr/bin/env bash
# deploy.sh -- the daily driver: rsync synth/ to the Pi, restart the synth,
# show the first log lines. The repo is the source of truth: files deleted
# here get deleted on the Pi too (--delete).
#
# Usage: ./deploy.sh [--ephemeral] [user@host]   (default: chaos@chaossynth.local)
#
# --ephemeral pushes ONLY mapping.json, without a restart: the engine
# hot-reloads it in ~2 s, sound uninterrupted. Works with overlayfs ON
# (writes land in RAM and revert on reboot) -- ideal for on-site remap
# experiments; a power cycle returns to the known-good mapping.
set -euo pipefail

EPHEMERAL=0
if [ "${1:-}" = "--ephemeral" ]; then EPHEMERAL=1; shift; fi
PI="${1:-chaos@chaossynth.local}"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

if [ "$EPHEMERAL" = 1 ]; then
  echo "==> ephemeral: mapping.json only, no restart (reverts on reboot if overlayfs is ON)"
  rsync -a "$SCRIPT_DIR/../synth/mapping.json" "$PI:chaossynth/synth/mapping.json"
  sleep 3
  ssh "$PI" 'journalctl -u chaossynth -n 3 --no-pager'
  echo "==> look for 'MAPPING: loaded' above; make it permanent later with a full deploy."
  exit 0
fi

# Refuse to deploy into a black hole: with overlayfs ON the rsync would
# land in RAM and silently vanish on reboot.
if [ "$(ssh "$PI" 'findmnt -n -o FSTYPE /')" = "overlay" ]; then
  echo "ERROR: overlayfs is ON -- this full deploy would vanish on reboot." >&2
  echo "Run ./overlayfs.sh off, wait for the reboot, then deploy." >&2
  echo "(Just remapping? ./deploy.sh --ephemeral works under overlayfs.)" >&2
  exit 1
fi

echo "==> rsync synth/ -> $PI:chaossynth/synth/"
rsync -a --delete --exclude=.venv --exclude=.DS_Store \
  "$SCRIPT_DIR/../synth/" "$PI:chaossynth/synth/"

echo "==> restarting chaossynth"
ssh "$PI" 'sudo systemctl restart chaossynth; sleep 2; sudo journalctl -u chaossynth -n 20 --no-pager'
