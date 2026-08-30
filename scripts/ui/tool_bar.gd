extends UIKit.GWindow
class_name ToolBar

## The Tool Bar. Everything you can build, plus the bulldozer, the finger and
## the magnifying glass, revealed as your star rating rises.

signal tool_picked(id: String)

const MODES := ["inspect", "bulldoze", "finger"]
const MODE_LABEL := {"inspect": "Lente", "bulldoze": "Ruspa", "finger": "Dito"}

var buttons: Dictionary = {}
var mode_buttons: Dictionary = {}
var pause_btn: Button
var speed_label: Label
var current: String = "lobby"
var mode: String = "build"

class ToolButton extends Button:
	var tool_id: String = ""
	var locked: bool = false
	var chosen: bool = false

	func _init(id: String) -> void:
		tool_id = id
		custom_minimum_size = Vector2(38, 38)
		focus_mode = Control.FOCUS_NONE
		tooltip_text = ""

	func _draw() -> void:
		var r := Rect2(4, 4, size.x - 8, size.y - 8)
		if locked:
			draw_rect(r, Color(0.6, 0.6, 0.58))
			draw_line(r.position, r.end, Color(0.4, 0.4, 0.4), 2.0)
			return
		_mini(r)
		if chosen:
			draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), UIKit.GOLD, false, 2.0)

	func _mini(r: Rect2) -> void:
		var col := Art.body(tool_id)
		var tr := Art.trim(tool_id)
		var det := Art.detail(tool_id)
		draw_rect(r, col)
		match tool_id:
			"lobby":
				draw_rect(Rect2(r.position.x, r.end.y - 4, r.size.x, 4), tr)
				draw_circle(Vector2(r.get_center().x, r.end.y - 9), 4.0,
					Color(0.26, 0.44, 0.24))
			"floor":
				draw_rect(Rect2(r.position.x, r.end.y - 5, r.size.x, 5), tr)
			"stairs":
				for i in range(4):
					draw_rect(Rect2(r.position.x + float(i) * r.size.x / 4.0,
						r.end.y - 4.0 - float(i) * r.size.y / 4.0,
						r.size.x / 4.0, 3.0), tr)
			"escalator":
				draw_line(Vector2(r.position.x, r.end.y - 3),
					Vector2(r.end.x, r.position.y + 3), tr, 4.0)
			"elevator", "service_elevator", "express_elevator":
				draw_rect(r, Color(0.25, 0.25, 0.28))
				draw_rect(Rect2(r.position.x + 2, r.position.y + 2,
					r.size.x * 0.45 - 2, r.size.y - 4), det)
				draw_rect(Rect2(r.get_center().x + 1, r.position.y + 2,
					r.size.x * 0.45 - 2, r.size.y - 4), det)
			"office":
				draw_rect(Rect2(r.position.x + 3, r.position.y + 4, r.size.x - 6, 8), det)
				draw_rect(Rect2(r.position.x + 3, r.end.y - 8, r.size.x - 6, 3), tr)
			"condo":
				draw_rect(Rect2(r.position.x + 3, r.position.y + 4, 10, 8), det)
				draw_rect(Rect2(r.end.x - 10, r.position.y + 4, 6, r.size.y - 10), tr)
			"hotel_single", "hotel_twin", "hotel_suite":
				var beds := 1 if tool_id == "hotel_single" else 2
				for i in range(beds):
					draw_rect(Rect2(r.position.x + 3.0 + float(i) * 11.0,
						r.end.y - 10, 9, 6), det)
			"fastfood":
				draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 5), tr)
				draw_circle(r.get_center() + Vector2(0, 3), 5.0, det)
			"restaurant":
				draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 5), tr)
				draw_rect(Rect2(r.get_center().x - 6, r.get_center().y, 12, 2), tr)
				draw_circle(r.get_center() + Vector2(0, -4), 4.0, det)
			"shop":
				draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 5), tr)
				draw_rect(Rect2(r.position.x + 4, r.position.y + 8,
					r.size.x - 8, r.size.y - 12), det)
			"party_hall":
				for i in range(3):
					draw_circle(Vector2(r.position.x + 7.0 + float(i) * 8.0,
						r.get_center().y), 3.5, det)
			"cinema":
				draw_rect(r, Color(0.18, 0.17, 0.24))
				draw_rect(Rect2(r.position.x + 4, r.position.y + 4,
					r.size.x - 8, r.size.y * 0.45), det)
			"housekeeping":
				draw_rect(Rect2(r.get_center().x - 5, r.end.y - 12, 10, 10), det)
				draw_rect(Rect2(r.get_center().x - 1, r.position.y + 4, 2, 12), tr)
			"security":
				draw_colored_polygon(PackedVector2Array([
					Vector2(r.get_center().x, r.position.y + 3),
					Vector2(r.end.x - 4, r.position.y + 8),
					Vector2(r.get_center().x, r.end.y - 3),
					Vector2(r.position.x + 4, r.position.y + 8)]), det)
			"medical":
				draw_rect(Rect2(r.get_center().x - 3, r.position.y + 4, 6, r.size.y - 8), det)
				draw_rect(Rect2(r.position.x + 4, r.get_center().y - 3, r.size.x - 8, 6), det)
			"recycling":
				for i in range(3):
					var a := float(i) * TAU / 3.0 - PI / 2.0
					var p := r.get_center() + Vector2(cos(a), sin(a)) * 7.0
					draw_colored_polygon(PackedVector2Array([
						p + Vector2(0, -4), p + Vector2(4, 3), p + Vector2(-4, 3)]), det)
			"parking":
				draw_rect(Rect2(r.get_center().x - 8, r.get_center().y, 16, 6), det)
				draw_circle(Vector2(r.get_center().x - 5, r.get_center().y + 7), 2.0, tr)
				draw_circle(Vector2(r.get_center().x + 5, r.get_center().y + 7), 2.0, tr)
			"parking_ramp":
				draw_line(Vector2(r.position.x + 2, r.end.y - 3),
					Vector2(r.end.x - 2, r.position.y + 3), det, 4.0)
			"metro":
				draw_rect(Rect2(r.position.x + 4, r.position.y + 6,
					r.size.x - 8, r.size.y - 16), det)
				draw_rect(Rect2(r.position.x + 3, r.end.y - 7, r.size.x - 6, 2), tr)
			"cathedral":
				draw_colored_polygon(PackedVector2Array([
					Vector2(r.get_center().x, r.position.y + 2),
					Vector2(r.end.x - 3, r.get_center().y),
					Vector2(r.position.x + 3, r.get_center().y)]), tr)
				draw_rect(Rect2(r.get_center().x - 4, r.get_center().y, 8, r.size.y * 0.5), tr)
		draw_rect(r, Art.OUTLINE, false, 1.0)

