// Pluck-timbre audition rig: choose what the chaos buttons should sound like.
// Same workflow as pad-picker: run INSTEAD of the engine, click layout-tool
// Simulate buttons. Listens to ALL MIDI sources (IAC works with no config).
//
// Run:  /Applications/SuperCollider.app/Contents/MacOS/sclang synth/auditions/voice-picker.scd
//
//   buttons 0-13  -> play the SELECTED candidate across the pentatonic
//   button 14     -> candidate 1: keys (current placeholder, for reference)
//   button 15     -> candidate 2: kalimba (Karplus-Strong pluck)
//   button 16     -> candidate 3: toy celesta (glassy sine partials)
//   button 17     -> candidate 4: marimba (Klank resonators)
//   pot 0 (CC 20) -> master filter cutoff
//
// Selecting a candidate plays a confirmation blip in that timbre.
(
var cands, noteFor;

s = Server(\audition, NetAddr("127.0.0.1", 57230));
Server.default = s;
s.options.numInputBusChannels = 0;
s.options.numOutputBusChannels = 2;

MIDIClient.init(verbose: false);
MIDIIn.connectAll;

s.waitForBoot({
	fork {
		SynthDef(\vpKeys, { |out = 0, freq = 220, amp = 0.25, pan = 0|
			var env = EnvGen.kr(Env.perc(0.003, 1.5, 1, -3), doneAction: 2);
			var strike = EnvGen.kr(Env.perc(0.001, 0.25));
			var tone = SinOsc.ar(freq)
				+ (LFTri.ar(freq * 1.002) * 0.4)
				+ (SinOsc.ar(freq * 2) * 0.25 * strike);
			Out.ar(out, Pan2.ar(LPF.ar(tone, (freq * 6).clip(400, 9000)) * env * amp, pan));
		}).add;

		SynthDef(\vpKalimba, { |out = 0, freq = 220, amp = 0.3, pan = 0|
			var exc = Decay.ar(Impulse.ar(0), 0.01) * WhiteNoise.ar(0.6);
			var sig = Pluck.ar(exc, Impulse.ar(0), 0.05, freq.reciprocal, 2.5, 0.35);
			var thump = SinOsc.ar(freq * 0.5) * EnvGen.kr(Env.perc(0.001, 0.08, 0.4));
			var env = EnvGen.kr(Env.perc(0.001, 2.5), doneAction: 2);
			Out.ar(out, Pan2.ar((sig + thump) * env * amp * 2, pan));
		}).add;

		SynthDef(\vpCelesta, { |out = 0, freq = 220, amp = 0.25, pan = 0|
			var env = EnvGen.kr(Env.perc(0.002, 1.8, 1, -4), doneAction: 2);
			var sig = (SinOsc.ar(freq * [1, 1.003]).sum * 0.5)
				+ (SinOsc.ar(freq * 4) * 0.18 * EnvGen.kr(Env.perc(0.001, 0.5)))
				+ (SinOsc.ar(freq * 10.1) * 0.05 * EnvGen.kr(Env.perc(0.001, 0.15)));
			Out.ar(out, Pan2.ar(sig * env * amp, pan));
		}).add;

		SynthDef(\vpMarimba, { |out = 0, freq = 220, amp = 0.3, pan = 0|
			var exc = Decay.ar(Impulse.ar(0), 0.004) * LPF.ar(WhiteNoise.ar, 4000);
			var sig = Klank.ar(`[[1, 3.932, 9.538], [1, 0.5, 0.25], [1.2, 0.4, 0.2]],
				exc, freqscale: freq);
			var env = EnvGen.kr(Env.perc(0.001, 1.6), doneAction: 2);
			Out.ar(out, Pan2.ar(sig * env * amp * 1.5, pan));
		}).add;

		SynthDef(\pickerMaster, { |in, out = 0, cutoff = 18000|
			var sig = In.ar(in, 2);
			sig = RLPF.ar(sig, cutoff.lag(0.08).clip(80, 18000), 0.7);
			Out.ar(out, Limiter.ar(sig, 0.8));
		}).add;

		s.sync;

		~bus = Bus.audio(s, 2);
		~master = Synth(\pickerMaster, [\in, ~bus, \out, 0], addAction: \addToTail);
		~sel = 0;

		cands = [
			[\vpKeys,    "1: keys (current placeholder)"],
			[\vpKalimba, "2: kalimba (Karplus-Strong)"],
			[\vpCelesta, "3: toy celesta"],
			[\vpMarimba, "4: marimba"]
		];
		noteFor = { |id| 45 + [0, 3, 5, 7, 10].at(id % 5) + (12 * (id div: 5)) };

		MIDIdef.noteOn(\vp, { |vel, num|
			if (vel > 0) {
				case
				{ (num >= 14) and: { num <= 17 } } {
					~sel = num - 14;
					Synth(cands[~sel][0], [\out, ~bus, \freq, 69.midicps], ~master, \addBefore);
					("CANDIDATE: " ++ cands[~sel][1]).postln;
				}
				{ num < 14 } {
					Synth(cands[~sel][0], [
						\out, ~bus, \freq, noteFor.(num).midicps,
						\pan, (num % 8).linlin(0, 7, -0.6, 0.6)
					], ~master, \addBefore);
					"note % (%)".format(num, cands[~sel][1]).postln;
				}
				{ true } { "note % — unbound in this rig".format(num).postln };
			};
		});

		MIDIdef.cc(\vpPot, { |val, cc|
			if (cc == 20) {
				~master.set(\cutoff, val.linexp(0, 127, 200, 18000));
				"FILTER: %".format(val).postln;
			};
		});

		"".postln;
		"VOICE PICKER READY — 14-17 pick a timbre, 0-13 play it, pot 0 = filter".postln;
		"(Ctrl-C to quit)".postln;
	};
}, onFailure: {
	"SERVER BOOT FAILED".postln;
	1.exit;
});
)
