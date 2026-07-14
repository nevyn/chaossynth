#!/usr/bin/env bash
# deploy.sh -- the daily driver: rsync synth/ to the Pi, restart the synth,
# show the first log lines. The repo is the source of truth: files deleted
# here get deleted on the Pi too (--delete).
#
# Usage: ./deploy.sh [user@host]   (default: chaos@chaossynth.local)
set -euo pipefail

PI="${1:-chaos@chaossynth.local}"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Refuse to deploy into a black hole: with overlayfs ON the rsync would
# land in RAM and silently vanish on reboot.
if [ "$(ssh "$PI" 'findmnt -n -o FSTYPE /')" = "overlay" ]; then
  echo "ERROR: overlayfs is ON -- this deploy would vanish on reboot." >&2
  echo "Run ./overlayfs.sh off, wait for the reboot, then deploy." >&2
  exit 1
fi

echo "==> rsync synth/ -> $PI:chaossynth/synth/"
rsync -a --delete --exclude=.venv --exclude=.DS_Store \
  "$SCRIPT_DIR/../synth/" "$PI:chaossynth/synth/"

echo "==> restarting chaossynth"
ssh "$PI" 'sudo systemctl restart chaossynth; sleep 2; sudo journalctl -u chaossynth -n 20 --no-pager'
