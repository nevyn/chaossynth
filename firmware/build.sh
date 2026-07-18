#!/usr/bin/env bash
# Build the chaossynth firmware for the Waveshare RP2350-Zero.
#
#   ./build.sh          compile (the agent-verifiable gate; runs the host check too)
#   ./build.sh --flash  compile + upload over USB (needs the board attached;
#                       if upload fails, replug while holding BOOTSEL and retry)
#
# The core and libraries are version-pinned and installed under firmware/.arduino/
# so this never touches a global Arduino setup, and rebuilds work offline once
# the toolchain is primed (matters in a field with no wifi).
set -euo pipefail
cd "$(dirname "$0")"

CORE="rp2040:rp2040"
CORE_VERSION="5.6.1"
FQBN="rp2040:rp2040:waveshare_rp2350_zero:usbstack=tinyusb"
LIBS=(
  "Adafruit TinyUSB Library@3.7.7"
  "MIDI Library@5.0.2"
  "Adafruit MCP23017 Arduino Library@2.3.2"
)
PICO_INDEX="https://github.com/earlephilhower/arduino-pico/releases/download/global/package_rp2040_index.json"

export ARDUINO_DIRECTORIES_DATA="$PWD/.arduino/data"
export ARDUINO_DIRECTORIES_DOWNLOADS="$PWD/.arduino/downloads"
export ARDUINO_DIRECTORIES_USER="$PWD/.arduino/user"
export ARDUINO_BOARD_MANAGER_ADDITIONAL_URLS="$PICO_INDEX"

if ! command -v arduino-cli >/dev/null 2>&1; then
  echo "error: arduino-cli not found. Install it first: brew install arduino-cli" >&2
  exit 1
fi

# Install the pinned core/libraries only when missing, so routine builds stay
# offline-safe and fast.
if ! arduino-cli core list 2>/dev/null | grep -Eq "^$CORE[[:space:]]+$CORE_VERSION"; then
  echo "== installing core $CORE@$CORE_VERSION (one-time, big download)"
  arduino-cli core update-index
  arduino-cli core install "$CORE@$CORE_VERSION"
fi

installed_libs="$(arduino-cli lib list 2>/dev/null || true)"
for lib in "${LIBS[@]}"; do
  name="${lib%@*}"
  version="${lib#*@}"
  if ! grep -F "$name" <<<"$installed_libs" | grep -qF " $version "; then
    echo "== installing library $lib"
    arduino-cli lib update-index
    arduino-cli lib install "$lib"
  fi
done

echo "== host check: pot filter"
mkdir -p .arduino
c++ -std=c++17 -Wall -Werror -o .arduino/pot_filter_test test/pot_filter_test.cpp
./.arduino/pot_filter_test

OUT="$PWD/.arduino/build-out"
echo "== compiling for $FQBN"
arduino-cli compile --fqbn "$FQBN" --output-dir "$OUT" chaossynth

if [[ "${1:-}" == "--flash" ]]; then
  # Most reliable path: a board in BOOTSEL mode mounts as a USB drive — copy the
  # UF2 straight onto it. Covers a brand-new/wedged board and the field spare.
  bootsel=""
  for v in /Volumes/RP2350 /Volumes/RPI-RP2 /Volumes/RP2040; do
    [[ -d "$v" ]] && bootsel="$v" && break
  done
  if [[ -n "$bootsel" ]]; then
    echo "== board in BOOTSEL mode ($bootsel) -- copying UF2"
    cp "$OUT/chaossynth.ino.uf2" "$bootsel/"
    echo "== done; the board reboots into the new firmware"
  else
    # Board running a sketch: find its USB serial port. arduino-cli does the
    # 1200bps-touch reset into BOOTSEL and flashes. Override with PORT=/dev/...
    port="${PORT:-}"
    if [[ -z "$port" ]]; then
      n=$(ls /dev/cu.usbmodem* 2>/dev/null | wc -l | tr -d ' ')
      if [[ "$n" == "0" ]]; then
        echo "error: no board found on a USB serial port." >&2
        echo "  Put it in BOOTSEL mode (hold BOOT, tap RESET, or hold BOOT while" >&2
        echo "  plugging in USB) so it mounts as a drive, then re-run --flash." >&2
        exit 1
      fi
      port=$(ls /dev/cu.usbmodem* 2>/dev/null | head -n1)
      [[ "$n" != "1" ]] && echo "note: $n usbmodem ports found; using $port (set PORT=... to pick another)"
    fi
    echo "== uploading to $port"
    arduino-cli upload -p "$port" --input-dir "$OUT" --fqbn "$FQBN" chaossynth
  fi
fi
