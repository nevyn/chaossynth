#!/bin/sh
# Create tools/.venv with mido + python-rtmidi for virtual-panel.py.
# python-rtmidi needs prebuilt wheels; try pythons newest-known-good first.
set -eu
cd "$(dirname "$0")"

if [ -x .venv/bin/python ] && .venv/bin/python -c "import mido, rtmidi" 2>/dev/null; then
  echo "setup: .venv already works"
  exit 0
fi

for py in python3.13 python3.12 python3; do
  command -v "$py" >/dev/null 2>&1 || continue
  echo "setup: trying $py"
  if "$py" -m venv .venv \
    && .venv/bin/pip install --quiet mido python-rtmidi \
    && .venv/bin/python -c "import mido, rtmidi" 2>/dev/null; then
    echo "setup: OK ($py)"
    exit 0
  fi
  echo "setup: $py did not work, trying next"
done

echo "setup: FAILED — no python with working python-rtmidi wheels found" >&2
exit 1
