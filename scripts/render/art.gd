extends RefCounted
class_name Art

## All the drawing. Flat shapes, dark outlines, a tight palette -- the same
## idea as the original's pixel art, done with primitives so the game carries
## no image files at all.
##
## Rooms are drawn as a shell (floor slab, back wall, ceiling) with furniture
## on top. Stairs and escalators are the exception: they are STRUCTURE laid
## over the floor, so they draw only their own geometry and leave everything
## around them transparent -- you must be able to see the rooms behind them.

const SEG_W := 8.0
const ROW_H := 36.0
const SLAB := 4.0      # thickness of a floor slab, drawn at the row's foot

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
const GLASS := Color(0.72, 0.86, 0.94)
const WARM := Color(0.99, 0.88, 0.55)

# Per-facility colours: [body, trim, detail]
const PALETTE := {
	"lobby":            [Color(0.88, 0.85, 0.77), Color(0.60, 0.55, 0.45), Color(0.30, 0.46, 0.26)],
	"floor":            [Color(0.60, 0.59, 0.56), Color(0.45, 0.44, 0.41), Color(0.35, 0.34, 0.32)],
	"office":           [Color(0.70, 0.77, 0.86), Color(0.26, 0.36, 0.50), Color(0.98, 0.90, 0.60)],
	"condo":            [Color(0.82, 0.63, 0.45), Color(0.44, 0.29, 0.20), Color(0.99, 0.86, 0.52)],
	"hotel_single":     [Color(0.74, 0.68, 0.82), Color(0.42, 0.36, 0.53), Color(0.98, 0.90, 0.66)],
	"hotel_twin":       [Color(0.70, 0.64, 0.82), Color(0.38, 0.32, 0.51), Color(0.98, 0.90, 0.66)],
	"hotel_suite":      [Color(0.64, 0.56, 0.80), Color(0.32, 0.26, 0.47), Color(0.99, 0.93, 0.72)],
	"fastfood":         [Color(0.94, 0.66, 0.36), Color(0.60, 0.32, 0.14), Color(0.99, 0.92, 0.70)],
	"restaurant":       [Color(0.78, 0.32, 0.29), Color(0.44, 0.15, 0.15), Color(0.99, 0.90, 0.66)],
	"shop":             [Color(0.42, 0.72, 0.64), Color(0.18, 0.42, 0.38), Color(0.98, 0.92, 0.74)],
	"party_hall":       [Color(0.84, 0.54, 0.70), Color(0.48, 0.24, 0.38), Color(0.99, 0.90, 0.72)],
	"cinema":           [Color(0.26, 0.24, 0.36), Color(0.14, 0.12, 0.22), Color(0.98, 0.86, 0.42)],
	"housekeeping":     [Color(0.68, 0.76, 0.58), Color(0.36, 0.44, 0.28), Color(0.94, 0.95, 0.90)],
	"security":         [Color(0.34, 0.44, 0.62), Color(0.16, 0.24, 0.40), Color(0.90, 0.94, 0.99)],
	"medical":          [Color(0.93, 0.93, 0.95), Color(0.56, 0.58, 0.64), Color(0.84, 0.22, 0.20)],
	"recycling":        [Color(0.45, 0.57, 0.43), Color(0.22, 0.32, 0.22), Color(0.70, 0.84, 0.58)],
	"parking":          [Color(0.45, 0.44, 0.43), Color(0.27, 0.27, 0.26), Color(0.86, 0.86, 0.84)],
	"parking_ramp":     [Color(0.39, 0.38, 0.37), Color(0.23, 0.23, 0.22), Color(0.90, 0.84, 0.42)],
	"metro":            [Color(0.30, 0.34, 0.44), Color(0.15, 0.18, 0.25), Color(0.96, 0.78, 0.32)],
	"cathedral":        [Color(0.86, 0.82, 0.72), Color(0.52, 0.48, 0.40), Color(0.42, 0.62, 0.84)],
	"stairs":           [Color(0.70, 0.68, 0.64), Color(0.34, 0.33, 0.31), Color(0.88, 0.88, 0.86)],
	"escalator":        [Color(0.60, 0.64, 0.70), Color(0.28, 0.32, 0.38), Color(0.93, 0.95, 0.97)],
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

## The moon, drawn with its phase. `phase` runs 0 (new) through 0.5 (full)
## back to 1 (new): the lit limb is a half circle and the terminator is an
## ellipse whose half-width is cos(2*pi*phase), which is negative past first
## quarter and so bulges the other way into a gibbous.
static func draw_moon(ci: CanvasItem, c: Vector2, rad: float, phase: float) -> void:
	var pale := Color(0.95, 0.95, 0.88)
	var unlit := Color(0.34, 0.36, 0.46)
	var p := fposmod(phase, 1.0)
	var waxing := p < 0.5
	var k := cos(p * TAU)
	var s := 1.0 if waxing else -1.0

	ci.draw_circle(c, rad, unlit)                       # the dark disc
	var n := 24
	var pts := PackedVector2Array()
	for i in range(n + 1):                              # the lit limb
		var a := -PI * 0.5 + PI * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rad * s, sin(a) * rad))
	for i in range(n + 1):                              # back along the terminator
		var a2 := PI * 0.5 - PI * float(i) / float(n)
		pts.append(c + Vector2(cos(a2) * rad * k * s, sin(a2) * rad))
	if absf(1.0 - k) > 0.02:
		ci.draw_colored_polygon(pts, pale)
		ci.draw_circle(c, rad * 1.7, Color(pale.r, pale.g, pale.b, 0.07))
	ci.draw_arc(c, rad, 0, TAU, 28, Color(0.62, 0.64, 0.72, 0.5), 1.0)

	# A few craters, drawn only where the sunlight actually reaches.
	for m in [Vector2(-0.30, -0.22), Vector2(0.24, 0.10), Vector2(-0.06, 0.38),
			Vector2(0.42, -0.36)]:
		var q := c + Vector2(m.x, m.y) * rad
		var yy: float = clampf(m.y, -0.99, 0.99)
		var term := rad * k * s * sqrt(1.0 - yy * yy)
		var lit := (q.x - c.x) >= term if waxing else (q.x - c.x) <= term
		if lit:
			ci.draw_circle(q, rad * 0.13, Color(0.84, 0.84, 0.79))

static func is_dark(minute: int) -> bool:
	var h := float(minute) / 60.0
	return h < 6.0 or h >= 19.5

# ---------------------------------------------------------------------------
# Small drawing helpers
# ---------------------------------------------------------------------------

## Floor slab, back wall in two tones, and a ceiling line. Everything else in
## a room is furniture standing on the slab.
static func _shell(ci: CanvasItem, r: Rect2, wall: Color, floor_c: Color) -> void:
	ci.draw_rect(r, wall)
	# a slightly darker band at the top reads as the ceiling in shadow
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, r.size.y * 0.22),
		wall.darkened(0.10))
	ci.draw_rect(Rect2(r.position.x, r.end.y - SLAB, r.size.x, SLAB), floor_c)
	ci.draw_line(Vector2(r.position.x, r.end.y - SLAB), Vector2(r.end.x, r.end.y - SLAB),
		floor_c.darkened(0.25), 1.0)

