#!/usr/bin/env bash
# provision.sh -- turn a freshly booted Pi into the chaossynth appliance,
# over SSH, idempotently: SuperCollider, audio to the headphone jack, the
# chaossynth systemd service, hardware watchdog, capped journal, timezone.
# Safe to re-run any time; every step converges to the same state.
#
# Usage: ./provision.sh [user@host]   (default: chaos@chaossynth.local)
set -euo pipefail

PI="${1:-chaos@chaossynth.local}"
PI_USER="${PI%%@*}"

# THE one place the audio device lives. A USB DAC later: change this,
# re-run provision. (Card name from `aplay -l` on the Pi.)
AUDIO_CARD=Headphones
TIMEZONE=Europe/Stockholm

echo "==> checking SSH + passwordless sudo on $PI"
ssh -o ConnectTimeout=10 "$PI" 'sudo -n true' || {
  echo "ERROR: cannot reach $PI, or sudo wants a password there." >&2
  echo "First boot takes 2-3 min; see README.md if this persists." >&2
  exit 1
}

# shellcheck disable=SC2029  # client-side expansion of the args is intended
ssh "$PI" "sudo bash -s -- '$AUDIO_CARD' '$TIMEZONE' '$PI_USER'" <<'REMOTE'
set -euo pipefail
AUDIO_CARD="$1"
TIMEZONE="$2"
RUN_USER="$3"
say() { echo; echo "==> $*"; }

say "apt: supercollider + plugins (first run downloads a lot; be patient)"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y supercollider sc3-plugins rsync alsa-utils

say "audio: default ALSA card -> $AUDIO_CARD"
cat >/etc/asound.conf <<EOF
defaults.pcm.card $AUDIO_CARD
defaults.ctl.card $AUDIO_CARD
EOF

say "audio: card name for the synth (read by run.sh via the service env)"
cat >/etc/default/chaossynth <<EOF
# Written by pi-image/provision.sh. The one knob for the output device.
CHAOS_AUDIO_CARD=$AUDIO_CARD
EOF

say "audio: unmute, full volume (the speaker's own knob sets loudness)"
amixer -c "$AUDIO_CARD" sset PCM 100% unmute \
  || amixer -c "$AUDIO_CARD" sset Headphone 100% unmute \
  || echo "WARNING: no PCM/Headphone control on card $AUDIO_CARD -- check 'aplay -l' and 'amixer -c $AUDIO_CARD'"

say "user $RUN_USER in the audio group"
usermod -aG audio "$RUN_USER"

say "synth dir + chaossynth.service"
install -d -o "$RUN_USER" -g "$RUN_USER" "/home/$RUN_USER/chaossynth/synth"
cat >/etc/systemd/system/chaossynth.service <<EOF
[Unit]
Description=Chaossynth SuperCollider engine
After=sound.target
# Unattended installation: keep restarting forever, never give up.
StartLimitIntervalSec=0

[Service]
User=$RUN_USER
WorkingDirectory=/home/$RUN_USER/chaossynth/synth
EnvironmentFile=-/etc/default/chaossynth
ExecStart=/home/$RUN_USER/chaossynth/synth/run.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable chaossynth

say "hardware watchdog: a hung kernel/systemd reboots the Pi in ~15 s"
install -d /etc/systemd/system.conf.d
cat >/etc/systemd/system.conf.d/10-chaossynth-watchdog.conf <<EOF
[Manager]
RuntimeWatchdogSec=15
RebootWatchdogSec=2min
EOF
systemctl daemon-reexec

say "journald capped at 50M (a week of logs must not fill the card)"
install -d /etc/systemd/journald.conf.d
cat >/etc/systemd/journald.conf.d/10-chaossynth.conf <<EOF
[Journal]
SystemMaxUse=50M
EOF
systemctl restart systemd-journald

say "timezone $TIMEZONE"
timedatectl set-timezone "$TIMEZONE"

say "PROVISION OK -- next: ./deploy.sh (the service is enabled but has nothing to run yet)"
REMOTE
