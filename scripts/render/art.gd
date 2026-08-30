extends RefCounted
class_name Art

## All the drawing. Flat shapes, dark outlines, a tight palette -- the same
## idea as the original's pixel art, done with primitives so the game carries
## no image files at all.

const SEG_W := 8.0
const ROW_H := 36.0

const OUTLINE := Color(0.10, 0.11, 0.14)
const SKY_DAY := Color(0.42, 0.66, 0.88)
const SKY_DUSK := Color(0.88, 0.55, 0.36)
const SKY_NIGHT := Color(0.06, 0.08, 0.18)
const SKY_DAWN := Color(0.62, 0.60, 0.72)
const EARTH := Color(0.31, 0.24, 0.18)
const EARTH_DARK := Color(0.22, 0.17, 0.12)
const GRASS := Color(0.30, 0.46, 0.26)
const CONCRETE := Color(0.72, 0.71, 0.66)
const CONCRETE_DARK := Color(0.52, 0.51, 0.47)

# Per-facility colours: [body, trim, detail]
const PALETTE := {
	"lobby":            [Color(0.86, 0.83, 0.74), Color(0.62, 0.58, 0.48), Color(0.30, 0.46, 0.26)],
	"floor":            [Color(0.60, 0.59, 0.56), Color(0.45, 0.44, 0.41), Color(0.35, 0.34, 0.32)],
	"office":           [Color(0.80, 0.82, 0.86), Color(0.42, 0.48, 0.58), Color(0.96, 0.86, 0.52)],
	"condo":            [Color(0.84, 0.74, 0.62), Color(0.52, 0.42, 0.34), Color(0.98, 0.88, 0.60)],
	"hotel_single":     [Color(0.72, 0.66, 0.80), Color(0.44, 0.38, 0.54), Color(0.98, 0.90, 0.66)],
	"hotel_twin":       [Color(0.68, 0.62, 0.80), Color(0.40, 0.34, 0.52), Color(0.98, 0.90, 0.66)],
	"hotel_suite":      [Color(0.62, 0.54, 0.78), Color(0.34, 0.28, 0.48), Color(0.99, 0.93, 0.72)],
	"fastfood":         [Color(0.92, 0.62, 0.34), Color(0.62, 0.34, 0.16), Color(0.99, 0.92, 0.70)],
	"restaurant":       [Color(0.76, 0.30, 0.28), Color(0.46, 0.16, 0.16), Color(0.99, 0.90, 0.66)],
	"shop":             [Color(0.40, 0.70, 0.62), Color(0.20, 0.44, 0.40), Color(0.98, 0.92, 0.74)],
	"party_hall":       [Color(0.82, 0.52, 0.68), Color(0.50, 0.26, 0.40), Color(0.99, 0.90, 0.72)],
	"cinema":           [Color(0.28, 0.26, 0.38), Color(0.16, 0.14, 0.24), Color(0.98, 0.86, 0.42)],
	"housekeeping":     [Color(0.66, 0.74, 0.56), Color(0.38, 0.46, 0.30), Color(0.92, 0.94, 0.88)],
	"security":         [Color(0.34, 0.44, 0.62), Color(0.18, 0.26, 0.42), Color(0.90, 0.94, 0.99)],
	"medical":          [Color(0.92, 0.92, 0.94), Color(0.58, 0.60, 0.66), Color(0.84, 0.22, 0.20)],
	"recycling":        [Color(0.44, 0.56, 0.42), Color(0.24, 0.34, 0.24), Color(0.68, 0.82, 0.56)],
	"parking":          [Color(0.44, 0.43, 0.42), Color(0.28, 0.28, 0.27), Color(0.86, 0.86, 0.84)],
	"parking_ramp":     [Color(0.38, 0.37, 0.36), Color(0.24, 0.24, 0.23), Color(0.90, 0.84, 0.42)],
	"metro":            [Color(0.30, 0.34, 0.44), Color(0.16, 0.19, 0.26), Color(0.96, 0.78, 0.32)],
	"cathedral":        [Color(0.84, 0.80, 0.70), Color(0.54, 0.50, 0.42), Color(0.42, 0.62, 0.84)],
	"stairs":           [Color(0.66, 0.64, 0.60), Color(0.36, 0.35, 0.33), Color(0.86, 0.86, 0.84)],
	"escalator":        [Color(0.58, 0.62, 0.68), Color(0.30, 0.34, 0.40), Color(0.92, 0.94, 0.96)],
	"elevator":         [Color(0.30, 0.30, 0.32), Color(0.16, 0.16, 0.18), Color(0.80, 0.82, 0.86)],
	"service_elevator": [Color(0.34, 0.24, 0.24), Color(0.20, 0.13, 0.13), Color(0.88, 0.70, 0.62)],
	"express_elevator": [Color(0.20, 0.28, 0.42), Color(0.12, 0.17, 0.28), Color(0.66, 0.82, 0.98)],
}

