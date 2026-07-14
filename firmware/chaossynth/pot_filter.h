// Pot conditioning: EMA smoothing plus a 12-bit deadband, so a pot at rest never
// emits CCs (even parked exactly on a 7-bit boundary) while a full sweep still
// reaches both 0 and 127. No Arduino dependencies on purpose: the runnable check
// is firmware/test/pot_filter_test.cpp, run by build.sh on the host.
#pragma once
#include <stdint.h>

struct PotFilter {
  // 12-bit counts. Must stay below 32 (one 7-bit step): the integer EMA settles
  // at >=4088 at the top rail and 0 at the bottom, so any deadband < 32 provably
  // still reaches 0 and 127. 24 is comfortably above ADC noise after smoothing.
  static constexpr uint16_t DEADBAND = 24;

  uint16_t smoothed = 0;
  uint16_t lastSentRaw = 0;
  uint8_t lastSent7 = 0;
  bool primed = false;

  // Feed one 12-bit ADC reading. Returns -1 for "nothing to send", else the
  // 7-bit CC value. The first reading seeds the EMA and is always sent, so the
  // synth gets one baseline CC per pot instead of a ramp-from-zero sweep.
  int update(uint16_t raw) {
    if (!primed) {
      smoothed = raw;
      lastSentRaw = raw;
      lastSent7 = raw >> 5;
      primed = true;
      return lastSent7;
    }
    smoothed = (smoothed * 7 + raw) / 8;  // EMA, alpha = 1/8
    uint16_t delta = smoothed > lastSentRaw ? smoothed - lastSentRaw
                                            : lastSentRaw - smoothed;
    uint8_t value7 = smoothed >> 5;
    if (delta < DEADBAND || value7 == lastSent7) return -1;
    lastSentRaw = smoothed;
    lastSent7 = value7;
    return value7;
  }
};
