extends Node2D

## Puts the game on screen: the camera over the Edit window, every floating
## window, the menus, and all the mouse work of building.

@onready var cam: Camera2D = $Camera2D
@onready var view: Node2D = $TowerView
@onready var ui: CanvasLayer = $UI

var theme_res: Theme
var root_ui: Control

var info_bar: InfoBar
var tool_bar: ToolBar
var map_window: MapWindow
var finance_window: FinanceWindow
var facility_window: FacilityWindow
var tenant_window: TenantWindow
var elevator_window: ElevatorWindow
var find_window: FindWindow
var ask_dialog: AskDialog
var menu_panel: PanelContainer
var options_menu: MenuButton

var pan_from := Vector2.ZERO
var panning := false
var right_from := Vector2.ZERO   # where a right press started, to tell a click from a drag
var drag_start := Vector2i.ZERO
var dragging := false
var drag_placed: int = -999999
var finger_shaft: int = -1
var finger_end: String = ""

const ZOOMS := [0.55, 0.75, 1.0, 1.4]
var zoom_index := 2
var refresh_accum := 0.0
var _last_view := Vector2.ZERO

func _ready() -> void:
	theme_res = UIKit.make_theme()
	root_ui = Control.new()
	root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.theme = theme_res
	ui.add_child(root_ui)

	_build_menus()
	_build_windows()

	cam.zoom = Vector2.ONE * ZOOMS[zoom_index]
	cam.position = Vector2(float(FacilityDB.MAP_SEGMENTS) * Art.SEG_W * 0.5,
		-Art.ROW_H * 5.0)

	Game.message.connect(func(_t): pass)
	Game.star_changed.connect(func(_s): tool_bar.refresh())
	Game.ask_player.connect(func(q, t): ask_dialog.ask(q, t))
	Game.tower_changed.connect(func(): pass)
	Audio.listen(Game)
	get_window().min_size = Vector2i(760, 520)
	get_viewport().size_changed.connect(_layout)
	_layout.call_deferred()
	set_process(true)
	set_process_unhandled_input(true)
	_maybe_screenshot_mode()

# --- a way to look at the game from a script -------------------------------
# Run with:  Godot.exe --path . -- --shot [seconds] [out.png]
# It builds a demonstration tower, lets it run, saves a picture and quits.

var _shot_after: float = -1.0
var _shot_path: String = "user://shot.png"

func _maybe_screenshot_mode() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--shot"):
		return
	var i := args.find("--shot")
	_shot_after = float(args[i + 1]) if args.size() > i + 1 else 3.0
	if args.size() > i + 2:
		_shot_path = args[i + 2]
	_demo_tower()

