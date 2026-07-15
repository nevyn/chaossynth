#!/bin/sh
# Start the Chaossynth engine. Same entry point on the dev Mac and the Pi.
# CHAOS_PLATFORM=pi|mac overrides autodetection; see README.md for other env knobs.
set -eu
cd "$(dirname "$0")"

PLATFORM="${CHAOS_PLATFORM:-}"
if [ -z "$PLATFORM" ]; then
  case "$(uname)" in
    Darwin) PLATFORM=mac ;;
    *)      PLATFORM=pi ;;
  esac
fi
export CHAOS_PLATFORM="$PLATFORM"

SCLANG=""
if command -v sclang >/dev/null 2>&1; then
  SCLANG=sclang
else
  for candidate in \
    /Applications/SuperCollider.app/Contents/MacOS/sclang \
    "$HOME/Applications/SuperCollider.app/Contents/MacOS/sclang"; do
    if [ -x "$candidate" ]; then
      SCLANG="$candidate"
      break
    fi
  done
fi
if [ -z "$SCLANG" ]; then
  echo "ERROR: sclang not found. Mac: brew install supercollider. Pi: apt install supercollider-language supercollider-server." >&2
  exit 1
fi

if [ "$PLATFORM" = "pi" ]; then
  # Headless armor (also set in /etc/default/chaossynth; kept here so a bare
  # `./run.sh` over SSH works too): Qt-built sclang needs offscreen rendering,
  # and jackd2's dbus device-reservation has no session bus under a service.
  export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"
  export JACK_NO_AUDIO_RESERVATION="${JACK_NO_AUDIO_RESERVATION:-1}"
  # scsynth on Linux speaks JACK only. Run jackd on the headphone jack unless
  # something (systemd, a previous run) already started it. -P: playback-only,
  # the jack has no capture side.
  # plughw, NOT hw: jackd's direct hw: access mangles bcm2835 audio into
  # click-storm noise (heard 07-15 on real hardware; a bare jack_metro
  # reproduced it, plughw fixed it). aplay-clean does not mean hw:-clean.
  ALSA_DEV="${CHAOS_ALSA_DEV:-plughw:Headphones}"
  if ! pgrep -x jackd >/dev/null 2>&1; then
    echo "chaossynth: starting jackd on $ALSA_DEV"
    jackd -d alsa -d "$ALSA_DEV" -P -r 48000 -p 1024 -n 3 &
    sleep 2
    if ! pgrep -x jackd >/dev/null 2>&1; then
      echo "ERROR: jackd failed to start on $ALSA_DEV (is the device name right? try 'aplay -l')" >&2
      exit 1
    fi
  fi
fi

echo "chaossynth: platform=$PLATFORM sclang=$SCLANG"
exec "$SCLANG" main.scd
