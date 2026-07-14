# Integration audit — 2026-07-14

Four read-only auditors swept the parallel build (code + each builder session's
transcript) for contract violations and cross-workstream drift. Overall: the
seams held — one real runtime blocker, two doc blockers, a handful of cheap
hardening wins. Fix items are routed by owner below; check them off as they land.

| Seam | Verdict |
|---|---|
| firmware vs contract, build.sh, layout-tool header parity | GREEN (parity proven by compiling both headers side-by-side with static_asserts) |
| synth engine vs contract, test harness, verification evidence | GREEN |
| synth on the Pi (runnability) | YELLOW — Qt blocker below |
| pi-image scripts (safety, correctness, docs agreement) | GREEN |
| cross-doc coherence | 2 blockers, several warns |

## Blockers

- [x] **B1 — headless sclang will likely crash-loop on the Pi.** Debian's sclang
  is Qt-built; nothing sets `QT_QPA_PLATFORM=offscreen`. Under systemd on a
  monitor-less Lite image, Qt's platform init typically aborts sclang →
  `Restart=always` loop → silent Pi. Fix: one line in the env file provision.sh
  writes (`/etc/default/chaossynth`), or exported in run.sh's pi branch.
  *(Owner: pi-image files, orchestrator can apply.)*
- [x] **B2 — master-volume doc contradiction.** patch-design.md (authoritative,
  Nevyn's explicit decision) says volume is NOT a panel control and the pot-3
  placeholder gets evicted; synth/README.md ("The one true volume knob") and
  installation.md's Volume row still document panel P3 as master volume. The
  field doc would send an operator hunting for a knob that won't exist.
  *(Docs: orchestrator. Engine eviction + smoke-test update: patch session,
  already in its brief.)*
- [x] **B3 — "remap live, no reflash" vs the overlayfs double-reboot.** README.md
  and plans/synth-engine.md promise hot-reload at the burn; installation.md's
  honest procedure is off→deploy→on (two reboots). Resolution: fix the promise
  language, AND add an ephemeral path — with overlayfs ON, writes land in RAM,
  so `deploy.sh --ephemeral` could rsync just mapping.json to the live system
  (hot-reloads in ~2 s, reverts to known-good on reboot — arguably the ideal
  on-site experiment mode). Today deploy.sh hard-refuses under overlayfs.
  *(Owner: pi-image + doc language, orchestrator can apply.)*

## For the patch/sound session (owns synth/)

- [x] Evict pot-3 volume placeholder per patch-design (retune smoke-test's
  "pot 3 drives the volume" check to pot 3's real role).
- [x] `synth/tools/smoke-test.sh:31` — cleanup `pkill -x scsynth` kills ANY
  scsynth on the machine, including a sibling session's. Scope it to its own
  child (process group / `pgrep -P`).
- [x] Never-boots wedge: if `s.waitForBoot` gives up, sclang idles forever
  without `CHAOSSYNTH READY` and systemd never restarts it. Add a boot timeout
  → exit 1.
- [x] Drone-on-boot: engine waits `CHAOS_IDLE_TIMEOUT` (90 s) after start before
  any drone, so real power-to-sound is ~2¼ min while installation.md promises
  ~1 min. Recommended: boot straight into idle state (nobody has touched it =
  idle by definition), which also fixes the docs for free.
- [x] patch-design.md: one sentence defining how special buttons
  (cc_momentary/cc_toggle, CC 40+) bind to roles — the pinned schema only
  covers note-buttons and pots. (Engine currently parks specials in a SPECIAL
  branch, unreferenced.)
- [x] Sample spec drift: amen bank is 20 stereo WAVs; patch-design says mono.
  Make the loader accept stereo or amend the doc.
- [ ] Wall-clock atmospheres vs reality: Pi 4 has no RTC, no field NTP, and
  overlayfs discards fake-hwclock saves — after a power cut the clock rewinds,
  and Night-mode breakcore could play at 07:00. Needs a clock-implausibility
  fallback to a safe atmosphere in the engine (plus see Nevyn items).
  *(Requirement pinned in patch-design.md 07-14; implement with atmospheres.)*

## pi-image hardening (session closed — orchestrator can apply)

- [x] jackd under systemd: add `JACK_NO_AUDIO_RESERVATION=1`, playback-only
  `-P`, and `LimitRTPRIO=95` + `LimitMEMLOCK=infinity` to chaossynth.service
  (RT scheduling is otherwise denied to services; xrun risk).
- [x] Add `overlayroot` to provision's apt line — Bookworm installs it lazily on
  first `overlayfs.sh on`, which would otherwise need working internet at
  lockdown time.
- [x] prepare-sd.sh: comment/fallback for stock-macOS LibreSSL lacking
  `openssl passwd -6` (works on this Mac via Homebrew; fails loudly elsewhere).

## Needs Nevyn

- [x] **Contract amendments (frozen doc, your sign-off):** CC 123 is sent on
  every USB mount, not "once at boot" (deliberate, safer, already in
  firmware/README); and the `synth{}` pointer's "pins its schema later" tense —
  patch-design.md pins it now.
- [x] **Clock integrity decision:** Electrokit DS3231 HAT picked 07-14
  (ordering; 1 in stock + needs a CR1220). `pi-image/rtc.sh` is ready for
  when it lands; the engine fallback stays in patch-design as shipping
  insurance.
- [x] **git-lfs for samples** — decided 07-14: no LFS; keep banks small, no
  more big binary batches without revisiting (noted in patch-design.md).
- [ ] **construction-plan.md** (you own it): fold in patch-design's "Informs the
  button build" list — all 8 pots (not "8 max"), piano row 5–6, two arcade
  hold-able FX buttons, one BIG bass button, 3–4-button chop cluster, optional
  mode rotary, phone-hook + USB audio dongle if the telephone happens.
- [ ] Bench items honestly parked by builders: layout-tool real-Chrome
  round-trip + WebMIDI simulate; firmware + pi hardware checklists
  (firmware/README.md, pi-image/README.md).

## Nits (batch whenever)

- pot_filter.h comment overclaims deadband bound (≤25 is the real limit, 24
  chosen — safe, 1 count of margin; host test guards it).
- Each pot emits one baseline CC on mount (intentional, synth gets a starting
  value; contract's table doesn't mention it).
- Layout tool: first clean save produces a one-time cosmetic mapping.h diff
  (`#pragma once`, comment placement — README warns); clearing the expanders
  field is a validation dead-end, not a data risk.
- provision installs the fat `supercollider` metapackage (pulls the IDE + Qt on
  a headless box) — but that fat install is also what guarantees the Qt libs
  for the B1 fix; leave it.
- overlayfs.sh re-runs append a redundant `,ro` to fstab per cycle (raspi-config
  quirk, harmless). prepare-sd installs only the first pubkey line; raw 64-hex
  PSKs are rejected by the 8–63 rule.
- smoke coverage gaps: version-refusal and yank/reconnect are implemented but
  untested; hot-reload tested via touch, not content change.

## What correlated cleanly

Every seam identity checked out end-to-end: "Chaossynth" naming (firmware
descriptor → midi.scd → virtual-panel → aconnect docs), note/CC ranges,
mapping.json seed vs firmware tables vs layout-tool generator (compile-proven),
`CHAOS_ALSA_DEV` env dialect across provision/service/run.sh, service paths in
all docs, deploy excludes, overlayfs semantics verified against raspi-config
source, wifi priority (hotspot wins), Bookworm firstrun mechanism verified
against raspberrypi-sys-mods source. Transcript sweeps found the builders
honest: deviations were disclosed and documented, no silent verification
claims — the one pipe-through-tail exit-code sin was re-verified by the auditor
(build.sh does exit 0).
