extends Node2D

## The Edit window: the cutaway view of the tower you build in.

@export var camera_path: NodePath
var cam: Camera2D

var overlay: String = ""            # "", "eval", "price", "hotel"
var ghost_type: String = ""
var ghost_cell := Vector2i(0, 0)
var ghost_ok: bool = false
var ghost_w: int = 1
var ghost_drag_to := Vector2i(0, 0)
var dragging: bool = false
var t: float = 0.0

func _ready() -> void:
	cam = get_node_or_null(camera_path) as Camera2D
	set_process(true)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func visible_world() -> Rect2:
	if cam == null:
		return Rect2(0, -2000, 4000, 4000)
	var size := get_viewport_rect().size / cam.zoom
	return Rect2(cam.global_position - size * 0.5, size).grow(64.0)

func world_to_cell(p: Vector2) -> Vector2i:
	var seg := int(floor(p.x / Art.SEG_W))
	var row := int(floor(-p.y / Art.ROW_H))
	return Vector2i(seg, row)

func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(float(c.x) * Art.SEG_W, -float(c.y + 1) * Art.ROW_H)

func _draw() -> void:
	var g := Game
	if g == null or g.tower == null:
		return
	var view := visible_world()
	var minute := g.clock.minute_of_day()
	_draw_sky(view, minute)
	_draw_ground(view)

	var row_lo := maxi(int(floor(-view.end.y / Art.ROW_H)) - 1, FacilityDB.ROW_MIN)
	var row_hi := mini(int(ceil(-view.position.y / Art.ROW_H)) + 1, FacilityDB.ROW_MAX)
	var seg_lo := maxi(int(floor(view.position.x / Art.SEG_W)) - 1, 0)
	var seg_hi := mini(int(ceil(view.end.x / Art.SEG_W)) + 1, FacilityDB.MAP_SEGMENTS - 1)

	_draw_structure(g.tower, row_lo, row_hi, seg_lo, seg_hi, minute)
	_draw_facilities(g.tower, row_lo, row_hi, seg_lo, seg_hi, minute)
	_draw_shafts(g.tower, row_lo, row_hi)
	_draw_people(g, row_lo, row_hi, seg_lo, seg_hi)
	_draw_events(g, view)
	_draw_selection(g)
	_draw_ghost(g)

# --- backdrop --------------------------------------------------------------

func _draw_sky(view: Rect2, minute: int) -> void:
	var sky := Art.sky_colour(minute)
	draw_rect(Rect2(view.position, Vector2(view.size.x, -view.position.y + view.size.y)), sky)
	if Art.is_dark(minute):
		var seed_rng := RandomNumberGenerator.new()
		seed_rng.seed = 20241224
		for i in range(90):
			var x := seed_rng.randf_range(0.0, float(FacilityDB.MAP_SEGMENTS) * Art.SEG_W)
			var y := seed_rng.randf_range(-3900.0, -200.0)
			if x < view.position.x or x > view.end.x or y < view.position.y or y > view.end.y:
				continue
			draw_circle(Vector2(x, y), seed_rng.randf_range(0.6, 1.4),
				Color(1, 1, 1, seed_rng.randf_range(0.3, 0.9)))
	# The sun rises in the east at six and sets in the west at eighteen; the
	# moon takes the other twelve hours.
	var day := minute >= 6 * 60 and minute < 18 * 60
	var t01 := (float(minute) - 6.0 * 60.0) / (12.0 * 60.0) if day \
		else (fposmod(float(minute) - 18.0 * 60.0, 24.0 * 60.0)) / (12.0 * 60.0)
	var orb := Vector2(view.position.x + view.size.x * (0.10 + 0.80 * t01),
		-(150.0 + sin(t01 * PI) * 320.0))
	if day:
		draw_circle(orb, 22.0, Color(0.99, 0.92, 0.62))
		draw_circle(orb, 30.0, Color(0.99, 0.94, 0.70, 0.20))
	else:
		draw_circle(orb, 15.0, Color(0.93, 0.94, 0.88))
		draw_circle(orb, 11.0, Art.sky_colour(minute).lerp(Color.BLACK, 0.2))
		draw_circle(orb + Vector2(4, -2), 12.0, Color(0.93, 0.94, 0.88))

func _draw_ground(view: Rect2) -> void:
	var below := Rect2(view.position.x, 0.0, view.size.x, maxf(view.end.y, 40.0))
	draw_rect(below, Art.EARTH)
	# strata, so the basements read as underground
	var y := 0.0
	var k := 0
	while y < below.end.y:
		if k % 2 == 1:
			draw_rect(Rect2(below.position.x, y, below.size.x, Art.ROW_H * 0.5),
				Art.EARTH_DARK)
		y += Art.ROW_H * 0.5
		k += 1
	draw_rect(Rect2(view.position.x, -3.0, view.size.x, 6.0), Art.GRASS)