static func body(t: String) -> Color:
	return PALETTE.get(t, [CONCRETE, CONCRETE_DARK, Color.WHITE])[0]

static func trim(t: String) -> Color:
	return PALETTE.get(t, [CONCRETE, CONCRETE_DARK, Color.WHITE])[1]

static func detail(t: String) -> Color:
	return PALETTE.get(t, [CONCRETE, CONCRETE_DARK, Color.WHITE])[2]

## World-space rectangle of a cell block.
static func cell_rect(seg: int, row: int, w: int = 1, h: int = 1) -> Rect2:
	return Rect2(float(seg) * SEG_W, -float(row + h) * ROW_H,
		float(w) * SEG_W, float(h) * ROW_H)

## The sky colour at a given minute of the day.
static func sky_colour(minute: int) -> Color:
	var h := float(minute) / 60.0
	if h < 4.5:
		return SKY_NIGHT
	if h < 6.5:
		return SKY_NIGHT.lerp(SKY_DAWN, (h - 4.5) / 2.0)
	if h < 8.0:
		return SKY_DAWN.lerp(SKY_DAY, (h - 6.5) / 1.5)
	if h < 17.0:
		return SKY_DAY
	if h < 19.0:
		return SKY_DAY.lerp(SKY_DUSK, (h - 17.0) / 2.0)
	if h < 21.0:
		return SKY_DUSK.lerp(SKY_NIGHT, (h - 19.0) / 2.0)
	return SKY_NIGHT

static func is_dark(minute: int) -> bool:
	var h := float(minute) / 60.0
	return h < 6.0 or h >= 19.5

# ---------------------------------------------------------------------------
# Facilities
# ---------------------------------------------------------------------------

static func draw_facility(ci: CanvasItem, f: Facility, minute: int,
		eval_tint: Color = Color(0, 0, 0, 0)) -> void:
	var r := cell_rect(f.seg, f.row, f.w, f.h)
	var t := f.type
	var col := body(t)
	var tr := trim(t)
	var det := detail(t)
	if f.wrecked:
		ci.draw_rect(r, Color(0.16, 0.15, 0.14))
		_hatch(ci, r, Color(0.34, 0.30, 0.26))
		ci.draw_rect(r, OUTLINE, false, 1.0)
		return
	# Three states, and they must look different at a glance: to let (pale and
	# bare), let but asleep (dark), and busy (lit).
	if _vacant(f):
		ci.draw_rect(r, Color(0.80, 0.79, 0.75))
		ci.draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3),
			Color(0.60, 0.59, 0.55))
		_to_let(ci, r)
		ci.draw_rect(r, OUTLINE, false, 1.0)
		return
	var lit := _lit(f, minute)
	if not lit:
		col = col.darkened(0.30)
		tr = tr.darkened(0.24)
		det = det.darkened(0.42)

	ci.draw_rect(r, col)
	match FacilityDB.kind_of(t):
		FacilityDB.Kind.OFFICE:
			_draw_office(ci, r, tr, det, lit)
		FacilityDB.Kind.CONDO:
			_draw_condo(ci, r, tr, det, lit)
		FacilityDB.Kind.HOTEL:
			_draw_hotel(ci, r, tr, det, lit, f)
		FacilityDB.Kind.FOOD:
			_draw_food(ci, r, tr, det, lit, t == "restaurant")
		FacilityDB.Kind.SHOP:
			_draw_shop(ci, r, tr, det, lit)
		FacilityDB.Kind.VENUE:
			if t == "cinema":
				_draw_cinema(ci, r, tr, det, lit)
			else:
				_draw_party(ci, r, tr, det, lit)
		FacilityDB.Kind.SERVICE:
			_draw_service(ci, r, tr, det, t)
		FacilityDB.Kind.PARKING:
			_draw_parking(ci, r, tr, det, t)
		FacilityDB.Kind.CIVIC:
			if t == "cathedral":
				_draw_cathedral(ci, r, tr, det)
			else:
				_draw_metro(ci, r, tr, det)
		FacilityDB.Kind.TRANSPORT:
			if t == "stairs":
				_draw_stairs(ci, r, tr, det)
			else:
				_draw_escalator(ci, r, tr, det)
	if eval_tint.a > 0.0:
		ci.draw_rect(r, eval_tint)
	ci.draw_rect(r, OUTLINE, false, 1.0)