static func _lamp(ci: CanvasItem, at: Vector2, lit: bool, col: Color) -> void:
	ci.draw_line(at + Vector2(0, -6), at, col.darkened(0.5), 1.0)
	ci.draw_circle(at, 3.0, col if lit else col.darkened(0.5))
	if lit:
		ci.draw_circle(at, 6.0, Color(col.r, col.g, col.b, 0.16))

static func _chair(ci: CanvasItem, x: float, base_y: float, ink: Color,
		facing_right: bool = true) -> void:
	var d := 1.0 if facing_right else -1.0
	ci.draw_rect(Rect2(x - 3, base_y - 5, 6, 2), ink)
	ci.draw_rect(Rect2(x - d * 3.0 - 1.0, base_y - 11, 2, 7), ink)
	ci.draw_rect(Rect2(x - 1, base_y - 4, 2, 4), ink)

static func _plant(ci: CanvasItem, x: float, base_y: float) -> void:
	ci.draw_rect(Rect2(x - 4, base_y - 8, 8, 8), Color(0.58, 0.38, 0.26))
	ci.draw_circle(Vector2(x, base_y - 12), 6.0, Color(0.24, 0.46, 0.24))
	ci.draw_circle(Vector2(x - 4, base_y - 9), 4.0, Color(0.28, 0.52, 0.28))
	ci.draw_circle(Vector2(x + 4, base_y - 9), 4.0, Color(0.28, 0.52, 0.28))

static func _window(ci: CanvasItem, r: Rect2, lit: bool, mullions: int = 1) -> void:
	ci.draw_rect(r, WARM if lit else GLASS.darkened(0.45))
	ci.draw_rect(r, OUTLINE.lightened(0.25), false, 1.0)
	for i in range(1, mullions + 1):
		var x := r.position.x + r.size.x * float(i) / float(mullions + 1)
		ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y),
			OUTLINE.lightened(0.35), 1.0)

# ---------------------------------------------------------------------------
# Facilities
# ---------------------------------------------------------------------------

## `present` is how many of the people who belong here are actually inside
## right now. A lit window is not the same as an occupied room, and a tower
## with nobody visible in it looks like a model rather than a place.
static func draw_facility(ci: CanvasItem, f: Facility, minute: int,
		eval_tint: Color = Color(0, 0, 0, 0), present: int = 0) -> void:
	var r := cell_rect(f.seg, f.row, f.w, f.h)
	var t := f.type

	# Stairs and escalators sit ON the floor, so they paint themselves and
	# nothing else. No card, no outline, no tint -- what is behind them stays
	# visible, which is the whole point of drawing them at all.
	if FacilityDB.kind_of(t) == FacilityDB.Kind.TRANSPORT:
		if f.wrecked:
			return
		# A flight connects its own floor to the one above, so it rises through
		# exactly ONE floor's height: from this floor's slab to the next one's.
		# It used to be drawn across the full two-row footprint, which made it
		# look as though it climbed two storeys and landed a floor higher than
		# it actually does.
		# A flight runs from the walking surface of its own floor to the
		# walking surface of the one above. Both slabs are drawn four pixels
		# thick at the BOTTOM of their row, so the run is the row's rectangle
		# lifted by that much -- without the lift it started just above one
		# slab and stopped just below the other, meeting neither.
		var run := cell_rect(f.seg, f.row, f.w, 1)
		run.position.y -= SLAB
		if t == "stairs":
			_draw_stairs(ci, run, trim(t), detail(t))
		else:
			_draw_escalator(ci, run, trim(t), detail(t), minute)
		return

	var col := body(t)
	var tr := trim(t)
	var det := detail(t)
	if FacilityDB.kind_of(t) == FacilityDB.Kind.FOOD and f.brand != "":
		col = brand_body(f.brand, col)
		tr = brand_trim(f.brand, tr)
	if f.wrecked:
		ci.draw_rect(r, Color(0.16, 0.15, 0.14))
		_hatch(ci, r, Color(0.34, 0.30, 0.26))
		ci.draw_rect(r, OUTLINE, false, 1.0)
		return
	# Three states, and they must look different at a glance: to let (pale and
	# bare), let but asleep (dark), and busy (lit).
	if _vacant(f):
		_shell(ci, r, Color(0.80, 0.79, 0.75), Color(0.62, 0.61, 0.57))
		_to_let(ci, r)
		ci.draw_rect(r, OUTLINE, false, 1.0)
		return
	var lit := _lit(f, minute)
	if not lit:
		col = col.darkened(0.30)
		tr = tr.darkened(0.24)
		det = det.darkened(0.42)

	match FacilityDB.kind_of(t):
		FacilityDB.Kind.OFFICE:
			_draw_office(ci, r, col, tr, det, lit, minute, present)
		FacilityDB.Kind.CONDO:
			_draw_condo(ci, r, col, tr, det, lit, minute, present)
		FacilityDB.Kind.HOTEL:
			_draw_hotel(ci, r, col, tr, det, lit, f, present)
		FacilityDB.Kind.FOOD:
			_draw_food(ci, r, col, tr, det, lit, t == "restaurant", f.brand, present)
		FacilityDB.Kind.SHOP:
			_draw_shop(ci, r, col, tr, det, lit, present)
		FacilityDB.Kind.VENUE:
			if t == "cinema":
				_draw_cinema(ci, r, col, tr, det, lit, present)
			else:
				_draw_party(ci, r, col, tr, det, lit, present)
		FacilityDB.Kind.SERVICE:
			_draw_service(ci, r, col, tr, det, t, present)
		FacilityDB.Kind.PARKING:
			_draw_parking(ci, r, col, tr, det, t)
		FacilityDB.Kind.CIVIC:
			if t == "cathedral":
				_draw_cathedral(ci, r, col, tr, det, lit)
			else:
				_draw_metro(ci, r, col, tr, det)
		_:
			ci.draw_rect(r, col)
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

## An empty room waiting for a tenant: bare boards, a ladder and a paint tin.
static func _to_let(ci: CanvasItem, r: Rect2) -> void:
	var x := r.position.x + 6.0
	while x < r.end.x - 6.0:
		ci.draw_line(Vector2(x, r.position.y + 7), Vector2(x, r.end.y - 5),
			Color(0.73, 0.72, 0.68), 1.0)
		x += 9.0
	var lx := r.position.x + 8.0
	ci.draw_line(Vector2(lx, r.end.y - 4), Vector2(lx + 6, r.position.y + 8),
		Color(0.64, 0.55, 0.40), 1.5)
	ci.draw_line(Vector2(lx + 7, r.end.y - 4), Vector2(lx + 13, r.position.y + 8),
		Color(0.64, 0.55, 0.40), 1.5)
	for i in range(3):
		var yy := r.end.y - 8.0 - float(i) * 7.0
		ci.draw_line(Vector2(lx + 2 + float(i) * 1.5, yy),
			Vector2(lx + 9 + float(i) * 1.5, yy), Color(0.64, 0.55, 0.40), 1.0)

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
		FacilityDB.Kind.CIVIC:
			return true
		_:
			return true

