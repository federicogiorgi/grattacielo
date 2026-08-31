extends SceneTree

## The rules that came out of the manual, checked against the code that is
## supposed to implement them. If one of these fails, the game has drifted
## away from SimTower and it is worth knowing which way.

var failures := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)

func _initialize() -> void:
	print("--- rules ---")
	_prices()
	_sizes()
	_stars()
	_limits()
	_placement()
	_stairs_overlay()
	_transport()
	_economy()
	_letting_timing()
	_save_load()
	print("--- %d failure(s) ---" % failures)
	quit(1 if failures > 0 else 0)

# Every price the manual and the reference tables give.
func _prices() -> void:
	var want := {
		"floor": 500, "lobby": 5000, "stairs": 5000, "escalator": 20000,
		"office": 40000, "condo": 80000,
		"hotel_single": 20000, "hotel_twin": 50000, "hotel_suite": 100000,
		"fastfood": 100000, "restaurant": 200000, "shop": 100000,
		"party_hall": 100000, "cinema": 500000,
		"housekeeping": 50000, "security": 100000,
		"medical": 500000, "recycling": 500000,
		"parking": 3000, "parking_ramp": 50000,
		"metro": 1000000, "cathedral": 3000000,
		"elevator": 200000, "service_elevator": 100000, "express_elevator": 400000,
	}
	for k in want:
		ok(FacilityDB.cost_of(k) == int(want[k]),
			"%s costs %d, not %d" % [k, int(want[k]), FacilityDB.cost_of(k)])
	ok(int(FacilityDB.DEFS["elevator"]["car_cost"]) == 80000, "a standard car is 80000")
	ok(int(FacilityDB.DEFS["service_elevator"]["car_cost"]) == 50000, "a service car is 50000")
	ok(int(FacilityDB.DEFS["express_elevator"]["car_cost"]) == 150000, "an express car is 150000")
	ok(int(FacilityDB.DEFS["cinema"]["movie_new"]) == 300000, "a new film costs 300000")
	ok(int(FacilityDB.DEFS["cinema"]["movie_classic"]) == 150000, "a classic costs 150000")
	ok(Rules.FIRE_HELICOPTER_COST == 500000, "the helicopter costs 500000")
	ok(FacilityDB.STARTING_FUNDS == 2000000, "you start with two million")

func _sizes() -> void:
	var want := {
		"office": Vector2i(9, 1), "condo": Vector2i(16, 1),
		"hotel_single": Vector2i(4, 1), "hotel_twin": Vector2i(6, 1),
		"hotel_suite": Vector2i(10, 1), "fastfood": Vector2i(16, 1),
		"restaurant": Vector2i(24, 1), "shop": Vector2i(12, 1),
		"party_hall": Vector2i(24, 2), "cinema": Vector2i(31, 2),
		"housekeeping": Vector2i(15, 1), "security": Vector2i(16, 1),
		"medical": Vector2i(26, 1), "recycling": Vector2i(25, 2),
		"metro": Vector2i(30, 3), "cathedral": Vector2i(28, 4),
		"stairs": Vector2i(8, 2), "escalator": Vector2i(8, 2),
		"elevator": Vector2i(4, 1), "express_elevator": Vector2i(6, 1),
	}
	for k in want:
		ok(FacilityDB.size_of(k) == want[k],
			"%s is %s, not %s" % [k, str(want[k]), str(FacilityDB.size_of(k))])
	var cap := {"office": 6, "condo": 3, "hotel_single": 1, "hotel_twin": 2,
		"hotel_suite": 2, "party_hall": 50, "cinema": 120, "housekeeping": 6,
		"elevator": 21, "service_elevator": 21, "express_elevator": 42}
	for k in cap:
		ok(int(FacilityDB.DEFS[k]["capacity"]) == int(cap[k]),
			"%s holds %d" % [k, int(cap[k])])
	ok(FacilityDB.MAP_SEGMENTS == 375, "the lot is 375 segments wide")
	ok(FacilityDB.FLOORS_ABOVE == 100 and FacilityDB.FLOORS_BELOW == 10,
		"100 storeys up and 10 down")

