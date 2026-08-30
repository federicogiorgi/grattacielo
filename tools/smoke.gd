extends SceneTree

## Headless sanity run: build a small tower, run a few game days, and report.
## Run with:
##   Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/smoke.gd

var failures := 0

func _fail(msg: String) -> void:
	failures += 1
	print("FAIL: ", msg)

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)

func _initialize() -> void:
	print("--- Grattacielo smoke test ---")
	var tower := Tower.new()
	var router := Router.new(tower)
	var econ := Economy.new()

	# 1. A lobby, then offices on top of it.
	var chk := tower.check_place("lobby", 40, 0, 60)
	_ok(chk["ok"], "lobby should be placeable: " + String(chk["reason"]))
	tower.place("lobby", 40, 0, 60)
	_ok(tower.has_lobby(), "tower has a lobby")
	_ok(tower.lobby_width() == 60, "lobby is 60 segments, got %d" % tower.lobby_width())

	chk = tower.check_place("office", 42, 1)
	_ok(chk["ok"], "office on floor 2 should be placeable: " + String(chk["reason"]))
	_ok(int(chk["cost"]) == 40000, "office costs 40000, got %d" % int(chk["cost"]))
	_ok(int(chk["floor_cost"]) == 9 * 500, "office floor costs 4500, got %d"
		% int(chk["floor_cost"]))
	var off := tower.place("office", 42, 1)
	_ok(off != null, "office placed")

	chk = tower.check_place("office", 200, 1)
	_ok(not chk["ok"], "office outside the lobby width must be refused")

	chk = tower.check_place("office", 42, 1)
	_ok(not chk["ok"], "office on top of an office must be refused")

	chk = tower.check_place("shop", 60, 0)
	_ok(not chk["ok"], "ground floor is lobby only")

	# 2. Stairs and an elevator, and a route through them.
	tower.place("floor", 40, 1, 60)
	var st := tower.place("stairs", 52, 0)
	_ok(st != null, "stairs placed")
	var legs := router.find(0, 45.0, 1, 44.0)
	_ok(not legs.is_empty(), "a route up the stairs exists")

	tower.place("floor", 40, 2, 60)
	tower.place("floor", 40, 3, 60)
	var sh := tower.place_shaft("elevator", 44, 0, 3)
	_ok(sh != null, "shaft placed")
	_ok(sh.cars.size() == 1, "a new shaft has one car")
	router.clear_cache()
	legs = router.find(0, 60.0, 3, 60.0)
	_ok(not legs.is_empty(), "a route to floor 4 exists via the lift")
	var used_lift := false
	for l in legs:
		if int(l["t"]) == Router.LEG_ELEVATOR:
			used_lift = true
	_ok(used_lift, "the route actually uses the lift")

	# 3. Prices match the manual.
	_ok(FacilityDB.cost_of("condo") == 80000, "condo costs 80000")
	_ok(FacilityDB.cost_of("cathedral") == 3000000, "cathedral costs 3000000")
	_ok(FacilityDB.cost_of("metro") == 1000000, "metro costs 1000000")
	_ok(FacilityDB.DEFS["express_elevator"]["capacity"] == 42, "express holds 42")
	_ok(FacilityDB.DEFS["elevator"]["capacity"] == 21, "standard lift holds 21")
	_ok(FacilityDB.size_of("cinema") == Vector2i(31, 2), "cinema is 31x2")
	_ok(econ.funds == 2000000, "you start with two million")

	# 4. Star thresholds.
	_ok(int(Rules.STARS[1]["pop"]) == 300, "two stars at 300 people")
	_ok(int(Rules.STARS[4]["pop"]) == 10000, "five stars at 10000 people")

	# 5. Floors and labels.
	_ok(FacilityDB.row_label(0) == "1", "row 0 is floor 1")
	_ok(FacilityDB.row_label(-1) == "B1", "row -1 is B1")
	_ok(FacilityDB.row_label(99) == "100", "row 99 is floor 100")

	# 6. Santa only on the last night of the year.
	var clock := GameClock.new()
	clock.quarter = 4
	clock.day_in_quarter = 2
	_ok(clock.is_last_night_of_year(), "Q4 day 3 is the last night of the year")
	clock.quarter = 3
	_ok(not clock.is_last_night_of_year(), "Q3 is not")

	# 7. Run the whole machine for a few days.
	var g = load("res://scripts/core/game.gd").new()
	root.add_child(g)
	g.new_game()
	g.tower.place("lobby", 40, 0, 80)
	for r in range(1, 8):
		g.tower.place("floor", 40, r, 80)
	for r in range(1, 8):
		for i in range(6):
			g.tower.place("office", 42 + i * 9, r)
	g.tower.place_shaft("elevator", 100, 0, 7)
	g.tower.place("stairs", 110, 0)
	var shaft: Shaft = g.tower.shafts.values()[0]
	shaft.add_car(0)
	shaft.add_car(3)
	g.clock.speed = 1.0
	var steps := 0
	while steps < 4000 and g.clock.year < 2:
		g._process(0.25)
		steps += 1
	print("  after %d steps: %s %s  pop=%d  fondi=%s  stelle=%d"
		% [steps, g.clock.clock_text(), g.clock.date_text(),
		g.tower.population(), Economy.money(g.econ.funds), g.stars])
	_ok(g.tower.population() > 0, "somebody moved in")
	_ok(g.clock.quarter >= 1, "the clock ran")

	print("--- %d failure(s) ---" % failures)
	quit(1 if failures > 0 else 0)