## Built, but nobody has taken it yet.
static func _vacant(f: Facility) -> bool:
	match FacilityDB.kind_of(f.type):
		FacilityDB.Kind.OFFICE, FacilityDB.Kind.SHOP:
			return f.occupants.is_empty()
		FacilityDB.Kind.CONDO:
			return not f.sold
		_:
			return false

## An empty room waiting for a tenant: bare boards and a stripe of daylight.
static func _to_let(ci: CanvasItem, r: Rect2) -> void:
	var x := r.position.x + 6.0
	while x < r.end.x - 6.0:
		ci.draw_line(Vector2(x, r.position.y + 6), Vector2(x, r.end.y - 5),
			Color(0.72, 0.71, 0.67), 1.0)
		x += 9.0
	ci.draw_rect(Rect2(r.position.x + 3, r.position.y + 5, r.size.x - 6, 3),
		Color(0.88, 0.88, 0.85))

static func _lit(f: Facility, minute: int) -> bool:
	var h := float(minute) / 60.0
	match FacilityDB.kind_of(f.type):
		FacilityDB.Kind.OFFICE:
			return not f.occupants.is_empty() and h >= 7.5 and h < 19.5
		FacilityDB.Kind.CONDO:
			return f.sold and (h < 8.0 or h >= 17.0)
		FacilityDB.Kind.HOTEL:
			return not f.occupants.is_empty() and (h >= 18.0 or h < 9.0)
		FacilityDB.Kind.FOOD:
			return h >= 9.0 and h < 23.0
		FacilityDB.Kind.SHOP:
			return not f.occupants.is_empty() and h >= 10.0 and h < 21.0
		FacilityDB.Kind.VENUE:
			return h >= 12.0 and h < 23.5
		_:
			return true

static func _draw_office(ci: CanvasItem, r: Rect2, tr: Color, det: Color, lit: bool) -> void:
	ci.draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), tr)
	var n := 3
	var pad := 5.0
	var wdt := (r.size.x - pad * float(n + 1)) / float(n)
	for i in range(n):
		var x := r.position.x + pad + float(i) * (wdt + pad)
		ci.draw_rect(Rect2(x, r.position.y + 7, wdt, r.size.y - 16),
			det if lit else tr.darkened(0.2))
	# a desk line
	ci.draw_rect(Rect2(r.position.x + 3, r.end.y - 9, r.size.x - 6, 2), tr)

static func _draw_condo(ci: CanvasItem, r: Rect2, tr: Color, det: Color, lit: bool) -> void:
	ci.draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), tr)
	# a window, a door, a plant
	ci.draw_rect(Rect2(r.position.x + 6, r.position.y + 8, 22, 14), det if lit else tr)
	ci.draw_rect(Rect2(r.position.x + 6, r.position.y + 8, 22, 14), tr, false, 1.0)
	ci.draw_rect(Rect2(r.end.x - 26, r.position.y + 6, 12, r.size.y - 12), tr)
	ci.draw_circle(Vector2(r.end.x - 8, r.end.y - 8), 4.0, Color(0.30, 0.50, 0.28))

static func _draw_hotel(ci: CanvasItem, r: Rect2, tr: Color, det: Color, lit: bool,
		f: Facility) -> void:
	ci.draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), tr)
	var bed_w := minf(r.size.x - 8.0, 18.0)
	ci.draw_rect(Rect2(r.position.x + 4, r.end.y - 14, bed_w, 9),
		det if lit else tr.darkened(0.2))
	ci.draw_rect(Rect2(r.position.x + 4, r.end.y - 18, 6, 5), Color(0.95, 0.95, 0.95, 0.8))
	if f.roaches:
		for i in range(4):
			var x := r.position.x + 5.0 + float(i) * 7.0
			ci.draw_circle(Vector2(x, r.end.y - 5), 2.0, Color(0.25, 0.15, 0.08))
	elif f.dirty:
		ci.draw_rect(Rect2(r.position.x + 2, r.position.y + 4, r.size.x - 4, 4),
			Color(0.60, 0.48, 0.30, 0.75))