func _stars() -> void:
	var pops := [0, 300, 1000, 5000, 10000, 15000]
	for i in range(pops.size()):
		ok(int(Rules.STARS[i]["pop"]) == pops[i],
			"star %d wants %d people" % [i + 1, pops[i]])
	ok(Rules.STARS[2]["needs"].has("security"), "three stars wants a security office")
	ok(Rules.STARS[3]["needs"].has("vip"), "four stars wants a happy VIP")
	ok(Rules.STARS[3]["needs"].has("hotel_suite"), "four stars wants suites")
	ok(Rules.STARS[4]["needs"].has("metro"), "five stars wants the metro")
	ok(Rules.STARS[5]["needs"].has("cathedral"), "GRATTACIELO wants the cathedral")
	# Tools unlock in step with the ratings.
	ok(FacilityDB.stars_for("hotel_suite") == 2, "suites at two stars")
	ok(FacilityDB.stars_for("express_elevator") == 3, "express lifts at three stars")
	ok(FacilityDB.stars_for("metro") == 4, "the metro at four stars")
	ok(FacilityDB.stars_for("cathedral") == 5, "the cathedral at five stars")

func _limits() -> void:
	var l := FacilityDB.LIMITS
	ok(int(l["shafts"]) == 24, "24 shafts")
	ok(int(l["cars_per_shaft"]) == 8, "8 cars a shaft")
	ok(int(l["stairs_escalators"]) == 64, "64 stairs and escalators")
	ok(int(l["retail"]) == 512, "512 retail units")
	ok(int(l["metro"]) == 1 and int(l["cathedral"]) == 1, "one metro, one cathedral")
	ok(int(FacilityDB.DEFS["elevator"]["max_span"]) == 30,
		"a standard lift runs 30 floors")

func _placement() -> void:
	var t := Tower.new()
	ok(not t.check_place("office", 10, 1)["ok"], "nothing before a lobby")
	t.place("lobby", 40, 0, 60)
	ok(not t.check_place("shop", 45, 0)["ok"], "the ground floor is lobby only")
	ok(not t.check_place("office", 45, 3)["ok"], "no building in mid-air")
	ok(t.check_place("office", 45, 1)["ok"], "but straight above the lobby is fine")
	ok(t.check_place("condo", 41, -1)["ok"], "a basement hangs off the lobby")
	ok(not t.check_place("condo", 41, -2)["ok"], "but B2 needs B1 built first")
	ok(t.check_place("parking_ramp", 45, -1)["ok"], "a ramp may start under the lobby")
	ok(not t.check_place("hotel_single", 45, -1)["ok"], "no hotel rooms underground")
	ok(not t.check_place("metro", 45, 1)["ok"], "the metro is underground only")
	ok(not t.check_place("lobby", 40, 5)["ok"], "sky lobbies only every 15 floors")
	ok(t.check_place("lobby", 40, 14)["ok"] == false, "and only where there is a floor")
	# The cathedral goes on the roof and nowhere else.
	ok(not t.check_place("cathedral", 45, 1)["ok"], "the cathedral is not a ground-floor shop")

## Stairs and escalators lie ON the floor. The manual: "You can place stairs
## on floors occupied by any type of facility including hotel residences."
func _stairs_overlay() -> void:
	var t := Tower.new()
	t.place("lobby", 40, 0, 120)
	for r in range(1, 4):
		t.place("floor", 40, r, 120)
	for x in range(42, 140, 9):
		t.place("office", x, 1)
	ok(t.check_place("stairs", 44, 1)["ok"],
		"stairs may be laid up through a floor full of offices")
	var st := t.place("stairs", 44, 1)
	ok(st != null, "the stairs are placed")
	ok(t.facility_at(44, 1) != null and t.facility_at(44, 1).type == "office",
		"and the office they cross is still there")
	ok(t.transit_at(44, 1) != null and t.transit_at(44, 1).type == "stairs",
		"with the stairs on their own layer over it")
	ok(not t.check_place("stairs", 46, 1)["ok"], "but not two flights in one place")
	# A flight claims only the storey it climbs through, so another can be
	# stacked directly on top of it to carry on upwards.
	ok(t.check_place("stairs", 44, 2)["ok"], "and a flight may be stacked on a flight")
	t.place("stairs", 150, 1)
	ok(not t.check_place("office", 150, 1)["ok"], "and no room built into a flight")
	# A lift may not run through a staircase, nor a staircase through a lift.
	ok(not t.check_place("elevator", 45, 1)["ok"], "no elevator through the stairs")
	t.place_shaft("elevator", 200, 0, 2)
	ok(not t.check_place("stairs", 199, 0)["ok"], "and no stairs through an elevator")
	# The bulldozer takes the flight first, leaving what it crossed alone.
	var res := t.bulldoze(46, 1)
	ok(bool(res["ok"]) and int(res["id"]) == st.id, "the bulldozer removes the stairs")
	ok(t.facility_at(46, 1) != null, "and the office it crossed survives")

