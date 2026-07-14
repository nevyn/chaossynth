// Voice management + the idle/active state machine.
// Public entry points (called from midi.scd with already-validated ints):
//   ~chaosNoteOn.(note)  ~chaosNoteOff.(note)  ~chaosCC.(cc, val)  ~chaosAllOff.()
(
~chaosIdleTimeout = ("CHAOS_IDLE_TIMEOUT".getenv ? "90").asFloat; // s of silence before drone
~chaosMaxHold = ("CHAOS_MAX_HOLD".getenv ? "300").asFloat; // yanked-cable stuck-note release
~chaosVoiceCap = 24;
~chaosDroneAmp = 1.0;

~chaosVoices = IdentityDictionary.new; // note -> synth
~chaosVoiceOrder = List.new;           // notes, oldest first, for the cap
~chaosUnmappedLogged = Set.new;
~chaosLastEvent = 0;
~chaosIsIdle = false;

// Button id -> A minor pentatonic degree across octaves, from A2.
// Contract: note number IS the button id, so this covers ids 0-31.
~chaosNoteToMidinote = { |id| 45 + [0, 3, 5, 7, 10].at(id % 5) + (12 * (id div: 5)) };

// Any human input: stamp the clock and duck the drone if it was up.
~chaosTouched = {
	~chaosLastEvent = Main.elapsedTime;
	if (~chaosIsIdle) {
		~chaosIsIdle = false;
		~chaosDrone.set(\fadeTime, 1, \targetAmp, 0);
		"IDLE: input received, drone ducking (1 s)".postln;
	};
};

~chaosReleaseVoice = { |note|
	var synth = ~chaosVoices[note];
	if (synth.notNil) {
		synth.set(\gate, 0);
		~chaosVoices.removeAt(note);
		~chaosVoiceOrder.remove(note);
	};
};

~chaosNoteOn = { |note|
	var ctl = ~chaosNoteMap !? { ~chaosNoteMap[note] };
	var midinote, synth;
	~chaosTouched.();
	if (ctl.isNil) {
		if (~chaosUnmappedLogged.includes("note" + note).not) {
			~chaosUnmappedLogged.add("note" + note);
			"UNMAPPED: note % — not in mapping.json (logged once)".format(note).postln;
		};
	} {
		~chaosReleaseVoice.(note); // retrigger if already held
		if (~chaosVoiceOrder.size >= ~chaosVoiceCap) {
			"VOICES: cap % hit, stealing oldest".format(~chaosVoiceCap).postln;
			~chaosReleaseVoice.(~chaosVoiceOrder.first);
		};
		midinote = ~chaosNoteToMidinote.(note);
		synth = Synth(\chaosKeys, [
			\out, ~chaosBus, \freq, midinote.midicps,
			\pan, (note % 8).linlin(0, 7, -0.6, 0.6)
		], ~chaosVoiceGroup);
		~chaosVoices[note] = synth;
		~chaosVoiceOrder.add(note);
		"VOICE: button % down -> midinote % ('%')"
			.format(note, midinote, ctl["label"]).postln;
		// Yanked-cable armor: if the NoteOff never arrives, release anyway.
		SystemClock.sched(~chaosMaxHold, {
			if (~chaosVoices[note] === synth) {
				"SAFETY: max-hold (% s) release of note %".format(~chaosMaxHold, note).postln;
				~chaosReleaseVoice.(note);
			};
			nil
		});
	};
};

~chaosNoteOff = { |note|
	~chaosTouched.();
	~chaosReleaseVoice.(note); // unknown/unheld notes: nothing to do
};

// Pot id (cc - 20) -> provisional master role. Real assignments come from
// patch-design via mapping.json's synth{} blobs later.
~chaosPotRoles = [
	{ |v| ~chaosMaster.set(\cutoff, v.linexp(0, 127, 200, 12000)); "cutoff" },
	{ |v| ~chaosMaster.set(\rq, v.linlin(0, 127, 1.0, 0.2)); "resonance" },
	{ |v| ~chaosMaster.set(\verbMix, v.linlin(0, 127, 0, 0.65)); "reverb mix" },
	// Floor is -35 dB, not silence: a zeroed pot must never look like a dead rig.
	{ |v| ~chaosMaster.set(\volDb, v.linlin(0, 127, -35, 0)); "volume" }
];

~chaosCC = { |cc, val|
	var ctl, role;
	if (cc == 123) {
		"ALL NOTES OFF (cc 123): releasing % voice(s)".format(~chaosVoiceOrder.size).postln;
		~chaosAllOff.();
	} {
		ctl = ~chaosCCMap !? { ~chaosCCMap[cc] };
		~chaosTouched.();
		case
		{ ctl.isNil } {
			if (~chaosUnmappedLogged.includes("cc" + cc).not) {
				~chaosUnmappedLogged.add("cc" + cc);
				"UNMAPPED: cc % — not in mapping.json (logged once)".format(cc).postln;
			};
		}
		{ ctl["kind"].asString == "pot" } {
			role = ~chaosPotRoles[cc - 20];
			if (role.notNil) {
				"MASTER: % <- % ('%')".format(role.(val), val, ctl["label"]).postln;
			} {
				"POT: % = % ('%') — no master role assigned yet".format(cc - 20, val, ctl["label"]).postln;
			};
		}
		{ true } {
			// Special buttons (cc_momentary/cc_toggle): state lands here for
			// patch-design to consume; for now just remember and log.
			~chaosCCState = ~chaosCCState ?? { IdentityDictionary.new };
			~chaosCCState[cc] = val;
			"SPECIAL: cc % = % ('%')".format(cc, val, ctl["label"]).postln;
		};
	};
};

~chaosAllOff = {
	~chaosVoiceOrder.copy.do { |note| ~chaosReleaseVoice.(note) };
};

~chaosEngineStart = { |s|
	~chaosBus = Bus.audio(s, 2);
	~chaosVoiceGroup = Group.new(s);
	~chaosFxGroup = Group.after(~chaosVoiceGroup);
	~chaosDrone = Synth(\chaosPad, [\out, ~chaosBus, \targetAmp, 0], ~chaosVoiceGroup);
	~chaosMaster = Synth(\chaosMaster, [\in, ~chaosBus, \out, 0], ~chaosFxGroup);
	~chaosLastEvent = Main.elapsedTime;

	// The idle clock: 1 s resolution is plenty for a 90 s timeout.
	SystemClock.sched(1, {
		if (~chaosIsIdle.not and: { (Main.elapsedTime - ~chaosLastEvent) > ~chaosIdleTimeout }) {
			~chaosIsIdle = true;
			~chaosDrone.set(\fadeTime, 10, \targetAmp, ~chaosDroneAmp);
			"IDLE: % s without input, drone fading in (10 s)".format(~chaosIdleTimeout).postln;
		};
		1
	});
	"ENGINE: started (idle timeout % s, max hold % s, voice cap %)"
		.format(~chaosIdleTimeout, ~chaosMaxHold, ~chaosVoiceCap).postln;
};
)
