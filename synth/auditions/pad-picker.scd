// Pad audition rig, round 2: click layout-tool Simulate buttons to A/B the
// atmosphere pads. Runs INSTEAD of the engine (stop run.sh first). Listens to
// ALL MIDI sources, so the layout tool's IAC bus works with no env vars.
//
// Run:  /Applications/SuperCollider.app/Contents/MacOS/sclang synth/auditions/pad-picker.scd
//
//   button 0 -> Day    (09-17)  tape-warble blooms + twinkles
//   button 1 -> Golden (17-20)  warm glass, sunset filter sweeps
//   button 2 -> Night  (20-01)  dub drone, breathing sub, hotter echo
//   button 3 -> Deep   (01-09)  Day's warmth an octave down + gentle sub
//   button 4 -> silence (or press the sounding pad's button again)
//   pot 0 (CC 20) -> master filter cutoff
//
// The sounding pad's root drifts to a neighbor every 2.5 min (A->C->G->D),
// gliding over ~4 s — the anti-annoyance behavior the real drone will have.
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
		// Day: voices bloom fully in and out (never one endless sustain), rare
		// high twinkles, smooth hiss only — the Dust crackle read as clicks.
		SynthDef(\padDay, { |out = 0, gate = 1, amp = 0.24, root = 45|
			var r = root.lag(4);
			var offs = [0, 7, 12, 15, 19];
			var wow = 1 + (LFNoise2.kr(0.4) * 0.006);
			var flutter = 1 + (LFNoise2.kr(7) * 0.0012);
			var env = EnvGen.kr(Env.asr(3, 1, 2.5), gate, doneAction: 2);
			var twinkTrig = Dust.kr(0.12); // a sparkle every ~8 s
			var twinkNote = r + 24 + TChoose.kr(twinkTrig, [0, 3, 7, 12]);
			var twinkle = SinOsc.ar(twinkNote.midicps)
				* EnvGen.kr(Env.perc(0.01, 2.5, 0.05), twinkTrig);
			var sig = Mix.fill(5, { |i|
				var f = (r + offs[i]).midicps * wow * flutter;
				var bloom = SinOsc.kr(0.04 + (0.011 * i), (i * 2.1) % 2pi).range(0, 1).squared;
				Pan2.ar(
					Saw.ar(f * 1.0018) + Saw.ar(f * 0.9982),
					i.linlin(0, 4, -0.6, 0.6)
				) * bloom * (1 / (i + 1)).sqrt
			});
			sig = MoogFF.ar(sig, LFNoise2.kr(0.06).exprange(450, 1700), 1.1);
			sig = sig + Pan2.ar(twinkle, TRand.kr(-0.7, 0.7, twinkTrig));
			sig = sig + PinkNoise.ar(0.004 ! 2);
			Out.ar(out, sig * env * amp);
		}).add;

		// Golden: the glass bloom warmed up — a saw glowing under the triangles,
		// Am7 voicing, slow sunset filter sweeps.
		SynthDef(\padGolden, { |out = 0, gate = 1, amp = 0.26, root = 45|
			var r = root.lag(4);
			var offs = [0, 7, 10, 12, 19];
			var wow = 1 + (LFNoise2.kr(0.25) * 0.004);
			var env = EnvGen.kr(Env.asr(4, 1, 3), gate, doneAction: 2);
			var sig = Mix.fill(5, { |i|
				var f = (r + offs[i]).midicps * wow;
				var bloom = SinOsc.kr(0.05 + (0.013 * i), (i * 1.7) % 2pi).range(0.1, 1);
				var v = (LFTri.ar(f) * 0.4) + (Saw.ar(f * 1.003) * 0.18)
					+ SinOsc.ar(f * 2, 0, 0.12);
				Pan2.ar(v, LFNoise2.kr(0.05 + (0.01 * i)).range(-0.5, 0.5))
					* bloom * (1 / (i + 1)).sqrt
			});
			sig = MoogFF.ar(sig, SinOsc.kr(0.03).exprange(700, 2600), 1.0);
			sig = sig + (DelayC.ar(sig, 0.05, SinOsc.kr(0.11, [0, pi]).range(0.012, 0.02)) * 0.4);
			sig = sig + PinkNoise.ar(0.003 ! 2);
			Out.ar(out, sig * env * amp);
		}).add;

		// Night: more energy + bass — brighter stab peak, hotter echo, and a sub
		// that swells up AFTER each chord (breathes against it).
		SynthDef(\padNight, { |out = 0, gate = 1, amp = 0.3, root = 45|
			var r = root.lag(4);
			var env = EnvGen.kr(Env.asr(0.5, 1, 3), gate, doneAction: 2);
			var trig = Impulse.kr(1 / 3.2);
			var chordEnv = EnvGen.kr(Env.perc(0.02, 1.6), trig);
			var subEnv = EnvGen.kr(Env.new([0, 0, 1, 0], [0.5, 0.7, 1.8], \sin), trig);
			var offs = [12, 15, 19, 22]; // Am7 above the root
			var stab = Mix(offs.collect { |o|
				Saw.ar((r + o).midicps * [0.9985, 1.0015]).sum * 0.12
			});
			var sub = SinOsc.ar((r - 12).midicps) * subEnv * 0.55;
			var echoL, echoR, mix;
			stab = RLPF.ar(stab, chordEnv.linexp(0, 1, 300, 3200), 0.45) * chordEnv;
			echoL = CombC.ar(stab, 1.0, 0.53, 9);
			echoR = CombC.ar(stab, 1.0, 0.35, 9);
			mix = LPF.ar([stab + (echoL * 0.85), stab + (echoR * 0.85)], 2000);
			mix = FreeVerb2.ar(mix[0], mix[1], 0.45, 0.92, 0.5);
			mix = mix + Pan2.ar(sub, 0) + PinkNoise.ar(0.004 ! 2);
			Out.ar(out, mix * env * amp);
		}).add;

		// Deep: Day's character dropped an octave, darker filter, slower blooms,
		// gentle sub sine. (In the installation this slot is also level-capped.)
		SynthDef(\padDeep, { |out = 0, gate = 1, amp = 0.2, root = 45|
			var r = root.lag(6);
			var offs = [-12, -5, 0, 3, 7];
			var wow = 1 + (LFNoise2.kr(0.3) * 0.005);
			var env = EnvGen.kr(Env.asr(5, 1, 4), gate, doneAction: 2);
			var sig = Mix.fill(5, { |i|
				var f = (r + offs[i]).midicps * wow;
				var bloom = SinOsc.kr(0.03 + (0.008 * i), (i * 2.3) % 2pi).range(0, 1).squared;
				Pan2.ar(
					Saw.ar(f * 1.0012) + Saw.ar(f * 0.9988),
					i.linlin(0, 4, -0.5, 0.5)
				) * bloom * (1 / (i + 1)).sqrt
			});
			var sub = SinOsc.ar((r - 12).midicps) * LFNoise2.kr(0.05).range(0.2, 0.5) * 0.6;
			sig = MoogFF.ar(sig, LFNoise2.kr(0.04).exprange(250, 800), 1.2);
			sig = sig + Pan2.ar(sub, 0) + PinkNoise.ar(0.003 ! 2);
			Out.ar(out, sig * env * amp);
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
			[\padDay,    "Day (09-17) — tape-warble blooms + twinkles"],
			[\padGolden, "Golden (17-20) — warm glass, sunset sweeps"],
			[\padNight,  "Night (20-01) — dub drone, breathing sub"],
			[\padDeep,   "Deep (01-09) — dark warmth + gentle sub"]
		];

		// Root drift: A -> C -> G -> D, every 2.5 min, glide not jump.
		~roots = [45, 48, 43, 50];
		~ri = 0;
		SystemClock.sched(150, {
			~ri = (~ri + 1) % ~roots.size;
			~current !? {
				~current.set(\root, ~roots[~ri]);
				"DRIFT: root glides to midinote %".format(~roots[~ri]).postln;
			};
			150
		});

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
						~current = Synth(pads[num][0], [\out, ~bus, \root, ~roots[~ri]]);
						~currentName = num;
						("PAD ON:  " ++ pads[num][1]).postln;
					};
				}
				{ num == 4 } {
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
		"PAD PICKER v2 READY — 0=Day 1=Golden 2=Night 3=Deep 4=silence, pot 0 = filter".postln;
		"Root drifts every 2.5 min while a pad sounds. (Ctrl-C to quit)".postln;
	};
}, onFailure: {
	"SERVER BOOT FAILED".postln;
	1.exit;
});
)
