extends SceneTree

## Watches a day of traffic in a demonstration tower and prints what the
## simulation is actually doing hour by hour: who is walking, who is queueing
## for a lift, who is aboard one, and how stressed everybody is.

func _initialize() -> void:
	var g = load("res://scripts/core/game.gd").new()
	root.add_child(g)
	g.new_game()
	var t: Tower = g.tower
	t.place("lobby", 120, 0, 140)
	for r in range(1, 9):
		t.place("floor", 122, r, 136)
	var x := 124
	while x < 250:
		for r in [1, 2, 6, 7]:
			t.place("office", x, r)
		x += 9
	t.place("fastfood", 124, 3)
	t.place("fastfood", 141, 3)
	t.place("restaurant", 175, 3)
	t.place("shop", 160, 3)
	var s := t.place_shaft("elevator", 200, 0, 8)
	s.add_car(3)
	s.add_car(6)
	t.place("stairs", 256, 0)
	t.place("stairs", 256, 1)
	g.stars = 3
	g._rest_period()
	print("population after leasing: ", t.population())
	print("offices leased: ", _leased(t))

	g.clock.minute = 0.0
	g.clock._last_int_minute = 0
	g.engine.plan_day(false, 0)
	print("trips planned today: ", g.engine.trips_today)

	var last_hour := -1
	var steps := 0
	while g.clock.minute < 24.0 * 60.0 and steps < 60000:
		g._process(0.05)
		steps += 1
		var h: int = g.clock.hour()
		if h != last_hour:
			last_hour = h
			_report(g, h)
	print("stranded today: ", g.engine.stranded_today)
	var pat := ""
	for f in t.all_of_kind(FacilityDB.Kind.FOOD):
		pat += "%s@%s=%d  " % [f.type, FacilityDB.row_label(f.row), f.patrons_today]
	print("patrons: ", pat)
	quit()

func _leased(t: Tower) -> int:
	var n := 0
	for f in t.all_of_type("office"):
		if not f.occupants.is_empty():
			n += 1
	return n

func _report(g, h: int) -> void:
	var walking := 0
	var waiting := 0
	var riding := 0
	var resting := 0
	var outside := 0
	var stress := 0.0
	for id in g.engine.sims:
		var s: Sim = g.engine.sims[id]
		stress += s.stress
		match s.state:
			Sim.State.WALKING, Sim.State.STAIRS: walking += 1
			Sim.State.WAITING: waiting += 1
			Sim.State.RIDING: riding += 1
			Sim.State.RESTING: resting += 1
			_: outside += 1
	var n: int = maxi(g.engine.sims.size(), 1)
	var pat := 0
	for f in g.tower.all_of_kind(FacilityDB.Kind.FOOD):
		pat += f.patrons_today
	var shp := 0
	for f in g.tower.all_of_kind(FacilityDB.Kind.SHOP):
		shp += f.patrons_today
	print("%02d:00  walking %4d  queueing %4d  riding %4d  at rest %4d  outside %4d  stress %5.1f  meals %3d  shoppers %3d"
		% [h, walking, waiting, riding, resting, outside, stress / float(n), pat, shp])
