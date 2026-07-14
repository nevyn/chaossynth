// Chaossynth engine entry point. Run via run.sh (or: sclang main.scd).
// Boots the server, loads lib/, wires MIDI -> mapping -> voices, then prints
// the one line the Pi's systemd journal watches for: CHAOSSYNTH READY.
(
var root = thisProcess.nowExecutingPath.dirname;
var s = Server.default;

// No inputs: we never record, and asking for them trips macOS mic permission
// prompts and in/out sample-rate-mismatch boot failures.
s.options.numInputBusChannels = 0;
s.options.memSize = 65536; // headroom for reverb + a panel full of voices

(root +/+ "lib" +/+ "mapping.scd").load;
(root +/+ "lib" +/+ "synthdefs.scd").load;
(root +/+ "lib" +/+ "engine.scd").load;
(root +/+ "lib" +/+ "midi.scd").load;

~chaosMappingLoad.(root +/+ "mapping.json");
if (~chaosMapping.isNil) {
	"CHAOSSYNTH FATAL: mapping.json missing or refused at boot, cannot start".postln;
	1.exit;
};

~chaosReady = false;
s.waitForBoot {
	~chaosDefineSynths.(s);
	s.sync;
	~chaosEngineStart.(s);
	~chaosMappingWatch.(); // hot-reload poll, ~2 s
	~chaosMidiStart.();    // connect-by-name retry loop
	~chaosReady = true;
	"CHAOSSYNTH READY".postln;
};

// waitForBoot can give up (jackd alive but scsynth unreachable) leaving sclang
// idling forever with Restart=always never firing. Die loudly instead.
SystemClock.sched(60, {
	if (~chaosReady.not) {
		"CHAOSSYNTH FATAL: server did not boot within 60 s, exiting for restart".postln;
		1.exit;
	};
	nil
});

// If scsynth dies we would otherwise sit silent forever; die loudly instead so
// systemd restarts us.
ServerQuit.add({
	"CHAOSSYNTH FATAL: server quit unexpectedly, exiting for restart".postln;
	1.exit;
}, s);
)
