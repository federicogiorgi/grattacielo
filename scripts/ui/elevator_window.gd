extends UIKit.GWindow
class_name ElevatorWindow

## The elevator control panel: the schedule bands, the two dispatch settings,
## and the floor-by-car grid where you switch floors off and park cars.

var shaft_id: int = -1
var weekend_view: bool = false
var wd_btn: Button
var we_btn: Button
var band_row: HBoxContainer
var band_buttons: Array[OptionButton] = []
var resp_label: Label
var dep_label: Label
var grid: CarGrid
var show_btn: Button
var info: Label

const MODE_NAMES := ["Local", "Express to top", "Express to bottom"]
# Seven bands across one panel means the selector has to be narrow, so the
# buttons carry the short form and the legend under them says what it means.
const MODE_SHORT := ["Local", "Top", "Bottom"]

class CarGrid extends Control:
	signal floor_toggled(row: int)
	signal home_set(car: int, row: int)

	var shaft_id: int = -1
	var top_row: int = 0        # first row shown
	const ROW_PX := 13.0
	const NUM_W := 34.0
	const CAR_W := 22.0
	var rows_shown := 22

	func _init() -> void:
		custom_minimum_size = Vector2(240, 22.0 * 13.0)
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	func fit_to(cars: int) -> void:
		custom_minimum_size.x = NUM_W + float(maxi(cars, 1)) * CAR_W + 6.0

	func shaft() -> Shaft:
		return Game.tower.shafts.get(shaft_id)

	func _draw() -> void:
		var s := shaft()
		if s == null:
			return
		var font := ThemeDB.fallback_font
		rows_shown = int(size.y / ROW_PX)
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
		for i in range(rows_shown):
			var r := top_row - i
			if not s.covers_row(r):
				continue
			var y := float(i) * ROW_PX
			var served := s.serves_row(r)
			var nr := Rect2(0, y, NUM_W, ROW_PX - 1)
			draw_rect(nr, UIKit.INK if served else Color.WHITE)
			draw_string(font, Vector2(4, y + ROW_PX - 3), FacilityDB.row_label(r),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color.WHITE if served else UIKit.INK)
			if not served:
				draw_line(nr.position, nr.end, Color(0.85, 0.15, 0.15), 1.5)
			for c in range(s.cars.size()):
				var car: Shaft.Car = s.cars[c]
				var cr := Rect2(NUM_W + 2.0 + float(c) * CAR_W, y, CAR_W - 2.0, ROW_PX - 1)
				draw_rect(cr, Color(0.95, 0.95, 0.93))
				draw_rect(cr, Color(0.75, 0.75, 0.72), false, 1.0)
				if car.home_row == r:
					draw_rect(cr.grow(-2.0), Color(0.98, 0.45, 0.62))
				if int(round(car.pos)) == r:
					var cc := cr.get_center()
					if car.dir > 0:
						draw_colored_polygon(PackedVector2Array([
							cc + Vector2(0, -4), cc + Vector2(4, 3), cc + Vector2(-4, 3)]),
							UIKit.INK)
					elif car.dir < 0:
						draw_colored_polygon(PackedVector2Array([
							cc + Vector2(0, 4), cc + Vector2(4, -3), cc + Vector2(-4, -3)]),
							UIKit.INK)
					else:
						draw_arc(cc, 4.0, 0, TAU, 12, UIKit.INK, 1.5)
					if car.full:
						draw_string(font, cc + Vector2(-3, 4), "F",
							HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.88, 0.16, 0.14))
				elif car.stops.has(r):
					draw_circle(cr.get_center(), 3.0, UIKit.ACCENT)
		draw_rect(Rect2(Vector2.ZERO, size), UIKit.INK, false, 1.0)

	func _gui_input(e: InputEvent) -> void:
		if not (e is InputEventMouseButton and e.pressed):
			return
		var s := shaft()
		if s == null:
			return
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			top_row = mini(top_row + 2, s.top_row)
			queue_redraw()
			accept_event()
			return
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			top_row = maxi(top_row - 2, s.bottom_row + rows_shown - 1)
			top_row = maxi(top_row, s.bottom_row)
			queue_redraw()
			accept_event()
			return
		if e.button_index != MOUSE_BUTTON_LEFT:
			return
		var i := int(e.position.y / ROW_PX)
		var r := top_row - i
		if not s.covers_row(r):
			return
		if e.position.x < NUM_W:
			floor_toggled.emit(r)
		else:
			var c := int((e.position.x - NUM_W - 2.0) / CAR_W)
			if c >= 0 and c < s.cars.size():
				home_set.emit(c, r)
		queue_redraw()
		accept_event()

