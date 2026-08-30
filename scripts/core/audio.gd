extends Node

## Sound, synthesized at startup so the project carries no audio files.
##
## The manual gives the Options menu three separate toggles -- Elevators,
## Background and Events -- so those are the three buses here, and each can be
## switched off independently exactly as it could in 1994.

const RATE := 22050

var elevators_on := true
var background_on := true
var events_on := true

var _bank: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
const VOICES := 12

func _ready() -> void:
	for i in range(VOICES):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_build_bank()

# --- the bank --------------------------------------------------------------

func _build_bank() -> void:
	# Lifts: a soft two-note chime as the doors open, and a low hum.
	_bank["ding"] = _tone([[988.0, 0.10], [1319.0, 0.22]], 0.30, 0.22)
	_bank["arrive"] = _tone([[660.0, 0.14], [880.0, 0.20]], 0.34, 0.20)
	# Money: the cash register the info bar mentions.
	_bank["cash"] = _tone([[1568.0, 0.05], [2093.0, 0.05], [1568.0, 0.16]], 0.26, 0.18)
	_bank["spend"] = _tone([[392.0, 0.09], [294.0, 0.16]], 0.25, 0.20)
	# Construction: workmen putting up walls.
	_bank["build"] = _noise(0.18, 0.22, 1400.0)
	_bank["wreck"] = _noise(0.34, 0.30, 500.0)
	# Events.
	_bank["fanfare"] = _tone([[523.0, 0.14], [659.0, 0.14], [784.0, 0.14],
		[1047.0, 0.34]], 0.55, 0.22)
	_bank["alarm"] = _tone([[880.0, 0.18], [740.0, 0.18], [880.0, 0.18],
		[740.0, 0.24]], 0.60, 0.24)
	_bank["bad"] = _tone([[330.0, 0.18], [247.0, 0.30]], 0.42, 0.22)
	# Santa, who arrives to sleigh bells.
	_bank["bells"] = _bells()

## A short melodic blip: a list of [frequency, seconds] with a soft envelope.
func _tone(notes: Array, total: float, gain: float) -> AudioStreamWAV:
	var n := int(total * float(RATE))
	var data := PackedByteArray()
	data.resize(n * 2)
	var t := 0.0
	var idx := 0
	for note in notes:
		var freq: float = note[0]
		var dur: float = note[1]
		var count := int(dur * float(RATE))
		for i in range(count):
			if idx >= n:
				break
			var u := float(i) / float(maxi(count, 1))
			# quick attack, exponential tail -- warm rather than bright
			var env: float = minf(u * 22.0, 1.0) * exp(-3.4 * u)
			var ph := TAU * freq * (float(i) / float(RATE))
			var s: float = sin(ph) * 0.72 + sin(ph * 2.0) * 0.20 + sin(ph * 3.0) * 0.08
			_put(data, idx, s * env * gain)
			idx += 1
		t += dur
	while idx < n:
		_put(data, idx, 0.0)
		idx += 1
	return _wav(data)

## Filtered noise, for hammering and for things falling down.
func _noise(total: float, gain: float, cutoff: float) -> AudioStreamWAV:
	var n := int(total * float(RATE))
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var prev := 0.0
	var a: float = clampf(cutoff / float(RATE), 0.02, 0.9)
	for i in range(n):
		var u := float(i) / float(n)
		var env: float = minf(u * 40.0, 1.0) * exp(-5.0 * u)
		prev = prev + a * (rng.randf_range(-1.0, 1.0) - prev)
		_put(data, i, prev * env * gain)
	return _wav(data)

## Sleigh bells: a cluster of high partials, jingling.
func _bells() -> AudioStreamWAV:
	var total := 1.6
	var n := int(total * float(RATE))
	var data := PackedByteArray()
	data.resize(n * 2)
	var parts := [2093.0, 2637.0, 3136.0, 3520.0]
	for i in range(n):
		var tt := float(i) / float(RATE)
		var jingle: float = 0.5 + 0.5 * sin(TAU * 6.0 * tt)
		var s := 0.0
		for k in range(parts.size()):
			s += sin(TAU * float(parts[k]) * tt) / float(parts.size())
		var env: float = exp(-1.1 * tt) * jingle
		_put(data, i, s * env * 0.16)
	return _wav(data)

func _put(data: PackedByteArray, i: int, v: float) -> void:
	var s := int(clampf(v, -1.0, 1.0) * 32000.0)
	data.encode_s16(i * 2, s)

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

# --- playing ---------------------------------------------------------------

func play(name: String, channel: String = "events", volume_db: float = -6.0) -> void:
	match channel:
		"elevators":
			if not elevators_on:
				return
		"background":
			if not background_on:
				return
		_:
			if not events_on:
				return
	var s: AudioStreamWAV = _bank.get(name)
	if s == null:
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = s
	p.volume_db = volume_db
	p.play()

## Hook the game up. Called once by Main.
func listen(game: Node) -> void:
	game.econ.transaction.connect(func(_label: String, amount: int):
		play("cash" if amount > 0 else "spend", "events", -12.0))
	game.star_changed.connect(func(_s): play("fanfare", "events", -3.0))
	game.events.announce.connect(func(text: String):
		var low := text.to_lower()
		if low.contains("incendio") or low.contains("bomba") or low.contains("terrorist"):
			play("alarm", "events", -4.0)
		elif low.contains("campanelli"):
			play("bells", "events", -5.0)
		elif low.contains("scarafaggi") or low.contains("non e' soddisfatto"):
			play("bad", "events", -8.0))
