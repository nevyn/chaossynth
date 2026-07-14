// The one runnable check for the pot logic: fails if a resting pot can chatter
// or a full sweep can't reach both rails. Run by build.sh, or by hand:
//   c++ -std=c++17 -o /tmp/pft test/pot_filter_test.cpp && /tmp/pft
#include "../chaossynth/pot_filter.h"

#include <cstdio>

static int fails = 0;
#define CHECK(cond, msg)                                                       \
  do {                                                                         \
    if (!(cond)) {                                                             \
      std::printf("FAIL: %s\n", msg);                                          \
      fails++;                                                                 \
    }                                                                          \
  } while (0)

int main() {
  // A pot parked exactly on the 7-bit boundary at 2048, with +-4 counts of ADC
  // jitter, must stay silent forever.
  {
    PotFilter f;
    f.update(2048);
    int sends = 0;
    for (int i = 0; i < 20000; i++) {
      uint16_t raw = 2048 + (i * 7 % 9) - 4;  // deterministic jitter -4..+4
      if (f.update(raw) >= 0) sends++;
    }
    CHECK(sends == 0, "resting pot on a boundary emitted CCs");
  }

  // A slow full sweep up must reach 127, monotonically; back down must reach 0.
  {
    PotFilter f;
    f.update(0);
    int last = 0;
    bool monotonic = true;
    for (int raw = 0; raw <= 4095; raw += 4) {
      int v = f.update(raw);
      if (v >= 0) {
        if (v < last) monotonic = false;
        last = v;
      }
    }
    for (int i = 0; i < 100; i++) {  // let the EMA settle at the rail
      int v = f.update(4095);
      if (v >= 0) last = v;
    }
    CHECK(last == 127, "up-sweep never reached 127");
    CHECK(monotonic, "up-sweep was not monotonic");

    for (int raw = 4095; raw >= 0; raw -= 4) {
      int v = f.update(raw);
      if (v >= 0) last = v;
    }
    for (int i = 0; i < 100; i++) {
      int v = f.update(0);
      if (v >= 0) last = v;
    }
    CHECK(last == 0, "down-sweep never reached 0");
  }

  // A small deliberate move (well past the deadband) must produce output.
  {
    PotFilter f;
    f.update(1000);
    int sends = 0;
    for (int i = 0; i < 50; i++) {
      if (f.update(1200) >= 0) sends++;
    }
    CHECK(sends >= 1, "deliberate move produced no CC");
  }

  if (fails == 0) std::printf("pot_filter: all checks passed\n");
  return fails == 0 ? 0 : 1;
}
