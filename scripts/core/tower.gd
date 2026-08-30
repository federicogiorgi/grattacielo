extends RefCounted
class_name Tower

## The building itself: a grid of segments by floors, the facilities placed on
## it, and every rule about what may go where.
##
## Rows run from ROW_MIN (the deepest basement) to ROW_MAX (floor 100).
## Row 0 is the ground floor and is lobby only, as in the original.

const VOID := 0
const FLOOR := 1
const LOBBY := 2

const ROWS := FacilityDB.FLOORS_ABOVE + FacilityDB.FLOORS_BELOW
const COLS := FacilityDB.MAP_SEGMENTS

var structure := PackedByteArray()
var occupancy := PackedInt32Array()   # facility id per cell, -1 empty
var shaft_grid := PackedInt32Array()  # shaft id per cell, -1 empty

var facilities: Dictionary = {}       # id -> Facility
var shafts: Dictionary = {}           # id -> Shaft
var next_id: int = 1

var lobby_left: int = -1
var lobby_right: int = -1

var top_built_row: int = -1
var bottom_built_row: int = 1

# Rebuilt lazily; the router asks for it.
var _transport_index: Dictionary = {}
var _index_dirty: bool = true

signal structure_changed()

func _init() -> void:
	structure.resize(ROWS * COLS)
	occupancy.resize(ROWS * COLS)
	shaft_grid.resize(ROWS * COLS)
	structure.fill(VOID)
	for i in range(occupancy.size()):
		occupancy[i] = -1
		shaft_grid[i] = -1

# --- grid access -----------------------------------------------------------

func idx(seg: int, row: int) -> int:
	return (row - FacilityDB.ROW_MIN) * COLS + seg

func in_bounds(seg: int, row: int) -> bool:
	return seg >= 0 and seg < COLS and row >= FacilityDB.ROW_MIN and row <= FacilityDB.ROW_MAX

func structure_at(seg: int, row: int) -> int:
	if not in_bounds(seg, row):
		return VOID
	return structure[idx(seg, row)]

func built(seg: int, row: int) -> bool:
	return structure_at(seg, row) != VOID

func facility_id_at(seg: int, row: int) -> int:
	if not in_bounds(seg, row):
		return -1
	return occupancy[idx(seg, row)]

func facility_at(seg: int, row: int) -> Facility:
	var fid := facility_id_at(seg, row)
	return facilities.get(fid, null)

func shaft_id_at(seg: int, row: int) -> int:
	if not in_bounds(seg, row):
		return -1
	return shaft_grid[idx(seg, row)]

func shaft_at(seg: int, row: int) -> Shaft:
	return shafts.get(shaft_id_at(seg, row), null)

func cell_free(seg: int, row: int) -> bool:
	return facility_id_at(seg, row) == -1 and shaft_id_at(seg, row) == -1

func range_free(seg: int, row: int, w: int) -> bool:
	for c in range(seg, seg + w):
		if not cell_free(c, row):
			return false
	return true

func range_built(seg: int, row: int, w: int) -> bool:
	for c in range(seg, seg + w):
		if not built(c, row):
			return false
	return true

# --- lobby & tower extent --------------------------------------------------

func has_lobby() -> bool:
	return lobby_left >= 0

func lobby_width() -> int:
	return 0 if lobby_left < 0 else lobby_right - lobby_left + 1

static func is_sky_lobby_row(r: int) -> bool:
	return r == 0 or (r > 0 and (r + 1) % Rules.SKY_LOBBY_EVERY == 0)

## Is there a lobby (ground or sky) built across this row?
func row_has_lobby(row: int) -> bool:
	if not is_sky_lobby_row(row):
		return false
	for c in range(COLS):
		if structure_at(c, row) == LOBBY:
			return true
	return false

# --- placement -------------------------------------------------------------

