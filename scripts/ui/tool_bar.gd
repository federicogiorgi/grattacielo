extends UIKit.GWindow
class_name ToolBar

## The Tool Bar. Everything you can build, plus the bulldozer, the finger and
## the magnifying glass, revealed as your star rating rises.
##
## The icons are drawn rather than loaded, so each one has to earn its
## recognisability from a bold silhouette on a coloured card: a bed reads as a
## bed at forty pixels, a plan view of a hotel room does not.

signal tool_picked(id: String)

# The finger tool is gone: you stretch a lift by dragging the lift, which is
# what everybody tried first anyway.
const MODES := ["inspect", "bulldoze"]
const MODE_LABEL := {"inspect": "Magnifying glass -- inspect anything.\nDrag a lift shaft to make it taller or shorter.",
	"bulldoze": "Bulldozer -- demolish"}

const ICON := 44.0
const COLUMNS := 3

var buttons: Dictionary = {}
var mode_buttons: Dictionary = {}
var pause_btn: Button
var undo_btn: Button
var speed_label: Label
var scroller: ScrollContainer
var current: String = "lobby"
var mode: String = "build"

# ---------------------------------------------------------------------------
# A small drawing kit shared by the icons.
# ---------------------------------------------------------------------------

class Glyph:
	## Ink that will actually be seen against a given card colour.
	static func ink(on: Color) -> Color:
		return Color(0.09, 0.10, 0.13) if on.get_luminance() > 0.45 \
			else Color(0.96, 0.96, 0.94)

	static func bed(ci: CanvasItem, r: Rect2, ink_c: Color, accent: Color) -> void:
		var h := r.size.y
		ci.draw_rect(Rect2(r.position.x, r.position.y, 3, h * 0.85), ink_c)
		ci.draw_rect(Rect2(r.position.x, r.position.y + h * 0.45, r.size.x, h * 0.32), accent)
		ci.draw_rect(Rect2(r.position.x, r.position.y + h * 0.45, r.size.x, h * 0.32),
			ink_c, false, 1.0)
		ci.draw_rect(Rect2(r.position.x + 3, r.position.y + h * 0.20, r.size.x * 0.34,
			h * 0.24), Color(0.98, 0.98, 0.96))
		ci.draw_rect(Rect2(r.position.x + 3, r.position.y + h * 0.20, r.size.x * 0.34,
			h * 0.24), ink_c, false, 1.0)

	static func doors(ci: CanvasItem, r: Rect2, ink_c: Color, panel: Color) -> void:
		ci.draw_rect(r, panel)
		ci.draw_rect(r, ink_c, false, 1.5)
		ci.draw_line(Vector2(r.get_center().x, r.position.y),
			Vector2(r.get_center().x, r.end.y), ink_c, 1.5)

	static func chevron(ci: CanvasItem, c: Vector2, w: float, h: float,
			col: Color, up: bool) -> void:
		var s := -1.0 if up else 1.0
		ci.draw_colored_polygon(PackedVector2Array([
			c + Vector2(-w, s * h), c + Vector2(0, -s * h), c + Vector2(w, s * h),
			c + Vector2(w, s * h + h * 0.9), c + Vector2(0, -s * h + h * 0.9),
			c + Vector2(-w, s * h + h * 0.9)]), col)

	static func star(ci: CanvasItem, c: Vector2, rad: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in range(10):
			var a := float(i) * PI / 5.0 - PI / 2.0
			var q := rad if i % 2 == 0 else rad * 0.45
			pts.append(c + Vector2(cos(a), sin(a)) * q)
		ci.draw_colored_polygon(pts, col)

	static func car(ci: CanvasItem, r: Rect2, body_c: Color, ink_c: Color) -> void:
		var h := r.size.y
		ci.draw_rect(Rect2(r.position.x, r.position.y + h * 0.42, r.size.x, h * 0.32), body_c)
		ci.draw_rect(Rect2(r.position.x + r.size.x * 0.20, r.position.y + h * 0.16,
			r.size.x * 0.58, h * 0.30), body_c)
		ci.draw_rect(Rect2(r.position.x + r.size.x * 0.25, r.position.y + h * 0.21,
			r.size.x * 0.48, h * 0.19), Color(0.80, 0.90, 0.96))
		ci.draw_circle(Vector2(r.position.x + r.size.x * 0.26, r.position.y + h * 0.78),
			h * 0.14, ink_c)
		ci.draw_circle(Vector2(r.position.x + r.size.x * 0.74, r.position.y + h * 0.78),
			h * 0.14, ink_c)

class ToolButton extends Button:
	var tool_id: String = ""
	var locked: bool = false
	var chosen: bool = false

	func _init(id: String) -> void:
		tool_id = id
		custom_minimum_size = Vector2(ToolBar.ICON, ToolBar.ICON)
		focus_mode = Control.FOCUS_NONE

	func _make_custom_tooltip(_for_text: String) -> Object:
		var d: Dictionary = FacilityDB.DEFS[tool_id]
		var price := Economy.money(int(d["cost"]))
		if String(d.get("drag", "")) == "h":
			price += " per segment"
		var note := ""
		if locked:
			note = "Needs %d stars" % int(d["stars"])
		return UIKit.tooltip(String(d["name"]), price, String(d.get("desc", "")), note)

	func _draw() -> void:
		var pad := 3.0
		var r := Rect2(pad, pad, size.x - pad * 2.0, size.y - pad * 2.0)
		if locked:
			draw_rect(r, Color(0.72, 0.72, 0.70))
			draw_rect(r, Color(0.52, 0.52, 0.50), false, 1.0)
			draw_line(r.position + Vector2(7, 7), r.end - Vector2(7, 7),
				Color(0.46, 0.46, 0.44), 2.0)
			draw_line(Vector2(r.end.x - 7, r.position.y + 7),
				Vector2(r.position.x + 7, r.end.y - 7), Color(0.46, 0.46, 0.44), 2.0)
			return
		_card(r)
		if chosen:
			draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), UIKit.GOLD, false, 2.5)

	func _card(r: Rect2) -> void:
		var body := Art.body(tool_id)
		var trim := Art.trim(tool_id)
		var det := Art.detail(tool_id)
		var ink := Glyph.ink(body)
		draw_rect(r, body)
		# The glyph lives in an inset square, so every icon is framed alike.
		var g := r.grow(-4.0)
		var c := g.get_center()
		match tool_id:
			"lobby":
				draw_rect(Rect2(g.position.x, g.end.y - 4, g.size.x, 4), trim)
				draw_rect(Rect2(g.position.x + 2, g.position.y + 3, 7, g.size.y - 7), trim)
				draw_rect(Rect2(g.end.x - 11, g.end.y - 11, 8, 7), Color(0.60, 0.40, 0.28))
				draw_circle(Vector2(g.end.x - 7, g.end.y - 14), 5.5, Color(0.26, 0.48, 0.26))
			"floor":
				draw_rect(Rect2(g.position.x, c.y - 2, g.size.x, 5), trim)
				for i in range(3):
					var x := g.position.x + 1.0 + float(i) * (g.size.x - 4.0) / 2.0
					draw_rect(Rect2(x, c.y + 3, 3, g.size.y * 0.42), trim)
			"stairs":
				var n := 4
				for i in range(n):
					var w := g.size.x / float(n)
					var h := g.size.y / float(n)
					draw_rect(Rect2(g.position.x + float(i) * w,
						g.end.y - float(i + 1) * h, w + 1.0, maxf(h * 0.45, 2.0)), ink)
					draw_rect(Rect2(g.position.x + float(i) * w,
						g.end.y - float(i + 1) * h, 2.0, h), ink)
			"escalator":
				var a := Vector2(g.position.x, g.end.y - 2)
				var b := Vector2(g.end.x, g.position.y + 6)
				draw_line(a, b, trim, 7.0)
				draw_line(a + Vector2(0, -9), b + Vector2(0, -9), ink, 1.5)
				for i in range(5):
					var p := a.lerp(b, float(i) / 4.0)
					draw_rect(Rect2(p.x - 2, p.y - 2, 4, 4), det)
			"elevator", "service_elevator", "express_elevator":
				var d := Rect2(g.position.x + 3, g.position.y + 7, g.size.x - 6, g.size.y - 9)
				Glyph.doors(self, d, ink, det)
				if tool_id == "express_elevator":
					Glyph.chevron(self, Vector2(c.x, g.position.y + 3), 6.0, 3.0, ink, true)
				elif tool_id == "service_elevator":
					draw_rect(Rect2(d.get_center().x - 5, d.end.y - 12, 10, 7), ink)
					draw_circle(Vector2(d.get_center().x - 3, d.end.y - 4), 2.0, ink)
					draw_circle(Vector2(d.get_center().x + 3, d.end.y - 4), 2.0, ink)
				else:
					draw_colored_polygon(PackedVector2Array([
						Vector2(c.x - 9, g.position.y + 6), Vector2(c.x - 2, g.position.y + 6),
						Vector2(c.x - 5.5, g.position.y)]), ink)
					draw_colored_polygon(PackedVector2Array([
						Vector2(c.x + 2, g.position.y), Vector2(c.x + 9, g.position.y),
						Vector2(c.x + 5.5, g.position.y + 6)]), ink)
			"office":
				# two big panes of sky over a desk: nothing else looks like it
				var pw := (g.size.x - 7.0) * 0.5
				for i in range(2):
					var pane := Rect2(g.position.x + 1.5 + float(i) * (pw + 4.0),
						g.position.y, pw, g.size.y * 0.60)
					draw_rect(pane, Art.SKY_DAY)
					draw_line(Vector2(pane.position.x, pane.get_center().y),
						Vector2(pane.end.x, pane.get_center().y), ink, 1.0)
					draw_line(Vector2(pane.get_center().x, pane.position.y),
						Vector2(pane.get_center().x, pane.end.y), ink, 1.0)
					draw_rect(pane, ink, false, 1.5)
				draw_rect(Rect2(g.position.x + 1, g.end.y - 8, g.size.x - 2, 2.5), ink)
				draw_rect(Rect2(g.position.x + 4, g.end.y - 6, 2, 6), ink)
				draw_rect(Rect2(g.end.x - 6, g.end.y - 6, 2, 6), ink)
			"condo":
				# a curtained window, a sofa and a standing lamp: a home
				draw_rect(Rect2(g.position.x + 2, g.position.y + 1, 11, 9), Art.SKY_DAY)
				draw_rect(Rect2(g.position.x + 2, g.position.y + 1, 11, 9), ink, false, 1.0)
				draw_rect(Rect2(g.position.x, g.position.y, 3, 11), trim)
				draw_rect(Rect2(g.position.x + 12, g.position.y, 3, 11), trim)
				draw_rect(Rect2(g.position.x + 2, g.end.y - 9, g.size.x - 11, 8), trim)
				draw_rect(Rect2(g.position.x + 2, g.end.y - 14, g.size.x - 11, 6),
					trim.lightened(0.18))
				draw_circle(Vector2(g.end.x - 4, g.end.y - 17), 3.5, det)
				draw_rect(Rect2(g.end.x - 5, g.end.y - 14, 2, 14), ink)
			"hotel_single":
				Glyph.bed(self, Rect2(g.position.x + 2, g.position.y + 7,
					g.size.x - 4, g.size.y - 12), ink, det)
			"hotel_twin":
				Glyph.bed(self, Rect2(g.position.x + 2, g.position.y + 1,
					g.size.x - 4, g.size.y * 0.42), ink, det)
				Glyph.bed(self, Rect2(g.position.x + 2, c.y + 2,
					g.size.x - 4, g.size.y * 0.42), ink, det)
			"hotel_suite":
				Glyph.bed(self, Rect2(g.position.x + 2, c.y,
					g.size.x - 4, g.size.y * 0.46), ink, det)
				Glyph.star(self, Vector2(c.x, g.position.y + 6), 6.5,
					Color(0.99, 0.86, 0.30))
			"fastfood":
				var w := g.size.x * 0.86
				var x0 := c.x - w * 0.5
				draw_circle(Vector2(c.x, c.y - 3), w * 0.5, det)
				draw_rect(Rect2(x0, c.y - 3, w, 4), Color(0.44, 0.64, 0.32))
				draw_rect(Rect2(x0, c.y + 1, w, 5), Color(0.46, 0.27, 0.16))
				draw_rect(Rect2(x0, c.y + 6, w, 5), det)
				draw_rect(Rect2(x0, c.y + 11, w, 2), ink)
				for i in range(3):
					draw_circle(Vector2(c.x - 7.0 + float(i) * 7.0, c.y - 9), 1.3, ink)
			"restaurant":
				var dark := Color(0.16, 0.15, 0.18)
				draw_circle(c, g.size.x * 0.44, Color(0.97, 0.96, 0.93))
				draw_arc(c, g.size.x * 0.44, 0, TAU, 26, dark, 1.5)
				draw_rect(Rect2(c.x - 8, c.y - 9, 2, 18), dark)
				for i in range(3):
					draw_rect(Rect2(c.x - 11.0 + float(i) * 3.0, c.y - 9, 1.5, 6), dark)
				draw_rect(Rect2(c.x + 6, c.y - 9, 2.5, 18), dark)
				draw_rect(Rect2(c.x + 5, c.y - 9, 5, 8), dark)
			"shop":
				var b := Rect2(g.position.x + 3, g.position.y + 8, g.size.x - 6,
					g.size.y - 10)
				draw_rect(b, det)
				draw_rect(b, ink, false, 1.5)
				draw_arc(Vector2(b.get_center().x, b.position.y), 6.5, PI, TAU, 16, ink, 2.0)
			"party_hall":
				for i in range(3):
					var bx := g.position.x + 5.0 + float(i) * (g.size.x - 10.0) / 2.0
					var by := g.position.y + 6.0 + (3.0 if i == 1 else 0.0)
					draw_circle(Vector2(bx, by), 5.5, det)
					draw_arc(Vector2(bx, by), 5.5, 0, TAU, 16, ink, 1.0)
					draw_line(Vector2(bx, by + 5), Vector2(bx + 1, g.end.y - 1), ink, 1.0)
			"cinema":
				var f := Rect2(g.position.x + 1, g.position.y + 3, g.size.x - 2,
					g.size.y - 6)
				draw_rect(f, Color(0.13, 0.12, 0.17))
				draw_rect(f, Color(0.55, 0.55, 0.58), false, 1.0)
				for i in range(4):
					var y := f.position.y + 2.0 + float(i) * (f.size.y - 5.0) / 3.0
					draw_rect(Rect2(f.position.x + 1.5, y, 3, 3), det)
					draw_rect(Rect2(f.end.x - 4.5, y, 3, 3), det)
				draw_rect(Rect2(f.position.x + 7, f.position.y + 3, f.size.x - 14,
					f.size.y - 6), Color(0.88, 0.88, 0.86))
			"housekeeping":
				draw_rect(Rect2(g.position.x + 2, g.end.y - 13, 12, 11), det)
				draw_rect(Rect2(g.position.x + 2, g.end.y - 13, 12, 11), ink, false, 1.0)
				draw_arc(Vector2(g.position.x + 8, g.end.y - 13), 6.0, PI, TAU, 14, ink, 1.5)
				draw_line(Vector2(g.end.x - 5, g.position.y + 1),
					Vector2(g.end.x - 10, g.end.y - 9), ink, 2.0)
				draw_colored_polygon(PackedVector2Array([
					Vector2(g.end.x - 15, g.end.y - 1), Vector2(g.end.x - 6, g.end.y - 1),
					Vector2(g.end.x - 8, g.end.y - 10), Vector2(g.end.x - 13, g.end.y - 10)]),
					Color(0.76, 0.58, 0.28))
			"security":
				draw_colored_polygon(PackedVector2Array([
					Vector2(c.x, g.position.y),
					Vector2(g.end.x - 2, g.position.y + 6),
					Vector2(g.end.x - 4, c.y + 6),
					Vector2(c.x, g.end.y),
					Vector2(g.position.x + 4, c.y + 6),
					Vector2(g.position.x + 2, g.position.y + 6)]), det)
				Glyph.star(self, Vector2(c.x, c.y - 1), 5.5, Color(0.20, 0.28, 0.44))
			"medical":
				draw_rect(Rect2(c.x - 4.5, g.position.y + 1, 9, g.size.y - 2), det)
				draw_rect(Rect2(g.position.x + 1, c.y - 4.5, g.size.x - 2, 9), det)
			"recycling":
				for i in range(3):
					var a2 := float(i) * TAU / 3.0 - PI / 2.0
					var p := c + Vector2(cos(a2), sin(a2)) * 8.5
					draw_colored_polygon(PackedVector2Array([
						p + Vector2(0, -6.0), p + Vector2(6.0, 4.0),
						p + Vector2(-6.0, 4.0)]), det)
			"parking":
				Glyph.car(self, g.grow(-1.0), det, ink)
			"parking_ramp":
				draw_colored_polygon(PackedVector2Array([
					Vector2(g.position.x + 1, g.end.y - 1),
					Vector2(g.end.x - 1, g.end.y - 1),
					Vector2(g.end.x - 1, g.position.y + 3)]), trim)
				draw_line(Vector2(g.end.x - 5, g.position.y + 7),
					Vector2(g.position.x + 7, g.end.y - 6), det, 2.5)
				draw_colored_polygon(PackedVector2Array([
					Vector2(g.position.x + 3, g.end.y - 4),
					Vector2(g.position.x + 11, g.end.y - 6),
					Vector2(g.position.x + 8, g.end.y - 13)]), det)
			"metro":
				var t := Rect2(g.position.x + 3, g.position.y + 1, g.size.x - 6,
					g.size.y - 7)
				draw_rect(t, det)
				draw_rect(t, ink, false, 1.0)
				draw_rect(Rect2(t.position.x + 2, t.position.y + 3, t.size.x * 0.38, 8),
					Color(0.75, 0.88, 0.95))
				draw_rect(Rect2(t.get_center().x + 1, t.position.y + 3, t.size.x * 0.38, 8),
					Color(0.75, 0.88, 0.95))
				draw_rect(Rect2(t.position.x + 2, t.end.y - 5, 5, 3), Color(0.99, 0.93, 0.62))
				draw_rect(Rect2(t.end.x - 7, t.end.y - 5, 5, 3), Color(0.99, 0.93, 0.62))
				draw_rect(Rect2(g.position.x, g.end.y - 4, g.size.x, 2), ink)
			"cathedral":
				draw_colored_polygon(PackedVector2Array([
					Vector2(c.x, g.position.y + 4), Vector2(c.x + 11, c.y),
					Vector2(c.x - 11, c.y)]), trim)
				draw_rect(Rect2(c.x - 9, c.y, 18, g.size.y * 0.44), trim)
				draw_rect(Rect2(c.x - 3, g.end.y - g.size.y * 0.30, 6, g.size.y * 0.30), det)
				draw_rect(Rect2(c.x - 1.5, g.position.y - 4, 3, 9), trim)
				draw_rect(Rect2(c.x - 5, g.position.y - 2, 10, 3), trim)
		draw_rect(r, Art.OUTLINE, false, 1.5)

