extends RefCounted
class_name Sim

## One person. Most of them sit quietly inside a facility costing nothing;
## only the ones actually travelling are stepped by the simulation.

enum State { RESTING, WALKING, WAITING, RIDING, STAIRS, OUTSIDE, ARRIVED }

enum Purpose { COMMUTE_IN, COMMUTE_OUT, LUNCH, DINNER, SHOP, SHOW, HOME,
	CHECK_IN, CHECK_OUT, WORK_ROUND, PARTY, SHOP_AFTER_SHOW }

var id: int = -1
var person_name: String = ""      # only set if the player named them
var role: String = "office"
var home_id: int = -1             # the facility they belong to
var work_id: int = -1

var state: int = State.OUTSIDE
var row: int = 0
var seg: float = 0.0
var stress: float = 0.0

var dest_id: int = -1
var purpose: int = Purpose.COMMUTE_IN

var route: Array = []             # legs from Router
var leg: int = 0
var leg_start_min: float = 0.0
var leg_end_min: float = 0.0
var leg_from_seg: float = 0.0
var leg_to_seg: float = 0.0

var shaft_id: int = -1            # while waiting or riding
var target_row: int = 0
var wait_started_min: float = 0.0

var is_vip: bool = false
var is_staff: bool = false
var doomed: bool = false          # leaving the tower for good

func display_name() -> String:
	if person_name != "":
		return person_name
	return Names.ROLES.get(role, "Persona")

func colour() -> Color:
	if person_name != "":
		return Color(0.20, 0.45, 0.95)
	if is_vip:
		return Color(0.95, 0.80, 0.15)
	return Rules.stress_colour(stress)

func add_stress(amount: float) -> void:
	stress = clampf(stress + amount, 0.0, Rules.STRESS_MAX)

func relax() -> void:
	stress = maxf(0.0, stress - Rules.STRESS_RELIEF_AT_REST)

func to_dict() -> Dictionary:
	return {
		"id": id, "name": person_name, "role": role, "home": home_id,
		"work": work_id, "row": row, "seg": seg, "stress": stress,
		"state": state, "vip": is_vip, "staff": is_staff,
	}

static func from_dict(d: Dictionary) -> Sim:
	var s := Sim.new()
	s.id = int(d["id"])
	s.person_name = String(d.get("name", ""))
	s.role = String(d.get("role", "office"))
	s.home_id = int(d.get("home", -1))
	s.work_id = int(d.get("work", -1))
	s.row = int(d.get("row", 0))
	s.seg = float(d.get("seg", 0.0))
	s.stress = float(d.get("stress", 0.0))
	s.state = int(d.get("state", State.RESTING))
	s.is_vip = bool(d.get("vip", false))
	s.is_staff = bool(d.get("staff", false))
	return s