static func _draw_food(ci: CanvasItem, r: Rect2, tr: Color, det: Color, lit: bool,
		posh: bool) -> void:
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 7), tr)
	# an awning of stripes
	var stripe := 6.0
	var x := r.position.x
	var on := true
	while x < r.end.x:
		if on:
			ci.draw_rect(Rect2(x, r.position.y, minf(stripe, r.end.x - x), 7),
				det.darkened(0.1))
		x += stripe
		on = not on
	# tables
	var n := int(r.size.x / (28.0 if posh else 20.0))
	for i in range(n):
		var cx := r.position.x + 12.0 + float(i) * (28.0 if posh else 20.0)
		if cx > r.end.x - 6:
			break
		ci.draw_rect(Rect2(cx - 6, r.end.y - 13, 12, 2), tr)
		ci.draw_rect(Rect2(cx - 1, r.end.y - 11, 2, 8), tr)
		if lit:
			ci.draw_circle(Vector2(cx, r.end.y - 16), 2.5, det)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), tr)

static func _draw_shop(ci: CanvasItem, r: Rect2, tr: Color, det: Color, lit: bool) -> void:
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 6), tr)
	ci.draw_rect(Rect2(r.position.x + 4, r.position.y + 9, r.size.x - 8, r.size.y - 16),
		det if lit else tr.darkened(0.15))
	ci.draw_rect(Rect2(r.position.x + 4, r.position.y + 9, r.size.x - 8, r.size.y - 16),
		tr, false, 1.0)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), tr)

static func _draw_cinema(ci: CanvasItem, r: Rect2, tr: Color, det: Color, lit: bool) -> void:
	ci.draw_rect(r, Color(0.16, 0.15, 0.22))
	# the screen
	var sc := Rect2(r.position.x + 8, r.position.y + 8, r.size.x * 0.35, r.size.y * 0.5)
	ci.draw_rect(sc, det if lit else Color(0.30, 0.30, 0.34))
	ci.draw_rect(sc, tr, false, 1.0)
	# rows of seats
	for row in range(4):
		var y := r.position.y + r.size.y * 0.62 + float(row) * 5.0
		if y > r.end.y - 4:
			break
		for i in range(int(r.size.x / 9.0)):
			ci.draw_rect(Rect2(r.position.x + 6.0 + float(i) * 9.0, y, 6, 3),
				Color(0.42, 0.20, 0.22))
	# the marquee
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 5),
		det if lit else det.darkened(0.6))

static func _draw_party(ci: CanvasItem, r: Rect2, tr: Color, det: Color, lit: bool) -> void:
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 6), tr)
	for i in range(int(r.size.x / 16.0)):
		var cx := r.position.x + 10.0 + float(i) * 16.0
		if cx > r.end.x - 8:
			break
		ci.draw_circle(Vector2(cx, r.position.y + 14), 5.0,
			det if lit else det.darkened(0.5))
		ci.draw_rect(Rect2(cx - 8, r.end.y - 12, 16, 2), tr)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), tr)

static func _draw_service(ci: CanvasItem, r: Rect2, tr: Color, det: Color, t: String) -> void:
	ci.draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), tr)
	var c := r.get_center()
	match t:
		"medical":
			ci.draw_rect(Rect2(c.x - 3, c.y - 10, 6, 20), det)
			ci.draw_rect(Rect2(c.x - 10, c.y - 3, 20, 6), det)
		"security":
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(c.x, c.y - 11), Vector2(c.x + 9, c.y - 6),
				Vector2(c.x + 7, c.y + 9), Vector2(c.x, c.y + 12),
				Vector2(c.x - 7, c.y + 9), Vector2(c.x - 9, c.y - 6)]), det)
		"recycling":
			for i in range(3):
				var a := float(i) * TAU / 3.0 - PI / 2.0
				var p := c + Vector2(cos(a), sin(a)) * 9.0
				ci.draw_colored_polygon(PackedVector2Array([
					p + Vector2(0, -5), p + Vector2(5, 4), p + Vector2(-5, 4)]), det)
		_:
			for i in range(3):
				var x := r.position.x + 10.0 + float(i) * 22.0
				if x > r.end.x - 8:
					break
				ci.draw_rect(Rect2(x, r.end.y - 16, 10, 12), det)
				ci.draw_rect(Rect2(x + 4, r.end.y - 22, 2, 7), tr)

