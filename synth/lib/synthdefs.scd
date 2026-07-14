// Placeholder SynthDefs with the right SHAPE — real sound design is
// docs/plans/patch-design.md's job. Everything routes through \chaosMaster,
// whose filter/reverb/volume the pots drive (see engine.scd).
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

	// Idle drone: warm evolving pad on an A-minor-pentatonic chord, so it can
	// never clash with the button scale. targetAmp/fadeTime drive the idle
	// crossfade (10 s in, 1 s duck) from the engine.
	SynthDef(\chaosPad, { |out = 0, targetAmp = 0, fadeTime = 10|
		var amp = VarLag.kr(targetAmp, fadeTime);
		var notes = [45, 52, 57, 60, 64]; // A2 E3 A3 C4 E4
		var sig = Mix.fill(notes.size, { |i|
			var f = notes[i].midicps;
			var drift = LFNoise2.kr(0.07 + (0.013 * i), 0.003, 1); // slow detune wander
			Pan2.ar(
				Saw.ar(f * drift) + Saw.ar(f / drift),
				i.linlin(0, notes.size - 1, -0.6, 0.6)
			) * (1 / (i + 1)).sqrt
		});
		sig = MoogFF.ar(sig, LFNoise2.kr(0.05).exprange(350, 1400), 1.2);
		Out.ar(out, sig * 0.11 * amp);
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