# --- people ----------------------------------------------------------------

## Shirt colours, so a room full of workers is not a row of identical dolls.
const SHIRTS := [Color(0.26, 0.32, 0.48), Color(0.55, 0.24, 0.26),
	Color(0.24, 0.42, 0.34), Color(0.46, 0.36, 0.22), Color(0.36, 0.28, 0.44),
	Color(0.62, 0.48, 0.28)]

const SKIN := Color(0.92, 0.76, 0.62)

## Somebody in a room, seen from the side. Seated figures are shorter and sit
## a chair's height off the floor; standing ones reach their full height.
static func _figure(ci: CanvasItem, x: float, base_y: float, tint: int,
		sitting: bool = false) -> void:
	var shirt: Color = SHIRTS[posmod(tint, SHIRTS.size())]
	if sitting:
		ci.draw_rect(Rect2(x - 2.5, base_y - 11, 5, 7), shirt)      # torso
		ci.draw_rect(Rect2(x - 1, base_y - 4, 5, 2.5), shirt.darkened(0.3))
		ci.draw_circle(Vector2(x, base_y - 13), 2.6, SKIN)
	else:
		ci.draw_rect(Rect2(x - 2.5, base_y - 13, 5, 9), shirt)
		ci.draw_rect(Rect2(x - 2.5, base_y - 4, 5, 4), shirt.darkened(0.35))
		ci.draw_circle(Vector2(x, base_y - 15), 2.8, SKIN)

# --- offices and homes -----------------------------------------------------

## An office is two big panes of glass with the sky behind them, a desk under
## each, and nothing else. It has to be told apart from a flat at a glance and
## across a whole floor of them, so the difference is structural: bare glazing
## and a cold grey-blue against curtains, a sofa and a warm tan.
static func _draw_office(ci: CanvasItem, r: Rect2, col: Color, tr: Color,
		det: Color, lit: bool, minute: int, present: int) -> void:
	_shell(ci, r, col, tr)
	var base := r.end.y - SLAB
	var ink := tr.darkened(0.15)
	var sky := sky_colour(minute)

	# Two large windows, glazed with whatever the sky is doing outside.
	var pad := 5.0
	var gap := 5.0
	var top := r.position.y + 5.0
	var bot := base - 13.0
	var w := (r.size.x - pad * 2.0 - gap) * 0.5
	for i in range(2):
		var g := Rect2(r.position.x + pad + float(i) * (w + gap), top, w, bot - top)
		ci.draw_rect(g, sky)
		ci.draw_line(Vector2(g.position.x, g.position.y + g.size.y * 0.38),
			Vector2(g.end.x, g.position.y + g.size.y * 0.38), ink, 1.0)
		ci.draw_line(Vector2(g.get_center().x, g.position.y),
			Vector2(g.get_center().x, g.end.y), ink, 1.0)
		ci.draw_rect(g, ink, false, 1.5)
		ci.draw_rect(Rect2(g.position.x - 1, g.end.y, g.size.x + 2, 2), tr)
		if lit:
			ci.draw_rect(Rect2(g.position.x - 1, g.end.y + 2, g.size.x + 2, 2),
				Color(det.r, det.g, det.b, 0.55))

	# A desk under each window, with whoever is at it.
	for i in range(2):
		var cx := r.position.x + pad + w * 0.5 + float(i) * (w + gap)
		if present > i:
			_figure(ci, cx + w * 0.20, base, i, true)
		ci.draw_rect(Rect2(cx - w * 0.34, base - 9, w * 0.68, 2.0), ink)
		ci.draw_rect(Rect2(cx - w * 0.30, base - 7, 1.5, 7), ink)
		ci.draw_rect(Rect2(cx + w * 0.28, base - 7, 1.5, 7), ink)
		ci.draw_rect(Rect2(cx - 4, base - 15, 8, 6), det if lit else ink)
		ci.draw_rect(Rect2(cx - 4, base - 15, 8, 6), ink, false, 1.0)
	# anybody else is on their feet between the desks
	if present > 2:
		_figure(ci, r.position.x + pad + w + gap * 0.5, base, 2, false)

## A flat is a home: one curtained window, a sofa, a standing lamp, a
## television and a plant, in warm tan. Nothing here is glazed edge to edge,
## which is the whole point of the contrast with an office.
static func _draw_condo(ci: CanvasItem, r: Rect2, col: Color, tr: Color,
		det: Color, lit: bool, minute: int, present: int) -> void:
	_shell(ci, r, col, tr)
	var base := r.end.y - SLAB
	var ink := tr.darkened(0.15)

	var g := Rect2(r.position.x + 9, r.position.y + 8, 22, 14)
	ci.draw_rect(g, sky_colour(minute))
	ci.draw_line(Vector2(g.get_center().x, g.position.y),
		Vector2(g.get_center().x, g.end.y), ink, 1.0)
	ci.draw_rect(g, ink, false, 1.5)
	for side in [-1.0, 1.0]:
		var cxx: float = g.get_center().x + side * (g.size.x * 0.5 + 2.0)
		ci.draw_rect(Rect2(cxx - 3.0, g.position.y - 2, 6, g.size.y + 4), tr)
	ci.draw_rect(Rect2(g.position.x - 6, g.position.y - 4, g.size.x + 12, 2.5), ink)

	var sx := r.position.x + 44.0
	ci.draw_rect(Rect2(sx - 6, base - 1, 40, 1.5), det.darkened(0.25))
	# whoever is home is on the sofa, so they are drawn before its front
	if present > 0:
		_figure(ci, sx + 7, base - 2, 3, true)
	if present > 1:
		_figure(ci, sx + 19, base - 2, 1, true)
	ci.draw_rect(Rect2(sx, base - 15, 26, 7), tr.lightened(0.16))
	ci.draw_rect(Rect2(sx, base - 9, 26, 9), tr)
	ci.draw_rect(Rect2(sx - 3, base - 14, 4, 14), tr)
	ci.draw_rect(Rect2(sx + 25, base - 14, 4, 14), tr)
	_lamp(ci, Vector2(sx + 34, base - 17), lit, det)
	ci.draw_rect(Rect2(sx + 33, base - 11, 2, 11), ink)
	if present > 2:
		_figure(ci, r.position.x + 34, base, 5, false)
	if r.size.x > 100.0:
		ci.draw_rect(Rect2(r.end.x - 24, base - 20, 18, 13), ink)
		ci.draw_rect(Rect2(r.end.x - 22, base - 18, 14, 9),
			det if lit else Color(0.30, 0.34, 0.38))
		ci.draw_rect(Rect2(r.end.x - 17, base - 7, 4, 7), ink)
	_plant(ci, r.position.x + 38, base)

