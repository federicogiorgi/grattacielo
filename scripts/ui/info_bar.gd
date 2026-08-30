extends UIKit.GWindow
class_name InfoBar

## The Info Bar: the clock, the stars, the date, the message line, your money
## and your population. Everything the original put across the top.

var clock_face: ClockFace
var stars_view: StarsView
var date_label: Label
var msg_label: Label
var funds_label: Label
var pop_label: Label

class ClockFace extends Control:
	var minute: int = 0

	func _init() -> void:
		custom_minimum_size = Vector2(44, 44)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.45
		draw_circle(c, r, Art.sky_colour(minute))
		draw_arc(c, r, 0, TAU, 32, UIKit.INK, 2.0)
		for i in range(12):
			var a := float(i) * TAU / 12.0 - PI / 2.0
			draw_line(c + Vector2(cos(a), sin(a)) * (r - 3.0),
				c + Vector2(cos(a), sin(a)) * (r - 6.0), UIKit.INK, 1.0)
		var h := float(minute) / 60.0
		var ha := (h / 12.0) * TAU - PI / 2.0
		var ma := (float(minute % 60) / 60.0) * TAU - PI / 2.0
		draw_line(c, c + Vector2(cos(ha), sin(ha)) * (r * 0.5), UIKit.INK, 2.5)
		draw_line(c, c + Vector2(cos(ma), sin(ma)) * (r * 0.75), UIKit.INK, 1.5)

class StarsView extends Control:
	var stars: int = 1

	func _init() -> void:
		custom_minimum_size = Vector2(96, 22)

	func _draw() -> void:
		for i in range(5):
			var filled := i < stars
			_star(Vector2(11.0 + float(i) * 18.0, 11.0), 8.0,
				UIKit.GOLD if filled else Color(0.72, 0.71, 0.68))
		if stars >= 6:
			draw_string(ThemeDB.fallback_font, Vector2(0, 18), "GRATTACIELO",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIKit.GOLD)

	func _star(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in range(10):
			var a := float(i) * PI / 5.0 - PI / 2.0
			var rad := r if i % 2 == 0 else r * 0.45
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		draw_colored_polygon(pts, col)
		draw_polyline(pts + PackedVector2Array([pts[0]]), UIKit.INK, 1.0)

func _init() -> void:
	super("Grattacielo", false)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)

	clock_face = ClockFace.new()
	row.add_child(clock_face)

	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 1)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	mid.add_child(top)
	stars_view = StarsView.new()
	top.add_child(stars_view)
	date_label = UIKit.label("WD  T1  Anno 1", 13)
	top.add_child(date_label)

	msg_label = UIKit.label("", 12, Color(0.24, 0.22, 0.20))
	msg_label.clip_text = true
	msg_label.custom_minimum_size.x = 420
	mid.add_child(msg_label)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 1)
	row.add_child(right)
	funds_label = UIKit.label("L. 2.000.000", 15)
	funds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(funds_label)
	pop_label = UIKit.label("Pop 0", 12)
	pop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(pop_label)

func refresh() -> void:
	var g := Game
	clock_face.minute = g.clock.minute_of_day()
	clock_face.queue_redraw()
	stars_view.stars = g.stars
	stars_view.queue_redraw()
	date_label.text = "%s   %s" % [g.clock.clock_text(), g.clock.date_text()]
	msg_label.text = g.last_message
	funds_label.text = Economy.money(g.econ.funds)
	funds_label.add_theme_color_override("font_color",
		Color(0.62, 0.14, 0.12) if g.econ.funds < 0 else UIKit.INK)
	pop_label.text = "Pop %d" % g.tower.population()
