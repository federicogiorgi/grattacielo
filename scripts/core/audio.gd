extends Node

## The sound of the tower: one-shots, a layered ambience bed, and music.
##
## Everything is addressed by logical name through AudioManifest; nothing here
## knows a file path. The recordings were cut from the Sonniss GDC bundle (see
## assets/audio/CREDITS.md); the music is synthesized by tools/make_music.py.
##
## The manual gives the Options menu three independent toggles -- Elevators,
## Background and Events -- so those are three real buses, and Music is a
## fourth because a soundtrack you cannot silence is a soundtrack you come to
## resent.

const BUSES := ["Elevators", "Background", "Events", "Music"]

var enabled := {"elevators": true, "background": true, "events": true, "music": true}

var _bus_index: Dictionary = {}          # channel name -> bus id
var _cache: Dictionary = {}              # resource path -> AudioStream or null
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
const VOICES := 14

# One player per bed, each fading independently to its own target.
var _beds: Dictionary = {}               # name -> {player, target_db}
# Two music players, so one can fade in while the other fades out.
var _music: Array[AudioStreamPlayer] = []
var _music_now := 0
var _track := ""

var _wired: bool = false

## True when there is no audio device to speak of -- a headless test run.
## Without this the mix starts up during every check, loads three ambiences
## nobody can hear, and leaves them held open at shutdown.
##
## The command line is the authority, not DisplayServer.get_name(): under
## --headless with a --script the display driver still reported itself as the
## platform's, so the mix started anyway and the first lift chime reached into
## an empty voice pool. Every method below is guarded on its own array as well,
## because "the sound engine is not set up" is a state worth surviving rather
## than a state worth crashing in.
var silent := false

func _ready() -> void:
	silent = DisplayServer.get_name() == "headless" 		or OS.get_cmdline_args().has("--headless")
	if silent:
		set_process(false)
		return
	_make_buses()
	for i in range(VOICES):
		var p := AudioStreamPlayer.new()
		p.bus = "Events"
		add_child(p)
		_voices.append(p)
	for i in range(2):
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = AudioManifest.OFF_DB
		add_child(m)
		_music.append(m)
	set_process(true)

## Streams are loaded the first time something asks for them, not at startup.
## Preloading them was tidier to read and meant a headless test that never
## plays a note still ended with a dozen resources held open at shutdown --
## the kind of noise that trains you to ignore the next real one.
func _stream(path: String, looping: bool) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		_cache[path] = null
		return null
	var s: AudioStream = load(path)
	if looping and s is AudioStreamOggVorbis:
		s.loop = true
	_cache[path] = s
	return s

func _make_buses() -> void:
	for name in BUSES:
		var idx := AudioServer.get_bus_index(name)
		if idx == -1:
			idx = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, name)
			AudioServer.set_bus_send(idx, "Master")
		_bus_index[name.to_lower()] = idx

func _bus_for(channel: String) -> String:
	match channel:
		"elevators": return "Elevators"
		"background": return "Background"
		"music": return "Music"
		_: return "Events"

# --- one-shots -------------------------------------------------------------

func play(name: String, channel: String = "events", volume_db: float = 0.0) -> void:
	if silent or _voices.is_empty():
		return
	var spec: Dictionary = AudioManifest.SFX.get(name, {})
	if spec.is_empty():
		return
	var ch := String(spec.get("channel", channel))
	if not enabled.get(ch, true):
		return
	var stream := _stream(AudioManifest.sfx_path(name), false)
	if stream == null:
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.bus = _bus_for(ch)
	p.stream = stream
	p.volume_db = float(spec.get("db", -10.0)) + volume_db
	p.pitch_scale = randf_range(0.97, 1.03)   # so a repeated sound is not a loop
	p.play()

# --- the running mix -------------------------------------------------------

func _process(delta: float) -> void:
	if silent or _music.is_empty():
		return
	var g = get_node_or_null(^"/root/Game")
	if g == null or g.clock == null:
		return
	_choose_music(g)
	_choose_beds(g)
	_fade(delta)

func _choose_music(g) -> void:
	if not enabled["music"] or AudioManifest.MUSIC.is_empty():
		_track = ""
		return
	var want := AudioManifest.track_for(g.clock.minute_of_day(), g.clock.is_weekend())
	if want == _track:
		return
	var path := AudioManifest.music_path(want)
	if _stream(path, true) == null:
		return
	_track = want
	var nxt := 1 - _music_now
	_music[nxt].stream = _stream(path, true)
	_music[nxt].volume_db = AudioManifest.OFF_DB
	_music[nxt].play()
	_music_now = nxt