class ModeButton extends Button:
	var kind: String = ""
	var chosen: bool = false

	func _init(k: String) -> void:
		kind = k
		custom_minimum_size = Vector2(ToolBar.ICON, 34)
		focus_mode = Control.FOCUS_NONE

	func _draw() -> void:
		var r := Rect2(3, 3, size.x - 6, size.y - 6)
		draw_rect(r, Color(0.91, 0.90, 0.87))
		var c := r.get_center()
		var ink := Color(0.10, 0.11, 0.14)
		match kind:
			"bulldoze":
				draw_rect(Rect2(c.x - 11, c.y - 2, 15, 7), Color(0.90, 0.68, 0.16))
				draw_rect(Rect2(c.x - 11, c.y - 2, 15, 7), ink, false, 1.0)
				draw_circle(Vector2(c.x - 7, c.y + 7), 3.5, ink)
				draw_circle(Vector2(c.x, c.y + 7), 3.5, ink)
				draw_colored_polygon(PackedVector2Array([
					Vector2(c.x + 5, c.y + 8), Vector2(c.x + 11, c.y - 5),
					Vector2(c.x + 8, c.y + 8)]), Color(0.52, 0.53, 0.56))
			"finger":
				draw_rect(Rect2(c.x - 2.5, c.y - 11, 5, 11), Color(0.96, 0.83, 0.70))
				draw_rect(Rect2(c.x - 2.5, c.y - 11, 5, 11), ink, false, 1.0)
				draw_rect(Rect2(c.x - 7, c.y, 14, 10), Color(0.96, 0.83, 0.70))
				draw_rect(Rect2(c.x - 7, c.y, 14, 10), ink, false, 1.0)
			"inspect":
				draw_circle(c + Vector2(-2, -3), 8.0, Color(0.76, 0.90, 0.97))
				draw_arc(c + Vector2(-2, -3), 8.0, 0, TAU, 26, ink, 2.5)
				draw_line(c + Vector2(3, 2), c + Vector2(10, 9), ink, 3.5)
		draw_rect(r, Art.OUTLINE, false, 1.0)
		if chosen:
			draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), UIKit.GOLD, false, 2.5)

