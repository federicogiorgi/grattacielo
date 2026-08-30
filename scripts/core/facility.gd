extends RefCounted
class_name Facility

## One placed thing in the tower. Everything that is not an elevator shaft --
## offices, condos, hotel rooms, shops, the cathedral -- is one of these.

var id: int = -1
var type: String = ""
var seg: int = 0          # leftmost segment
var row: int = 0          # bottom row (row 0 is the ground floor)
var w: int = 1
var h: int = 1

var brand: String = ""            # "Ramen", "Fiorista", ...
var label: String = ""            # display name
var rent_tier: int = 2            # index into the def's rents array
var built_quarter: int = 0        # for the "in attivita da" line

# --- occupancy -------------------------------------------------------------
var occupants: Array[int] = []    # sim ids that belong here
var wanted: int = 0               # how many occupants it is trying to hold
var vacant: bool = true

# --- hotel -----------------------------------------------------------------
var dirty: bool = false
var roaches: bool = false
var dirty_since_day: int = -1
var checked_in: int = 0
var nights_paid: int = 0

# --- condo -----------------------------------------------------------------
var sale_price: int = 0
var sold: bool = false

# --- patronage (food, shops, venues) ---------------------------------------
var patrons: int = Rules.PATRON_START
var patrons_today: int = 0
var takings_today: int = 0

# --- cinema ----------------------------------------------------------------
var movie: String = ""
var movie_is_new: bool = false
var movie_since_quarter: int = 0

# --- evaluation ------------------------------------------------------------
var stress_sum: float = 0.0
var stress_n: int = 0
var quality: float = 300.0
var eval: int = Rules.Eval.A
var message: String = ""

# --- damage ----------------------------------------------------------------
var burning: bool = false
var wrecked: bool = false

func _init(p_id: int = -1, p_type: String = "", p_seg: int = 0, p_row: int = 0) -> void:
	id = p_id
	type = p_type
	seg = p_seg
	row = p_row
	if p_type != "" and FacilityDB.has_def(p_type):
		var sz := FacilityDB.size_of(p_type)
		w = sz.x
		h = sz.y
		rent_tier = 2
		label = FacilityDB.DEFS[p_type].get("name", p_type)

func def() -> Dictionary:
	return FacilityDB.DEFS.get(type, {})

func kind() -> int:
	return def().get("kind", FacilityDB.Kind.STRUCTURE)

func capacity() -> int:
	return def().get("capacity", 0)

func rect() -> Rect2i:
	return Rect2i(seg, row, w, h)

func centre_seg() -> int:
	return seg + w / 2

func rent() -> int:
	var d := def()
	if not d.has("rents"):
		return 0
	return d["rents"][clampi(rent_tier, 0, 3)]

func title() -> String:
	if brand != "":
		return brand
	return label

## Population this facility contributes to the tower total.
func population() -> int:
	match kind():
		FacilityDB.Kind.OFFICE, FacilityDB.Kind.CONDO, FacilityDB.Kind.SERVICE:
			return occupants.size()
		FacilityDB.Kind.HOTEL:
			return checked_in
		FacilityDB.Kind.FOOD, FacilityDB.Kind.SHOP:
			return patrons_today
		FacilityDB.Kind.VENUE:
			return patrons_today
		_:
			return 0

## Roll the day's evaluation from the stress its people accumulated.
func recompute_eval() -> void:
	if stress_n > 0:
		quality = 300.0 - (stress_sum / float(stress_n))
	else:
		quality = 300.0
	# What you charge colours how they feel about the place.
	var d := def()
	if d.has("rents"):
		quality -= Rules.RENT_STRESS[clampi(rent_tier, 0, 3)]
	quality = clampf(quality, 0.0, 300.0)
	eval = Rules.eval_of_quality(quality)

func note_stress(s: float) -> void:
	stress_sum += s
	stress_n += 1

func reset_stress_window() -> void:
	stress_sum = 0.0
	stress_n = 0

## Patron-driven facilities score themselves on how many people turned up.
func patron_rating() -> int:
	var hi := Rules.FOOD_RATING_A
	var lo := Rules.FOOD_RATING_C
	if kind() == FacilityDB.Kind.SHOP:
		hi = Rules.SHOP_RATING_A
		lo = Rules.SHOP_RATING_C
	if patrons_today > hi:
		return Rules.Eval.A
	if patrons_today >= lo:
		return Rules.Eval.B
	return Rules.Eval.C

## The day's take for a food outlet, from its patron count.
func food_takings() -> int:
	var t: Array = def().get("takings", [0, 0, 0, 0])
	var n := patrons_today
	if n < 20:
		return t[0]
	if n < 25:
		return t[1]
	if n < 50:
		return t[2]
	return t[3]

func to_dict() -> Dictionary:
	return {
		"id": id, "type": type, "seg": seg, "row": row, "brand": brand,
		"rent_tier": rent_tier, "built_quarter": built_quarter,
		"patrons": patrons, "sale_price": sale_price, "sold": sold,
		"dirty": dirty, "roaches": roaches, "movie": movie,
		"movie_is_new": movie_is_new, "occupants": occupants,
		"checked_in": checked_in, "wrecked": wrecked,
	}

static func from_dict(d: Dictionary) -> Facility:
	var f := Facility.new(int(d["id"]), String(d["type"]), int(d["seg"]), int(d["row"]))
	f.brand = String(d.get("brand", ""))
	f.rent_tier = int(d.get("rent_tier", 2))
	f.built_quarter = int(d.get("built_quarter", 0))
	f.patrons = int(d.get("patrons", Rules.PATRON_START))
	f.sale_price = int(d.get("sale_price", 0))
	f.sold = bool(d.get("sold", false))
	f.dirty = bool(d.get("dirty", false))
	f.roaches = bool(d.get("roaches", false))
	f.movie = String(d.get("movie", ""))
	f.movie_is_new = bool(d.get("movie_is_new", false))
	f.checked_in = int(d.get("checked_in", 0))
	f.wrecked = bool(d.get("wrecked", false))
	var occ: Array = d.get("occupants", [])
	for o in occ:
		f.occupants.append(int(o))
	f.vacant = f.occupants.is_empty() and f.checked_in == 0
	return f
