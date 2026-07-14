# Plan: LED sync (PARKED — stretch goal)

Not part of v1. Do not build until everything else in docs/plan-v1.md ships.

The idea, preserved so it isn't lost: shinycore (our LED controller, running the
panel's RGB strips independently) can switch presets via a control signal on a
pin. The Pi knows the musical state. Wire one or two Pi GPIOs to shinycore's
control input and:

- switch idle ↔ active presets in time with the engine's state machine, and/or
- if fancy: a PWM signal proportional to musical intensity, for shinycore to map
  onto animation speed.

Total scope if built: a tiny gpio hook in the synth engine (or a python sidecar)
toggling pins on state changes, two shinycore presets, one wiring line in
docs/construction-plan.md.

Prerequisite question for Gustav/Madde: which shinycore build is on the panel,
and what does its control-pin protocol accept?