static func _draw_parking(ci: CanvasItem, r: Rect2, tr: Color, det: Color, t: String) -> void:
	if t == "parking_ramp":
		ci.draw_line(Vector2(r.position.x + 2, r.end.y - 3),
			Vector2(r.end.x - 2, r.position.y + 4), det, 3.0)
		ci.draw_line(Vector2(r.position.x + 2, r.end.y - 9),
			Vector2(r.end.x - 2, r.position.y), tr, 2.0)
		return
	# a bay with a little car
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y + 4, r.size.x - 2, 1), det)
	var cx := r.get_center().x
	ci.draw_rect(Rect2(cx - 12, r.end.y - 14, 24, 8), det.darkened(0.25))
	ci.draw_rect(Rect2(cx - 7, r.end.y - 19, 14, 6), det.darkened(0.1))
	ci.draw_circle(Vector2(cx - 7, r.end.y - 6), 2.5, Color(0.15, 0.15, 0.15))
	ci.draw_circle(Vector2(cx + 7, r.end.y - 6), 2.5, Color(0.15, 0.15, 0.15))

static func _draw_metro(ci: CanvasItem, r: Rect2, tr: Color, det: Color) -> void:
	ci.draw_rect(Rect2(r.position.x + 4, r.end.y - 6, r.size.x - 8, 2), det)
	ci.draw_rect(Rect2(r.position.x + 4, r.end.y - 10, r.size.x - 8, 2), det)
	var train := Rect2(r.position.x + 20, r.end.y - 30, r.size.x - 60, 20)
	ci.draw_rect(train, det.darkened(0.15))
	ci.draw_rect(train, tr, false, 1.0)
	for i in range(4):
		ci.draw_rect(Rect2(train.position.x + 8.0 + float(i) * 26.0,
			train.position.y + 5, 16, 8), Color(0.72, 0.86, 0.94))

static func _draw_cathedral(ci: CanvasItem, r: Rect2, tr: Color, det: Color) -> void:
	var c := r.get_center()
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, r.position.y + 2),
		Vector2(r.end.x - 4, r.position.y + r.size.y * 0.42),
		Vector2(r.position.x + 4, r.position.y + r.size.y * 0.42)]), tr)
	# rose window
	ci.draw_circle(Vector2(c.x, r.position.y + r.size.y * 0.60), 12.0, det)
	ci.draw_circle(Vector2(c.x, r.position.y + r.size.y * 0.60), 12.0, tr, false, 2.0)
	# arched doors
	for i in [-1, 1]:
		var x := c.x + float(i) * 40.0
		ci.draw_rect(Rect2(x - 10, r.end.y - 30, 20, 30), tr)
	ci.draw_rect(Rect2(c.x - 14, r.end.y - 40, 28, 40), tr)
	# the cross
	ci.draw_rect(Rect2(c.x - 2, r.position.y - 14, 4, 16), tr)
	ci.draw_rect(Rect2(c.x - 7, r.position.y - 9, 14, 4), tr)

static func _draw_stairs(ci: CanvasItem, r: Rect2, tr: Color, det: Color) -> void:
	var steps := 8
	for i in range(steps):
		var t := float(i) / float(steps)
		var x := r.position.x + t * r.size.x
		var y := r.end.y - (t + 1.0 / float(steps)) * r.size.y
		ci.draw_rect(Rect2(x, y, r.size.x / float(steps) + 1.0, 3.0), det)
	ci.draw_line(r.position + Vector2(0, r.size.y), Vector2(r.end.x, r.position.y),
		tr, 1.5)

