#!/usr/bin/env bash
# overlayfs.sh -- the festival lockdown switch, wrapping raspi-config's
# overlay-filesystem toggle over SSH.
#
#   ON  = root filesystem read-only, all writes go to RAM: rude power cuts
#         cannot corrupt the SD, and NOTHING persists (deploys, logs).
#         The LAST step before packing.
#   OFF = back to normal, deploys stick again.
#
# Each toggle reboots the Pi; verify with `status` afterwards.
#
# Usage: ./overlayfs.sh on|off|status [user@host]
set -euo pipefail

MODE="${1:-status}"
PI="${2:-chaos@chaossynth.local}"

root_is_overlay() {
  [ "$(ssh "$PI" 'findmnt -n -o FSTYPE /')" = "overlay" ]
}

case "$MODE" in
  status)
    if root_is_overlay; then
      echo "overlay ON: root is read-only, writes go to RAM, nothing persists"
    else
      echo "overlay OFF: normal read-write root, deploys persist"
    fi
    echo "boot partition options: $(ssh "$PI" 'findmnt -n -o OPTIONS /boot/firmware')"
    ;;
  on)
    if root_is_overlay; then
      echo "overlay already ON -- nothing to do"
      exit 0
    fi
    echo "==> enabling overlayfs + write-protecting the boot partition"
    echo "    (rebuilds the initramfs -- takes a minute or two)"
    ssh "$PI" 'sudo raspi-config nonint enable_overlayfs && sudo raspi-config nonint enable_bootro'
    echo "==> rebooting to apply"
    ssh "$PI" 'sudo reboot' || true
    echo "Wait ~1 min, then verify:  $0 status"
    ;;
  off)
    if ! root_is_overlay; then
      echo "overlay already OFF -- nothing to do"
      exit 0
    fi
    # cmdline.txt lives on the FAT boot partition, which is NOT under the
    # overlay -- that's why disabling from inside the overlay works. The
    # boot partition stays write-protected (harmless; remounted on demand).
    echo "==> disabling overlayfs"
    ssh "$PI" 'sudo mount -o remount,rw /boot/firmware && sudo raspi-config nonint disable_overlayfs'
    echo "==> rebooting to apply"
    ssh "$PI" 'sudo reboot' || true
    echo "Wait ~1 min, then verify:  $0 status   (root must NOT be overlay before deploying)"
    ;;
  *)
    echo "usage: $0 on|off|status [user@host]" >&2
    exit 1
    ;;
esac
