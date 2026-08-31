extends SceneTree

## A small tower, one lift, and a row of offices marching away from it.
##
## Prints how far each office is from the nearest transport and whether it ever
## found a tenant. Everything past Rules.MAX_WALK_TO_TRANSPORT should still be
## empty at the end of the run, however long the run is.
##
##   Godot_v4.7-...console.exe --headless --path . --script res://tools/reach_probe.gd

const SHAFT_SEG := 40

func _initialize() -> void:
	var g = load("res://scripts/core/game.gd").new()
	get_root().add_child(g)
	g.new_game()
	g.econ.funds = 100000000
	g.stars = 5

	g.try_place("lobby", 20, 0, 220)
	g.try_place("floor", 100, 1, 1)
	g.try_place("floor", 100, 2, 1)
	g.try_place("elevator", SHAFT_SEG, 0, -1, 2)

	var offices := []
	var c := SHAFT_SEG + 4
	while c + 8 <= 239:
		var f = g.tower.place("office", c, 1)
		if f != null:
			offices.append(f)
		c += 9
	print("small tower: lobby 20..239, one standard lift at %d, %d offices on floor 1"
		% [SHAFT_SEG, offices.size()])
	print("walking limit is %d segments" % Rules.MAX_WALK_TO_TRANSPORT)

	# Give it every chance: forty letting rounds is far more than a game day.
	for i in range(40):
		g._letting_round(10 * 60)
		g._rest_period()

	print("")
	print(" office at | gap to lift | let?")
	var let_far := 0
	var empty_near := 0
	for f in offices:
		var gap: int = g.tower.transport_distance(f.seg, f.w, f.row)
		var taken: bool = not f.occupants.is_empty()
		var mark := "yes" if taken else "NO"
		print("%9d | %11d | %s%s" % [f.seg, gap, mark,
			"   <-- limit" if gap > Rules.MAX_WALK_TO_TRANSPORT
				and gap - 9 <= Rules.MAX_WALK_TO_TRANSPORT else ""])
		if gap > Rules.MAX_WALK_TO_TRANSPORT and taken:
			let_far += 1
		if gap <= Rules.MAX_WALK_TO_TRANSPORT and not taken:
			empty_near += 1
	print("")
	print("%d let beyond the limit (want 0), %d empty inside it (want 0)"
		% [let_far, empty_near])

	# Now put a staircase at the far end and watch the dead wing come to life.
	g.try_place("stairs", 200, 1, -1)
	for i in range(40):
		g._letting_round(10 * 60)
	var revived := 0
	for f in offices:
		if not f.occupants.is_empty():
			revived += 1
	print("after a staircase at 200: %d of %d offices let" % [revived, offices.size()])
	quit()