## Ask whether something may be built, and what it would cost.
## Returns {"ok": bool, "reason": String, "cost": int, "floor_cost": int}
func check_place(type: String, seg: int, row: int, w_override: int = -1,
		h_override: int = -1) -> Dictionary:
	var res := {"ok": false, "reason": "", "cost": 0, "floor_cost": 0}
	if not FacilityDB.has_def(type):
		res.reason = "Struttura sconosciuta"
		return res
	var d: Dictionary = FacilityDB.DEFS[type]
	var w: int = w_override if w_override > 0 else int(d.get("w", 1))
	var h: int = h_override if h_override > 0 else int(d.get("h", 1))

	if seg < 0 or seg + w > COLS:
		res.reason = "Fuori dal terreno"
		return res
	if row < FacilityDB.ROW_MIN or row + h - 1 > FacilityDB.ROW_MAX:
		res.reason = "Fuori dal terreno"
		return res

	var ug: int = int(d.get("underground", 0))
	if ug == -1 and row < 0:
		res.reason = "Non si costruisce sottoterra"
		return res
	if ug == 1 and row + h - 1 >= 0:
		res.reason = "Solo sottoterra"
		return res

	if FacilityDB.is_elevator(type):
		return _check_shaft(type, seg, row, h)

	# The lobby and the empty floor are both dragged across a span and both
	# FILL what is missing rather than demanding an empty run -- the manual is
	# explicit that a floor "will extend to close the gap".
	if type == "lobby":
		if not is_sky_lobby_row(row):
			res.reason = "Un atrio ogni 15 piani"
			return res
		if row > 0 and not range_built(seg, row - 1, w):
			res.reason = "Manca il piano sotto"
			return res
		var new_cells := 0
		for c in range(seg, seg + w):
			if structure_at(c, row) == LOBBY:
				continue
			if not cell_free(c, row):
				res.reason = "Occupato"
				return res
			new_cells += 1
		if new_cells == 0:
			res.reason = "Atrio gia costruito"
			return res
		res.ok = true
		res.cost = int(d["cost"]) * new_cells
		return res

	if not has_lobby():
		res.reason = "Costruisci prima un atrio"
		return res

	if type == "floor":
		if seg < lobby_left or seg + w - 1 > lobby_right:
			res.reason = "Piu largo dell atrio"
			return res
		var gaps := 0
		for c in range(seg, seg + w):
			if built(c, row):
				continue
			var supported := built(c, row - 1) if row > 0 else built(c, row + 1)
			if not supported:
				continue
			gaps += 1
		if gaps == 0:
			res.reason = "Niente da colmare qui"
			return res
		res.ok = true
		res.cost = int(d["cost"]) * gaps
		return res

	# The ground floor is all lobby; only transport and ramps cut through it.
	if row == 0 and type not in ["stairs", "escalator", "parking_ramp", "floor"]:
		res.reason = "Il piano terra e' solo atrio"
		return res

	# Everything must sit inside the width of the lobby below it.
	if seg < lobby_left or seg + w - 1 > lobby_right:
		res.reason = "Piu' largo dell atrio"
		return res

	# Support: floors are held up from below, basements hang from above.
	for r in range(row, row + h):
		if r > 0 and not range_built(seg, r - 1, w) and r != row:
			pass
	if row > 0:
		if not range_built(seg, row - 1, w):
			res.reason = "Manca il piano sotto"
			return res
	elif row < 0:
		if not range_built(seg, row + h, w):
			res.reason = "Manca il piano sopra"
			return res

	# Multi-storey things need every one of their rows clear.
	for r in range(row, row + h):
		if not range_free(seg, r, w):
			res.reason = "Occupato"
			return res

	if type == "escalator" and not _escalator_site_ok(seg, row):
		res.reason = "Solo su aree commerciali o atri"
		return res
	if type == "parking" and not _parking_has_ramp(row):
		res.reason = "Serve prima una rampa su questo piano"
		return res
	if type == "parking_ramp" and not _ramp_column_ok(seg, row):
		res.reason = "Una sola colonna di rampe, collegata all atrio"
		return res
	if type == "cathedral":
		if row + h - 1 != FacilityDB.ROW_MAX:
			res.reason = "Solo in cima ai 100 piani"
			return res
	if type == "metro":
		if _facilities_below(seg, row, w):
			res.reason = "Niente puo' stare sotto la metropolitana"
			return res

	# Charge for the empty floor the facility needs under itself.
	var floor_cost := 0
	var floor_unit: int = int(FacilityDB.DEFS["floor"]["cost"])
	for r in range(row, row + h):
		for c in range(seg, seg + w):
			if not built(c, r):
				floor_cost += floor_unit

	res.ok = true
	res.cost = int(d["cost"])
	res.floor_cost = floor_cost
	return res

