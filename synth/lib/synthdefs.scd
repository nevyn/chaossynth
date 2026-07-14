// SynthDefs: the settled atmosphere drones (auditioned by ear 07-15, see
// docs/plans/patch-design.md) + the interactive voices (\chaosKeys is still a
// placeholder — the main-instrument build iterates it next). Everything routes
// through \chaosMaster.
(
~chaosDefineSynths = { |s|

	// Per-button voice: soft keys/pluck. Gated so NoteOff (or the safety
	// release) always works; frees itself when the release tail ends.
	// bright (0..1, from the timbre pot) morphs soft keys -> glassy.
	SynthDef(\chaosKeys, { |out = 0, freq = 220, amp = 0.25, gate = 1, pan = 0, bright = 0.5|
		var env = EnvGen.kr(Env.adsr(0.003, 0.35, 0.4, 1.2), gate, doneAction: 2);
		var strike = EnvGen.kr(Env.perc(0.001, 0.25));
		var tone = SinOsc.ar(freq)
			+ (LFTri.ar(freq * 1.002) * 0.4)
			+ (SinOsc.ar(freq * 2) * (0.1 + (bright * 0.35)) * strike)
			+ (SinOsc.ar(freq * 4.02) * bright * 0.12 * strike);
		var sig = LPF.ar(tone, (freq * bright.linexp(0, 1, 3, 12)).clip(400, 12000));
		Out.ar(out, Pan2.ar(sig * env * amp, pan));
	}).add;

	// Bass gesture (role "bass"): held LFO-wobble stab on the chord root.
	// rate in Hz from the wobble pot; 2nd harmonic so small speakers read it.
	SynthDef(\chaosBass, { |out = 0, freq = 55, gate = 1, amp = 0.5, rate = 4|
		var env = EnvGen.kr(Env.asr(0.03, 1, 0.5), gate, doneAction: 2);
		var lfo = SinOsc.kr(Lag.kr(rate, 0.4)).range(0, 1);
		var sig = (Saw.ar(freq * [1, 1.006]).sum * 0.5)
			+ SinOsc.ar(freq, 0, 0.7)
			+ SinOsc.ar(freq * 2, 0, 0.25);
		sig = MoogFF.ar(sig, lfo.linexp(0, 1, 90, 2200), 2.2);
		Out.ar(out, Pan2.ar(sig * env * amp * 0.8, 0));
	}).add;

	// One-shots (role "oneshot", slots 0-2). All self-freeing.
	SynthDef(\chaosThunder, { |out = 0, amp = 0.6|
		var env = EnvGen.kr(Env.perc(0.04, 4.5, 1, -5), doneAction: 2);
		var rumble = LPF.ar(BrownNoise.ar(1 ! 2), LFNoise2.kr(2).exprange(80, 400));
		var crack = HPF.ar(WhiteNoise.ar(0.3), 1200) * EnvGen.kr(Env.perc(0.001, 0.12));
		Out.ar(out, (rumble + Pan2.ar(crack, Rand(-0.3, 0.3))) * env * amp);
	}).add;

	SynthDef(\chaosWhale, { |out = 0, amp = 0.4|
		var env = EnvGen.kr(Env.new([0, 1, 0.7, 0], [0.4, 2.2, 1.6], \sin), doneAction: 2);
		var f = EnvGen.kr(Env.new([180, 320, 240], [1.8, 2.4], \exp));
		var vib = SinOsc.kr(4.5, 0, 6);
		var sig = SinOsc.ar(f + vib) + SinOsc.ar((f + vib) * 2.01, 0, 0.3);
		Out.ar(out, Pan2.ar(sig * env * amp * 0.5, Rand(-0.4, 0.4)));
	}).add;

	SynthDef(\chaosBellSwell, { |out = 0, freq = 440, amp = 0.5|
		var exc = PinkNoise.ar(EnvGen.kr(Env.new([0, 1, 0], [1.2, 0.4])) * 0.02);
		var sig = Klank.ar(`[[1, 2.756, 5.404, 8.933], [1, 0.6, 0.4, 0.25], [2.5, 2, 1.5, 1]],
			exc, freqscale: freq);
		var env = EnvGen.kr(Env.new([0, 1, 0], [1.4, 3.2], \sin), doneAction: 2);
		Out.ar(out, Pan2.ar(sig, Rand(-0.5, 0.5)) * env * amp);
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

	// Master chain: filter -> echo -> phaser -> reverb -> volume -> limiter.
	// The limiter is non-negotiable festival armor: whatever campers mash,
	// never clip. echoHold/verbHold are the hold_fx buttons — they compose
	// with the pot values via max(), so a held button can't be undone by a pot.
	SynthDef(\chaosMaster, { |in, out = 0, cutoff = 12000, rq = 1.0,
		verbMix = 0.25, verbRoom = 0.8, echoMix = 0, echoFb = 0.35,
		phaserDepth = 0, phaserRate = 0.3, echoHold = 0, verbHold = 0, volDb = -6|
		var sig = In.ar(in, 2);
		var em = max(echoMix.lag(0.3), echoHold.lag(0.3) * 0.6);
		var ef = max(echoFb.lag(0.3), echoHold.lag(0.3) * 0.8).clip(0, 0.92);
		var vm = max(verbMix.lag(0.1), verbHold.lag(1.5) * 0.85);
		var echo, ph, lfo;
		sig = RLPF.ar(sig, cutoff.lag(0.05).clip(60, 18000), rq.lag(0.05).clip(0.18, 1.0));
		// Feedback dub echo (unsynced for now; tempo lands with the beat work).
		echo = LocalIn.ar(2);
		echo = DelayC.ar((sig * em) + (echo * ef), 0.8, [0.42, 0.56]);
		echo = LPF.ar(echo, 2500);
		LocalOut.ar(echo);
		sig = sig + echo;
		// Phaser: 4 swept allpasses, mixed in by depth.
		lfo = SinOsc.kr(phaserRate.lag(0.5), [0, pi/2]).range(0.0004, 0.006);
		ph = sig;
		4.do { ph = AllpassC.ar(ph, 0.01, lfo, 0) };
		sig = sig + (ph * phaserDepth.lag(0.3));
		sig = FreeVerb2.ar(sig[0], sig[1], vm, verbRoom.lag(0.3), 0.4);
		sig = sig * volDb.lag(0.1).dbamp;
		Out.ar(out, Limiter.ar(sig, 0.9));
	}).add;
};
)
