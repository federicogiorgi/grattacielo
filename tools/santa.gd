extends SceneTree

## The Christmas easter egg, checked on its own because it only happens for a
## few minutes once a year and is very easy to break without noticing.
##
## In the original, on the last night of the fourth quarter a red dot crosses
## the map; centre on it and Santa is there in his sleigh, and clicking on him
## pays out. Same here.

var failures := 0

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)

func _initialize() -> void:
	print("--- Santa Claus ---")
	var g = load("res://scripts/core/game.gd").new()
	root.add_child(g)
	g.new_game()
	g.tower.place("lobby", 100, 0, 60)
	for r in range(1, 6):
		g.tower.place("floor", 100, r, 60)

	# Nowhere near Christmas: nothing in the sky.
	g.clock.quarter = 2
	g.clock.day_in_quarter = 2
	g.clock.minute = 21.0 * 60.0 + 5.0
	g.clock._last_int_minute = int(g.clock.minute)
	g.events.update_santa(g.clock, 0.1)
	_ok(not g.events.santa_active, "no Santa in the second quarter")

	# The last quarter, but not the last day of it: still nothing.
	g.clock.quarter = 4
	g.clock.day_in_quarter = 0
	g.events.update_santa(g.clock, 0.1)
	_ok(not g.events.santa_active, "no Santa on the first day of the fourth quarter")

	# The last day of the fourth quarter, but the middle of the afternoon.
	g.clock.day_in_quarter = Rules.DAYS_PER_QUARTER - 1
	g.clock.minute = 15.0 * 60.0
	g.clock._last_int_minute = int(g.clock.minute)
	g.events.update_santa(g.clock, 0.1)
	_ok(not g.events.santa_active, "no Santa in the afternoon")

	# The last night of the last quarter, at nine o'clock. There he is.
	g.clock.minute = float(Rules.SANTA_HOUR) * 60.0 + 3.0
	g.clock._last_int_minute = int(g.clock.minute)
	_ok(g.clock.is_last_night_of_year(), "the clock agrees it is the last night")
	g.events.update_santa(g.clock, 0.1)
	_ok(g.events.santa_active, "Santa appears on the last night of the year")
	_ok(g.events.santa_row() > g.tower.top_built_row,
		"he flies above the tower, not through it")

	var start_x: float = g.events.santa_x
	for i in range(20):
		g.events.update_santa(g.clock, 1.0)
	# West to east: the reindeer are drawn ahead of the sleigh, so travelling
	# the other way had the team pushing him backwards across the sky.
	_ok(g.events.santa_x > start_x, "the sleigh travels east across the sky")

	# Clicking on him pays out, once.
	var before: int = g.econ.funds
	g.claim_santa()
	_ok(g.econ.funds == before + Rules.SANTA_GIFT,
		"the present is worth %s" % Economy.money(Rules.SANTA_GIFT))
	g.claim_santa()
	_ok(g.econ.funds == before + Rules.SANTA_GIFT, "and you only get it once")

	# He leaves, and does not come back the same year.
	for i in range(400):
		g.events.update_santa(g.clock, 2.0)
	_ok(not g.events.santa_active, "he flies off the edge of the map")
	g.events.update_santa(g.clock, 0.1)
	_ok(not g.events.santa_active, "and does not come round again this year")

	# And he is gone by morning even if the clock is racing.
	g.events.santa_active = true
	g.events.santa_x = 100.0
	g.clock.minute = 9.0 * 60.0
	g.events.update_santa(g.clock, 1.0)
	_ok(not g.events.santa_active, "and he never flies in daylight")
	g.clock.minute = float(Rules.SANTA_HOUR) * 60.0 + 3.0

	# Next year he does.
	g.clock.year += 1
	g.events.update_santa(g.clock, 0.1)
	_ok(g.events.santa_active, "but he does come back next Christmas")

	print("--- %d failure(s) ---" % failures)
	quit(1 if failures > 0 else 0)