static func _draw_escalator(ci: CanvasItem, r: Rect2, tr: Color, det: Color) -> void:
	ci.draw_line(Vector2(r.position.x, r.end.y - 4), Vector2(r.end.x, r.position.y + 6),
		tr, 5.0)
	ci.draw_line(Vector2(r.position.x, r.end.y - 10), Vector2(r.end.x, r.position.y),
		det, 2.0)
	for i in range(6):
		var t := float(i) / 6.0
		var p := Vector2(r.position.x, r.end.y - 4).lerp(Vector2(r.end.x, r.position.y + 6), t)
		ci.draw_rect(Rect2(p.x - 2, p.y - 2, 4, 4), det.darkened(0.2))

static func _hatch(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var x := r.position.x - r.size.y
	while x < r.end.x:
		ci.draw_line(Vector2(x, r.end.y), Vector2(x + r.size.y, r.position.y), col, 1.0)
		x += 7.0

# ---------------------------------------------------------------------------
# Structure, shafts, people
# ---------------------------------------------------------------------------

## Bare structure: a slab and the columns holding it up, with the sky showing
## through. Anything heavier and an unfinished tower reads as a solid block.
static func draw_empty_floor(ci: CanvasItem, seg: int, row: int, w: int) -> void:
	var r := cell_rect(seg, row, w, 1)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 5, r.size.x, 5), CONCRETE_DARK)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 5, r.size.x, 2), CONCRETE)
	var x := r.position.x + 4.0
	while x < r.end.x - 2.0:
		ci.draw_rect(Rect2(x, r.position.y + 2, 3.0, r.size.y - 7.0),
			Color(0.55, 0.55, 0.55, 0.55))
		x += 64.0

static func draw_lobby(ci: CanvasItem, seg: int, row: int, w: int, minute: int) -> void:
	var r := cell_rect(seg, row, w, 1)
	var col := body("lobby")
	if is_dark(minute):
		col = col.darkened(0.25)
	ci.draw_rect(r, col)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 5, r.size.x, 5), trim("lobby"))
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 4), trim("lobby"))
	# potted plants and a marble stripe
	var x := r.position.x + 20.0
	while x < r.end.x - 10.0:
		ci.draw_rect(Rect2(x - 4, r.end.y - 14, 8, 9), Color(0.55, 0.38, 0.28))
		ci.draw_circle(Vector2(x, r.end.y - 18), 6.0, Color(0.26, 0.44, 0.24))
		x += 120.0
	ci.draw_line(Vector2(r.position.x, r.end.y - 6), Vector2(r.end.x, r.end.y - 6),
		Color(1, 1, 1, 0.30), 1.0)

static func draw_shaft(ci: CanvasItem, s: Shaft, now_row_top: int, now_row_bot: int) -> void:
	var w := float(s.width()) * SEG_W
	var top := maxi(s.bottom_row, now_row_bot)
	var bot := mini(s.top_row, now_row_top)
	var x := float(s.seg) * SEG_W
	var y0 := -float(s.top_row + 1) * ROW_H
	var y1 := -float(s.bottom_row) * ROW_H
	var col := body(s.type)
	ci.draw_rect(Rect2(x, y0, w, y1 - y0), col)
	ci.draw_rect(Rect2(x, y0, w, y1 - y0), OUTLINE, false, 1.0)
	# guide rails
	ci.draw_line(Vector2(x + 2, y0), Vector2(x + 2, y1), trim(s.type), 1.0)
	ci.draw_line(Vector2(x + w - 2, y0), Vector2(x + w - 2, y1), trim(s.type), 1.0)
	# the motor room on top
	ci.draw_rect(Rect2(x, y0 - 9, w, 9), trim(s.type))
	ci.draw_rect(Rect2(x, y0 - 9, w, 9), OUTLINE, false, 1.0)
	ci.draw_circle(Vector2(x + w * 0.5, y0 - 4.5), 3.0, detail(s.type))
	# and a matching one below, which is the drag handle
	ci.draw_rect(Rect2(x, y1, w, 6), trim(s.type))
	ci.draw_rect(Rect2(x, y1, w, 6), OUTLINE, false, 1.0)