func _check_shaft(type: String, seg: int, bottom: int, _h: int) -> Dictionary:
	var res := {"ok": false, "reason": "", "cost": 0, "floor_cost": 0}
	var d: Dictionary = FacilityDB.DEFS[type]
	var w: int = int(d["w"])
	if not has_lobby():
		res.reason = "Costruisci prima un atrio"
		return res
	if seg < lobby_left or seg + w - 1 > lobby_right:
		res.reason = "Piu' largo dell atrio"
		return res
	if shafts.size() >= FacilityDB.LIMITS["shafts"]:
		res.reason = "Massimo %d vani ascensore" % FacilityDB.LIMITS["shafts"]
		return res
	if not range_built(seg, bottom, w):
		res.reason = "Manca il piano"
		return res
	if not range_free(seg, bottom, w):
		res.reason = "Occupato"
		return res
	res.ok = true
	res.cost = int(d["cost"]) + int(d["car_cost"])   # a shaft arrives with one car
	return res

func _escalator_site_ok(seg: int, row: int) -> bool:
	for r in [row, row + 1]:
		var ok := false
		for c in range(maxi(0, seg - 30), mini(COLS, seg + 38)):
			if structure_at(c, r) == LOBBY:
				ok = true
				break
			var f := facility_at(c, r)
			if f != null and f.kind() in [FacilityDB.Kind.FOOD, FacilityDB.Kind.SHOP,
					FacilityDB.Kind.VENUE]:
				ok = true
				break
		if not ok:
			return false
	return true

func _parking_has_ramp(row: int) -> bool:
	for c in range(COLS):
		var f := facility_at(c, row)
		if f != null and f.type == "parking_ramp":
			return true
	return false

func _ramp_column_ok(seg: int, row: int) -> bool:
	# One column only, and it must reach the ground floor lobby.
	var existing: Facility = null
	for fid in facilities:
		var f: Facility = facilities[fid]
		if f.type == "parking_ramp":
			existing = f
			break
	if existing != null and existing.seg != seg:
		return false
	if row == -1:
		return true
	return facility_at(seg, row + 1) != null and facility_at(seg, row + 1).type == "parking_ramp"

func _facilities_below(seg: int, row: int, w: int) -> bool:
	for r in range(FacilityDB.ROW_MIN, row):
		for c in range(seg, seg + w):
			if built(c, r):
				return true
	return false

## Build it. Assumes check_place said yes. Returns the new facility, or null
## for pure structure.
func place(type: String, seg: int, row: int, w_override: int = -1) -> Facility:
	var d: Dictionary = FacilityDB.DEFS[type]
	var w: int = w_override if w_override > 0 else int(d.get("w", 1))
	var h: int = int(d.get("h", 1))

	if type == "lobby":
		for c in range(seg, seg + w):
			if cell_free(c, row):
				structure[idx(c, row)] = LOBBY
		if row == 0:
			lobby_left = seg if lobby_left < 0 else mini(lobby_left, seg)
			lobby_right = maxi(lobby_right, seg + w - 1)
		_touch(row)
		_index_dirty = true
		structure_changed.emit()
		return null

	if type == "floor":
		for c in range(seg, seg + w):
			if structure[idx(c, row)] != VOID:
				continue
			var supported := built(c, row - 1) if row > 0 else built(c, row + 1)
			if supported:
				structure[idx(c, row)] = FLOOR
		_touch(row)
		_index_dirty = true
		structure_changed.emit()
		return null

	var f := Facility.new(next_id, type, seg, row)
	f.w = w
	next_id += 1
	for r in range(row, row + h):
		for c in range(seg, seg + w):
			if structure[idx(c, r)] == VOID:
				structure[idx(c, r)] = FLOOR
			occupancy[idx(c, r)] = f.id
		_touch(r)
	facilities[f.id] = f
	_index_dirty = true
	structure_changed.emit()
	return f