static func _draw_hotel(ci: CanvasItem, r: Rect2, col: Color, tr: Color,
		det: Color, lit: bool, f: Facility, present: int) -> void:
	_shell(ci, r, col, tr)
	var base := r.end.y - SLAB
	var ink := tr.darkened(0.2)
	var beds := 1 if f.type == "hotel_single" else 2
	var bw: float = minf((r.size.x - 14.0) / float(beds) - 3.0, 20.0)
	for i in range(beds):
		var bx := r.position.x + 4.0 + float(i) * (bw + 4.0)
		ci.draw_rect(Rect2(bx, base - 20, 2.5, 18), ink)
		ci.draw_rect(Rect2(bx, base - 10, bw, 8), Color(0.94, 0.93, 0.90))
		ci.draw_rect(Rect2(bx + bw * 0.42, base - 10, bw * 0.58, 8), det.darkened(0.1))
		ci.draw_rect(Rect2(bx + 1, base - 13, bw * 0.32, 4), Color(0.98, 0.98, 0.96))
		# a guest in the bed: a head on the pillow and a hump under the blanket
		if present > i:
			ci.draw_circle(Vector2(bx + bw * 0.20, base - 13), 2.6, SKIN)
			ci.draw_rect(Rect2(bx + bw * 0.42, base - 12, bw * 0.34, 2.5),
				det.darkened(0.25))
		ci.draw_rect(Rect2(bx, base - 2, bw, 2), ink)
	var lx := r.position.x + 4.0 + float(beds) * (bw + 4.0) + 3.0
	if lx < r.end.x - 8.0:
		_lamp(ci, Vector2(lx + 3, base - 15), lit, det)
		ci.draw_rect(Rect2(lx, base - 9, 7, 9), ink)
	if f.type == "hotel_suite":
		ci.draw_rect(Rect2(r.end.x - 16, base - 12, 12, 12), tr.lightened(0.15))
		ci.draw_rect(Rect2(r.end.x - 16, base - 18, 12, 7), tr)
	if f.roaches:
		for i in range(5):
			var x := r.position.x + 6.0 + float(i) * (r.size.x - 12.0) / 4.0
			ci.draw_circle(Vector2(x, base - 3), 2.2, Color(0.24, 0.14, 0.07))
			ci.draw_line(Vector2(x - 3, base - 5), Vector2(x - 1, base - 3),
				Color(0.24, 0.14, 0.07), 1.0)
			ci.draw_line(Vector2(x + 3, base - 5), Vector2(x + 1, base - 3),
				Color(0.24, 0.14, 0.07), 1.0)
	elif f.dirty:
		ci.draw_rect(Rect2(r.position.x + 3, r.position.y + 5, r.size.x - 6, 4),
			Color(0.62, 0.50, 0.30, 0.8))

# --- trade -----------------------------------------------------------------

## Each brand gets its own colour and its own sign. Five identical orange
## boxes labelled differently in a menu is not five kinds of restaurant.
const BRANDS := {
	"Burger Bar":    [Color(0.90, 0.55, 0.20), Color(0.62, 0.26, 0.12), "burger"],
	"Noodle House":  [Color(0.82, 0.42, 0.28), Color(0.46, 0.20, 0.16), "bowl"],
	"Cucina cinese": [Color(0.80, 0.24, 0.24), Color(0.48, 0.12, 0.12), "lantern"],
	"Chinese Cafe":  [Color(0.80, 0.24, 0.24), Color(0.48, 0.12, 0.12), "lantern"],
	"Pizza Slice":   [Color(0.88, 0.72, 0.36), Color(0.44, 0.46, 0.24), "slice"],
	"Coffee Shop":   [Color(0.58, 0.42, 0.30), Color(0.32, 0.22, 0.15), "cup"],
	"The Grill":     [Color(0.46, 0.32, 0.32), Color(0.24, 0.16, 0.16), "flame"],
	"Sushi Bar":     [Color(0.30, 0.40, 0.60), Color(0.16, 0.22, 0.38), "sushi"],
	"Steakhouse":    [Color(0.62, 0.24, 0.22), Color(0.34, 0.12, 0.12), "flame"],
	"Bistro":        [Color(0.72, 0.32, 0.34), Color(0.40, 0.16, 0.18), "glass"],
	"Brasserie":     [Color(0.34, 0.48, 0.36), Color(0.18, 0.28, 0.20), "glass"],
}

static func brand_body(brand: String, fallback: Color) -> Color:
	return BRANDS[brand][0] if BRANDS.has(brand) else fallback

static func brand_trim(brand: String, fallback: Color) -> Color:
	return BRANDS[brand][1] if BRANDS.has(brand) else fallback

static func _sign(ci: CanvasItem, c: Vector2, brand: String, lit: bool) -> void:
	var glyph := String(BRANDS[brand][2]) if BRANDS.has(brand) else ""
	var on := Color(0.99, 0.92, 0.66) if lit else Color(0.70, 0.66, 0.56)
	var hot := Color(0.95, 0.55, 0.20) if lit else Color(0.55, 0.36, 0.22)
	match glyph:
		"burger":
			ci.draw_circle(c + Vector2(0, -2), 5.0, on)
			ci.draw_rect(Rect2(c.x - 5, c.y - 1, 10, 2), Color(0.42, 0.62, 0.30))
			ci.draw_rect(Rect2(c.x - 5, c.y + 1, 10, 3), Color(0.46, 0.27, 0.16))
			ci.draw_rect(Rect2(c.x - 5, c.y + 4, 10, 3), on)
		"bowl":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-7, 0), c + Vector2(7, 0), c + Vector2(4, 6),
				c + Vector2(-4, 6)]), on)
			for i in range(3):
				ci.draw_line(c + Vector2(-3.0 + float(i) * 3.0, -1),
					c + Vector2(-4.0 + float(i) * 3.0, -6), on, 1.0)
		"lantern":
			ci.draw_circle(c + Vector2(0, 1), 5.0, hot)
			ci.draw_rect(Rect2(c.x - 3, c.y - 5, 6, 1.5), on)
			ci.draw_rect(Rect2(c.x - 1, c.y + 5, 2, 4), on)
		"slice":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -6), c + Vector2(6, 6), c + Vector2(-6, 6)]), on)
			ci.draw_circle(c + Vector2(-2, 2), 1.4, Color(0.78, 0.22, 0.18))
			ci.draw_circle(c + Vector2(2, 3), 1.4, Color(0.78, 0.22, 0.18))
		"cup":
			ci.draw_rect(Rect2(c.x - 5, c.y - 3, 9, 8), on)
			ci.draw_arc(c + Vector2(5, 1), 3.0, -1.4, 1.4, 10, on, 1.5)
			ci.draw_line(c + Vector2(-2, -6), c + Vector2(-3, -9), on, 1.0)
		"flame":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-5, 6), c + Vector2(5, 6), c + Vector2(0, -7)]), hot)
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-2, 6), c + Vector2(2, 6), c + Vector2(0, -1)]), on)
		"sushi":
			ci.draw_rect(Rect2(c.x - 7, c.y - 1, 6, 6), Color(0.96, 0.95, 0.92))
			ci.draw_rect(Rect2(c.x - 7, c.y - 4, 6, 3), Color(0.86, 0.42, 0.34))
			ci.draw_rect(Rect2(c.x + 1, c.y - 1, 6, 6), Color(0.96, 0.95, 0.92))
			ci.draw_rect(Rect2(c.x + 1, c.y - 4, 6, 3), Color(0.30, 0.34, 0.30))
		"glass":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-5, -6), c + Vector2(5, -6), c + Vector2(0, 2)]), on)
			ci.draw_rect(Rect2(c.x - 1, c.y + 1, 2, 5), on)
			ci.draw_rect(Rect2(c.x - 4, c.y + 6, 8, 1.5), on)