func _init() -> void:
	super("Elevator")
	var days := HBoxContainer.new()
	wd_btn = UIKit.button("WD", func(): _set_day(false))
	we_btn = UIKit.button("WE", func(): _set_day(true))
	wd_btn.custom_minimum_size = Vector2(46, 24)
	we_btn.custom_minimum_size = Vector2(46, 24)
	days.add_child(wd_btn)
	days.add_child(we_btn)
	body.add_child(days)

	body.add_child(UIKit.label("Car schedule", 12, UIKit.ACCENT))
	band_row = HBoxContainer.new()
	band_row.add_theme_constant_override("separation", 2)
	body.add_child(band_row)
	for i in range(Shaft.BAND_STARTS.size()):
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		var from_h: int = Shaft.BAND_STARTS[i]
		var to_h: int = Shaft.BAND_STARTS[i + 1] if i + 1 < Shaft.BAND_STARTS.size() else 24
		col.add_child(UIKit.label("%02d-%02d" % [from_h, to_h], 10))
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		ob.custom_minimum_size = Vector2(70, 22)
		ob.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		ob.clip_text = true
		ob.add_theme_font_size_override("font_size", 10)
		for n in MODE_SHORT:
			ob.add_item(n)
		ob.tooltip_text = "Local, Express to top, Express to bottom"
		ob.item_selected.connect(_set_band.bind(i))
		col.add_child(ob)
		band_buttons.append(ob)
		band_row.add_child(col)

	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 16)
	body.add_child(settings)

	var respc := VBoxContainer.new()
	respc.add_child(UIKit.label("Waiting car response", 11))
	var rr := HBoxContainer.new()
	rr.add_child(UIKit.button("-", func(): _resp(-1)))
	resp_label = UIKit.label("5 floors", 12)
	rr.add_child(resp_label)
	rr.add_child(UIKit.button("+", func(): _resp(1)))
	respc.add_child(rr)
	settings.add_child(respc)

	var depc := VBoxContainer.new()
	depc.add_child(UIKit.label("Standard floor departure", 11))
	var dr := HBoxContainer.new()
	dr.add_child(UIKit.button("-", func(): _dep(-5)))
	dep_label = UIKit.label("0 s", 12)
	dr.add_child(dep_label)
	dr.add_child(UIKit.button("+", func(): _dep(5)))
	depc.add_child(dr)
	settings.add_child(depc)

	body.add_child(UIKit.label(
		"Local = stops on call   Top / Bottom = express in that direction", 10,
		Color(0.35, 0.34, 0.32)))

	body.add_child(UIKit.label("Floors and cars", 12, UIKit.ACCENT))
	grid = CarGrid.new()
	grid.floor_toggled.connect(_toggle_floor)
	grid.home_set.connect(_set_home)
	var holder := HBoxContainer.new()
	holder.add_child(grid)
	holder.add_child(UIKit.label(
		"Click a floor number to\nswitch its service off.\nClick a car's column to\npark that car on the floor.\nScroll with the wheel.", 10,
		Color(0.35, 0.34, 0.32)))
	body.add_child(holder)

	info = UIKit.label("", 11)
	body.add_child(info)

	var bottom := HBoxContainer.new()
	show_btn = UIKit.button("Show: On", _toggle_show)
	bottom.add_child(show_btn)
	bottom.add_child(UIKit.button("Add car", _add_car))
	bottom.add_child(UIKit.button("OK", func(): hide()))
	body.add_child(bottom)

	visibility_changed.connect(func():
		if visible:
			refresh())

