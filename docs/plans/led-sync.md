# Plan: LED sync (bonus — build only after the patch's clock exists)

Very-likely bonus, planned 07-14: three signal pins from the Pi to shinycore
switch LED patterns in time with the music. Do NOT start this until the sound
build (docs/plans/patch-design.md) has its global clock and energy axis
working — this rides on both.

## Pin protocol (the contract with shinycore)

Three GPIOs + shared GND, 3.3 V logic, **one-hot**: exactly one pin high at
any time. shinycore debounces ~20 ms and latches on change; if none or
several are high (boot, rewiring), it keeps the last valid pattern.

| Pi GPIO (proposal) | Pattern | Meaning |
|---|---|---|
| 17 | 0 | idle / drone |
| 27 | 1 | active |
| 22 | 2 | active alternate |

(17/27/22 are free of I2C and other duties; final pick when the RTC HAT's
header situation is known.)

While active, the engine alternates 1 <-> 2 on the global clock: every Nth
beat, default N=4, overridable per atmosphere. **Flicker floor: never
alternate faster than ~1 s** — every-beat at Night's 170 BPM would be a
~2.8 Hz strobe (photosensitivity + plain exhausting).

## Engine hook (synth/lib/led.scd)

- `~chaosLed.(n)` — sets the pattern, idempotent, logs `LED: pattern N`.
- Pi: `"gpioset ..."​.unixCmd` (async, never blocks audio). User `chaos` needs
  the `gpio` group (one provision.sh line — add it in this build). On BCM
  chips gpioset values persist after the process exits; verify on hardware.
- Mac / gpioset missing: log-only. The feature is then fully testable by log.
- Wire-up: state machine calls pattern 0 on idle, 1 on active (use the energy
  axis, not raw touch, so a single button poke doesn't flap the lights);
  the beat clock alternates 1/2 while active.

## Hardware + shinycore side (Nevyn/Gustav, outside this repo)

- 3 signal wires + GND, panel-labeled, strain-relieved.
- The RTC HAT occupies the 40-pin header: needs a stacking header or solder
  taps off the HAT's through-holes. Resolve when the HAT arrives.
- Confirm shinycore inputs are 3.3 V-tolerant and add the 3-pin read +
  debounce + pattern switch to its firmware. Pattern 0 should double as its
  power-on default so the lights are sane before the Pi is up.

## Acceptance

- Mac, log-only: engine boots -> `LED: pattern 0`; virtual-panel press ->
  `LED: pattern 1`; while the beat runs, `LED: pattern 2`/`1` alternate at
  the configured cadence; idle timeout -> `LED: pattern 0`. Extend
  smoke-test.sh with these (they're platform-independent).
- Pi: multimeter or a bare LED on the pins (gpioget would reconfigure the
  pin to input — don't use it to verify), then the real shinycore.

## Guardrails

- Work in synth/ + this doc only; provision.sh only for the gpio group line.
- No destructive commands. Sound build outranks this — if time gets tight,
  the panel makes music and the LEDs do their own thing (shinycore's
  standalone patterns are the fallback, and they're already good).