func _demo_tower() -> void:
	var t: Tower = Game.tower
	t.place("lobby", 120, 0, 140)
	for r in range(1, 13):
		t.place("floor", 122, r, 136)
	for r in range(-3, 0):
		t.place("floor", 130, r, 110)
	var x := 124
	while x < 250:
		t.place("office", x, 1)
		t.place("office", x, 2)
		x += 9
	t.place("fastfood", 124, 3)
	t.place("fastfood", 141, 3)
	t.place("shop", 160, 3)
	t.place("restaurant", 175, 3)
	t.place("cinema", 205, 3)
	x = 124
	while x < 200:
		t.place("condo", x, 5)
		x += 16
	x = 200
	while x < 250:
		t.place("hotel_single", x, 5)
		x += 4
	t.place("hotel_suite", 124, 6)
	t.place("hotel_twin", 136, 6)
	t.place("security", 150, 6)
	t.place("housekeeping", 168, 6)
	t.place("medical", 186, 6)
	t.place("party_hall", 214, 6)
	t.place("parking", 140, -1)
	t.place("parking", 148, -1)
	t.place("parking_ramp", 130, -1)
	t.place("metro", 170, -2)
	t.place("stairs", 256, 0)
	t.place("stairs", 256, 1)
	t.place("stairs", 256, 2)
	t.place("stairs", 150, 1)
	t.place("stairs", 190, 5)
	t.place("escalator", 252, 2)
	var s := t.place_shaft("elevator", 200, 0, 8)
	s.add_car(3)
	s.add_car(6)
	var s2 := t.place_shaft("express_elevator", 190, 0, 8)
	s2.add_car(8)
	Game.stars = 5
	# The demo builds through Tower directly, which skips the step that gives
	# a shop or a diner its brand -- so do it here, or every fast food in the
	# picture comes out the same colour.
	for fid in t.facilities:
		Game._after_place(t.facilities[fid])
	# Fill it up straight away, so the picture shows a working tower rather
	# than a hundred empty rooms waiting for their first tenant.
	for i in range(30):
		Game._rest_period()
		Game._letting_round(10 * 60)
		for fid in t.facilities:
			var f: Facility = t.facilities[fid]
			if f.kind() in [FacilityDB.Kind.OFFICE, FacilityDB.Kind.CONDO,
					FacilityDB.Kind.SHOP]:
				f.eval = Rules.Eval.A
	# Run the morning for real, so the tower in the picture has people in it
	# rather than a cast that was scheduled to arrive at eight and never did.
	Game.clock.minute = 6.0 * 60.0
	Game.clock._last_int_minute = int(Game.clock.minute)
	Game.engine.plan_day(false, 0)
	var guard := 0
	while Game.clock.minute_of_day() < 13 * 60 and guard < 60000:
		Game._process(0.2)
		guard += 1
	if OS.get_cmdline_user_args().has("--moon"):
		Game.clock.minute = 23.0 * 60.0
		view.moon_demo = true
	cam.position = Vector2(190.0 * Art.SEG_W, -5.0 * Art.ROW_H)
	zoom_index = 2
	var args2 := OS.get_cmdline_user_args()
	if args2.has("--focus"):
		var j := args2.find("--focus")
		cam.position = Vector2(float(args2[j + 1]) * Art.SEG_W,
			-float(args2[j + 2]) * Art.ROW_H)
		zoom_index = 3
	cam.zoom = Vector2.ONE * ZOOMS[zoom_index] * (2.6 if args2.has("--focus") else 1.0)
	tool_bar.refresh()
	if OS.get_cmdline_user_args().has("--windows"):
		# Show every panel at once, so a screenshot proves they all lay out.
		elevator_window.show_shaft(s.id)
		elevator_window.position = Vector2(150, 130)
		var offices := t.all_of_type("office")
		if not offices.is_empty():
			facility_window.show_facility(offices[0].id)
			facility_window.position = Vector2(600, 130)
			if not offices[0].occupants.is_empty():
				_show_tenant(offices[0].occupants[0])
				tenant_window.position = Vector2(940, 130)
		finance_window.show()
		finance_window.position = Vector2(600, 430)
		find_window.position = Vector2(940, 430)
		find_window.show()
	elif OS.get_cmdline_user_args().has("--tip"):
		# Show a few tooltips at once, so their contrast can be judged from a
		# screenshot rather than by hovering.
		var y := 150.0
		for id in ["condo", "express_elevator", "cathedral"]:
			var tip := UIKit.tooltip(String(FacilityDB.DEFS[id]["name"]),
				Economy.money(int(FacilityDB.DEFS[id]["cost"])),
				String(FacilityDB.DEFS[id]["desc"]),
				"Needs %d stars" % int(FacilityDB.DEFS[id]["stars"]) if id == "cathedral" else "")
			tip.position = Vector2(260, y)
			root_ui.add_child(tip)
			y += 130.0
	elif not OS.get_cmdline_user_args().has("--focus"):
		map_window.show()

func _shot_tick(delta: float) -> void:
	if _shot_after < 0.0:
		return
	_shot_after -= delta
	if _shot_after <= 0.0:
		_shot_after = -1.0
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot_path)
		print("shot saved to ", _shot_path)
		print("audio: ", Audio.mix_report())
		Audio.shutdown()
		get_tree().quit()

# --- construction of the interface -----------------------------------------

