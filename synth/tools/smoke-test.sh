#!/bin/bash
# End-to-end smoke test of the synth engine on a dev Mac: boots the engine with
# short timeouts, drives it via the virtual panel, asserts on the log.
# This is THE runnable check for synth/ — if the engine logic breaks, this fails.
set -u
cd "$(dirname "$0")/.." || exit 1

LOG="$(mktemp -t chaossynth-smoke)"
FAILURES=0

check() { # check <description> <grep-pattern>
  if grep -qE "$2" "$LOG"; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (no /$2/ in $LOG)"
    FAILURES=$((FAILURES + 1))
  fi
}

tools/setup.sh || exit 1

echo "smoke: starting engine (log: $LOG)"
CHAOS_IDLE_TIMEOUT=6 CHAOS_MAX_HOLD=8 ./run.sh >"$LOG" 2>&1 &
ENGINE_PID=$!
cleanup() {
  kill "$ENGINE_PID" 2>/dev/null
  wait "$ENGINE_PID" 2>/dev/null # swallow bash's "Terminated" noise
  # run.sh execs sclang, so ENGINE_PID is sclang; its scsynth child survives
  # the kill and must go separately. Exact-name match to spare anything else.
  sleep 1
  pkill -x scsynth 2>/dev/null
}
trap cleanup EXIT

for _ in $(seq 60); do
  grep -q "CHAOSSYNTH READY" "$LOG" && break
  if ! kill -0 "$ENGINE_PID" 2>/dev/null; then break; fi
  sleep 1
done
check "engine reaches READY with no MIDI source present" "CHAOSSYNTH READY"
if [ "$FAILURES" -gt 0 ]; then
  echo "smoke: engine never came up, aborting. Log tail:"
  tail -20 "$LOG"
  exit 1
fi
if grep -q "MIDI: connected" "$LOG"; then
  echo "FAIL: engine claims a MIDI connection before the panel exists"
  FAILURES=$((FAILURES + 1))
fi

echo "smoke: running scenario (~25 s)"
tools/.venv/bin/python tools/virtual-panel.py scenario tools/smoke-scenario.json

echo "smoke: touching mapping.json for the hot-reload check"
touch mapping.json
sleep 5

check "connects when the source appears late" "MIDI: connected to 'Chaossynth'"
check "button 0 makes a voice" "VOICE: button 0 down"
DISTINCT=$(grep -oE "midinote [0-9]+" "$LOG" | sort -u | wc -l | tr -d ' ')
if [ "$DISTINCT" -ge 18 ]; then
  echo "PASS: all 18 seed buttons distinct ($DISTINCT pitches)"
else
  echo "FAIL: only $DISTINCT distinct pitches over 18 buttons"
  FAILURES=$((FAILURES + 1))
fi
check "pot 0 drives the filter" "MASTER: cutoff"
check "pot 3 drives the volume" "MASTER: volume"
check "cc 123 releases the held chord" "ALL NOTES OFF \(cc 123\): releasing 3"
check "unmapped note logs once, no crash" "UNMAPPED: note 31"
check "unmapped cc logs once, no crash" "UNMAPPED: cc 45"
check "stuck note released by max-hold safety" "SAFETY: max-hold"
check "idle timeout brings the drone in" "IDLE: .* drone fading in"
check "input ducks the drone" "IDLE: input received, drone ducking"
check "mapping.json hot-reload noticed" "MAPPING: change detected"
if [ "$(grep -c "MAPPING: loaded" "$LOG")" -ge 2 ]; then
  echo "PASS: mapping reloaded without restart"
else
  echo "FAIL: no reload after mapping.json changed"
  FAILURES=$((FAILURES + 1))
fi
if ! kill -0 "$ENGINE_PID" 2>/dev/null; then
  echo "FAIL: engine died during the test"
  FAILURES=$((FAILURES + 1))
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "smoke: ALL PASS"
else
  echo "smoke: $FAILURES FAILURE(S) — full log: $LOG"
  trap - EXIT; cleanup
  exit 1
fi
