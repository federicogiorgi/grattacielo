extends RefCounted
class_name TowerEvents

## The things that happen to you rather than because of you: fire, the
## terrorist, the VIP, buried treasure -- and, on the last night of the year,
## Santa Claus.

enum Kind { NONE, FIRE, TERRORIST, VIP, TREASURE, SANTA, WEDDING }

class Fire extends RefCounted:
	var cells: Dictionary = {}        # Vector2i -> intensity 0..1
	var started_min: float = 0.0
	var helicopter: bool = false
	var out: bool = false
	var destroyed: int = 0

class Bomb extends RefCounted:
	var seg: int = 0
	var row: int = 0
	var found: bool = false
	var defused: bool = false
	var demand: int = 0
	var paid: bool = false

var tower: Tower
var rng := RandomNumberGenerator.new()

var fire: Fire = null
var bomb: Bomb = null
var vip_room: int = -1
var vip_happy: bool = false
var vip_visited: bool = false
var santa_x: float = -1.0        # segment position while flying
var santa_active: bool = false
var santa_claimed: bool = false
var santa_year: int = -1
var wedding_done: bool = false

signal announce(text: String)
signal ask(question: String, tag: String)
signal fire_changed()

func _init(p_tower: Tower) -> void:
	tower = p_tower
	rng.randomize()

func has_security() -> bool:
	return tower.count_of_type("security") > 0

# --- rolled once a quarter -------------------------------------------------

func roll_quarter(quarter: int, _year: int, population: int) -> void:
	# Fire and the terrorist only bother towers that have something to protect,
	# which the manual states outright: both need security personnel present.
	if has_security():
		if rng.randf() < Rules.P_FIRE:
			_schedule_fire()
		if rng.randf() < Rules.P_TERRORIST:
			_schedule_bomb()
	if rng.randf() < Rules.P_TREASURE and _has_underground_homes():
		_treasure()
	if population >= 2000 and rng.randf() < Rules.P_VIP:
		_schedule_vip()
	if quarter == Rules.QUARTERS_PER_YEAR:
		pass  # Santa is handled by the clock, not by chance

func _has_underground_homes() -> bool:
	for f in tower.all_of_kind(FacilityDB.Kind.CONDO):
		if f.row < 0:
			return true
	for f in tower.all_of_kind(FacilityDB.Kind.HOTEL):
		if f.row < 0:
			return true
	return false

func _treasure() -> void:
	announce.emit("Scavando, gli operai hanno trovato un tesoro sepolto.")
	pending_treasure = true

var pending_treasure: bool = false
var pending_fire_minute: int = -1
var pending_bomb: bool = false
var pending_vip: bool = false

func _schedule_fire() -> void:
	pending_fire_minute = rng.randi_range(0, 24 * 60 - 1)

func _schedule_bomb() -> void:
	pending_bomb = true

func _schedule_vip() -> void:
	pending_vip = true

# --- daily -----------------------------------------------------------------

func begin_day() -> void:
	if pending_bomb:
		pending_bomb = false
		_start_terrorist()
	if pending_vip:
		pending_vip = false
		_start_vip()

func _start_terrorist() -> void:
	bomb = Bomb.new()
	bomb.demand = Rules.TERRORIST_DEMAND[rng.randi() % Rules.TERRORIST_DEMAND.size()]
	var spot := _random_built_cell()
	bomb.seg = spot.x
	bomb.row = spot.y
	ask.emit("Un terrorista minaccia di piazzare una bomba nella torre.\n"
		+ "Chiede " + Economy.money(bomb.demand) + ". Vuoi pagare?", "bomb_pay")

func _start_vip() -> void:
	var suites := tower.all_of_type("hotel_suite")
	if suites.is_empty():
		return
	var s: Facility = suites[rng.randi() % suites.size()]
	vip_room = s.id
	vip_visited = true
	announce.emit("Un VIP e' arrivato nella tua torre.")

func _random_built_cell() -> Vector2i:
	var tries := 0
	while tries < 400:
		tries += 1
		var c := rng.randi_range(maxi(0, tower.lobby_left), maxi(0, tower.lobby_right))
		var r := rng.randi_range(1, maxi(1, tower.top_built_row))
		if tower.built(c, r):
			return Vector2i(c, r)
	return Vector2i(maxi(0, tower.lobby_left), 1)

# --- fire ------------------------------------------------------------------

func maybe_start_fire(minute_of_day: int) -> void:
	if pending_fire_minute == -1 or fire != null:
		return
	if minute_of_day != pending_fire_minute:
		return
	pending_fire_minute = -1
	start_fire()

func start_fire() -> void:
	if fire != null:
		return
	fire = Fire.new()
	var spot := _random_built_cell()
	fire.cells[spot] = 0.2
	announce.emit("INCENDIO al piano " + FacilityDB.row_label(spot.y) + "!")
	ask.emit("Vuoi chiamare l elicottero dei vigili del fuoco?\nCosta "
		+ Economy.money(Rules.FIRE_HELICOPTER_COST) + ".", "fire_heli")
	fire_changed.emit()