func _build_menus() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	menu_panel.add_theme_stylebox_override("panel",
		UIKit.panel_style(UIKit.BG_DARK, UIKit.INK, 1))
	root_ui.add_child(menu_panel)
	var row := HBoxContainer.new()
	menu_panel.add_child(row)

	var file := MenuButton.new()
	file.text = "File"
	file.flat = false
	file.get_popup().add_item("New Tower", 0)
	file.get_popup().add_item("Open", 1)
	file.get_popup().add_item("Save", 2)
	file.get_popup().add_separator()
	file.get_popup().add_item("Quit", 3)
	file.get_popup().id_pressed.connect(_file_menu)
	row.add_child(file)

	var wins := MenuButton.new()
	wins.text = "Windows"
	wins.get_popup().add_item("Tool Bar", 0)
	wins.get_popup().add_item("Info Bar", 1)
	wins.get_popup().add_item("Map Window", 2)
	wins.get_popup().add_item("Finance Window", 3)
	wins.get_popup().add_item("Find Person", 4)
	wins.get_popup().id_pressed.connect(_windows_menu)
	row.add_child(wins)

	var opts := MenuButton.new()
	options_menu = opts
	opts.text = "Options"
	var op := opts.get_popup()
	op.add_item("Call Fire Rescue", 0)
	op.add_separator()
	op.add_item("Zoom In", 1)
	op.add_item("Zoom Out", 2)
	op.add_separator()
	# The manual's three independent sound toggles.
	op.add_check_item("Sound: Elevators", 3)
	op.add_check_item("Sound: Background", 4)
	op.add_check_item("Sound: Events", 5)
	op.add_check_item("Music", 6)
	for id in [3, 4, 5, 6]:
		op.set_item_checked(op.get_item_index(id), true)
	op.id_pressed.connect(_options_menu)
	row.add_child(opts)

func _build_windows() -> void:
	info_bar = InfoBar.new()
	info_bar.position = Vector2(112, 36)
	root_ui.add_child(info_bar)

	tool_bar = ToolBar.new()
	tool_bar.position = Vector2(6, 126)
	tool_bar.tool_picked.connect(func(_id):
		view.ghost_type = ""
		Audio.play("click"))
	root_ui.add_child(tool_bar)

	map_window = MapWindow.new()
	map_window.position = Vector2(760, 128)
	map_window.jump_to.connect(_jump_to)
	map_window.overlay_changed.connect(func(m): view.overlay = m)
	root_ui.add_child(map_window)
	map_window.hide()

	finance_window = FinanceWindow.new()
	finance_window.position = Vector2(360, 140)
	root_ui.add_child(finance_window)
	finance_window.hide()

	facility_window = FacilityWindow.new()
	facility_window.position = Vector2(300, 200)
	facility_window.tenant_picked.connect(_show_tenant)
	root_ui.add_child(facility_window)
	facility_window.hide()

	tenant_window = TenantWindow.new()
	tenant_window.position = Vector2(600, 260)
	root_ui.add_child(tenant_window)
	tenant_window.hide()

	elevator_window = ElevatorWindow.new()
	elevator_window.position = Vector2(340, 120)
	root_ui.add_child(elevator_window)
	elevator_window.hide()

	find_window = FindWindow.new()
	find_window.position = Vector2(760, 380)
	find_window.locate.connect(_locate_sim)
	root_ui.add_child(find_window)
	find_window.hide()

	ask_dialog = AskDialog.new()
	root_ui.add_child(ask_dialog)

func _file_menu(id: int) -> void:
	match id:
		0:
			Game.new_game()
			tool_bar.refresh()
		1:
			Game.load_game()
			tool_bar.refresh()
		2: Game.save_game()
		3:
			Audio.shutdown()
			get_tree().quit()

func _windows_menu(id: int) -> void:
	match id:
		0: tool_bar.visible = not tool_bar.visible
		1: info_bar.visible = not info_bar.visible
		2: map_window.visible = not map_window.visible
		3:
			finance_window.visible = not finance_window.visible
			if finance_window.visible:
				finance_window.refresh()
		4: find_window.visible = not find_window.visible

func _options_menu(id: int) -> void:
	match id:
		0:
			if Game.events.fire_active():
				Game.answer("fire_heli", true)
			else:
				Game.say("There is no fire to put out.")
		1: _zoom(1)
		2: _zoom(-1)
		3, 4, 5, 6:
			var op: PopupMenu = options_menu.get_popup()
			var i: int = op.get_item_index(id)
			var on: bool = not op.is_item_checked(i)
			op.set_item_checked(i, on)
			match id:
				3: Audio.set_channel("elevators", on)
				4: Audio.set_channel("background", on)
				5: Audio.set_channel("events", on)
				6: Audio.set_channel("music", on)