# --- the building ----------------------------------------------------------

func _draw_structure(tw: Tower, row_lo: int, row_hi: int, seg_lo: int, seg_hi: int,
		minute: int) -> void:
	for row in range(row_lo, row_hi + 1):
		var c := seg_lo
		while c <= seg_hi:
			var s := tw.structure_at(c, row)
			if s == Tower.VOID:
				c += 1
				continue
			var start := c
			while c <= seg_hi and tw.structure_at(c, row) == s:
				c += 1
			var w := c - start
			if s == Tower.LOBBY:
				Art.draw_lobby(self, start, row, w, minute)
			else:
				Art.draw_empty_floor(self, start, row, w)

func _draw_facilities(tw: Tower, row_lo: int, row_hi: int, seg_lo: int, seg_hi: int,
		minute: int) -> void:
	var seen := {}
	for row in range(row_lo, row_hi + 1):
		var c := seg_lo
		while c <= seg_hi:
			var f := tw.facility_at(c, row)
			if f == null:
				c += 1
				continue
			if not seen.has(f.id):
				seen[f.id] = true
				Art.draw_facility(self, f, minute, _tint_for(f))
			c = maxi(c + 1, f.seg + f.w)

func _tint_for(f: Facility) -> Color:
	match overlay:
		"eval":
			if f.kind() in [FacilityDB.Kind.OFFICE, FacilityDB.Kind.CONDO,
					FacilityDB.Kind.HOTEL, FacilityDB.Kind.SHOP, FacilityDB.Kind.FOOD]:
				var c := Rules.eval_colour(f.eval)
				c.a = 0.45
				return c
		"price":
			if f.def().has("rents"):
				var shades := [Color(0.30, 0.60, 0.95), Color(0.42, 0.78, 0.62),
					Color(0.95, 0.82, 0.25), Color(0.90, 0.32, 0.24)]
				var c: Color = shades[clampi(f.rent_tier, 0, 3)]
				c.a = 0.45
				return c
		"hotel":
			if f.kind() == FacilityDB.Kind.HOTEL:
				if f.roaches:
					return Color(0.30, 0.12, 0.08, 0.7)
				if f.dirty:
					return Color(0.90, 0.25, 0.20, 0.5)
				return Color(0.30, 0.60, 0.95, 0.35)
	return Color(0, 0, 0, 0)

func _draw_shafts(tw: Tower, row_lo: int, row_hi: int) -> void:
	for sid in tw.shafts:
		var s: Shaft = tw.shafts[sid]
		if s.top_row < row_lo - 1 or s.bottom_row > row_hi + 1:
			continue
		if not s.show:
			_draw_shaft_outline(s)
		else:
			Art.draw_shaft(self, s, row_hi, row_lo)
		for c in s.cars:
			Art.draw_car(self, s, c)
		_draw_shaft_marks(s, row_lo, row_hi)

func _draw_shaft_outline(s: Shaft) -> void:
	var w := float(s.width()) * Art.SEG_W
	var x := float(s.seg) * Art.SEG_W
	var y0 := -float(s.top_row + 1) * Art.ROW_H
	var y1 := -float(s.bottom_row) * Art.ROW_H
	draw_line(Vector2(x, y0), Vector2(x, y1), Art.trim(s.type), 1.5)
	draw_line(Vector2(x + w, y0), Vector2(x + w, y1), Art.trim(s.type), 1.5)

func _draw_shaft_marks(s: Shaft, row_lo: int, row_hi: int) -> void:
	var x := float(s.seg) * Art.SEG_W
	var w := float(s.width()) * Art.SEG_W
	var font := ThemeDB.fallback_font
	for r in range(maxi(s.bottom_row, row_lo), mini(s.top_row, row_hi) + 1):
		var y := -float(r) * Art.ROW_H
		var waiting := s.waiting_at(r)
		if waiting > 0:
			var up: int = s.queues[r]["up"].size()
			var down: int = s.queues[r]["down"].size()
			for i in range(mini(up, 8)):
				Art.draw_person(self, x - 4.0 - float(i) * 3.5, r,
					Color(0.15, 0.15, 0.2), 0.75)
			for i in range(mini(down, 8)):
				Art.draw_person(self, x + w + 4.0 + float(i) * 3.5, r,
					Color(0.15, 0.15, 0.2), 0.75)
		# waiting-floor numbers, in pink as in the original
		var home := false
		for c in s.cars:
			if c.home_row == r:
				home = true
		if home:
			draw_string(font, Vector2(x + 1, y - Art.ROW_H + 10),
				FacilityDB.row_label(r), HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
				Color(0.98, 0.45, 0.62))
		elif s.disabled_rows.has(r):
			draw_line(Vector2(x + 2, y - Art.ROW_H + 4), Vector2(x + w - 2, y - 4),
				Color(0.9, 0.2, 0.2, 0.8), 1.5)

