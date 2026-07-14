// mapping.json loading + hot reload. Schema: docs/midi-contract.md (version 1).
(
// sclang's JSON parser returns scalars as Strings; coerce on the way out.
~cInt = { |v| v.asString.asInteger };

~chaosMapping = nil;     // parsed dict, nil until first successful load
~chaosNoteMap = nil;     // note number -> control (buttons, midi.type "note")
~chaosCCMap = nil;       // cc number -> control (pots + special buttons)
~chaosMappingPath = nil;
~chaosMappingMtime = 0;

// Load (or reload) the file. Any failure logs loudly and keeps the previous
// mapping — a half-written file during deploy must not take the sound down.
~chaosMappingLoad = { |path|
	var text, data, noteMap, ccMap, version;
	~chaosMappingPath = path;
	try {
		text = File.readAllString(path);
		data = text.parseJSON;
		if (data.isNil) { Error("parse failed").throw };
		version = ~cInt.(data["version"]);
		if (version != 1) {
			"MAPPING: REFUSED unknown version % in %".format(data["version"], path).postln;
		} {
			noteMap = IdentityDictionary.new;
			ccMap = IdentityDictionary.new;
			data["controls"].do { |ctl|
				var type = ctl["midi"]["type"].asString;
				case
				{ type == "note" } { noteMap[~cInt.(ctl["midi"]["note"])] = ctl }
				{ ["cc", "cc_momentary", "cc_toggle"].includesEqual(type) }
					{ ccMap[~cInt.(ctl["midi"]["cc"])] = ctl }
				{ "MAPPING: ignoring control '%' with unknown midi.type '%'"
					.format(ctl["label"], type).postln };
			};
			~chaosMapping = data;
			~chaosNoteMap = noteMap;
			~chaosCCMap = ccMap;
			~chaosMappingMtime = File.mtime(path);
			"MAPPING: loaded % controls (version %) from %"
				.format(data["controls"].size, version, path).postln;
		};
	} { |err|
		"MAPPING: FAILED to load % (%) — keeping previous mapping"
			.format(path, err.errorString).postln;
	};
};

// Poll mtime every ~2 s; reload on change. Running voices are untouched —
// only the lookup tables swap.
~chaosMappingWatch = {
	SystemClock.sched(2, {
		var mtime;
		try {
			mtime = File.mtime(~chaosMappingPath);
			if (mtime != ~chaosMappingMtime) {
				~chaosMappingMtime = mtime;
				"MAPPING: change detected, reloading".postln;
				~chaosMappingLoad.(~chaosMappingPath);
			};
		} { |err|
			"MAPPING: watch error (%)".format(err.errorString).postln;
		};
		2 // reschedule
	});
};
)