# --- per-frame -------------------------------------------------------------

## Re-lay the interface for the current viewport. Called once at startup and
## again whenever the window changes shape: the palette is capped to the height
## available and every floating window is pulled back inside the frame.
func _layout() -> void:
	var vp := get_viewport_rect().size
	_last_view = vp
	info_bar.position = Vector2(112, 36)
	tool_bar.position = Vector2(6, 126)
	tool_bar.fit_height(vp.y - tool_bar.position.y - 10.0)
	if map_window.size.x > 0.0 and map_window.position.x + map_window.size.x > vp.x - 8.0:
		map_window.position.x = maxf(vp.x - map_window.size.x - 8.0, 160.0)
	for w in [map_window, finance_window, facility_window, tenant_window,
			elevator_window, find_window, ask_dialog]:
		w.clamp_into(vp)

func _process(delta: float) -> void:
	_shot_tick(delta)
	if get_viewport_rect().size != _last_view:
		_layout()
	_keyboard_pan(delta)
	refresh_accum += delta
	if refresh_accum > 0.1:
		refresh_accum = 0.0
		info_bar.refresh()
		tool_bar.sync_pause_button()
		if map_window.visible:
			map_window.refresh(view.visible_world())
		if facility_window.visible:
			facility_window.refresh()
		if tenant_window.visible:
			tenant_window.refresh()
		if elevator_window.visible:
			elevator_window.refresh()
		if finance_window.visible:
			finance_window.refresh()
	_update_ghost()

func _keyboard_pan(delta: float) -> void:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		v.y += 1.0
	if v != Vector2.ZERO:
		cam.position += v.normalized() * 900.0 * delta / cam.zoom.x
		_clamp_camera()

func _clamp_camera() -> void:
	var w := float(FacilityDB.MAP_SEGMENTS) * Art.SEG_W
	cam.position.x = clampf(cam.position.x, 0.0, w)
	cam.position.y = clampf(cam.position.y,
		-float(FacilityDB.FLOORS_ABOVE + 4) * Art.ROW_H,
		float(FacilityDB.FLOORS_BELOW + 2) * Art.ROW_H)

func _zoom(d: int) -> void:
	zoom_index = clampi(zoom_index + d, 0, ZOOMS.size() - 1)
	cam.zoom = Vector2.ONE * ZOOMS[zoom_index]

