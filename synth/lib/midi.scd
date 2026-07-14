// MIDI input: connect to the source named "Chaossynth" (docs/midi-contract.md),
// tolerating it appearing late and re-appearing after a cable yank.
//
// CoreMIDI/ALSA source lists are snapshots from MIDIClient.init, so the only
// way to see arrivals/departures is to re-init and rescan: every 2 s while
// disconnected, every 10 s while connected. A rescan drops connections for a
// few ms; a NoteOff lost in that window is caught by the engine's max-hold.
(
~chaosSrcIDs = Set.new; // uids of connected Chaossynth sources

// macOS gotcha (cost us an afternoon): the FIRST MIDIClient.init must run on
// the main thread, i.e. here at load time. If it first runs inside a clock
// task, CoreMIDI silently reports zero sources forever. Re-inits from clock
// tasks are fine once this one has happened.
MIDIClient.init(verbose: false);

~chaosMidiRescan = {
	var found, foundIDs;
	MIDIClient.init(verbose: false); // init disposes + rescans internally
	found = MIDIClient.sources.select { |src|
		(src.device == "Chaossynth") or: { src.name == "Chaossynth" }
	};
	found.do { |src| MIDIIn.connect(0, src) };
	foundIDs = Set.newFrom(found.collect(_.uid));
	if (foundIDs.notEmpty and: { ~chaosSrcIDs.isEmpty }) {
		"MIDI: connected to 'Chaossynth' (uid %)".format(foundIDs.asArray).postln;
	};
	if (foundIDs.isEmpty and: { ~chaosSrcIDs.notEmpty }) {
		"MIDI: 'Chaossynth' source LOST — releasing voices, waiting for it to return".postln;
		~chaosAllOff.();
	};
	~chaosSrcIDs = foundIDs;
};

~chaosMidiStart = {
	// Channel 1 only (chan 0 here), and only from Chaossynth-named sources.
	var fromPanel = { |chan, srcID| (chan == 0) and: { ~chaosSrcIDs.includes(srcID) } };

	MIDIFunc.noteOn({ |vel, note, chan, srcID|
		if (fromPanel.(chan, srcID)) {
			// vel-0 NoteOn is NoteOff in disguise (common firmware shortcut)
			if (vel > 0) { ~chaosNoteOn.(note) } { ~chaosNoteOff.(note) };
		};
	});
	MIDIFunc.noteOff({ |vel, note, chan, srcID|
		if (fromPanel.(chan, srcID)) { ~chaosNoteOff.(note) };
	});
	MIDIFunc.cc({ |val, cc, chan, srcID|
		if (fromPanel.(chan, srcID)) { ~chaosCC.(cc, val) };
	});

	SystemClock.sched(0, {
		try { ~chaosMidiRescan.() } { |err|
			"MIDI: rescan failed (%) — retrying".format(err.errorString).postln;
		};
		if (~chaosSrcIDs.isEmpty) { 2 } { 10 } // reschedule
	});
	"MIDI: watching for source named 'Chaossynth'".postln;
};
)
