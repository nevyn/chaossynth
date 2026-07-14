#!/usr/bin/env bash
# rtc.sh -- integrate the DS3231 RTC HAT (Electrokit), so wall-clock
# atmospheres survive power cuts under overlayfs. Run AFTER mounting the
# HAT (with its CR1220 battery in!). Two-phase: first run enables the
# overlay and asks for a reboot; second run syncs and verifies.
#
# Usage: ./rtc.sh [user@host]   (default: chaos@chaossynth.local)
set -euo pipefail

PI="${1:-chaos@chaossynth.local}"

# shellcheck disable=SC2029
ssh "$PI" 'sudo bash -s' <<'REMOTE'
set -euo pipefail
say() { echo; echo "==> $*"; }
CONFIG=/boot/firmware/config.txt

say "i2c on + tools"
raspi-config nonint do_i2c 0
apt-get install -y i2c-tools >/dev/null

say "looking for the DS3231 at 0x68"
if ! i2cdetect -y 1 | grep -qE '(68|UU)'; then
  echo "ERROR: nothing at i2c 0x68 -- is the HAT seated? battery in?" >&2
  exit 1
fi

if ! grep -q '^dtoverlay=i2c-rtc,ds3231' "$CONFIG"; then
  say "enabling the ds3231 overlay in $CONFIG"
  echo 'dtoverlay=i2c-rtc,ds3231' >>"$CONFIG"
fi

say "installing rtc-hctosys.service (system clock <- RTC before the synth)"
cat >/etc/systemd/system/rtc-hctosys.service <<EOF
[Unit]
Description=Set system clock from the DS3231 RTC
After=multi-user.target
Before=chaossynth.service

[Service]
Type=oneshot
ExecStart=/sbin/hwclock --hctosys --utc

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable rtc-hctosys

if [ ! -e /dev/rtc0 ]; then
  say "overlay armed but /dev/rtc0 not up yet: reboot, then re-run ./rtc.sh"
  exit 0
fi

say "writing system time -> RTC (make sure the Pi's clock is right NOW)"
if [ "$(timedatectl show -p NTPSynchronized --value)" != "yes" ]; then
  echo "WARNING: system clock is NOT NTP-synced; the RTC gets whatever 'date' says:" >&2
  date >&2
fi
hwclock --systohc --utc

say "verify: RTC vs system clock"
hwclock -r
date
say "RTC OK -- power cuts can no longer rewind the atmospheres"
REMOTE
