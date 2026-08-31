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
	_condo_timing()
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
	ok(t.check_place("stairs", 44, 0)["ok"],
		"stairs may be laid up through a floor full of offices")
	var st := t.place("stairs", 44, 0)
	ok(st != null, "the stairs are placed")
	ok(t.facility_at(44, 1) != null and t.facility_at(44, 1).type == "office",
		"and the office underneath them is still there")
	ok(t.transit_at(44, 1) != null and t.transit_at(44, 1).type == "stairs",
		"with the stairs on their own layer above it")
	ok(not t.check_place("stairs", 46, 0)["ok"], "but not two flights in one place")
	# A second flight where no office stands, to show a room cannot then be
	# built into it. (Row 2 is free of the first flight, which only spans 0-1.)
	t.place("stairs", 150, 0)
	ok(not t.check_place("office", 150, 1)["ok"], "and no room built into a flight")
	# A lift may not run through a staircase, nor a staircase through a lift.
	ok(not t.check_place("elevator", 45, 0)["ok"], "no elevator through the stairs")
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
	ok(Rules.SKY_LOBBY_EVERY == 15, "sky lobbies every fifteen floors")

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

## Flats are bought in the late morning. They used to be bought at three in
## the morning along with everything else, which meant the one move-in the
## player might actually watch happened while the tower was asleep.
func _condo_timing() -> void:
	# NB: the autoload's global name "Game" does not exist while a --script
	# SceneTree is being compiled, so the constant is read off the instance.
	var g = load("res://scripts/core/game.gd").new()
	root.add_child(g)
	g.new_game()
	ok(int(g.CONDO_SALE_MINUTE) < 12 * 60, "flats are sold before midday")
	g.tower.place("lobby", 40, 0, 120)
	g.tower.place("floor", 40, 1, 120)
	g.tower.place("stairs", 44, 0)
	for x in range(60, 130, 16):
		g.tower.place("condo", x, 1)
	g.clock.minute = 0.0
	g.clock._last_int_minute = 0
	_run_to(g, 9 * 60)
	ok(_sold(g) == 0, "nothing is sold overnight, got %d" % _sold(g))
	_run_to(g, 11 * 60 + 30)
	ok(_sold(g) > 0, "and the morning viewing sells some")

func _run_to(g, minute_of_day: int) -> void:
	var guard := 0
	while g.clock.minute_of_day() < minute_of_day and guard < 40000:
		g._process(0.2)
		guard += 1

func _sold(g) -> int:
	var n := 0
	for f in g.tower.all_of_kind(FacilityDB.Kind.CONDO):
		if f.sold:
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