# --- input -----------------------------------------------------------------

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		match e.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if e.pressed:
					_zoom(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if e.pressed:
					_zoom(-1)
			MOUSE_BUTTON_MIDDLE:
				panning = e.pressed
				pan_from = e.position
			MOUSE_BUTTON_RIGHT:
				# Right drag pans; a right CLICK puts the tool down. The two are
				# told apart by whether the mouse actually moved.
				panning = e.pressed
				pan_from = e.position
				if e.pressed:
					right_from = e.position
				elif (e.position - right_from).length() < 6.0:
					_go_back()
			MOUSE_BUTTON_LEFT:
				if e.pressed:
					_press(_cell_under_mouse())
				else:
					_release(_cell_under_mouse())
	elif e is InputEventMouseMotion:
		if panning:
			cam.position -= e.relative / cam.zoom
			_clamp_camera()
		elif dragging:
			_drag(_cell_under_mouse())
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE:
				tool_bar._toggle_pause()
			KEY_ESCAPE:
				Game.selected_facility = -1
				Game.selected_shaft = -1
			KEY_M:
				map_window.visible = not map_window.visible
			KEY_F:
				if finance_window.visible:
					finance_window.hide()
				else:
					finance_window.show()
					finance_window.refresh()

## Right click means "back": it shuts the front-most window that is open, and
## once they are all shut it puts the current tool down. One button to undo
## whatever the last thing you opened or picked was.
func _go_back() -> void:
	var windows := [ask_dialog, tenant_window, facility_window, elevator_window,
		finance_window, find_window, map_window]
	var front: Control = null
	var best := -1
	for w in windows:
		if w.visible and w.get_index() > best:
			best = w.get_index()
			front = w
	if front != null:
		front.hide()
		Game.selected_facility = -1
		Game.selected_shaft = -1
		return
	tool_bar.deselect()

func _cell_under_mouse() -> Vector2i:
	return view.world_to_cell(get_global_mouse_position())

func _update_ghost() -> void:
	var c := _cell_under_mouse()
	view.ghost_cell = c
	view.dragging = dragging
	if tool_bar.mode != "build":
		view.ghost_type = ""
		return
	var t: String = Game.tool
	view.ghost_type = t
	var d := FacilityDB.get_def(t)
	if d.is_empty():
		return
	if dragging and String(d.get("drag", "")) in ["h", "repeat"]:
		var lo := mini(drag_start.x, c.x)
		var hi := maxi(drag_start.x, c.x)
		view.ghost_cell = Vector2i(lo, drag_start.y)
		view.ghost_w = maxi(hi - lo + 1, int(d.get("w", 1)))
	elif dragging and FacilityDB.is_elevator(t):
		view.ghost_cell = Vector2i(drag_start.x, drag_start.y)
		view.ghost_drag_to = Vector2i(drag_start.x, c.y)
		view.ghost_w = int(d["w"])
	else:
		view.ghost_w = int(d.get("w", 1))
	var chk := Game.tower.check_place(t, view.ghost_cell.x, view.ghost_cell.y,
		view.ghost_w)
	view.ghost_ok = bool(chk["ok"]) and Game.can_use_tool(t)

# --- clicking --------------------------------------------------------------

func _press(c: Vector2i) -> void:
	# Santa first: he is only there for a few minutes a year.
	if Game.events.santa_active:
		var sx := Game.events.santa_x
		if absf(float(c.x) - sx) < 14.0 and absi(c.y - Game.events.santa_row()) < 2:
			Game.claim_santa()
			return
	match tool_bar.mode:
		"bulldoze":
			Game.try_bulldoze(c.x, c.y)
			return
		"inspect":
			_inspect(c)
			return
		"finger":
			_finger_press(c)
			return
	# build
	var t: String = Game.tool
	var d := FacilityDB.get_def(t)
	drag_start = c
	dragging = true
	drag_placed = -999999
	if String(d.get("drag", "")) != "" or FacilityDB.is_elevator(t):
		return   # committed on release
	_place_at(c)

func _drag(c: Vector2i) -> void:
	if tool_bar.mode == "finger":
		_finger_drag(c)
		return
	if tool_bar.mode != "build" or not dragging:
		return
	var t: String = Game.tool
	var d := FacilityDB.get_def(t)
	if String(d.get("drag", "")) != "" or FacilityDB.is_elevator(t):
		return
	# painting a row of rooms: only when the cursor has cleared the last one
	var w: int = int(d.get("w", 1))
	if c.y != drag_start.y:
		drag_start.y = c.y
		drag_placed = -999999
	if absi(c.x - drag_placed) >= w:
		_place_at(c)

func _release(c: Vector2i) -> void:
	if tool_bar.mode == "finger":
		finger_shaft = -1
		finger_end = ""
		dragging = false
		return
	if not dragging:
		return
	dragging = false
	var t: String = Game.tool
	var d := FacilityDB.get_def(t)
	if String(d.get("drag", "")) == "h":
		var lo := mini(drag_start.x, c.x)
		var hi := maxi(drag_start.x, c.x)
		Game.try_place(t, lo, drag_start.y, hi - lo + 1)
	elif String(d.get("drag", "")) == "repeat":
		var lo3 := mini(drag_start.x, c.x)
		var hi3 := maxi(drag_start.x, c.x)
		var step: int = int(d.get("w", 1))
		var at := lo3
		while at + step - 1 <= hi3 or at == lo3:
			if not Game.try_place(t, at, drag_start.y)["ok"]:
				break
			at += step
	elif String(d.get("drag", "")) == "v":
		var lo2 := mini(drag_start.y, c.y)
		var hi2 := maxi(drag_start.y, c.y)
		for r in range(hi2, lo2 - 1, -1):
			Game.try_place(t, drag_start.x, r)
	elif FacilityDB.is_elevator(t):
		Game.try_place(t, drag_start.x, drag_start.y, -1, c.y)

func _place_at(c: Vector2i) -> void:
	var t: String = Game.tool
	var d := FacilityDB.get_def(t)
	if String(d.get("drag", "")) == "v":
		return
	var res := Game.try_place(t, c.x, c.y)
	if res["ok"]:
		drag_placed = c.x

func _inspect(c: Vector2i) -> void:
	# A person standing right here?
	var sid := _sim_near(c)
	if sid != -1:
		_show_tenant(sid)
		return
	var s := Game.tower.shaft_at(c.x, c.y)
	if s != null:
		Game.selected_shaft = s.id
		Game.selected_facility = -1
		elevator_window.show_shaft(s.id)
		return
	var f := Game.tower.facility_at(c.x, c.y)
	if f == null:
		f = Game.tower.transit_at(c.x, c.y)
	if f != null:
		Game.selected_facility = f.id
		Game.selected_shaft = -1
		facility_window.show_facility(f.id)
		return
	Game.selected_facility = -1
	Game.selected_shaft = -1

func _sim_near(c: Vector2i) -> int:
	var list: Array = Game.engine.walking_by_row.get(c.y, [])
	var now := Game.clock.minute
	for sid in list:
		var s: Sim = Game.engine.sims.get(sid)
		if s == null:
			continue
		var x := s.seg
		if s.state == Sim.State.WALKING:
			x = Game.engine.walk_position(s, now)
		if absf(x - float(c.x)) < 2.0:
			return sid
	return -1

func _show_tenant(sid: int) -> void:
	Game.selected_sim = sid
	tenant_window.show_sim(sid)

func _locate_sim(sid: int) -> void:
	var s: Sim = Game.engine.sims.get(sid)
	if s == null:
		return
	if s.state == Sim.State.OUTSIDE:
		Game.say(s.display_name() + " is not in the tower right now.")
		return
	cam.position = Vector2(s.seg * Art.SEG_W, -float(s.row) * Art.ROW_H - 60.0)
	_clamp_camera()
	Game.set_manual_pause(true)
	tool_bar.sync_pause_button()
	_show_tenant(sid)

func _jump_to(seg: int, row: int) -> void:
	cam.position = Vector2(float(seg) * Art.SEG_W, -float(row) * Art.ROW_H)
	_clamp_camera()

# --- the finger tool -------------------------------------------------------

func _finger_press(c: Vector2i) -> void:
	var s := Game.tower.shaft_at(c.x, c.y)
	if s == null:
		# The machinery sits just above the top and just below the bottom.
		for sid in Game.tower.shafts:
			var t: Shaft = Game.tower.shafts[sid]
			if c.x >= t.seg and c.x < t.seg + t.width():
				if c.y == t.top_row + 1:
					finger_shaft = t.id
					finger_end = "top"
					dragging = true
					return
				if c.y == t.bottom_row - 1:
					finger_shaft = t.id
					finger_end = "bottom"
					dragging = true
					return
		return
	# Clicking a floor number in the shaft switches its service off.
	if s.is_express():
		Game.say("An express elevator's floors cannot be changed.")
		return
	var blocked := false
	for car in s.cars:
		if car.home_row == c.y:
			blocked = true
	if blocked:
		Game.say("You cannot switch off service to a car's waiting floor.")
		return
	if s.disabled_rows.has(c.y):
		s.disabled_rows.erase(c.y)
	else:
		s.disabled_rows[c.y] = true
	Game.tower.mark_dirty()
	Game.router.clear_cache()

func _finger_drag(c: Vector2i) -> void:
	if finger_shaft == -1:
		return
	var s: Shaft = Game.tower.shafts.get(finger_shaft)
	if s == null:
		return
	var nb := s.bottom_row
	var nt := s.top_row
	if finger_end == "top":
		nt = maxi(c.y, s.bottom_row)
	else:
		nb = mini(c.y, s.top_row)
	if nb == s.bottom_row and nt == s.top_row:
		return
	var err := Game.tower.resize_shaft(s, nb, nt)
	if err != "":
		Audio.play("deny")
		Game.say(err + " -- clear it before the shaft can pass")