static func _draw_food(ci: CanvasItem, r: Rect2, col: Color, tr: Color,
		det: Color, lit: bool, posh: bool, brand: String, present: int) -> void:
	_shell(ci, r, col, tr)
	var base := r.end.y - SLAB
	var ink := tr.darkened(0.2)
	# a striped awning across the top, in the brand's own colours
	var stripe := 7.0
	var x := r.position.x
	var on := true
	while x < r.end.x:
		ci.draw_rect(Rect2(x, r.position.y, minf(stripe, r.end.x - x), 6),
			det.darkened(0.05) if on else tr)
		x += stripe
		on = not on
	ci.draw_rect(Rect2(r.position.x, r.position.y + 6, r.size.x, 1.5), ink)

	if posh:
		var n := maxi(int(r.size.x / 46.0), 1)
		for i in range(n):
			var cx := r.position.x + 24.0 + (float(i) + 0.5) * (r.size.x - 24.0) / float(n)
			_lamp(ci, Vector2(cx, r.position.y + 14), lit, det)
			if present > i * 2:
				_figure(ci, cx - 15, base, i, true)
			if present > i * 2 + 1:
				_figure(ci, cx + 15, base, i + 3, true)
			ci.draw_rect(Rect2(cx - 11, base - 11, 22, 2.5), ink)
			ci.draw_rect(Rect2(cx - 10, base - 9, 20, 7), Color(0.95, 0.94, 0.91))
			_chair(ci, cx - 15, base, ink, true)
			_chair(ci, cx + 15, base, ink, false)
	else:
		ci.draw_rect(Rect2(r.position.x + 4, base - 13, r.size.x * 0.42, 3), ink)
		ci.draw_rect(Rect2(r.position.x + 4, base - 11, r.size.x * 0.42, 11),
			tr.lightened(0.1))
		if present > 0:                    # somebody behind the counter
			_figure(ci, r.position.x + 10, base - 12, 4, false)
		var sx := r.position.x + r.size.x * 0.42 + 12.0
		var k := 1
		while sx < r.end.x - 6.0:
			if present > k:
				_figure(ci, sx, base - 2, k, true)
			ci.draw_rect(Rect2(sx - 4, base - 9, 8, 2), ink)
			ci.draw_rect(Rect2(sx - 1, base - 7, 2, 7), ink)
			sx += 14.0
			k += 1

	# The sign goes on last, on a board of its own. Drawn earlier it ended up
	# behind the counter, which is exactly where a sign should not be.
	var board := Rect2(r.position.x + 5, r.position.y + 9, 26, 19)
	ci.draw_rect(board, ink.darkened(0.25))
	ci.draw_rect(board, tr.lightened(0.35), false, 1.5)
	_sign(ci, board.get_center(), brand, lit)

static func _draw_shop(ci: CanvasItem, r: Rect2, col: Color, tr: Color,
		det: Color, lit: bool, present: int) -> void:
	_shell(ci, r, col, tr)
	var base := r.end.y - SLAB
	var ink := tr.darkened(0.2)
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 7), tr)
	ci.draw_rect(Rect2(r.position.x + 3, r.position.y + 2, r.size.x - 6, 3),
		det if lit else tr.lightened(0.15))
	var w := Rect2(r.position.x + 4, r.position.y + 11, r.size.x * 0.52,
		base - r.position.y - 13)
	ci.draw_rect(w, WARM.lerp(col, 0.35) if lit else col.darkened(0.25))
	ci.draw_rect(w, ink, false, 1.0)
	for k in range(2):
		var sy := w.position.y + 7.0 + float(k) * 11.0
		if sy > w.end.y - 3.0:
			break
		ci.draw_line(Vector2(w.position.x + 2, sy), Vector2(w.end.x - 2, sy), ink, 1.0)
		for j in range(3):
			ci.draw_rect(Rect2(w.position.x + 4.0 + float(j) * 12.0, sy - 5, 6, 5),
				det.darkened(0.15))
	if present > 1:
		_figure(ci, w.end.x - 6, base, 2, false)      # a customer at the window
	ci.draw_rect(Rect2(w.end.x + 6, base - 12, r.end.x - w.end.x - 10, 3), ink)
	ci.draw_rect(Rect2(w.end.x + 6, base - 10, r.end.x - w.end.x - 10, 10),
		tr.lightened(0.1))
	if present > 0:
		_figure(ci, w.end.x + 14, base - 13, 0, false)   # the shopkeeper

# --- venues ----------------------------------------------------------------

static func _draw_party(ci: CanvasItem, r: Rect2, col: Color, tr: Color,
		det: Color, lit: bool, present: int) -> void:
	_shell(ci, r, col, tr)
	var base := r.end.y - SLAB
	var ink := tr.darkened(0.2)
	var c := Vector2(r.get_center().x, r.position.y + 16)
	ci.draw_line(Vector2(c.x, r.position.y), c, ink, 1.5)
	ci.draw_circle(c, 7.0, det if lit else ink)
	for i in range(5):
		var a := PI + float(i) * PI / 4.0
		ci.draw_circle(c + Vector2(cos(a), -sin(a)) * 11.0, 2.5, det if lit else ink)
	var n := maxi(int(r.size.x / 60.0), 2)
	for i in range(n):
		var tx := r.position.x + (float(i) + 0.5) * r.size.x / float(n)
		var here: int = present * (i + 1) / maxi(n, 1) - present * i / maxi(n, 1)
		for k in range(mini(here, 3)):
			_figure(ci, tx - 16.0 + float(k) * 16.0, base, i + k, false)
		ci.draw_rect(Rect2(tx - 13, base - 14, 26, 3), ink)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(tx - 13, base - 12), Vector2(tx + 13, base - 12),
			Vector2(tx + 9, base), Vector2(tx - 9, base)]),
			Color(0.96, 0.95, 0.92))
	for sx in [r.position.x + 10.0, r.end.x - 10.0]:
		for k in range(2):
			var bx: float = sx + float(k) * 7.0 - 3.0
			ci.draw_circle(Vector2(bx, r.position.y + 26.0 + float(k) * 4.0), 4.5, det)
			ci.draw_line(Vector2(bx, r.position.y + 30.0 + float(k) * 4.0),
				Vector2(bx + 1, base), ink, 1.0)

