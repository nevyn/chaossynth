// Role-dispatch test: boots a private server (port 57236) at -60 dB, loads
// auditions/roles-demo.json, and drives the engine's entry points DIRECTLY
// (~chaosNoteOn/Off/CC — no MIDI involved, so a live engine on the default
// port is never disturbed). Asserts engine-side state per role.
//
// Run:  /Applications/SuperCollider.app/Contents/MacOS/sclang tools/roles-test.scd
// (or any cwd — paths resolve relative to this file)
(
var here = thisProcess.nowExecutingPath.dirname;
var lib = here.dirname +/+ "lib";
var fails = 0;
var check = { |desc, ok|
	if (ok) { ("PASS: " ++ desc).postln } { ("FAIL: " ++ desc).postln; fails = fails + 1 };
};

s = Server(\rolestest, NetAddr("127.0.0.1", 57236));
Server.default = s;
s.options.numInputBusChannels = 0;
s.options.numOutputBusChannels = 2;
s.options.memSize = 65536;

(lib +/+ "mapping.scd").load;
(lib +/+ "synthdefs.scd").load;
(lib +/+ "engine.scd").load;

~chaosMappingLoad.(here.dirname +/+ "auditions" +/+ "roles-demo.json");
if (~chaosMapping.isNil) { "FATAL: fixture mapping did not load".postln; 1.exit };

s.waitForBoot({
	fork {
		~chaosDefineSynths.(s);
		s.sync;
		~chaosEngineStart.(s);
		~chaosMaster.set(\volDb, -60); // near-silence: this test may run at night
		s.sync;

		// chop bank loads async; give it a moment
		10.do { if (~chaosChopReady.not) { 0.5.wait } };
		check.("chop bank loaded", ~chaosChopReady == true);

		// roots
		~chaosNoteOn.(1); ~chaosNoteOff.(1);
		check.("root button 1 -> chord C (index 1)", ~chaosChordIndex == 1);
		~chaosNoteOn.(4); ~chaosNoteOff.(4);
		check.("root button 4 -> chord G (index 4)", ~chaosChordIndex == 4);

		// voice lifecycle
		~chaosNoteOn.(6);
		check.("voice press tracked", ~chaosVoices[6].notNil);
		~chaosNoteOff.(6);
		check.("voice release untracked", ~chaosVoices[6].isNil);
		~chaosNoteOn.(11); // degree-override voice
		check.("voice with explicit degree tracked", ~chaosVoices[11].notNil);
		~chaosNoteOff.(11);

		// bass
		~chaosNoteOn.(12);
		check.("bass press tracked", ~chaosVoices[12].notNil);
		~chaosNoteOff.(12);
		check.("bass release untracked", ~chaosVoices[12].isNil);

		// hold FX counters
		~chaosNoteOn.(13);
		check.("hold delay engaged", ~chaosHoldDelay == 1);
		~chaosNoteOn.(14);
		check.("hold reverb engaged", ~chaosHoldReverb == 1);
		~chaosNoteOff.(13);
		~chaosNoteOff.(14);
		check.("holds released", (~chaosHoldDelay == 0) and: { ~chaosHoldReverb == 0 });

		// macros write engine state
		~chaosCC.(26, 127);
		check.("timbre macro -> 1.0", ~chaosTimbre == 1.0);
		~chaosCC.(27, 0);
		check.("chaos macro -> 0.0", ~chaosChaos == 0.0);
		~chaosCC.(25, 64);
		check.("wobble macro stored", (~chaosWobble - 0.504).abs < 0.01);
		~chaosCC.(20, 100); // filter -> master synth; just must not crash
		~chaosCC.(21, 80);  // space
		~chaosCC.(22, 90);  // echo
		~chaosCC.(23, 40);  // phaser

		// oneshots + chop slice: must not crash
		~chaosNoteOn.(15); ~chaosNoteOff.(15);
		~chaosNoteOn.(16); ~chaosNoteOff.(16);
		~chaosNoteOn.(17); ~chaosNoteOff.(17);
		~chaosNoteOn.(18); ~chaosNoteOff.(18);
		s.sync;
		check.("oneshots + chop slice survived", true);

		// CC 123 releases voices AND stuck holds
		~chaosNoteOn.(5);
		~chaosNoteOn.(13);
		~chaosCC.(123, 0);
		check.("cc123 empties voices", ~chaosVoiceOrder.size == 0);
		check.("cc123 resets holds", ~chaosHoldDelay == 0);

		// Pot relaxation — meaningful only when the env knobs shrink the clock:
		// run with CHAOS_RELAX_AFTER=3 CHAOS_RELAX_OVER=2 (as the runner below
		// documents); with production timing this block self-skips.
		if (~chaosRelaxAfter < 30) {
			~chaosCC.(26, 127); // timbre to 1.0
			14.wait;            // stale (3 s) + a 5 s tick + ease (2 s) + margin
			check.("stale timbre pot relaxed home (~0.5)", (~chaosTimbre - 0.5).abs < 0.05);
		} {
			"SKIP: relaxation (set CHAOS_RELAX_AFTER=3 CHAOS_RELAX_OVER=2 to test)".postln;
		};

		1.wait; // let any straggler server messages land
		s.sync;
		"".postln;
		if (fails == 0) {
			"ROLES TEST: ALL PASS".postln;
			s.quit; 1.wait; 0.exit;
		} {
			"ROLES TEST: % FAILURE(S)".format(fails).postln;
			s.quit; 1.wait; 1.exit;
		};
	};
}, onFailure: {
	"FATAL: server boot failed".postln;
	1.exit;
});
)
