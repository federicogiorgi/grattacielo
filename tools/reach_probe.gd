extends SceneTree

## How many offices can ONE standard elevator actually serve, and does it
## matter how far along the floor they are?
##
## Nothing in the rules caps lateral distance -- the manual calls width a
## "strategic factor", not a limit -- so the answer has to be measured.
##
##   Godot_v4.7-...console.exe --headless --path . --script res://tools/reach_probe.gd

const SHAFT_SEG := 180
const FLOORS := 8

func _initialize() -> void:
	print("offices | cars | peak stress | red (>120) | by distance from the shaft")
	for cfg in [[2, 1], [4, 1], [8, 1], [16, 1], [16, 4], [16, 8], [32, 8], [64, 8]]:
		_run(int(cfg[0]), int(cfg[1]))
	quit()

func _run(per_floor: int, cars: int) -> void:
	var g = load("res://scripts/core/game.gd").new()
	get_root().add_child(g)
	g.new_game()
	g.econ.funds = 999000000
	g.stars = 5
	g.try_place("lobby", 5, 0, 365)
	for r in range(1, FLOORS + 1):
		g.try_place("floor", 100, r, 1)
	g.try_place("elevator", SHAFT_SEG, 0, -1, FLOORS)
	var s: Shaft = g.tower.shaft_at(SHAFT_SEG, 0)
	while s.cars.size() < cars:
		s.add_car(0)

	# offices spread outwards from the shaft, alternating sides, so every
	# count is as evenly balanced as it can be
	var offices := 0
	for r in range(1, FLOORS + 1):
		var right := SHAFT_SEG + 4
		var left := SHAFT_SEG - 9
		for i in range(per_floor):
			var seg := right if i % 2 == 0 else left
			if g.try_place("office", seg, r)["ok"]:
				offices += 1
			if i % 2 == 0:
				right += 9
			else:
				left -= 9
	for i in range(40):
		g._rest_period()
		g._letting_round(10 * 60)

	g.clock.minute = 5.0 * 60.0
	g.clock._last_int_minute = int(g.clock.minute)
	for d in range(3):
		_day(g)
	while g.clock.is_weekend():
		_day(g)

	g.engine.plan_day(false, g.clock.day_in_quarter)
	var peak := {}
	var guard := 0
	while guard < 400000 and g.clock.minute_of_day() < 9 * 60 + 30:
		g._process(0.05)
		guard += 1
		for sid in g.engine.sims:
			peak[sid] = maxf(float(peak.get(sid, 0.0)), g.engine.sims[sid].stress)

	var near := 0.0
	var near_n := 0
	var far := 0.0
	var far_n := 0
	var worst := 0.0
	var red := 0
	for fid in g.tower.facilities:
		var f: Facility = g.tower.facilities[fid]
		if f.type != "office" or f.occupants.is_empty():
			continue
		var st := 0.0
		for pid in f.occupants:
			var v := float(peak.get(pid, 0.0))
			st += v
			if v > Rules.STRESS_RED:
				red += 1
		st /= float(f.occupants.size())
		worst = maxf(worst, st)
		if absi(f.seg - SHAFT_SEG) <= 40:
			near += st
			near_n += 1
		else:
			far += st
			far_n += 1
	var people := 0
	for sid in g.engine.sims:
		people += 1
	print("%7d | %4d | %11.1f | %4d of %4d | near %.0f  far %.0f"
		% [offices, cars, worst, red, people,
			near / maxf(float(near_n), 1.0), far / maxf(float(far_n), 1.0)])
	g.queue_free()

func _day(g) -> void:
	g.engine.plan_day(g.clock.is_weekend(), g.clock.day_in_quarter)
	var guard := 0
	var start: int = g.clock.day_in_quarter
	while guard < 400000 and g.clock.day_in_quarter == start:
		g._process(0.05)
		guard += 1