static func draw_car(ci: CanvasItem, s: Shaft, c: Shaft.Car) -> void:
	var w := float(s.width()) * SEG_W
	var x := float(s.seg) * SEG_W
	var y := -(c.pos + 1.0) * ROW_H
	var r := Rect2(x + 1, y + 3, w - 2, ROW_H - 6)
	ci.draw_rect(r, detail(s.type))
	ci.draw_rect(r, OUTLINE, false, 1.0)
	# how full it is
	var cap := maxf(float(s.car_capacity()), 1.0)
	var fill := clampf(float(c.riders.size()) / cap, 0.0, 1.0)
	if fill > 0.0:
		ci.draw_rect(Rect2(r.position.x + 1, r.end.y - 1 - (r.size.y - 2) * fill,
			r.size.x - 2, (r.size.y - 2) * fill), Color(0.30, 0.34, 0.42, 0.85))
	if c.full:
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(r.get_center().x, r.position.y + 3),
			Vector2(r.get_center().x + 4, r.get_center().y),
			Vector2(r.get_center().x, r.end.y - 3),
			Vector2(r.get_center().x - 4, r.get_center().y)]),
			Color(0.88, 0.20, 0.18))

static func draw_person(ci: CanvasItem, x: float, row: int, col: Color,
		scale: float = 1.0) -> void:
	var y := -float(row) * ROW_H
	var h := 12.0 * scale
	ci.draw_rect(Rect2(x - 1.5 * scale, y - h, 3.0 * scale, h), col)
	ci.draw_circle(Vector2(x, y - h - 2.0 * scale), 2.0 * scale, col)

static func draw_santa(ci: CanvasItem, x: float, row: int, t: float) -> void:
	var y := -float(row) * ROW_H + sin(t * 2.0) * 6.0
	var red := Color(0.82, 0.14, 0.16)
	var brown := Color(0.45, 0.30, 0.18)
	# reindeer
	for i in range(3):
		var rx := x + 26.0 + float(i) * 20.0
		ci.draw_rect(Rect2(rx, y - 8, 14, 7), brown)
		ci.draw_rect(Rect2(rx + 11, y - 13, 5, 6), brown)
		ci.draw_line(Vector2(rx + 13, y - 13), Vector2(rx + 17, y - 19), brown, 1.5)
		ci.draw_line(Vector2(rx + 12, y - 13), Vector2(rx + 8, y - 19), brown, 1.5)
		ci.draw_line(Vector2(rx + 2, y - 1), Vector2(rx + 1, y + 4), brown, 1.5)
		ci.draw_line(Vector2(rx + 11, y - 1), Vector2(rx + 12, y + 4), brown, 1.5)
	ci.draw_line(Vector2(x + 16, y - 5), Vector2(x + 88, y - 5), brown, 1.0)
	# sleigh
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(x, y), Vector2(x + 22, y), Vector2(x + 22, y - 10),
		Vector2(x + 6, y - 10), Vector2(x, y - 4)]), red)
	ci.draw_line(Vector2(x - 2, y + 2), Vector2(x + 24, y + 2), Color(0.90, 0.78, 0.30), 2.0)
	ci.draw_line(Vector2(x - 2, y + 2), Vector2(x - 5, y - 3), Color(0.90, 0.78, 0.30), 2.0)
	# the man himself
	ci.draw_rect(Rect2(x + 8, y - 22, 9, 13), red)
	ci.draw_circle(Vector2(x + 12.5, y - 25), 4.0, Color(0.96, 0.82, 0.70))
	ci.draw_circle(Vector2(x + 12.5, y - 16), 3.0, Color(0.96, 0.96, 0.96))
	ci.draw_rect(Rect2(x + 7, y - 30, 11, 4), red)
	ci.draw_circle(Vector2(x + 18, y - 30), 2.0, Color(0.96, 0.96, 0.96))

static func draw_fire(ci: CanvasItem, cell: Vector2i, intensity: float, t: float) -> void:
	var r := cell_rect(cell.x, cell.y, 8, 1)
	var n := 4
	for i in range(n):
		var ph := t * 6.0 + float(i) * 1.7
		var hgt := (10.0 + sin(ph) * 5.0) * (0.4 + intensity)
		var cx := r.position.x + 6.0 + float(i) * (r.size.x - 12.0) / float(n - 1)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 5, r.end.y - 2), Vector2(cx + 5, r.end.y - 2),
			Vector2(cx, r.end.y - 2 - hgt)]),
			Color(0.95, 0.45, 0.10, 0.9))
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 2.5, r.end.y - 2), Vector2(cx + 2.5, r.end.y - 2),
			Vector2(cx, r.end.y - 2 - hgt * 0.6)]),
			Color(0.99, 0.88, 0.35, 0.95))