## The bed is a mix, not a track: the city outside, the concourse inside, the
## weather and the fire all fade up and down independently.
func _choose_beds(g) -> void:
	var h := float(g.clock.minute_of_day()) / 60.0
	var day := h >= 6.0 and h < 19.5
	var pop: float = float(g.tower.population())
	var on: bool = enabled["background"]

	_want("amb_day", day and on)
	_want("amb_night", not day and on)
	# The concourse only sounds busy once there is a crowd to make the noise.
	var busy: bool = on and h >= 7.0 and h < 21.0 and pop > 120.0
	_want("amb_lobby", busy, minf(pop / 3000.0, 1.0))
	_want("amb_rain", on and g.weather == "rain")
	_want("amb_fire", on and g.events.fire_active())

func _want(name: String, playing: bool, scale: float = 1.0) -> void:
	var bed: Dictionary = _beds.get(name, {})
	if bed.is_empty():
		if not playing:
			return          # never heard, never loaded
		var stream := _stream(AudioManifest.bed_path(name), true)
		if stream == null:
			return
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = "Background"
		p.volume_db = AudioManifest.OFF_DB
		add_child(p)
		p.play()
		bed = {"player": p, "target": AudioManifest.OFF_DB}
		_beds[name] = bed
	if not playing:
		bed["target"] = AudioManifest.OFF_DB
		return
	var base: float = float(AudioManifest.BEDS[name]["db"])
	# scale 0..1 maps to a further 18 dB of headroom below the bed's own level
	bed["target"] = base - (1.0 - clampf(scale, 0.0, 1.0)) * 18.0

func _fade(delta: float) -> void:
	for name in _beds:
		var bed: Dictionary = _beds[name]
		var p: AudioStreamPlayer = bed["player"]
		var step := 60.0 * delta / AudioManifest.FADE_BED
		p.volume_db = move_toward(p.volume_db, float(bed["target"]), step)
		if p.volume_db <= AudioManifest.OFF_DB + 0.5 and p.playing:
			p.stream_paused = true
		elif p.volume_db > AudioManifest.OFF_DB + 0.5 and p.stream_paused:
			p.stream_paused = false
	for i in range(_music.size()):
		var p2: AudioStreamPlayer = _music[i]
		var target := AudioManifest.OFF_DB
		if i == _music_now and _track != "" and enabled["music"]:
			target = float(AudioManifest.MUSIC[_track]["db"])
		var step2 := 60.0 * delta / AudioManifest.FADE_MUSIC
		p2.volume_db = move_toward(p2.volume_db, target, step2)
		if p2.volume_db <= AudioManifest.OFF_DB + 0.5 and p2.playing and i != _music_now:
			p2.stop()

# --- hooking the game up ---------------------------------------------------

## Called once by Main. Connects the things worth hearing.
func listen(game: Node) -> void:
	if _wired:
		return
	_wired = true
	game.econ.transaction.connect(func(_label: String, amount: int):
		play("cash" if amount > 0 else "spend"))
	game.star_changed.connect(func(_s): play("fanfare"))
	game.events.cue.connect(func(name: String, gain: float): play(name, "events", gain))

## Godot tears the tree down before it checks for stragglers, so the loaded
## streams have to be let go here or every headless run ends with a page of
## "resources still in use" that nobody reads and that hides a real one.
func shutdown() -> void:
	_exit_tree()

func _exit_tree() -> void:
	for name in _beds:
		var p: AudioStreamPlayer = _beds[name]["player"]
		p.stop()
		p.stream = null
	for m in _music:
		m.stop()
		m.stream = null
	for v in _voices:
		v.stop()
		v.stream = null
	_beds.clear()
	_music.clear()
	_voices.clear()
	_cache.clear()

## What is actually audible right now, for the screenshot tool and for anybody
## wondering why the tower is quiet.
func mix_report() -> String:
	var parts := PackedStringArray()
	parts.append("music=" + (_track if _track != "" else "-"))
	for name in _beds:
		var p: AudioStreamPlayer = _beds[name]["player"]
		if p.volume_db > AudioManifest.OFF_DB + 1.0:
			parts.append("%s %.0fdB" % [name, p.volume_db])
	parts.append("streams=%d loaded" % _cache.size())
	return ", ".join(parts)

func set_channel(channel: String, on: bool) -> void:
	enabled[channel] = on
	if channel == "music" and not on:
		_track = ""
