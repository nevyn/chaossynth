// Voice management + the idle/active state machine + the harmonic brain
// (wall-clock atmospheres, chord drift — docs/plans/patch-design.md).
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

// --- Harmonic brain ---
// The chord walks A -> C -> G -> D, all voiced inside A minor pentatonic: any
// two chords can overlap mid-transition without clashing, and the button scale
// below stays consonant with every chord by construction. Drift mechanics live
// in the pad synthdefs (settled by ear 07-15: Day/Deep re-pitch each voice
// only while it's silent, Golden glides over 12 s).
~chaosChordNames = ["A", "C", "G", "D"];
~chaosChords = [
	[45, 52, 57, 60, 64],  // A: A E A C E
	[48, 55, 60, 64, 67],  // C: C G C E G
	[43, 50, 55, 62, 67],  // G: G D G D G (open fifths)
	[50, 57, 62, 67, 69]   // D: D A D G A
];
~chaosChordIndex = 0;
~chaosDriftEvery = 150; // s per chord step: a nearby camp never hears the same minute twice

// Button id -> A minor pentatonic degree across octaves, from A2.
// Contract: note number IS the button id, so this covers ids 0-31.
~chaosNoteToMidinote = { |id| 45 + [0, 3, 5, 7, 10].at(id % 5) + (12 * (id div: 5)) };

// --- Atmospheres ---
// Wall-clock slot -> drone pad (schedule per patch-design.md, Nevyn 07-15).
// Night's own pad is an open design problem; Deep stands in.
// CHAOS_FAKE_HOUR pins the hour for tests. CHAOS_CLOCK_UNTRUSTED=1 is the
// no-RTC power-cut fallback (integration audit): Day's palette at reduced
// volume until pi-image trusts the clock again.
~chaosAtmoPads = (day: \chaosPadDay, golden: \chaosPadGolden, night: \chaosPadDeep, deep: \chaosPadDeep);
~chaosAtmoForHour = { |h|
	case
	{ (h >= 9) and: { h < 17 } } { \day }
	{ (h >= 17) and: { h < 20 } } { \golden }
	{ (h >= 20) or: { h < 1 } } { \night }
	{ \deep }
};
~chaosClockUntrusted = "CHAOS_CLOCK_UNTRUSTED".getenv == "1";
~chaosHourNow = { ("CHAOS_FAKE_HOUR".getenv !? (_.asInteger)) ?? { Date.getDate.hour } };
~chaosAtmoNow = { if (~chaosClockUntrusted) { \day } { ~chaosAtmoForHour.(~chaosHourNow.()) } };
~chaosDroneTarget = { ~chaosDroneAmp * if (~chaosClockUntrusted) { 0.4 } { 1.0 } };
~chaosAtmo = nil;

// Swap the drone to an atmosphere's pad, crossfading over 30 s.
// TODO: the brief asks for ~10 min boundary crossfades; revisit with energy.
~chaosSpawnDrone = { |atmo|
	var def = ~chaosAtmoPads[atmo];
	var old = ~chaosDrone;
	old !? {
		old.set(\fadeTime, 30, \targetAmp, 0);
		SystemClock.sched(35, { old.free; nil });
	};
	~chaosDrone = Synth(def, [\out, ~chaosBus, \targetAmp, 0], ~chaosVoiceGroup);
	~chaosDrone.setn(\notes, ~chaosChords[~chaosChordIndex]);
	if (~chaosIsIdle and: { old.notNil }) {
		~chaosDrone.set(\fadeTime, 30, \targetAmp, ~chaosDroneTarget.());
	};
	~chaosAtmo = atmo;
	"ATMOSPHERE: % (pad %)".format(atmo, def).postln;
};

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
// patch-design via mapping.json's synth{} blobs later. Master volume is
// deliberately NOT here (patch-design decision: the speaker's knob is the
// ceiling, software stays at \chaosMaster's fixed -6 dB); pot 3 is
// unassigned until the sound build gives it its real role.
~chaosPotRoles = [
	{ |v| ~chaosMaster.set(\cutoff, v.linexp(0, 127, 200, 12000)); "cutoff" },
	{ |v| ~chaosMaster.set(\rq, v.linlin(0, 127, 1.0, 0.2)); "resonance" },
	{ |v| ~chaosMaster.set(\verbMix, v.linlin(0, 127, 0, 0.65)); "reverb mix" }
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
	~chaosMaster = Synth(\chaosMaster, [\in, ~chaosBus, \out, 0], ~chaosFxGroup);
	~chaosLastEvent = Main.elapsedTime;

	if (~chaosClockUntrusted) {
		"CLOCK: untrusted (CHAOS_CLOCK_UNTRUSTED=1) — Day palette, capped volume".postln;
	};
	~chaosSpawnDrone.(~chaosAtmoNow.());

	// Boot straight into idle: nobody has touched it yet, by definition. This
	// is what makes "drone within a minute of power" in installation.md true.
	~chaosIsIdle = true;
	~chaosDrone.set(\fadeTime, 10, \targetAmp, ~chaosDroneTarget.());
	"IDLE: starting idle, drone fading in (10 s)".postln;

	// The idle clock: 1 s resolution is plenty for a 90 s timeout.
	SystemClock.sched(1, {
		if (~chaosIsIdle.not and: { (Main.elapsedTime - ~chaosLastEvent) > ~chaosIdleTimeout }) {
			~chaosIsIdle = true;
			~chaosDrone.set(\fadeTime, 10, \targetAmp, ~chaosDroneTarget.());
			"IDLE: % s without input, drone fading in (10 s)".format(~chaosIdleTimeout).postln;
		};
		1
	});

	// Chord drift: harmless while ducked, lovely while idle.
	SystemClock.sched(~chaosDriftEvery, {
		~chaosChordIndex = (~chaosChordIndex + 1) % ~chaosChords.size;
		~chaosDrone !? { ~chaosDrone.setn(\notes, ~chaosChords[~chaosChordIndex]) };
		"DRIFT: chord -> %".format(~chaosChordNames[~chaosChordIndex]).postln;
		~chaosDriftEvery
	});

	// Atmosphere clock: check the hour every minute, swap pads on slot change.
	SystemClock.sched(60, {
		var atmo = ~chaosAtmoNow.();
		if (atmo != ~chaosAtmo) { ~chaosSpawnDrone.(atmo) };
		60
	});

	"ENGINE: started (idle timeout % s, max hold % s, voice cap %, atmosphere %)"
		.format(~chaosIdleTimeout, ~chaosMaxHold, ~chaosVoiceCap, ~chaosAtmo).postln;
};
)