func _transport() -> void:
	ok(Shaft.is_sky_lobby_row(0), "the ground floor is a sky lobby")
	ok(Shaft.is_sky_lobby_row(14), "floor 15 is a sky lobby")
	ok(Shaft.is_sky_lobby_row(29), "floor 30 is a sky lobby")
	ok(Shaft.is_sky_lobby_row(89), "floor 90 is a sky lobby")
	ok(not Shaft.is_sky_lobby_row(20), "floor 21 is not")
	var s := Shaft.new(1, "express_elevator", 10, -3, 99)
	ok(s.serves_row(0) and s.serves_row(14) and s.serves_row(89),
		"an express lift stops at every sky lobby")
	ok(not s.serves_row(7), "and at nothing in between")
	ok(s.serves_row(-3), "but it does serve the basements")
	var n := Shaft.new(2, "elevator", 10, 0, 10)
	ok(n.serves_row(5), "a standard lift stops everywhere in its shaft")
	n.disabled_rows[5] = true
	ok(not n.serves_row(5), "unless you switch that floor off")
	ok(Rules.MAX_STAIR_FLIGHTS == 4, "nobody climbs more than four flights")
	_climb_limits()
	_floor_stays_in_one_piece()
	_shafts_stretch()
	_moon_holds_all_night()
	_one_rule_for_shafts()
	ok(Rules.SKY_LOBBY_EVERY == 15, "sky lobbies every fifteen floors")

## How far the legs alone will carry somebody. The manual gives two numbers
## for one journey -- four flights of stairs, seven escalator rides -- and both
## are checked by walking a tower rather than by reading the constant back.
## A storey stays in ONE PIECE. A new one is laid to the width its support can
## hold; after that the tool reaches out from the floor you have to where you
## pointed, so there is never a gap in the middle of a row.
func _floor_stays_in_one_piece() -> void:
	var g = load("res://scripts/core/game.gd").new()
	root.add_child(g)
	g.new_game()
	g.econ.funds = 100000000
	g.try_place("lobby", 40, 0, 100)

	# a brand new storey: the whole width the lobby holds up
	g.try_place("floor", 70, 1, 8)
	var run: Vector2i = g.tower.built_span(1)
	ok(run == Vector2i(40, 139), "a new storey is laid full width, got %s" % run)

	# now a storey above a PARTIAL one. Build floor 2 across half of floor 1,
	# by bulldozing floor 1 back first -- easier: put floor 2 down, then check
	# extending it.
	g.try_place("floor", 70, 2, 8)
	ok(g.tower.built_span(2) == Vector2i(40, 139), "and so is the next")

	# Cut a storey short so there is something to extend. Floor 3 is laid full
	# width; take the right half away again and it must grow back to order.
	g.try_place("floor", 70, 3, 8)
	for c in range(100, 140):
		g.tower.unbuild("floor", c, 3, 1)
	var short: Vector2i = g.tower.built_span(3)
	ok(short == Vector2i(40, 99), "a short storey, %s" % short)

	# click at 120: floor appears from where the storey ends to the click, and
	# nowhere else
	g.try_place("floor", 120, 3, 1)
	ok(g.tower.built_span(3) == Vector2i(40, 120),
		"the floor reaches out to the click, got %s" % g.tower.built_span(3))
	ok(g.tower.built(100, 3) and g.tower.built(120, 3), "filling the gap")
	ok(not g.tower.built(121, 3), "and stopping there, not at the far wall")

	# clicking inside what is already floor lays nothing
	var again: Dictionary = g.try_place("floor", 60, 3, 1)
	ok(not again.get("ok", false), "clicking existing floor does nothing")
	ok(g.tower.built_span(3) == Vector2i(40, 120), "and changes nothing")

	# and it may not reach past what holds it up
	g.try_place("floor", 135, 4, 1)
	ok(g.tower.built_span(4).x < 0, "no floor where nothing holds one up")

	# extending leftwards works the same way
	for c in range(40, 60):
		g.tower.unbuild("floor", c, 3, 1)
	g.try_place("floor", 45, 3, 1)
	ok(g.tower.built_span(3) == Vector2i(45, 120),
		"and reaches left as readily as right, got %s" % g.tower.built_span(3))