static func _draw_cinema(ci: CanvasItem, r: Rect2, col: Color, tr: Color,
		det: Color, lit: bool, present: int) -> void:
	ci.draw_rect(r, Color(0.15, 0.14, 0.20))
	var base := r.end.y - SLAB
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 8), tr)
	for i in range(int(r.size.x / 12.0)):
		ci.draw_circle(Vector2(r.position.x + 7.0 + float(i) * 12.0, r.position.y + 4),
			2.0, det if lit else det.darkened(0.6))
	var sc := Rect2(r.position.x + 10, r.position.y + 16, r.size.x * 0.34, r.size.y * 0.42)
	ci.draw_rect(sc, Color(0.90, 0.90, 0.88) if lit else Color(0.26, 0.26, 0.30))
	ci.draw_rect(sc, Color(0.55, 0.54, 0.58), false, 1.5)
	if lit:
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(r.end.x - 14, r.position.y + 20), sc.end,
			Vector2(sc.end.x, sc.position.y)]), Color(0.98, 0.96, 0.80, 0.10))
	var seats := 0
	for row in range(4):
		var y := base - 6.0 - float(row) * 7.0
		if y < sc.end.y:
			break
		for i in range(int(r.size.x / 11.0)):
			var x := r.position.x + 8.0 + float(i) * 11.0 + float(row) * 2.0
			if x > r.end.x - 8.0:
				break
			# an audience: a head over the seat back where somebody is sitting
			if seats < present:
				ci.draw_circle(Vector2(x + 3.5, y - 4), 2.4, SKIN.darkened(0.15))
			seats += 1
			ci.draw_rect(Rect2(x, y, 7, 5), Color(0.44, 0.18, 0.20))
			ci.draw_rect(Rect2(x, y - 3, 7, 3), Color(0.52, 0.22, 0.24))

# --- services --------------------------------------------------------------

static func _draw_service(ci: CanvasItem, r: Rect2, col: Color, tr: Color,
		det: Color, t: String, present: int) -> void:
	_shell(ci, r, col, tr)
	var base := r.end.y - SLAB
	var ink := tr.darkened(0.2)
	var c := Vector2(r.get_center().x, r.get_center().y)
	match t:
		"medical":
			ci.draw_rect(Rect2(r.position.x + 10, r.position.y + 8, 7, 20), det)
			ci.draw_rect(Rect2(r.position.x + 3.5, r.position.y + 14.5, 20, 7), det)
			ci.draw_rect(Rect2(r.end.x - 46, base - 11, 34, 3), ink)
			ci.draw_rect(Rect2(r.end.x - 46, base - 9, 34, 7), Color(0.94, 0.94, 0.92))
			ci.draw_rect(Rect2(r.end.x - 46, base - 15, 8, 5), Color(0.98, 0.98, 0.96))
			ci.draw_rect(Rect2(r.end.x - 10, base - 22, 3, 22), ink)
			ci.draw_rect(Rect2(r.end.x - 14, base - 26, 11, 6), ink)
			for i in range(mini(present, 2)):
				_figure(ci, r.position.x + 34.0 + float(i) * 14.0, base, i, false)
		"security":
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(r.position.x + 16, r.position.y + 7),
				Vector2(r.position.x + 26, r.position.y + 12),
				Vector2(r.position.x + 16, r.position.y + 26),
				Vector2(r.position.x + 6, r.position.y + 12)]), det)
			for i in range(mini(present, 2)):
				_figure(ci, r.position.x + 40.0 + float(i) * 13.0, base, i, false)
			ci.draw_rect(Rect2(r.end.x - 44, base - 12, 32, 3), ink)
			ci.draw_rect(Rect2(r.end.x - 44, base - 10, 32, 10), tr.lightened(0.1))
			for i in range(3):
				ci.draw_rect(Rect2(r.end.x - 42.0 + float(i) * 11.0, base - 24, 9, 10),
					Color(0.30, 0.46, 0.36))
				ci.draw_rect(Rect2(r.end.x - 42.0 + float(i) * 11.0, base - 24, 9, 10),
					ink, false, 1.0)
		"recycling":
			for i in range(3):
				var a2 := float(i) * TAU / 3.0 - PI / 2.0
				var p := Vector2(r.position.x + 30, c.y) + Vector2(cos(a2), sin(a2)) * 12.0
				ci.draw_colored_polygon(PackedVector2Array([
					p + Vector2(0, -7), p + Vector2(7, 5), p + Vector2(-7, 5)]), det)
			var bx := r.position.x + 62.0
			while bx < r.end.x - 12.0:
				ci.draw_rect(Rect2(bx, base - 18, 14, 18), ink)
				ci.draw_rect(Rect2(bx - 1, base - 21, 16, 4), tr)
				bx += 20.0
		_:
			var cx := r.position.x + 10.0
			var k := 0
			while cx < r.end.x - 22.0:
				if present > k:
					_figure(ci, cx + 17, base, k, false)
				ci.draw_rect(Rect2(cx, base - 14, 13, 12), det)
				ci.draw_rect(Rect2(cx, base - 18, 13, 5), tr)
				ci.draw_circle(Vector2(cx + 3, base - 1), 2.0, ink)
				ci.draw_circle(Vector2(cx + 10, base - 1), 2.0, ink)
				cx += 20.0
				k += 1
			ci.draw_line(Vector2(r.end.x - 8, r.position.y + 8),
				Vector2(r.end.x - 13, base - 6), ink, 2.0)
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(r.end.x - 18, base), Vector2(r.end.x - 8, base),
				Vector2(r.end.x - 10, base - 7), Vector2(r.end.x - 16, base - 7)]),
				Color(0.78, 0.62, 0.32))

# --- underground and civic -------------------------------------------------

static func _draw_parking(ci: CanvasItem, r: Rect2, col: Color, tr: Color,
		det: Color, t: String) -> void:
	if t == "parking_ramp":
		ci.draw_rect(r, col)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(r.position.x + 2, r.end.y - 3), Vector2(r.end.x - 2, r.position.y + 5),
			Vector2(r.end.x - 2, r.position.y + 11), Vector2(r.position.x + 2, r.end.y + 3)]),
			tr.lightened(0.2))
		for i in range(4):
			var p := Vector2(r.position.x + 4, r.end.y - 6).lerp(
				Vector2(r.end.x - 6, r.position.y + 8), float(i) / 3.0)
			ci.draw_rect(Rect2(p.x - 4, p.y - 1, 8, 2), det)
		return
	# a bay: painted lines, a car, a strip light
	ci.draw_rect(r, col)
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 3), tr)
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y + 6, r.size.x - 2, 1),
		Color(0.90, 0.90, 0.86, 0.6))
	ci.draw_rect(Rect2(r.position.x, r.position.y + 4, 1.5, r.size.y - 6),
		Color(0.90, 0.90, 0.86, 0.5))
	var cx := r.get_center().x
	var base := r.end.y - 3.0
	ci.draw_rect(Rect2(cx - 13, base - 10, 26, 6), det.darkened(0.3))
	ci.draw_rect(Rect2(cx - 8, base - 15, 16, 6), det.darkened(0.15))
	ci.draw_rect(Rect2(cx - 6, base - 14, 12, 4), GLASS.darkened(0.2))
	ci.draw_circle(Vector2(cx - 7, base - 3), 3.0, Color(0.13, 0.13, 0.13))
	ci.draw_circle(Vector2(cx + 7, base - 3), 3.0, Color(0.13, 0.13, 0.13))