func show_shaft(id: int) -> void:
	shaft_id = id
	grid.shaft_id = id
	var s: Shaft = Game.tower.shafts.get(id)
	if s != null:
		grid.top_row = s.top_row
		weekend_view = Game.clock.is_weekend()
	refresh()
	show()
	move_to_front()

func shaft() -> Shaft:
	return Game.tower.shafts.get(shaft_id)

func refresh() -> void:
	var s := shaft()
	if s == null:
		hide()
		return
	set_title("%s -- floors %s to %s" % [s.def()["name"],
		FacilityDB.row_label(s.bottom_row), FacilityDB.row_label(s.top_row)])
	wd_btn.add_theme_stylebox_override("normal",
		UIKit.panel_style(UIKit.BG_LIGHT if weekend_view else UIKit.GOLD))
	we_btn.add_theme_stylebox_override("normal",
		UIKit.panel_style(UIKit.GOLD if weekend_view else UIKit.BG_LIGHT))
	var modes := s.modes_we if weekend_view else s.modes_wd
	for i in range(band_buttons.size()):
		band_buttons[i].select(clampi(modes[i], 0, 2))
		band_buttons[i].disabled = s.is_express()
	band_row.modulate = Color(1, 1, 1, 0.45) if s.is_express() else Color.WHITE
	resp_label.text = "%d floors" % s.wait_response
	dep_label.text = "%d s" % s.floor_departure
	show_btn.text = "Show: On" if s.show else "Show: Off"
	grid.fit_to(s.cars.size())
	info.text = "%d cars, %d waiting, %d aboard" % [s.cars.size(),
		s.total_waiting(), s.riders_total()]
	if s.is_express():
		info.text += "   (stops at sky lobbies only)"
	grid.queue_redraw()

func _set_day(we: bool) -> void:
	weekend_view = we
	refresh()

func _set_band(index: int, band: int) -> void:
	var s := shaft()
	if s == null:
		return
	if weekend_view:
		s.modes_we[band] = index
	else:
		s.modes_wd[band] = index

func _resp(d: int) -> void:
	var s := shaft()
	if s == null:
		return
	s.wait_response = clampi(s.wait_response + d, 0, 30)
	refresh()

func _dep(d: int) -> void:
	var s := shaft()
	if s == null:
		return
	s.floor_departure = clampi(s.floor_departure + d, 0, 60)
	refresh()

func _toggle_floor(row: int) -> void:
	var s := shaft()
	if s == null:
		return
	for c in s.cars:
		if c.home_row == row:
			Game.say("You cannot switch off service to a car's waiting floor.")
			return
	if s.is_express():
		Game.say("An express elevator's floors cannot be changed.")
		return
	if s.disabled_rows.has(row):
		s.disabled_rows.erase(row)
	else:
		s.disabled_rows[row] = true
	Game.tower.mark_dirty()
	Game.router.clear_cache()
	refresh()

func _set_home(car: int, row: int) -> void:
	var s := shaft()
	if s == null or car >= s.cars.size():
		return
	if not s.serves_row(row):
		Game.say("That floor has no service.")
		return
	s.cars[car].home_row = row
	refresh()

func _toggle_show() -> void:
	var s := shaft()
	if s == null:
		return
	s.show = not s.show
	refresh()

func _add_car() -> void:
	var s := shaft()
	if s == null:
		return
	Game.try_place(s.type, s.seg, s.cars[0].home_row if not s.cars.is_empty()
		else s.bottom_row)
	refresh()