class ModeButton extends Button:
	var kind: String = ""
	var chosen: bool = false

	func _init(k: String) -> void:
		kind = k
		custom_minimum_size = Vector2(38, 30)
		focus_mode = Control.FOCUS_NONE

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		match kind:
			"bulldoze":
				draw_rect(Rect2(c.x - 10, c.y + 2, 20, 6), Color(0.85, 0.62, 0.15))
				draw_circle(Vector2(c.x - 5, c.y + 9), 3.0, Color(0.2, 0.2, 0.2))
				draw_circle(Vector2(c.x + 5, c.y + 9), 3.0, Color(0.2, 0.2, 0.2))
				draw_line(Vector2(c.x + 8, c.y + 2), Vector2(c.x + 12, c.y - 6),
					Color(0.4, 0.4, 0.4), 3.0)
			"finger":
				draw_rect(Rect2(c.x - 3, c.y - 10, 6, 12), Color(0.95, 0.82, 0.70))
				draw_rect(Rect2(c.x - 6, c.y, 12, 9), Color(0.95, 0.82, 0.70))
				draw_rect(Rect2(c.x - 6, c.y, 12, 9), UIKit.INK, false, 1.0)
			"inspect":
				draw_circle(c + Vector2(-2, -2), 7.0, Color(0.75, 0.88, 0.95))
				draw_arc(c + Vector2(-2, -2), 7.0, 0, TAU, 24, UIKit.INK, 2.0)
				draw_line(c + Vector2(3, 3), c + Vector2(9, 9), UIKit.INK, 3.0)
		if chosen:
			draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), UIKit.GOLD, false, 2.0)

func _init() -> void:
	super("Strumenti", false)
	custom_minimum_size = Vector2(96, 0)
	_build()

func _build() -> void:
	var row := HBoxContainer.new()
	body.add_child(row)
	pause_btn = UIKit.button("||", func(): _toggle_pause())
	pause_btn.custom_minimum_size = Vector2(30, 26)
	row.add_child(pause_btn)
	var slower := UIKit.button("<", func(): _speed(-1))
	slower.custom_minimum_size = Vector2(24, 26)
	row.add_child(slower)
	var faster := UIKit.button(">", func(): _speed(1))
	faster.custom_minimum_size = Vector2(24, 26)
	row.add_child(faster)
	speed_label = UIKit.label("x1", 11)
	body.add_child(speed_label)

	var modes := HBoxContainer.new()
	body.add_child(modes)
	for m in MODES:
		var b := ModeButton.new(m)
		b.tooltip_text = MODE_LABEL[m]
		b.pressed.connect(_pick_mode.bind(m))
		modes.add_child(b)
		mode_buttons[m] = b

	body.add_child(UIKit.hsep())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	body.add_child(grid)
	for id in FacilityDB.TOOL_ORDER:
		var b := ToolButton.new(id)
		var d: Dictionary = FacilityDB.DEFS[id]
		b.tooltip_text = "%s\n%s\n%s" % [d["name"],
			Economy.money(int(d["cost"])) + (" / segmento" if d.get("drag", "") == "h" else ""),
			d.get("desc", "")]
		b.pressed.connect(_pick.bind(id))
		grid.add_child(b)
		buttons[id] = b
	_pick("lobby")
	refresh()

func _toggle_pause() -> void:
	Game.set_manual_pause(not Game.manual_paused)
	sync_pause_button()

func sync_pause_button() -> void:
	pause_btn.text = ">" if Game.manual_paused else "||"

func _speed(d: int) -> void:
	Game.speed_index = clampi(Game.speed_index + d, 0, Game.SPEEDS.size() - 1)
	speed_label.text = "x%s" % str(Game.SPEEDS[Game.speed_index])

func _pick(id: String) -> void:
	if not Game.can_use_tool(id):
		Game.say("Non ancora disponibile a questo livello")
		return
	current = id
	mode = "build"
	Game.tool = id
	for k in buttons:
		buttons[k].chosen = k == id
		buttons[k].queue_redraw()
	for k in mode_buttons:
		mode_buttons[k].chosen = false
		mode_buttons[k].queue_redraw()
	tool_picked.emit(id)

func _pick_mode(m: String) -> void:
	mode = m
	for k in buttons:
		buttons[k].chosen = false
		buttons[k].queue_redraw()
	for k in mode_buttons:
		mode_buttons[k].chosen = k == m
		mode_buttons[k].queue_redraw()
	tool_picked.emit("")

func refresh() -> void:
	for id in buttons:
		var b: ToolButton = buttons[id]
		b.locked = not Game.can_use_tool(id)
		b.disabled = b.locked
		b.queue_redraw()
