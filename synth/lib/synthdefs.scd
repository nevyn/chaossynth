// SynthDefs: the settled atmosphere drones (auditioned by ear 07-15, see
// docs/plans/patch-design.md) + the interactive voices (\chaosKeys is still a
// placeholder — the main-instrument build iterates it next). Everything routes
// through \chaosMaster.
(
~chaosDefineSynths = { |s|

	// Per-button voice: soft keys/pluck. Gated so NoteOff (or the safety
	// release) always works; frees itself when the release tail ends.
	SynthDef(\chaosKeys, { |out = 0, freq = 220, amp = 0.25, gate = 1, pan = 0|
		var env = EnvGen.kr(Env.adsr(0.003, 0.35, 0.4, 1.2), gate, doneAction: 2);
		var strike = EnvGen.kr(Env.perc(0.001, 0.25));
		var tone = SinOsc.ar(freq)
			+ (LFTri.ar(freq * 1.002) * 0.4)
			+ (SinOsc.ar(freq * 2) * 0.2 * strike);
		var sig = LPF.ar(tone, (freq * 6).clip(400, 9000));
		Out.ar(out, Pan2.ar(sig * env * amp, pan));
	}).add;

	// The idle drones. Shared protocol: targetAmp/fadeTime (VarLag) so the
	// engine can duck and raise them any number of times; \notes (5 midinotes)
	// is the current chord from the harmonic brain. No doneAction — the engine
	// frees the old drone after an atmosphere crossfade.

	// Day (09-17): tape-warble saw blooms + rare high twinkles. Each voice
	// re-pitches only while silent (bloom near zero), so chord drift arrives
	// as reborn notes — a pause, then the new key — never a bend.
	SynthDef(\chaosPadDay, { |out = 0, targetAmp = 0, fadeTime = 10|
		var amp = VarLag.kr(targetAmp, fadeTime) * 0.24;
		var notes = \notes.kr([45, 52, 57, 60, 64]);
		var wow = 1 + (LFNoise2.kr(0.4) * 0.006);   // shared: the whole tape wobbles
		var flutter = 1 + (LFNoise2.kr(7) * 0.0012);
		var twinkTrig = Dust.kr(0.12);               // a sparkle every ~8 s
		var twinkNote = Select.kr(TIRand.kr(0, 4, twinkTrig), notes) + 24;
		var twinkle = SinOsc.ar(Latch.kr(twinkNote, twinkTrig).midicps)
			* EnvGen.kr(Env.perc(0.01, 2.5, 0.05), twinkTrig);
		var sig = Mix.fill(5, { |i|
			var bloom = SinOsc.kr(0.04 + (0.011 * i), (i * 2.1) % 2pi).range(0, 1).squared;
			var note = Latch.kr(notes[i], Impulse.kr(0) + (bloom < 0.004));
			var f = note.midicps * wow * flutter;
			Pan2.ar(
				Saw.ar(f * 1.0018) + Saw.ar(f * 0.9982),
				i.linlin(0, 4, -0.6, 0.6)
			) * bloom * (1 / (i + 1)).sqrt
		});
		sig = MoogFF.ar(sig, LFNoise2.kr(0.06).exprange(450, 1700), 1.1);
		sig = sig + Pan2.ar(twinkle, TRand.kr(-0.7, 0.7, twinkTrig));
		sig = sig + PinkNoise.ar(0.004 ! 2); // smooth tape hiss (no impulse crackle)
		Out.ar(out, sig * amp);
	}).add;

	// Golden (17-20): warm glass with a deliberate microtonal shimmer pair and
	// slow sunset filter sweeps. Chord drift GLIDES over 12 s (this pad's
	// settled preference — rebirth belongs to Day/Deep).
	SynthDef(\chaosPadGolden, { |out = 0, targetAmp = 0, fadeTime = 10|
		var amp = VarLag.kr(targetAmp, fadeTime) * 0.26;
		var notes = \notes.kr([45, 52, 57, 60, 64]);
		var sig = Mix.fill(5, { |i|
			var f = Lag.kr(notes[i], 12).midicps;
			var bloom = SinOsc.kr(0.05 + (0.013 * i), (i * 1.7) % 2pi).range(0.1, 1);
			var v = (LFTri.ar(f) * 0.4)
				+ (LFTri.ar(f * 1.006) * 0.25)   // ~10 cent shimmer
				+ (SinOsc.ar(f * 2.01, 0, 0.14)) // barely-sharp octave
				+ (Saw.ar(f * 0.997) * 0.1);     // faint warm glow
			Pan2.ar(v, LFNoise2.kr(0.05 + (0.01 * i)).range(-0.5, 0.5))
				* bloom * (1 / (i + 1)).sqrt
		});
		sig = MoogFF.ar(sig, SinOsc.kr(0.03).exprange(700, 2600), 1.0);
		sig = sig + (DelayC.ar(sig, 0.05, SinOsc.kr(0.11, [0, pi]).range(0.012, 0.02)) * 0.4);
		sig = sig + PinkNoise.ar(0.003 ! 2);
		Out.ar(out, sig * amp);
	}).add;

	// Deep (01-09, and Night's stopgap while its own pad is unresolved):
	// Day's warmth an octave down, darker filter, slower blooms, gentle sub.
	// Rebirth drift like Day.
	SynthDef(\chaosPadDeep, { |out = 0, targetAmp = 0, fadeTime = 10|
		var amp = VarLag.kr(targetAmp, fadeTime) * 0.2;
		var notes = \notes.kr([45, 52, 57, 60, 64]);
		var wow = 1 + (LFNoise2.kr(0.3) * 0.005);
		var sig = Mix.fill(5, { |i|
			var bloom = SinOsc.kr(0.03 + (0.008 * i), (i * 2.3) % 2pi).range(0, 1).squared;
			var note = Latch.kr(notes[i] - 12, Impulse.kr(0) + (bloom < 0.004));
			var f = note.midicps * wow;
			Pan2.ar(
				Saw.ar(f * 1.0012) + Saw.ar(f * 0.9988),
				i.linlin(0, 4, -0.5, 0.5)
			) * bloom * (1 / (i + 1)).sqrt
		});
		var sub = SinOsc.ar(Lag.kr(notes[0] - 12, 8).midicps)
			* LFNoise2.kr(0.05).range(0.2, 0.5) * 0.6;
		sig = MoogFF.ar(sig, LFNoise2.kr(0.04).exprange(250, 800), 1.2);
		sig = sig + Pan2.ar(sub, 0) + PinkNoise.ar(0.003 ! 2);
		Out.ar(out, sig * amp);
	}).add;

	// Master chain: filter -> reverb -> volume -> limiter. The limiter is
	// non-negotiable festival armor: whatever campers mash, never clip.
	SynthDef(\chaosMaster, { |in, out = 0, cutoff = 12000, rq = 1.0, verbMix = 0.25, volDb = -6|
		var sig = In.ar(in, 2);
		sig = RLPF.ar(sig, cutoff.lag(0.05).clip(60, 18000), rq.lag(0.05).clip(0.18, 1.0));
		sig = FreeVerb2.ar(sig[0], sig[1], verbMix.lag(0.1), 0.8, 0.4);
		sig = sig * volDb.lag(0.1).dbamp;
		Out.ar(out, Limiter.ar(sig, 0.9));
	}).add;
};
)