static func _draw_metro(ci: CanvasItem, r: Rect2, col: Color, tr: Color,
		det: Color) -> void:
	ci.draw_rect(r, col)
	# tiled wall
	var y := r.position.y + 6.0
	while y < r.end.y - 24.0:
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y),
			col.lightened(0.08), 1.0)
		y += 9.0
	# platform edge and rails
	var base := r.end.y - 4.0
	ci.draw_rect(Rect2(r.position.x, base - 14, r.size.x, 3), tr.lightened(0.3))
	ci.draw_rect(Rect2(r.position.x, base - 2, r.size.x, 2), tr)
	ci.draw_rect(Rect2(r.position.x, base - 6, r.size.x, 1.5), tr.lightened(0.4))
	# the train, with lit windows
	var train := Rect2(r.position.x + 16, base - 40, r.size.x - 44, 26)
	ci.draw_rect(train, det.darkened(0.05))
	ci.draw_rect(train, OUTLINE, false, 1.5)
	ci.draw_rect(Rect2(train.position.x, train.position.y, train.size.x, 4),
		det.darkened(0.35))
	var i := 0
	while train.position.x + 7.0 + float(i) * 26.0 < train.end.x - 16.0:
		ci.draw_rect(Rect2(train.position.x + 7.0 + float(i) * 26.0,
			train.position.y + 8, 17, 10), GLASS)
		i += 1
	ci.draw_rect(Rect2(train.end.x - 6, train.position.y + 9, 4, 5), WARM)
	# a hanging sign
	ci.draw_rect(Rect2(r.get_center().x - 18, r.position.y + 4, 36, 9), tr)
	ci.draw_rect(Rect2(r.get_center().x - 15, r.position.y + 6, 30, 5), det)

static func _draw_cathedral(ci: CanvasItem, r: Rect2, col: Color, tr: Color,
		det: Color, lit: bool) -> void:
	ci.draw_rect(r, col)
	var c := r.get_center()
	# gabled roof and a spire
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, r.position.y + 2),
		Vector2(r.end.x - 6, r.position.y + r.size.y * 0.38),
		Vector2(r.position.x + 6, r.position.y + r.size.y * 0.38)]), tr)
	ci.draw_rect(Rect2(c.x - 3, r.position.y - 22, 6, 24), tr)
	ci.draw_rect(Rect2(c.x - 9, r.position.y - 14, 18, 5), tr)
	# rose window
	var rw := Vector2(c.x, r.position.y + r.size.y * 0.52)
	ci.draw_circle(rw, 15.0, det if lit else det.darkened(0.4))
	ci.draw_circle(rw, 15.0, tr, false, 2.5)
	for i in range(8):
		var a := float(i) * TAU / 8.0
		ci.draw_line(rw, rw + Vector2(cos(a), sin(a)) * 15.0, tr, 1.5)
	# arched doors and lancet windows
	for i in [-1, 1]:
		var x := c.x + float(i) * 46.0
		_arch(ci, Vector2(x, r.end.y), 11.0, 34.0, tr)
		_arch(ci, Vector2(x, r.position.y + r.size.y * 0.62), 6.0, 20.0,
			det if lit else det.darkened(0.4))
	_arch(ci, Vector2(c.x, r.end.y), 16.0, 46.0, tr)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 4, r.size.x, 4), tr.darkened(0.2))

static func _arch(ci: CanvasItem, base: Vector2, half_w: float, h: float,
		col: Color) -> void:
	ci.draw_rect(Rect2(base.x - half_w, base.y - h + half_w, half_w * 2.0, h - half_w), col)
	ci.draw_circle(Vector2(base.x, base.y - h + half_w), half_w, col)

# --- transport laid over the floor -----------------------------------------
#
# These paint only themselves: no card behind them, no bounding outline, so
# the rooms and the structure they cross stay legible.

static func _draw_stairs(ci: CanvasItem, r: Rect2, tr: Color, det: Color) -> void:
	# A THIN stepped ribbon, not a filled wedge. Everything the flight does not
	# physically occupy stays transparent, so the floor and the rooms it crosses
	# read straight through.
	var steps := 7
	var sw := r.size.x / float(steps)
	var sh := r.size.y / float(steps)
	var slab := tr.lightened(0.52)
	var thick := 4.0
	for i in range(steps):
		var x := r.position.x + float(i) * sw
		var y := r.end.y - float(i + 1) * sh
		# tread, then the riser rising to the next one
		ci.draw_rect(Rect2(x, y, sw + 0.5, thick), slab)
		ci.draw_rect(Rect2(x, y, sw + 0.5, thick), OUTLINE, false, 1.0)
		ci.draw_rect(Rect2(x, y, 1.5, thick), det)
		if i < steps - 1:
			ci.draw_rect(Rect2(x + sw - 0.5, y - sh, thick, sh + thick), slab)
			ci.draw_rect(Rect2(x + sw - 0.5, y - sh, thick, sh + thick),
				OUTLINE, false, 1.0)
	# the stringer running under the noses, which is what carries the flight
	ci.draw_line(Vector2(r.position.x, r.end.y - sh + thick + 1.0),
		Vector2(r.end.x, r.position.y + thick + 1.0), tr, 2.0)
	# handrail above, on short posts
	ci.draw_line(Vector2(r.position.x + 1, r.end.y - sh - 11.0),
		Vector2(r.end.x - 1, r.position.y - 11.0 + thick), tr, 2.0)
	for i in range(0, steps + 1, 3):
		var px := r.position.x + float(i) * sw
		var py := r.end.y - float(i) * sh - sh
		ci.draw_line(Vector2(px, py + thick), Vector2(px, py - 11.0), tr, 1.2)

## The line from corner to corner of the run IS the step surface, and the
## machine is built upwards from it. It used to be the top of the truss, with
## the steps hanging eleven pixels below -- so the escalator appeared to hang
## off the upper floor and never quite touch either one.
static func _draw_escalator(ci: CanvasItem, r: Rect2, tr: Color, det: Color,
		minute: int) -> void:
	var a := Vector2(r.position.x, r.end.y)          # foot, on the lower slab
	var b := Vector2(r.end.x, r.position.y)          # head, on the upper slab
	var n := (b - a).normalized()
	var up := Vector2(n.y, -n.x)                     # perpendicular, upwards

	# the truss under the steps
	ci.draw_colored_polygon(PackedVector2Array([
		a, b, b - up * 5.0, a - up * 5.0]), tr.darkened(0.15))
	# the step band itself, sitting on the line
	ci.draw_colored_polygon(PackedVector2Array([
		a, b, b + up * 4.0, a + up * 4.0]), tr.lightened(0.45))
	ci.draw_polyline(PackedVector2Array([a, b, b + up * 4.0, a + up * 4.0, a]),
		OUTLINE, 1.2)
	# the treads, marching while the day is on
	var phase := fmod(float(minute) * 0.35, 1.0)
	for i in range(9):
		var t := (float(i) + phase) / 9.0
		if t > 1.0:
			continue
		var p := a.lerp(b, t)
		ci.draw_line(p + up * 0.5, p + up * 3.5, det, 1.8)
	# balustrade and handrail, above the steps where they belong
	ci.draw_line(a + up * 13.0, b + up * 13.0, tr, 2.2)
	ci.draw_line(a + up * 4.0, a + up * 14.0, tr, 1.5)
	ci.draw_line(b + up * 4.0, b + up * 14.0, tr, 1.5)
	ci.draw_line(a + up * 8.0, b + up * 8.0, Color(tr.r, tr.g, tr.b, 0.45), 1.0)