func _draw_people(g, row_lo: int, row_hi: int, seg_lo: int, seg_hi: int) -> void:
	var now: float = g.clock.minute
	for row in range(row_lo, row_hi + 1):
		var list: Array = g.engine.walking_by_row.get(row, [])
		var drawn := 0
		for sid in list:
			if drawn > 220:
				break
			var s: Sim = g.engine.sims.get(sid)
			if s == null:
				continue
			var x := 0.0
			if s.state == Sim.State.WALKING:
				x = g.engine.walk_position(s, now) * Art.SEG_W
			else:
				x = s.seg * Art.SEG_W
			if x < view_left(seg_lo) or x > view_right(seg_hi):
				continue
			Art.draw_person(self, x, row, s.colour(), 1.0)
			drawn += 1

func view_left(seg_lo: int) -> float:
	return float(seg_lo) * Art.SEG_W

func view_right(seg_hi: int) -> float:
	return float(seg_hi + 1) * Art.SEG_W

# --- events ----------------------------------------------------------------

func _draw_events(g, view: Rect2) -> void:
	if g.events.fire != null:
		for cell in g.events.fire.cells:
			Art.draw_fire(self, cell, float(g.events.fire.cells[cell]), t)
		if g.events.fire.helicopter:
			var c: Vector2i = g.events.fire.cells.keys()[0] if not g.events.fire.cells.is_empty() \
				else Vector2i(0, 0)
			var p := Art.cell_rect(c.x, c.y).get_center() + Vector2(0, -90)
			_draw_helicopter(p)
	if g.events.santa_active:
		Art.draw_santa(self, g.events.santa_x * Art.SEG_W, g.events.santa_row(), t)

func _draw_helicopter(p: Vector2) -> void:
	draw_rect(Rect2(p.x - 16, p.y - 8, 32, 14), Color(0.20, 0.34, 0.28))
	draw_rect(Rect2(p.x + 14, p.y - 4, 18, 4), Color(0.20, 0.34, 0.28))
	var sweep := sin(t * 40.0) * 26.0
	draw_line(Vector2(p.x - sweep, p.y - 12), Vector2(p.x + sweep, p.y - 12),
		Color(0.15, 0.15, 0.15), 2.0)
	draw_line(Vector2(p.x, p.y + 6), Vector2(p.x + 6, p.y + 60),
		Color(0.55, 0.72, 0.92, 0.7), 3.0)

# --- selection and ghost ---------------------------------------------------

func _draw_selection(g) -> void:
	if g.selected_facility != -1:
		var f: Facility = g.tower.facilities.get(g.selected_facility)
		if f != null:
			draw_rect(Art.cell_rect(f.seg, f.row, f.w, f.h).grow(2.0),
				Color(1.0, 0.85, 0.20), false, 2.0)
	if g.selected_shaft != -1:
		var s: Shaft = g.tower.shafts.get(g.selected_shaft)
		if s != null:
			var x := float(s.seg) * Art.SEG_W
			var w := float(s.width()) * Art.SEG_W
			var y0 := -float(s.top_row + 1) * Art.ROW_H - 10.0
			var y1 := -float(s.bottom_row) * Art.ROW_H + 7.0
			draw_rect(Rect2(x - 2, y0, w + 4, y1 - y0), Color(1.0, 0.85, 0.20),
				false, 2.0)

func _draw_ghost(g) -> void:
	if ghost_type == "":
		return
	var d: Dictionary = FacilityDB.get_def(ghost_type)
	if d.is_empty():
		return
	var w: int = ghost_w if ghost_w > 0 else int(d.get("w", 1))
	var h: int = int(d.get("h", 1))
	var r: Rect2
	if FacilityDB.is_elevator(ghost_type) and dragging:
		var lo := mini(ghost_cell.y, ghost_drag_to.y)
		var hi := maxi(ghost_cell.y, ghost_drag_to.y)
		r = Art.cell_rect(ghost_cell.x, lo, int(d["w"]), hi - lo + 1)
	else:
		r = Art.cell_rect(ghost_cell.x, ghost_cell.y, w, h)
	var col := Color(0.25, 0.95, 0.45, 0.35) if ghost_ok else Color(0.95, 0.25, 0.25, 0.35)
	draw_rect(r, col)
	draw_rect(r, col.lightened(0.3), false, 2.0)
