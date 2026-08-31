extends SceneTree

## Every sound the game can ask for must exist, load, and be the right shape.
##
## A missing effect is silent, and silence is exactly what a sound bug looks
## like -- there is no error, nothing crashes, and you find out months later
## that the lift never dinged. So the manifest is checked against the disk.

var failures := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)

func _initialize() -> void:
	print("--- audio ---")
	_files()
	_beds_loop()
	_music_choice()
	_channels()
	print("--- %d failure(s) ---" % failures)
	quit(1 if failures > 0 else 0)

func _files() -> void:
	for name in AudioManifest.SFX:
		var path := AudioManifest.sfx_path(name)
		ok(ResourceLoader.exists(path), "sfx %s is missing (%s)" % [name, path])
		var s = load(path) if ResourceLoader.exists(path) else null
		ok(s != null, "sfx %s failed to load" % name)
		if s != null:
			ok(s.get_length() > 0.05, "sfx %s is empty" % name)
			ok(s.get_length() < 9.0, "sfx %s is %.1fs, too long for a one-shot"
				% [name, s.get_length()])
	for name in AudioManifest.BEDS:
		var path2 := AudioManifest.bed_path(name)
		ok(ResourceLoader.exists(path2), "bed %s is missing (%s)" % [name, path2])
	for name in AudioManifest.MUSIC:
		var path3 := AudioManifest.music_path(name)
		ok(ResourceLoader.exists(path3), "music %s is missing (%s)" % [name, path3])

func _beds_loop() -> void:
	# A bed that does not loop leaves the tower silent after half a minute.
	for name in AudioManifest.BEDS:
		var path := AudioManifest.bed_path(name)
		if not ResourceLoader.exists(path):
			continue
		var s = load(path)
		ok(s is AudioStreamOggVorbis, "bed %s should be ogg vorbis" % name)
		if s is AudioStreamOggVorbis:
			s.loop = true
			ok(s.loop, "bed %s can be set to loop" % name)
		ok(s.get_length() > 6.0, "bed %s is only %.1fs, too short to hide the seam"
			% [name, s.get_length()])
	for name in AudioManifest.MUSIC:
		var path2 := AudioManifest.music_path(name)
		if not ResourceLoader.exists(path2):
			continue
		var m = load(path2)
		ok(m.get_length() > 25.0, "music %s is only %.1fs; it will wear out"
			% [name, m.get_length()])

func _music_choice() -> void:
	# Night, the two weekday rush hours, and the rest of the day.
	ok(AudioManifest.track_for(2 * 60, false) == "night", "2am is night music")
	ok(AudioManifest.track_for(22 * 60, false) == "night", "10pm is night music")
	ok(AudioManifest.track_for(8 * 60, false) == "rush", "8am on a weekday is rush")
	ok(AudioManifest.track_for(18 * 60, false) == "rush", "6pm on a weekday is rush")
	ok(AudioManifest.track_for(8 * 60, true) == "day", "8am at the weekend is not rush")
	ok(AudioManifest.track_for(13 * 60, false) == "day", "the afternoon is day music")
	for t in ["day", "night", "rush"]:
		ok(AudioManifest.MUSIC.has(t), "there is a %s track to play" % t)

func _channels() -> void:
	# Every effect must name a channel the Options menu can actually silence.
	var valid := ["elevators", "background", "events"]
	for name in AudioManifest.SFX:
		var ch := String(AudioManifest.SFX[name].get("channel", ""))
		ok(ch in valid, "sfx %s has channel %s, which no toggle covers" % [name, ch])
	# And nothing may be so loud that it clips the bus on its own.
	for name in AudioManifest.SFX:
		var db := float(AudioManifest.SFX[name]["db"])
		ok(db <= 0.0, "sfx %s is at %+.1f dB, above unity" % [name, db])
	for name in AudioManifest.BEDS:
		ok(float(AudioManifest.BEDS[name]["db"]) <= -8.0,
			"bed %s is too loud to sit under the game" % name)
	for name in AudioManifest.MUSIC:
		ok(float(AudioManifest.MUSIC[name]["db"]) <= -12.0,
			"music %s is too loud to sit under the game" % name)
