// Pad audition rig: click layout-tool Simulate buttons to A/B the pad
// candidates. Runs INSTEAD of the engine (stop run.sh first — otherwise its
// plucks play over everything). Listens to ALL MIDI sources, so the layout
// tool's IAC bus works with no env vars.
//
// Run:  /Applications/SuperCollider.app/Contents/MacOS/sclang synth/auditions/pad-picker.scd
//
//   button 0 -> pad A  tape-warble saws  (Day: BoC, whole chord bends like tape)
//   button 1 -> pad B  glass organ bloom (Dawn/Afterhours: voices breathe in/out)
//   button 2 -> pad C  dub-techno drone  (Golden: chord swells into dark echo)
//   button 3 -> silence (or press the sounding pad's button again)
//   pot 0 (CC 20) -> master filter cutoff
//
// Pressing a different pad crossfades via the pads' own attack/release.
(
var pads;

s = Server(\audition, NetAddr("127.0.0.1", 57230)); // clear of both sclangs' 5712x ports
Server.default = s;
s.options.numInputBusChannels = 0;
s.options.numOutputBusChannels = 2;

MIDIClient.init(verbose: false); // first init must be on the main thread (see lib/midi.scd)
MIDIIn.connectAll;

s.waitForBoot({
	fork {
		SynthDef(\padA, { |out = 0, gate = 1, amp = 0.22|
			var notes = [45, 52, 57, 60, 64]; // A2 E3 A3 C4 E4
			var wow = 1 + (LFNoise2.kr(0.4) * 0.006);   // shared: whole tape wobbles together
			var flutter = 1 + (LFNoise2.kr(7) * 0.0012);
			var env = EnvGen.kr(Env.asr(3, 1, 2.5), gate, doneAction: 2);
			var sig = Mix.fill(notes.size, { |i|
				var f = notes[i].midicps * wow * flutter;
				var breath = LFNoise2.kr(0.09 + (0.017 * i)).range(0.4, 1);
				Pan2.ar(
					Saw.ar(f * 1.0018) + Saw.ar(f * 0.9982),
					i.linlin(0, notes.size - 1, -0.6, 0.6)
				) * breath * (1 / (i + 1)).sqrt
			});
			sig = MoogFF.ar(sig, LFNoise2.kr(0.06).exprange(450, 1700), 1.1);
			sig = sig + PinkNoise.ar(0.006 ! 2);                          // tape hiss
			sig = sig + Pan2.ar(BPF.ar(Dust2.ar(4), 3500, 0.6) * 0.8, 0); // vinyl crackle
			Out.ar(out, sig * env * amp);
		}).add;

		SynthDef(\padB, { |out = 0, gate = 1, amp = 0.3|
			var notes = [45, 52, 57, 60, 64];
			var wow = 1 + (LFNoise2.kr(0.3) * 0.003);
			var env = EnvGen.kr(Env.asr(4, 1, 3), gate, doneAction: 2);
			var sig = Mix.fill(notes.size, { |i|
				var f = notes[i].midicps * wow;
				var bloom = SinOsc.kr(0.05 + (0.013 * i), (i * 1.7) % 2pi).range(0.1, 1);
				var v = (LFTri.ar(f) * 0.5) + SinOsc.ar(f * 2, 0, 0.15)
					+ SinOsc.ar(f * 4, 0, 0.05 * bloom);
				Pan2.ar(v, LFNoise2.kr(0.05 + (0.01 * i)).range(-0.5, 0.5))
					* bloom * (1 / (i + 1)).sqrt
			});
			sig = LPF.ar(sig, 2800);
			sig = sig + (DelayC.ar(sig, 0.05, SinOsc.kr(0.11, [0, pi]).range(0.012, 0.02)) * 0.4);
			sig = sig + PinkNoise.ar(0.003 ! 2);
			Out.ar(out, sig * env * amp);
		}).add;

		SynthDef(\padC, { |out = 0, gate = 1, amp = 0.3|
			var env = EnvGen.kr(Env.asr(0.5, 1, 3), gate, doneAction: 2);
			var trig = Impulse.kr(1 / 3.6);               // a chord swell every ~3.6 s
			var chordEnv = EnvGen.kr(Env.perc(0.02, 1.4), trig);
			var notes = [57, 60, 64, 67];                 // Am7 stab
			var stab = Mix(notes.collect { |n|
				Saw.ar(n.midicps * [0.9985, 1.0015]).sum * 0.12
			});
			var sub = SinOsc.ar(55) * LFNoise2.kr(0.07).range(0.25, 0.5); // A1 breath
			var echoL, echoR, mix;
			stab = RLPF.ar(stab, chordEnv.linexp(0, 1, 250, 2400), 0.5) * chordEnv;
			echoL = CombC.ar(stab, 1.0, 0.57, 7);
			echoR = CombC.ar(stab, 1.0, 0.38, 7);
			mix = LPF.ar([stab + (echoL * 0.7), stab + (echoR * 0.7)], 1800); // dark tape echo
			mix = FreeVerb2.ar(mix[0], mix[1], 0.45, 0.9, 0.5);
			mix = mix + Pan2.ar(sub * 0.5, 0) + PinkNoise.ar(0.005 ! 2);
			Out.ar(out, mix * env * amp);
		}).add;

		SynthDef(\pickerMaster, { |in, out = 0, cutoff = 18000|
			var sig = In.ar(in, 2);
			sig = RLPF.ar(sig, cutoff.lag(0.08).clip(80, 18000), 0.7);
			Out.ar(out, Limiter.ar(sig, 0.8));
		}).add;

		s.sync;

		~bus = Bus.audio(s, 2);
		~master = Synth(\pickerMaster, [\in, ~bus, \out, 0]);
		~current = nil;
		~currentName = nil;

		pads = [
			[\padA, "A — tape-warble saws (Day)"],
			[\padB, "B — glass organ bloom (Dawn/Afterhours)"],
			[\padC, "C — dub-techno drone (Golden)"]
		];

		~stopPad = {
			~current !? { ~current.set(\gate, 0) };
			~current = nil;
			~currentName = nil;
		};

		MIDIdef.noteOn(\pick, { |vel, num|
			if (vel > 0) {
				case
				{ num < pads.size } {
					if (~currentName == num) {
						("PAD OFF: " ++ pads[num][1]).postln;
						~stopPad.();
					} {
						~current !? { ~current.set(\gate, 0) };
						~current = Synth(pads[num][0], [\out, ~bus]);
						~currentName = num;
						("PAD ON:  " ++ pads[num][1]).postln;
					};
				}
				{ num == 3 } {
					"SILENCE".postln;
					~stopPad.();
				}
				{ true } { "note % — unbound in this rig".format(num).postln };
			};
		});

		MIDIdef.cc(\pot, { |val, cc|
			if (cc == 20) {
				~master.set(\cutoff, val.linexp(0, 127, 200, 18000));
				"FILTER: %".format(val).postln;
			};
		});

		"".postln;
		"PAD PICKER READY — buttons 0/1/2 = pads A/B/C, 3 = silence, pot 0 = filter".postln;
		"(Ctrl-C to quit)".postln;
	};
}, onFailure: {
	"SERVER BOOT FAILED".postln;
	1.exit;
});
)