static func _hatch(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var x := r.position.x - r.size.y
	while x < r.end.x:
		ci.draw_line(Vector2(x, r.end.y), Vector2(x + r.size.y, r.position.y), col, 1.0)
		x += 7.0

# ---------------------------------------------------------------------------
# Structure, shafts, people
# ---------------------------------------------------------------------------

## An empty floor is BUILT, and must look it: opaque grey shell, not sky seen
## through a skeleton. You have paid for this storey and it is the difference
## between "there is a floor here" and "there is nothing here", which is the
## single most important thing the edit view has to tell you.
static func draw_empty_floor(ci: CanvasItem, seg: int, row: int, w: int) -> void:
	var r := cell_rect(seg, row, w, 1)
	ci.draw_rect(r, Color(0.62, 0.62, 0.60))
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, r.size.y * 0.20),
		Color(0.55, 0.55, 0.53))
	var x := r.position.x + 8.0
	while x < r.end.x - 4.0:
		ci.draw_rect(Rect2(x, r.position.y + 3, 3.0, r.size.y - 8.0), CONCRETE_DARK)
		x += 56.0
	ci.draw_rect(Rect2(r.position.x, r.end.y - SLAB, r.size.x, SLAB), CONCRETE_DARK)
	ci.draw_rect(Rect2(r.position.x, r.end.y - SLAB, r.size.x, 1.5), CONCRETE)

static func draw_lobby(ci: CanvasItem, seg: int, row: int, w: int, minute: int) -> void:
	var r := cell_rect(seg, row, w, 1)
	var col := body("lobby")
	var tr := trim("lobby")
	if is_dark(minute):
		col = col.darkened(0.22)
		tr = tr.darkened(0.18)
	ci.draw_rect(r, col)
	# a polished marble floor with a reflected band
	ci.draw_rect(Rect2(r.position.x, r.end.y - 7, r.size.x, 7), col.darkened(0.14))
	ci.draw_line(Vector2(r.position.x, r.end.y - 7), Vector2(r.end.x, r.end.y - 7),
		Color(1, 1, 1, 0.35), 1.0)
	# coffered ceiling
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 5), tr)
	var cx := r.position.x + 16.0
	while cx < r.end.x - 8.0:
		ci.draw_rect(Rect2(cx, r.position.y + 5, 10, 2), tr.lightened(0.25))
		cx += 34.0
	# columns, planters and benches along the concourse
	var x := r.position.x + 26.0
	var k := 0
	while x < r.end.x - 12.0:
		if k % 3 == 0:
			ci.draw_rect(Rect2(x - 3, r.position.y + 6, 6, r.size.y - 13), tr.lightened(0.18))
			ci.draw_rect(Rect2(x - 5, r.position.y + 6, 10, 3), tr)
			ci.draw_rect(Rect2(x - 5, r.end.y - 10, 10, 3), tr)
		elif k % 3 == 1:
			_plant(ci, x, r.end.y - 7)
		else:
			ci.draw_rect(Rect2(x - 9, r.end.y - 14, 18, 2.5), tr)
			ci.draw_rect(Rect2(x - 7, r.end.y - 12, 2, 5), tr)
			ci.draw_rect(Rect2(x + 5, r.end.y - 12, 2, 5), tr)
		x += 42.0
		k += 1

static func draw_shaft(ci: CanvasItem, s: Shaft, _row_top: int, _row_bot: int) -> void:
	var w := float(s.width()) * SEG_W
	var x := float(s.seg) * SEG_W
	var y0 := -float(s.top_row + 1) * ROW_H
	var y1 := -float(s.bottom_row) * ROW_H
	var col := body(s.type)
	ci.draw_rect(Rect2(x, y0, w, y1 - y0), col)
	# guide rails and counterweight track
	ci.draw_rect(Rect2(x + 1.5, y0, 2, y1 - y0), trim(s.type).lightened(0.25))
	ci.draw_rect(Rect2(x + w - 3.5, y0, 2, y1 - y0), trim(s.type).lightened(0.25))
	ci.draw_rect(Rect2(x, y0, w, y1 - y0), OUTLINE, false, 1.0)
	# the motor room on top, with its sheave
	ci.draw_rect(Rect2(x, y0 - 10, w, 10), trim(s.type))
	ci.draw_rect(Rect2(x, y0 - 10, w, 10), OUTLINE, false, 1.0)
	ci.draw_circle(Vector2(x + w * 0.5, y0 - 5), 3.5, detail(s.type))
	ci.draw_circle(Vector2(x + w * 0.5, y0 - 5), 1.5, trim(s.type).darkened(0.3))
	# and a matching pit below, which is the other drag handle
	ci.draw_rect(Rect2(x, y1, w, 7), trim(s.type))
	ci.draw_rect(Rect2(x, y1, w, 7), OUTLINE, false, 1.0)

static func draw_car(ci: CanvasItem, s: Shaft, c: Shaft.Car) -> void:
	var w := float(s.width()) * SEG_W
	var x := float(s.seg) * SEG_W
	var y := -(c.pos + 1.0) * ROW_H
	var r := Rect2(x + 1.5, y + 3, w - 3, ROW_H - 6)
	ci.draw_rect(r, detail(s.type))
	# the doors, parted a little so it reads as a car and not a block
	ci.draw_line(Vector2(r.get_center().x, r.position.y + 2),
		Vector2(r.get_center().x, r.end.y - 2), detail(s.type).darkened(0.28), 1.5)
	ci.draw_rect(r, OUTLINE, false, 1.0)
	# how full it is, filling from the floor of the car
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
	for i in range(3):
		var rx := x + 26.0 + float(i) * 20.0
		ci.draw_rect(Rect2(rx, y - 8, 14, 7), brown)
		ci.draw_rect(Rect2(rx + 11, y - 13, 5, 6), brown)
		ci.draw_line(Vector2(rx + 13, y - 13), Vector2(rx + 17, y - 19), brown, 1.5)
		ci.draw_line(Vector2(rx + 12, y - 13), Vector2(rx + 8, y - 19), brown, 1.5)
		ci.draw_line(Vector2(rx + 2, y - 1), Vector2(rx + 1, y + 4), brown, 1.5)
		ci.draw_line(Vector2(rx + 11, y - 1), Vector2(rx + 12, y + 4), brown, 1.5)
	ci.draw_line(Vector2(x + 16, y - 5), Vector2(x + 88, y - 5), brown, 1.0)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(x, y), Vector2(x + 22, y), Vector2(x + 22, y - 10),
		Vector2(x + 6, y - 10), Vector2(x, y - 4)]), red)
	ci.draw_line(Vector2(x - 2, y + 2), Vector2(x + 24, y + 2), Color(0.90, 0.78, 0.30), 2.0)
	ci.draw_line(Vector2(x - 2, y + 2), Vector2(x - 5, y - 3), Color(0.90, 0.78, 0.30), 2.0)
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