func place_shaft(type: String, seg: int, bottom: int, top: int) -> Shaft:
	var d: Dictionary = FacilityDB.DEFS[type]
	var w: int = int(d["w"])
	var s := Shaft.new(next_id, type, seg, bottom, top)
	next_id += 1
	s.add_car(bottom)
	shafts[s.id] = s
	_paint_shaft(s)
	_index_dirty = true
	structure_changed.emit()
	return s

func _paint_shaft(s: Shaft) -> void:
	var w := s.width()
	for r in range(s.bottom_row, s.top_row + 1):
		for c in range(s.seg, s.seg + w):
			if in_bounds(c, r):
				shaft_grid[idx(c, r)] = s.id
		_touch(r)

func _unpaint_shaft(s: Shaft) -> void:
	var w := s.width()
	for r in range(s.bottom_row, s.top_row + 1):
		for c in range(s.seg, s.seg + w):
			if in_bounds(c, r) and shaft_grid[idx(c, r)] == s.id:
				shaft_grid[idx(c, r)] = -1

## Grow or shrink a shaft. Returns "" on success or a reason.
func resize_shaft(s: Shaft, new_bottom: int, new_top: int) -> String:
	if new_top < new_bottom:
		return "Vano non valido"
	if new_top - new_bottom + 1 > s.max_span():
		return "Massimo %d piani" % s.max_span()
	var w := s.width()
	for r in range(new_bottom, new_top + 1):
		if not s.covers_row(r):
			if not range_built(s.seg, r, w):
				return "Manca il piano " + FacilityDB.row_label(r)
			if not range_free(s.seg, r, w):
				return "Occupato al piano " + FacilityDB.row_label(r)
	for c in s.cars:
		if c.home_row < new_bottom or c.home_row > new_top:
			return "Una cabina resterebbe fuori dal vano"
	_unpaint_shaft(s)
	s.bottom_row = new_bottom
	s.top_row = new_top
	_paint_shaft(s)
	_index_dirty = true
	structure_changed.emit()
	return ""

func _touch(row: int) -> void:
	if row > top_built_row:
		top_built_row = row
	if row < bottom_built_row:
		bottom_built_row = row

# --- demolition ------------------------------------------------------------

func bulldoze(seg: int, row: int) -> Dictionary:
	var out := {"ok": false, "kind": "", "refund": 0, "id": -1}
	var sid := shaft_id_at(seg, row)
	if sid != -1:
		var s: Shaft = shafts[sid]
		_unpaint_shaft(s)
		shafts.erase(sid)
		out.ok = true
		out.kind = "shaft"
		out.id = sid
		_index_dirty = true
		structure_changed.emit()
		return out
	var f := facility_at(seg, row)
	if f == null:
		return out
	if f.type == "cinema":
		out.kind = "refuse"
		return out
	for r in range(f.row, f.row + f.h):
		for c in range(f.seg, f.seg + f.w):
			if in_bounds(c, r) and occupancy[idx(c, r)] == f.id:
				occupancy[idx(c, r)] = -1
	facilities.erase(f.id)
	out.ok = true
	out.kind = "facility"
	out.id = f.id
	if f.type == "condo" and f.sold:
		out.refund = -f.sale_price     # you give the money back
	_index_dirty = true
	structure_changed.emit()
	return out