# ---------------------------------------------------------------------------

func _init() -> void:
	super("Tools", false)
	_build()

func _build() -> void:
	var row := HBoxContainer.new()
	body.add_child(row)
	pause_btn = UIKit.button("||", func(): _toggle_pause())
	pause_btn.custom_minimum_size = Vector2(32, 26)
	row.add_child(pause_btn)
	var slower := UIKit.button("<", func(): _speed(-1))
	slower.custom_minimum_size = Vector2(26, 26)
	row.add_child(slower)
	var faster := UIKit.button(">", func(): _speed(1))
	faster.custom_minimum_size = Vector2(26, 26)
	row.add_child(faster)
	speed_label = UIKit.label("x" + Game.speed_text(Game.SPEEDS[Game.speed_index]), 11)
	row.add_child(speed_label)

	undo_btn = UIKit.button("Undo", func(): Game.undo_build())
	undo_btn.custom_minimum_size = Vector2(COLUMNS * ICON - 4, 24)
	undo_btn.tooltip_text = "Take back the last thing you built.\nTwo tower hours to change your mind."
	body.add_child(undo_btn)

	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 1)
	body.add_child(modes)
	for m in MODES:
		var b := ModeButton.new(m)
		b.tooltip_text = MODE_LABEL[m]
		b.pressed.connect(_pick_mode.bind(m))
		modes.add_child(b)
		mode_buttons[m] = b

	body.add_child(UIKit.hsep())

	# The palette scrolls, so a short window never hides the cathedral.
	scroller = ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.custom_minimum_size = Vector2(COLUMNS * ICON + 12, 300)
	body.add_child(scroller)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	scroller.add_child(grid)
	for id in FacilityDB.TOOL_ORDER:
		var b := ToolButton.new(id)
		var d: Dictionary = FacilityDB.DEFS[id]
		b.tooltip_text = "%s\n%s\n%s" % [d["name"],
			Economy.money(int(d["cost"])) + (" per segment" if d.get("drag", "") == "h" else ""),
			d.get("desc", "")]
		b.pressed.connect(_pick.bind(id))
		grid.add_child(b)
		buttons[id] = b
	_pick("lobby")
	refresh()