## One step of the blaze. Returns the facilities it destroyed this step.
func step_fire(dt_minutes: float) -> Array:
	var destroyed := []
	if fire == null or fire.out:
		return destroyed
	if fire.helicopter:
		# The helicopter's hose does not miss.
		for k in fire.cells.keys():
			fire.cells[k] = float(fire.cells[k]) - dt_minutes * 0.9
			if float(fire.cells[k]) <= 0.0:
				fire.cells.erase(k)
		if fire.cells.is_empty():
			_extinguish()
		fire_changed.emit()
		return destroyed

	var suppression := _suppression_at()
	var grow := dt_minutes * (0.10 - suppression)
	for k in fire.cells.keys():
		fire.cells[k] = clampf(float(fire.cells[k]) + grow, 0.0, 1.0)
		if float(fire.cells[k]) <= 0.0:
			fire.cells.erase(k)
			continue
		if float(fire.cells[k]) >= 1.0:
			var f := tower.facility_at(k.x, k.y)
			if f != null and not f.wrecked:
				f.wrecked = true
				f.burning = false
				destroyed.append(f)
				fire.destroyed += 1
	if fire.cells.is_empty():
		_extinguish()
		fire_changed.emit()
		return destroyed
	# Spread, radially, as the manual's "radial broadcasting" would have it.
	if grow > 0.0 and rng.randf() < dt_minutes * 0.35:
		var keys := fire.cells.keys()
		var src: Vector2i = keys[rng.randi() % keys.size()]
		var d := [Vector2i(8, 0), Vector2i(-8, 0), Vector2i(0, 1), Vector2i(0, -1)]
		var n: Vector2i = src + d[rng.randi() % d.size()]
		if tower.built(n.x, n.y) and not fire.cells.has(n):
			fire.cells[n] = 0.05
	fire_changed.emit()
	return destroyed

func _suppression_at() -> float:
	# How well security fights it depends on how near the nearest office is;
	# they use the emergency stairs, so distance really costs.
	var best := 1e9
	var focus: Vector2i = fire.cells.keys()[0]
	for f in tower.all_of_type("security"):
		var d := absf(float(f.row - focus.y)) * 3.0 + absf(float(f.centre_seg() - focus.x)) * 0.1
		best = minf(best, d)
	if best > 1e8:
		return 0.0
	return clampf(0.14 - best * 0.0016, 0.0, 0.13)

func call_helicopter() -> void:
	if fire != null:
		fire.helicopter = true

func _extinguish() -> void:
	if fire == null:
		return
	fire.out = true
	announce.emit("L incendio e' spento. Puoi ricostruire i piani distrutti.")
	fire = null

func fire_active() -> bool:
	return fire != null and not fire.out

# --- bomb ------------------------------------------------------------------

func pay_terrorist() -> int:
	if bomb == null:
		return 0
	var d := bomb.demand
	bomb.paid = true
	bomb = null
	announce.emit("Hai pagato. Il terrorista sparisce.")
	return d

## Called every minute while a bomb is live. Security hunts it down.
func step_bomb(minute_of_day: int) -> Dictionary:
	var out := {"exploded": false, "seg": 0, "row": 0}
	if bomb == null or bomb.defused:
		return out
	if not bomb.found:
		var searchers := tower.count_of_type("security")
		var near := 0
		for f in tower.all_of_type("security"):
			if absi(f.row - bomb.row) <= 12:
				near += 1
		var chance := 0.0008 * float(searchers) + 0.004 * float(near)
		if rng.randf() < chance:
			bomb.found = true
			bomb.defused = true
			announce.emit("La sicurezza ha trovato la bomba. Disinnescata.")
			bomb = null
			return out
	if minute_of_day == Rules.BOMB_HOUR * 60:
		out.exploded = true
		out.seg = bomb.seg
		out.row = bomb.row
		announce.emit("La bomba e' esplosa al piano " + FacilityDB.row_label(bomb.row) + ".")
		bomb = null
	return out

# --- Santa Claus -----------------------------------------------------------
#
# The original's Christmas easter egg: on the last night of the year a small
# red dot crosses the sky. Centre on it and there is Santa in his sleigh, and
# clicking on him pays out.

func update_santa(clock: GameClock, dt_seconds: float) -> void:
	if clock.is_last_night_of_year() and clock.hour() == Rules.SANTA_HOUR:
		if not santa_active and santa_year != clock.year:
			santa_active = true
			santa_claimed = false
			santa_year = clock.year
			santa_x = float(FacilityDB.MAP_SEGMENTS) + 20.0
			announce.emit("Senti dei campanelli nel cielo...")
	if santa_active:
		santa_x -= dt_seconds * 26.0
		if santa_x < -40.0:
			santa_active = false

func santa_row() -> int:
	return maxi(tower.top_built_row + 6, 12)

func claim_santa() -> int:
	if not santa_active or santa_claimed:
		return 0
	santa_claimed = true
	announce.emit("Babbo Natale ti lascia un regalo!")
	return Rules.SANTA_GIFT

func to_dict() -> Dictionary:
	return {
		"vip_room": vip_room, "vip_happy": vip_happy, "vip_visited": vip_visited,
		"santa_year": santa_year, "wedding_done": wedding_done,
	}

func from_dict(d: Dictionary) -> void:
	vip_room = int(d.get("vip_room", -1))
	vip_happy = bool(d.get("vip_happy", false))
	vip_visited = bool(d.get("vip_visited", false))
	santa_year = int(d.get("santa_year", -1))
	wedding_done = bool(d.get("wedding_done", false))
