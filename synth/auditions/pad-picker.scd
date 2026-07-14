// Pad audition rig, round 3: click layout-tool Simulate buttons to A/B the
// atmosphere pads. Runs INSTEAD of the engine (stop run.sh first). Listens to
// ALL MIDI sources, so the layout tool's IAC bus works with no env vars.
//
// Run:  /Applications/SuperCollider.app/Contents/MacOS/sclang synth/auditions/pad-picker.scd
//
//   button 0 -> Day    (09-17)  tape-warble blooms + twinkles          [SETTLED 07-15]
//   button 1 -> Golden (17-20)  warm glass, microtonal shimmer         [SETTLED 07-15]
//   button 2 -> Night  (20-01)  dubby arp — TABLED, not working yet
//   button 3 -> Deep   (01-09)  dark low blooms + sub                  [SETTLED 07-15]
//   button 4 -> silence (or press the sounding pad's button again)
//   pot 0 (CC 20) -> master filter cutoff
//
// Drift: every 2.5 min the chord moves A -> C -> G -> D, all voiced inside
// A minor pentatonic so transitions can overlap without clashing.
// TWO drift styles to compare:  Day/Deep re-pitch each voice as it is REBORN
// (pause, then new note in new key); Golden GLIDES over 12 s.  Night's arp
// simply picks the new chord on its next step.
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
		// Day: voices bloom fully in and out; each voice latches its pitch while
		// silent, so drift arrives as reborn notes, never a bend.
		SynthDef(\padDay, { |out = 0, gate = 1, amp = 0.24|
			var notes = \notes.kr([45, 52, 57, 60, 64]);
			var wow = 1 + (LFNoise2.kr(0.4) * 0.006);
			var flutter = 1 + (LFNoise2.kr(7) * 0.0012);
			var env = EnvGen.kr(Env.asr(3, 1, 2.5), gate, doneAction: 2);
			var twinkTrig = Dust.kr(0.12); // a sparkle every ~8 s
			var twinkNote = Select.kr(TIRand.kr(0, 4, twinkTrig), notes) + 24;
			var twinkle = SinOsc.ar(Latch.kr(twinkNote, twinkTrig).midicps)
				* EnvGen.kr(Env.perc(0.01, 2.5, 0.05), twinkTrig); // plain sine: bell rejected 07-15
			var sig = Mix.fill(5, { |i|
				var bloom = SinOsc.kr(0.04 + (0.011 * i), (i * 2.1) % 2pi).range(0, 1).squared;
				var note = Latch.kr(notes[i], Impulse.kr(0) + (bloom < 0.004)); // re-pitch while silent
				var f = note.midicps * wow * flutter;
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

		// Golden: glassier than Day on purpose — triangle/sine partials with a
		// LEANED-IN microdetune shimmer (that quality you noticed and liked),
		// quiet saw glow, sunset sweeps. Drift GLIDES over 12 s.
		SynthDef(\padGolden, { |out = 0, gate = 1, amp = 0.26|
			var notes = \notes.kr([45, 52, 57, 60, 64]);
			var env = EnvGen.kr(Env.asr(4, 1, 3), gate, doneAction: 2);
			var sig = Mix.fill(5, { |i|
				var f = Lag.kr(notes[i], 12).midicps; // the 12 s glide drift
				var bloom = SinOsc.kr(0.05 + (0.013 * i), (i * 1.7) % 2pi).range(0.1, 1);
				var v = (LFTri.ar(f) * 0.4)
					+ (LFTri.ar(f * 1.006) * 0.25)          // ~10 cent shimmer pair
					+ (SinOsc.ar(f * 2.01, 0, 0.14))        // barely-sharp octave
					+ (Saw.ar(f * 0.997) * 0.1);            // faint warm glow
				Pan2.ar(v, LFNoise2.kr(0.05 + (0.01 * i)).range(-0.5, 0.5))
					* bloom * (1 / (i + 1)).sqrt
			});
			sig = MoogFF.ar(sig, SinOsc.kr(0.03).exprange(700, 2600), 1.0);
			sig = sig + (DelayC.ar(sig, 0.05, SinOsc.kr(0.11, [0, pi]).range(0.012, 0.02)) * 0.4);
			sig = sig + PinkNoise.ar(0.003 ! 2);
			Out.ar(out, sig * env * amp);
		}).add;

		// Night: single dubby stabs, sequenced by the rig's arp task.
		SynthDef(\nightStab, { |out = 0, note = 57, amp = 0.5|
			var f = note.midicps;
			var env = EnvGen.kr(Env.perc(0.01, 0.9, 1, -4), doneAction: 2);
			var sig = Saw.ar(f * [0.9985, 1.0015]).sum * 0.5;
			sig = RLPF.ar(sig, env.linexp(0, 1, 300, 3000), 0.5);
			Out.ar(out, sig * env * amp);
		}).add;

		// Night's shared tail: dark stereo echo + verb + the sub. Sub got LOUD
		// (0.85) plus a 2nd harmonic so it reads on small speakers.
		SynthDef(\nightFx, { |in, out = 0, subnote = 33, gate = 1, amp = 0.32|
			var stab = In.ar(in, 1);
			var env = EnvGen.kr(Env.asr(0.5, 1, 3), gate, doneAction: 2);
			var echoL = CombC.ar(stab, 1.0, 0.53, 9);
			var echoR = CombC.ar(stab, 1.0, 0.35, 9);
			var mix = LPF.ar([stab + (echoL * 0.85), stab + (echoR * 0.85)], 2000);
			var sf = Lag.kr(subnote, 8).midicps;
			var breath = LFNoise2.kr(0.06).range(0.4, 1);
			var sub = ((SinOsc.ar(sf) * 0.85) + (SinOsc.ar(sf * 2) * 0.28)) * breath;
			mix = FreeVerb2.ar(mix[0], mix[1], 0.45, 0.92, 0.5);
			mix = mix + Pan2.ar(sub, 0) + PinkNoise.ar(0.004 ! 2);
			Out.ar(out, mix * env * amp);
		}).add;

		// Deep: round-2 timbre (Day's warmth an octave down — Nevyn preferred it
		// over the triangle/ocean-breath experiment) + the rebirth chord drift.
		SynthDef(\padDeep, { |out = 0, gate = 1, amp = 0.2|
			var notes = \notes.kr([45, 52, 57, 60, 64]);
			var wow = 1 + (LFNoise2.kr(0.3) * 0.005);
			var env = EnvGen.kr(Env.asr(5, 1, 4), gate, doneAction: 2);
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
			Out.ar(out, sig * env * amp);
		}).add;

		SynthDef(\pickerMaster, { |in, out = 0, cutoff = 18000|
			var sig = In.ar(in, 2);
			sig = RLPF.ar(sig, cutoff.lag(0.08).clip(80, 18000), 0.7);
			Out.ar(out, Limiter.ar(sig, 0.8));
		}).add;

		s.sync;

		~bus = Bus.audio(s, 2);
		~nightBus = Bus.audio(s, 1);
		~master = Synth(\pickerMaster, [\in, ~bus, \out, 0], addAction: \addToTail);
		~current = nil;
		~currentName = nil;
		~nightTask = nil;
		~nightFx = nil;

		// Chords voiced inside A minor pentatonic (A C D E G) so any two can
		// overlap during a drift transition without clashing.
		~chordNames = ["A", "C", "G", "D"];
		~chords = [
			[45, 52, 57, 60, 64],  // A: A E A C E
			[48, 55, 60, 64, 67],  // C: C G C E G
			[43, 50, 55, 62, 67],  // G: G D G D G (open fifths)
			[50, 57, 62, 67, 69]   // D: D A D G A
		];
		~ci = 0;

		pads = [
			[\padDay,    "Day (09-17) — tape-warble blooms + twinkles"],
			[\padGolden, "Golden (17-20) — warm glass, microtonal shimmer"],
			[nil,        "Night (20-01) — dubby arp, breathing sub"],
			[\padDeep,   "Deep (01-09) — dark still blooms + ocean breath"]
		];

		// 8-step arp pattern over the chord: 6 tones + 2 rests, reshuffled
		// every 32 steps (~26 s) so it never settles into one loop.
		~makePattern = {
			([0, 1, 2, 3, 4].scramble.keep(6) ++ [nil, nil]).scramble
		};

		~startNight = {
			~nightFx = Synth(\nightFx,
				[\in, ~nightBus, \out, ~bus, \subnote, ~chords[~ci][0] - 12],
				~master, \addBefore);
			~nightTask = Task({
				var pattern = ~makePattern.();
				var step = 0;
				loop {
					var slot = pattern[step % 8];
					slot !? {
						Synth(\nightStab, [\out, ~nightBus, \note, ~chords[~ci][slot] + 12],
							~nightFx, \addBefore);
					};
					step = step + 1;
					if (step % 32 == 0) {
						pattern = ~makePattern.();
						"ARP: new pattern".postln;
					};
					0.75.wait;
				};
			}).play;
		};

		~stopPad = {
			~current !? { ~current.set(\gate, 0) };
			~current = nil;
			~nightTask !? { ~nightTask.stop };
			~nightTask = nil;
			~nightFx !? { ~nightFx.set(\gate, 0) };
			~nightFx = nil;
			~currentName = nil;
		};

		SystemClock.sched(150, {
			~ci = (~ci + 1) % ~chords.size;
			~current !? { ~current.setn(\notes, ~chords[~ci]) };
			~nightFx !? { ~nightFx.set(\subnote, ~chords[~ci][0] - 12) };
			if (~currentName.notNil) {
				"DRIFT: chord -> %".format(~chordNames[~ci]).postln;
			};
			150
		});

		MIDIdef.noteOn(\pick, { |vel, num|
			if (vel > 0) {
				case
				{ num < pads.size } {
					if (~currentName == num) {
						("PAD OFF: " ++ pads[num][1]).postln;
						~stopPad.();
					} {
						~stopPad.();
						if (num == 2) {
							~startNight.();
						} {
							~current = Synth(pads[num][0], [\out, ~bus], ~master, \addBefore);
							~current.setn(\notes, ~chords[~ci]);
						};
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
		"PAD PICKER v3 READY — 0=Day 1=Golden 2=Night(arp) 3=Deep 4=silence, pot 0 = filter".postln;
		"Drift every 2.5 min: Day/Deep re-pitch on rebirth, Golden glides 12 s.".postln;
		"(Ctrl-C to quit)".postln;
	};
}, onFailure: {
	"SERVER BOOT FAILED".postln;
	1.exit;
});
)
