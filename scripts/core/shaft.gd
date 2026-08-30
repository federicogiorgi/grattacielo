extends RefCounted
class_name Shaft

## An elevator shaft and its cars. The heart of the game, as Yoot Saito
## intended: everything else is scenery around how well these are scheduled.

enum Mode { LOCAL, EXPRESS_TOP, EXPRESS_BOTTOM }
enum CarState { IDLE, MOVING, DOORS }

# The seven bands of the day the schedule buttons sit between.
const BAND_STARTS := [0, 7, 9, 12, 15, 18, 21]

class Car extends RefCounted:
	var pos: float = 0.0            # fractional row
	var home_row: int = 0           # the "waiting floor"
	var dir: int = 0                # -1 down, 0 idle, +1 up
	var state: int = CarState.IDLE
	var door_minutes: float = 0.0
	var riders: Array[int] = []     # sim ids
	var stops: Dictionary = {}      # row -> true, where this car must stop
	var full: bool = false

	func row() -> int:
		return int(round(pos))

var id: int = -1
var type: String = "elevator"
var seg: int = 0
var bottom_row: int = 0
var top_row: int = 0
var cars: Array[Car] = []
var disabled_rows: Dictionary = {}   # row -> true, service switched off
var show: bool = true

# Scheduling, as set in the elevator window.
var modes_wd: Array[int] = []
var modes_we: Array[int] = []
var wait_response: int = 5           # floors closer than a moving car
var floor_departure: int = 0         # seconds a car pauses before leaving

# Hall calls: row -> {"up": [sim ids], "down": [sim ids]}
var queues: Dictionary = {}

func _init(p_id: int = -1, p_type: String = "elevator", p_seg: int = 0,
		p_bottom: int = 0, p_top: int = 0) -> void:
	id = p_id
	type = p_type
	seg = p_seg
	bottom_row = p_bottom
	top_row = p_top
	modes_wd.resize(BAND_STARTS.size())
	modes_we.resize(BAND_STARTS.size())
	modes_wd.fill(Mode.LOCAL)
	modes_we.fill(Mode.LOCAL)

func def() -> Dictionary:
	return FacilityDB.DEFS[type]

func width() -> int:
	return def().get("w", 4)

func car_capacity() -> int:
	return def().get("capacity", 21)

func is_express() -> bool:
	return type == "express_elevator"

func is_service() -> bool:
	return type == "service_elevator"

func span() -> int:
	return top_row - bottom_row + 1

func max_span() -> int:
	return def().get("max_span", 30)

func covers_row(r: int) -> bool:
	return r >= bottom_row and r <= top_row

## Express cars only stop at sky lobbies and basements; everything else stops
## anywhere it is not switched off.
func serves_row(r: int) -> bool:
	if not covers_row(r):
		return false
	if disabled_rows.has(r):
		return false
	if is_express():
		return r < 0 or r == 0 or (r + 1) % Rules.SKY_LOBBY_EVERY == 0
	return true

static func is_sky_lobby_row(r: int) -> bool:
	return r == 0 or (r > 0 and (r + 1) % Rules.SKY_LOBBY_EVERY == 0)

func band_for(minute_of_day: int) -> int:
	var h := minute_of_day / 60
	var b := 0
	for i in range(BAND_STARTS.size()):
		if h >= BAND_STARTS[i]:
			b = i
	return b

func mode_at(minute_of_day: int, weekend: bool) -> int:
	var b := band_for(minute_of_day)
	return modes_we[b] if weekend else modes_wd[b]

func speed_floors_per_min() -> float:
	return Rules.EXPRESS_FLOORS_PER_MIN if is_express() else Rules.ELEVATOR_FLOORS_PER_MIN

# --- queues ----------------------------------------------------------------

func queue_at(r: int) -> Dictionary:
	if not queues.has(r):
		queues[r] = {"up": [] as Array[int], "down": [] as Array[int]}
	return queues[r]

func enqueue(sim_id: int, r: int, going_up: bool) -> void:
	var q := queue_at(r)
	var key := "up" if going_up else "down"
	if not q[key].has(sim_id):
		q[key].append(sim_id)

func dequeue(sim_id: int) -> void:
	for r in queues:
		queues[r]["up"].erase(sim_id)
		queues[r]["down"].erase(sim_id)

func waiting_at(r: int) -> int:
	if not queues.has(r):
		return 0
	return queues[r]["up"].size() + queues[r]["down"].size()

func total_waiting() -> int:
	var n := 0
	for r in queues:
		n += queues[r]["up"].size() + queues[r]["down"].size()
	return n

func riders_total() -> int:
	var n := 0
	for c in cars:
		n += c.riders.size()
	return n

# --- cars ------------------------------------------------------------------

func add_car(home: int) -> Car:
	var c := Car.new()
	c.home_row = clampi(home, bottom_row, top_row)
	c.pos = float(c.home_row)
	cars.append(c)
	return c

func to_dict() -> Dictionary:
	var car_data := []
	for c in cars:
		car_data.append({"home": c.home_row, "pos": c.pos})
	var dis := []
	for r in disabled_rows:
		dis.append(r)
	return {
		"id": id, "type": type, "seg": seg, "bottom": bottom_row, "top": top_row,
		"cars": car_data, "disabled": dis, "wait_response": wait_response,
		"floor_departure": floor_departure,
		"modes_wd": modes_wd, "modes_we": modes_we, "show": show,
	}

static func from_dict(d: Dictionary) -> Shaft:
	var s := Shaft.new(int(d["id"]), String(d["type"]), int(d["seg"]),
		int(d["bottom"]), int(d["top"]))
	for cd in d.get("cars", []):
		var c := s.add_car(int(cd.get("home", s.bottom_row)))
		c.pos = float(cd.get("pos", c.home_row))
	for r in d.get("disabled", []):
		s.disabled_rows[int(r)] = true
	s.wait_response = int(d.get("wait_response", 5))
	s.floor_departure = int(d.get("floor_departure", 0))
	s.show = bool(d.get("show", true))
	var mwd: Array = d.get("modes_wd", [])
	for i in range(min(mwd.size(), s.modes_wd.size())):
		s.modes_wd[i] = int(mwd[i])
	var mwe: Array = d.get("modes_we", [])
	for i in range(min(mwe.size(), s.modes_we.size())):
		s.modes_we[i] = int(mwe[i])
	return s