## Dragging a shaft taller and shorter again. The finger tool that used to be
## the only way in is gone; this is the operation behind the drag.
func _shafts_stretch() -> void:
	var g = load("res://scripts/core/game.gd").new()
	root.add_child(g)
	g.new_game()
	g.econ.funds = 100000000     # this one builds a whole tower to climb
	g.try_place("lobby", 40, 0, 100)
	for r in range(1, 14):
		g.try_place("floor", 70, r, 8)
	g.try_place("elevator", 60, 0, 0)
	var s = g.tower.shaft_at(60, 0)
	ok(s != null, "a shaft goes up")
	ok(g.tower.resize_shaft(s, s.bottom_row, 9) == "", "and can be dragged taller")
	ok(s.top_row == 9, "the top follows the pointer")
	ok(g.tower.shaft_at(60, 9) != null, "and the new rows are shaft")
	ok(g.tower.resize_shaft(s, s.bottom_row, 4) == "", "and dragged shorter again")
	ok(g.tower.shaft_at(60, 9) == null, "the rows it gave up are free")
	# past the top of the building there is nothing to run through
	ok(g.tower.resize_shaft(s, s.bottom_row, 40) != "", "but not past the top floor")
	ok(g.tower.resize_shaft(s, s.bottom_row, 200) != "", "nor past its own reach")

	# The whole point: a shaft runs THROUGH the building, not around it. Fill
	# every storey it wants with offices and it must still go up.
	for r in range(1, 12):
		for c in range(80, 130, 12):
			g.try_place("office", c, r, -1)
	var offices: int = g.tower.all_of_type("office").size()
	ok(offices > 20, "the floors above are full, %d offices" % offices)
	ok(g.tower.resize_shaft(s, s.bottom_row, 11) == "",
		"and the lift passes over every one of them")
	ok(s.top_row == 11, "reaching the top floor")
	ok(g.tower.all_of_type("office").size() == offices,
		"without demolishing a single tenant")

	# What it may not cross is another vertical thing. A flight of stairs is
	# laid across the storey above it, in the shaft's own column.
	g.try_place("stairs", 58, 12, -1)
	ok(g.tower.transit_id_at(60, 12) != -1, "a staircase crosses floor 12")
	var over_stairs: String = g.tower.resize_shaft(s, s.bottom_row, 12)
	ok(over_stairs != "", "but never a staircase: " + over_stairs)
	ok(s.top_row == 11, "and it stays where it was")

	# A second lift, in a column full of offices, is fine.
	var put: Dictionary = g.try_place("elevator", 100, 0, 0)
	var s2 = g.tower.shaft_at(100, 0)
	ok(s2 != null, "a second lift goes in, in a column of offices (%s)"
		% String(put.get("reason", "")))
	ok(s2 != null and g.tower.resize_shaft(s2, s2.bottom_row, 6) == "",
		"and climbs its own column of offices")
	# but not through the first one
	ok(g.tower.resize_shaft(s, s.bottom_row, 5) == "", "the first shrinks back")
	var s3 = g.tower.shaft_at(100, 0)
	ok(s3 != null, "still there")

	# And a room may not be built under a lift, for the reason stairs may not:
	# it would be a room nobody could see.
	var under: Dictionary = g.tower.check_place("office", s.seg, 5, -1)
	ok(not under.ok, "no room under a lift")
	ok(under.reason.contains("elevator"), "and it says which: " + under.reason)

## One night, one moon.
func _moon_holds_all_night() -> void:
	var g = load("res://scripts/core/game.gd").new()
	root.add_child(g)
	g.new_game()
	var view = load("res://scripts/render/tower_view.gd")
	g.clock.day_in_quarter = 5
	g.clock.minute = 22.0 * 60.0
	var evening: float = view.moon_phase(g.clock)
	g.clock.minute = 2.0 * 60.0
	g.clock.day_in_quarter = 6
	ok(is_equal_approx(view.moon_phase(g.clock), evening),
		"the moon keeps one face from dusk to dawn")
	g.clock.minute = 13.0 * 60.0
	ok(not is_equal_approx(view.moon_phase(g.clock), evening),
		"and turns over in the afternoon, when nobody is looking")

