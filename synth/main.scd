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

s.waitForBoot {
	~chaosDefineSynths.(s);
	s.sync;
	~chaosEngineStart.(s);
	~chaosMappingWatch.(); // hot-reload poll, ~2 s
	~chaosMidiStart.();    // connect-by-name retry loop
	"CHAOSSYNTH READY".postln;
};

// If scsynth dies we would otherwise sit silent forever; die loudly instead so
// systemd restarts us.
ServerQuit.add({
	"CHAOSSYNTH FATAL: server quit unexpectedly, exiting for restart".postln;
	1.exit;
}, s);
)