# --- queries the rest of the game asks -------------------------------------

func count_of_kind(k: int) -> int:
	var n := 0
	for fid in facilities:
		if facilities[fid].kind() == k:
			n += 1
	return n

func count_of_type(t: String) -> int:
	var n := 0
	for fid in facilities:
		if facilities[fid].type == t:
			n += 1
	return n

func count_transport() -> int:
	return count_of_type("stairs") + count_of_type("escalator")

func count_retail() -> int:
	return count_of_type("fastfood") + count_of_type("restaurant") + count_of_type("shop")

func count_venues() -> int:
	return count_of_type("cinema") + count_of_type("party_hall")

func all_of_type(t: String) -> Array:
	var out := []
	for fid in facilities:
		if facilities[fid].type == t:
			out.append(facilities[fid])
	return out

func all_of_kind(k: int) -> Array:
	var out := []
	for fid in facilities:
		if facilities[fid].kind() == k:
			out.append(facilities[fid])
	return out

func population() -> int:
	var n := 0
	for fid in facilities:
		n += facilities[fid].population()
	return n

## Everything on a row that can move a person off it, cached until the
## structure changes.
func transports_on_row(row: int) -> Array:
	if _index_dirty:
		_rebuild_index()
	return _transport_index.get(row, [])

func _rebuild_index() -> void:
	_transport_index.clear()
	for fid in facilities:
		var f: Facility = facilities[fid]
		if f.type == "stairs" or f.type == "escalator":
			_add_index(f.row, {"kind": f.type, "id": f.id, "seg": f.seg,
				"from": f.row, "to": f.row + 1})
			_add_index(f.row + 1, {"kind": f.type, "id": f.id, "seg": f.seg,
				"from": f.row + 1, "to": f.row})
	for sid in shafts:
		var s: Shaft = shafts[sid]
		for r in range(s.bottom_row, s.top_row + 1):
			if s.serves_row(r):
				_add_index(r, {"kind": s.type, "id": s.id, "seg": s.seg, "shaft": true})
	_index_dirty = false

func _add_index(row: int, entry: Dictionary) -> void:
	if not _transport_index.has(row):
		_transport_index[row] = []
	_transport_index[row].append(entry)

func mark_dirty() -> void:
	_index_dirty = true

# --- save / load -----------------------------------------------------------

func to_dict() -> Dictionary:
	var facs := []
	for fid in facilities:
		facs.append(facilities[fid].to_dict())
	var shf := []
	for sid in shafts:
		shf.append(shafts[sid].to_dict())
	return {
		"structure": Marshalls.raw_to_base64(structure.compress()),
		"structure_size": structure.size(),
		"facilities": facs, "shafts": shf, "next_id": next_id,
		"lobby_left": lobby_left, "lobby_right": lobby_right,
	}

func from_dict(d: Dictionary) -> void:
	var raw := Marshalls.base64_to_raw(String(d["structure"]))
	structure = raw.decompress(int(d["structure_size"]))
	occupancy.resize(ROWS * COLS)
	shaft_grid.resize(ROWS * COLS)
	for i in range(occupancy.size()):
		occupancy[i] = -1
		shaft_grid[i] = -1
	facilities.clear()
	shafts.clear()
	for fd in d.get("facilities", []):
		var f := Facility.from_dict(fd)
		facilities[f.id] = f
		for r in range(f.row, f.row + f.h):
			for c in range(f.seg, f.seg + f.w):
				if in_bounds(c, r):
					occupancy[idx(c, r)] = f.id
			_touch(r)
	for sd in d.get("shafts", []):
		var s := Shaft.from_dict(sd)
		shafts[s.id] = s
		_paint_shaft(s)
	next_id = int(d.get("next_id", 1))
	lobby_left = int(d.get("lobby_left", -1))
	lobby_right = int(d.get("lobby_right", -1))
	_index_dirty = true
	structure_changed.emit()