## One rule, in one place. The lift refused to cross an office for a week
## because game.gd tested range_free itself instead of asking the tower -- so
## the tower's rule was right and nothing read it. A second copy of a rule is
## a rule that will be half-fixed.
func _one_rule_for_shafts() -> void:
	var f := FileAccess.open("res://scripts/core/game.gd", FileAccess.READ)
	ok(f != null, "game.gd is readable")
	if f == null:
		return
	var src := f.get_as_text()
	var at := src.find("func _place_shaft")
	var end := src.find("
func ", at + 10)
	var body := src.substr(at, end - at)
	# Read the code, not the comments -- the paragraph above _place_shaft
	# explaining what it must not do would otherwise fail this on its own.
	var code := ""
	for line in body.split("
"):
		var t2 := String(line).strip_edges()
		if t2.begins_with("#"):
			continue
		code += t2 + "
"
	ok(not code.contains("range_free"),
		"placing a shaft asks tower.shaft_blocked, never range_free itself")

func _climb_limits() -> void:
	var t := Tower.new()
	var r := Router.new(t)
	t.place("lobby", 40, 0, 60)
	for row in range(1, 12):
		t.place("floor", 40, row, 60)
	for row in range(0, 11):
		t.place("stairs", 44, row)
	ok(not r.find(0, 60.0, 4, 60.0).is_empty(),
		"four flights up from the lobby is walkable")
	ok(r.find(0, 60.0, 5, 60.0).is_empty(),
		"the fifth is not, so a stair-only tower stops at four floors")

	var t2 := Tower.new()
	var r2 := Router.new(t2)
	t2.place("lobby", 40, 0, 60)
	for row in range(1, 12):
		t2.place("floor", 40, row, 60)
	for row in range(0, 11):
		t2.place("escalator", 44, row)
	ok(not r2.find(0, 60.0, 7, 60.0).is_empty(),
		"seven escalator rides is walkable")
	ok(r2.find(0, 60.0, 8, 60.0).is_empty(),
		"the eighth is not")

func _economy() -> void:
	var e := Economy.new()
	e.spend_construction(40000)
	ok(e.funds == 2000000 - 40000, "construction comes out of the fund")
	ok(e.construction == 40000, "and shows on the balance sheet")
	e.earn("office", 10000)
	ok(int(e.income["office"]) == 10000, "rent goes to its own line")
	ok(e.net_revenue() == 10000 - 40000, "net revenue nets off")
	ok(Economy.money(1234567) == "$1,234,567", "money reads with commas")
	ok(Economy.money(-500) == "-$500", "and negatives keep their sign")
	# Fast food takings follow the customer count.
	var f := Facility.new(1, "fastfood", 0, 1)
	f.patrons_today = 10
	ok(f.food_takings() == -3000, "a quiet day loses money")
	f.patrons_today = 22
	ok(f.food_takings() == 2000, "a fair day makes a little")
	f.patrons_today = 30
	ok(f.food_takings() == 3000, "a good day makes more")
	ok(f.patron_rating() == Rules.Eval.A, "30 customers is an A")
	f.patrons_today = 20
	ok(f.patron_rating() == Rules.Eval.B, "20 is a B")
	f.patrons_today = 12
	ok(f.patron_rating() == Rules.Eval.C, "12 is a C")

## Anything built in the morning is taken the same day, if the tower has
## earned it. This used to happen only at three the following morning, so a
## floor of offices you had just paid for sat empty for the rest of the day.
func _letting_timing() -> void:
	# NB: the autoload's global name "Game" does not exist while a --script
	# SceneTree is being compiled, so constants are read off the instance.
	var g = load("res://scripts/core/game.gd").new()
	root.add_child(g)
	g.new_game()
	g.stars = 5
	ok(int(g.CONDO_SALE_TO) <= 12 * 60, "flats are viewed before midday")

	g.try_place("lobby", 40, 0, 120)
	g.try_place("floor", 40, 1, 120)
	g.try_place("floor", 40, 2, 120)
	g.try_place("stairs", 44, 0)
	g.try_place("stairs", 44, 1)

	# Eight o'clock: put up offices, flats, a hotel room and a security office.
	g.clock.minute = 8.0 * 60.0
	g.clock._last_int_minute = int(g.clock.minute)
	for x in range(52, 124, 9):
		g.try_place("office", x, 1)
	g.try_place("security", 130, 1)
	for x in range(52, 100, 16):
		g.try_place("condo", x, 2)
	g.try_place("hotel_twin", 110, 2)

	var sec: Facility = g.tower.all_of_type("security")[0]
	ok(not sec.occupants.is_empty(), "the guards are on duty the moment you pay")

	_run_to(g, 8 * 60 + 50)
	ok(_sold(g) == 0, "no flat is sold before the morning viewing")
	_run_to(g, 12 * 60)
	ok(_vacant(g, FacilityDB.Kind.OFFICE) == 0,
		"every office built at eight is let by noon, %d still empty"
		% _vacant(g, FacilityDB.Kind.OFFICE))
	ok(_sold(g) > 0, "and the flats have been viewed and sold")

	# An office put up in the afternoon waits for tomorrow morning: letting is
	# a morning business and stops at noon.
	g.try_place("office", 148, 1)
	var late: Facility = null
	for f in g.tower.all_of_kind(FacilityDB.Kind.OFFICE):
		if f.seg == 148:
			late = f
	ok(late != null, "the afternoon office was built")
	_run_to(g, 17 * 60)
	ok(late == null or late.occupants.is_empty(),
		"nothing is let after noon, however good the tower is")

	# Guests are booked in anywhere between six and ten, so the assertion has
	# to sit after the last of them could arrive. Checking at nine passed most
	# runs and failed the ones where the dice came up late.
	_run_to(g, 23 * 60 + 30)
	var room: Facility = g.tower.all_of_type("hotel_twin")[0]
	ok(not room.occupants.is_empty(), "a room built today still takes guests tonight")

	# And the tower stops letting once word gets round.
	for f in g.tower.all_of_kind(FacilityDB.Kind.OFFICE):
		f.eval = Rules.Eval.C
	ok(not g._letting_allowed(FacilityDB.Kind.OFFICE),
		"nothing new lets while the offices are all in crisis")

func _run_to(g, minute_of_day: int) -> void:
	var guard := 0
	while g.clock.minute_of_day() < minute_of_day and guard < 60000:
		g._process(0.2)
		guard += 1

func _sold(g) -> int:
	var n := 0
	for f in g.tower.all_of_kind(FacilityDB.Kind.CONDO):
		if f.sold:
			n += 1
	return n

func _vacant(g, kind: int) -> int:
	var n := 0
	for f in g.tower.all_of_kind(kind):
		if f.occupants.is_empty():
			n += 1
	return n

func _save_load() -> void:
	var g = load("res://scripts/core/game.gd").new()
	root.add_child(g)
	g.new_game()
	# Build through the game's own API, the way the tool bar does.
	ok(g.try_place("lobby", 50, 0, 80)["ok"], "the lobby goes down")
	ok(g.try_place("office", 52, 1)["ok"], "and an office on top of it")
	ok(not g.try_place("hotel_single", 52, 2)["ok"],
		"but hotel rooms are locked at one star")
	var before_funds: int = g.econ.funds
	ok(not g.try_place("office", 52, 1)["ok"], "you cannot build on an office")
	ok(g.econ.funds == before_funds, "and a refused build costs nothing")
	ok(not g.try_place("elevator", 70, 0, -1, 4)["ok"],
		"a shaft cannot run through floors that do not exist yet")
	for r in range(1, 5):
		g.try_place("floor", 50, r, 80)
	g.try_place("elevator", 70, 0, -1, 4)
	ok(g.tower.shafts.size() == 1, "a dragged lift makes one shaft")
	var sh: Shaft = g.tower.shafts.values()[0]
	ok(sh.bottom_row == 0 and sh.top_row == 4, "spanning the floors you dragged over")
	g.try_place("elevator", 70, 2)
	ok(sh.cars.size() == 2, "clicking the shaft again adds a car")

	var path := "user://test_save.json"
	g.save_game(path)
	var pop_before: int = g.tower.population()
	var facs: int = g.tower.facilities.size()
	ok(g.load_game(path), "the game loads back")
	ok(g.tower.facilities.size() == facs, "with all its facilities")
	ok(g.tower.shafts.size() == 1, "and its shafts")
	ok(g.tower.lobby_width() == 80, "and the lobby it had")
	var reloaded: Shaft = g.tower.shafts.values()[0]
	ok(reloaded.cars.size() == 2, "and both cars")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if pop_before < 0:
		pass
