extends UIKit.GWindow
class_name MapWindow

## The satellite view, with the four evaluation buttons across the top.
## Edit shows the silhouette; Eval, Prezzi and Hotel colour it and pause the
## game, exactly as the original did.

signal jump_to(seg: int, row: int)
signal overlay_changed(mode: String)

const MODES := [["edit", "Edit"], ["eval", "Eval"], ["price", "Prezzi"],
	["hotel", "Hotel"]]

var canvas: MapCanvas
var mode: String = "edit"
var buttons: Dictionary = {}
var legend: Label

class MapCanvas extends Control:
	signal picked(seg: int, row: int)
	var mode: String = "edit"
	var view_rect := Rect2()      # in world coords, what the Edit window shows

	func _init() -> void:
		custom_minimum_size = Vector2(300, 220)

	func _sx() -> float:
		return size.x / float(FacilityDB.MAP_SEGMENTS)

	func _sy() -> float:
		return size.y / float(FacilityDB.FLOORS_ABOVE + FacilityDB.FLOORS_BELOW)

	func _draw() -> void:
		var tw: Tower = Game.tower
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.78, 0.86, 0.92))
		var sx := _sx()
		var sy := _sy()
		var ground_y := float(FacilityDB.FLOORS_ABOVE) * sy
		draw_rect(Rect2(0, ground_y, size.x, size.y - ground_y), Color(0.46, 0.40, 0.32))

		# the tower itself
		for fid in tw.facilities:
			var f: Facility = tw.facilities[fid]
			var y := (float(FacilityDB.FLOORS_ABOVE) - float(f.row + f.h)) * sy
			var r := Rect2(float(f.seg) * sx, y, maxf(float(f.w) * sx, 1.0),
				maxf(float(f.h) * sy, 1.0))
			draw_rect(r, _colour_for(f))
		# the ground lobby
		if tw.has_lobby():
			draw_rect(Rect2(float(tw.lobby_left) * sx,
				(float(FacilityDB.FLOORS_ABOVE) - 1.0) * sy,
				float(tw.lobby_width()) * sx, maxf(sy, 1.0)), Color(0.92, 0.90, 0.82))
		# shafts: express blue, standard grey, service red
		for sid in tw.shafts:
			var s: Shaft = tw.shafts[sid]
			var col := Color(0.45, 0.45, 0.48)
			if s.is_express():
				col = Color(0.25, 0.45, 0.90)
			elif s.is_service():
				col = Color(0.85, 0.22, 0.20)
			var y0 := (float(FacilityDB.FLOORS_ABOVE) - float(s.top_row + 1)) * sy
			var y1 := (float(FacilityDB.FLOORS_ABOVE) - float(s.bottom_row)) * sy
			draw_rect(Rect2(float(s.seg) * sx, y0, maxf(float(s.width()) * sx, 1.5),
				maxf(y1 - y0, 1.0)), col)
		# Santa's little red dot, which is how you find him
		if Game.events.santa_active:
			var x := Game.events.santa_x * sx
			var y := (float(FacilityDB.FLOORS_ABOVE) - float(Game.events.santa_row())) * sy
			draw_circle(Vector2(x, y), 3.0, Color(0.92, 0.16, 0.16))

		if view_rect.size.x > 0.0:
			var vr := Rect2(view_rect.position.x / Art.SEG_W * sx,
				(float(FacilityDB.FLOORS_ABOVE) + view_rect.position.y / Art.ROW_H) * sy,
				view_rect.size.x / Art.SEG_W * sx, view_rect.size.y / Art.ROW_H * sy)
			draw_rect(vr, Color(0.10, 0.10, 0.12), false, 1.5)
		draw_rect(Rect2(Vector2.ZERO, size), UIKit.INK, false, 1.0)

	func _colour_for(f: Facility) -> Color:
		match mode:
			"eval":
				if f.kind() in [FacilityDB.Kind.OFFICE, FacilityDB.Kind.CONDO,
						FacilityDB.Kind.HOTEL, FacilityDB.Kind.SHOP, FacilityDB.Kind.FOOD]:
					return Rules.eval_colour(f.eval)
				return Color(0.55, 0.55, 0.55)
			"price":
				if f.def().has("rents"):
					return [Color(0.30, 0.60, 0.95), Color(0.42, 0.78, 0.62),
						Color(0.95, 0.82, 0.25), Color(0.90, 0.32, 0.24)][clampi(f.rent_tier, 0, 3)]
				return Color(0.55, 0.55, 0.55)
			"hotel":
				if f.kind() == FacilityDB.Kind.HOTEL:
					if f.roaches:
						return Color(0.35, 0.10, 0.08)
					return Color(0.90, 0.22, 0.18) if f.dirty else Color(0.30, 0.60, 0.95)
				return Color(0.60, 0.60, 0.60)
		return Color(0.36, 0.36, 0.40) if not f.wrecked else Color(0.20, 0.18, 0.16)

	func _gui_input(e: InputEvent) -> void:
		var wants: bool = e is InputEventMouseButton and e.pressed \
			and e.button_index == MOUSE_BUTTON_LEFT
		var drags: bool = e is InputEventMouseMotion \
			and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		if wants or drags:
			var seg := int(e.position.x / _sx())
			var row := FacilityDB.FLOORS_ABOVE - int(e.position.y / _sy())
			picked.emit(seg, row)
			accept_event()

func _init() -> void:
	super("Mappa")
	var row := HBoxContainer.new()
	body.add_child(row)
	for m in MODES:
		var b := UIKit.button(String(m[1]), _set_mode.bind(String(m[0])))
		b.custom_minimum_size = Vector2(64, 24)
		row.add_child(b)
		buttons[String(m[0])] = b
	canvas = MapCanvas.new()
	canvas.picked.connect(func(s, r): jump_to.emit(s, r))
	body.add_child(canvas)
	legend = UIKit.label("Vista dall alto della torre.", 11)
	body.add_child(legend)
	_set_mode("edit")

func _set_mode(m: String) -> void:
	mode = m
	canvas.mode = m
	for k in buttons:
		buttons[k].add_theme_stylebox_override("normal",
			UIKit.panel_style(UIKit.GOLD if k == m else UIKit.BG_LIGHT))
	# The three evaluation views pause the game, as they did in the original.
	Game.hold_pause("map", m != "edit")
	match m:
		"eval": legend.text = "Blu ottimo, giallo discreto, rosso in crisi."
		"price": legend.text = "Blu molto basso, verde basso, giallo medio, rosso alto."
		"hotel": legend.text = "Rosso: camere sporche. Serve piu personale."
		_: legend.text = "Vista dall alto della torre."
	overlay_changed.emit("" if m == "edit" else m)
	canvas.queue_redraw()

func _notification(what: int) -> void:
	# Closing the window must let go of the pause it was holding.
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		Game.hold_pause("map", visible and mode != "edit")

func refresh(view: Rect2) -> void:
	canvas.view_rect = view
	canvas.queue_redraw()