## Keep the palette inside the window however short it is.
func fit_height(available: float) -> void:
	var rows := ceilf(float(FacilityDB.TOOL_ORDER.size()) / float(COLUMNS))
	var full := rows * (ICON + 1.0)
	var chrome := 150.0    # title bar, clock buttons, mode buttons, separator
	scroller.custom_minimum_size.y = clampf(available - chrome, 130.0, full)
	reset_size()

func _toggle_pause() -> void:
	Game.set_manual_pause(not Game.manual_paused)
	sync_pause_button()

func sync_pause_button() -> void:
	pause_btn.text = ">" if Game.manual_paused else "||"
	# No countdown on the button. It is either available or greyed out -- a
	# number ticking down in the corner of a screen you are trying to think on
	# top of is a pressure nobody asked for.
	undo_btn.disabled = not Game.can_undo()

func _speed(d: int) -> void:
	Game.speed_index = clampi(Game.speed_index + d, 0, Game.SPEEDS.size() - 1)
	speed_label.text = "x" + Game.speed_text(Game.SPEEDS[Game.speed_index])

func _pick(id: String) -> void:
	if not Game.can_use_tool(id):
		Game.say("Not available at this star rating")
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

## Put the current tool down and go back to the magnifying glass. Right
## clicking anywhere does this, which is the quickest way out of a build you
## have changed your mind about.
func deselect() -> void:
	if mode == "inspect":
		return
	_pick_mode("inspect")

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
