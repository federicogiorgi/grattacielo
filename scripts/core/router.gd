extends RefCounted
class_name Router

## Works out how a person gets from one place in the tower to another.
##
## Dijkstra over two sorts of node: standing on a floor at a segment, and
## being inside a car of a particular shaft. Boarding a shaft costs the
## expected wait, which is where congestion enters the routing -- a busy shaft
## genuinely looks worse to the next traveller, exactly as it should.
##
## Routes are cached per origin/destination row-and-segment pair and thrown
## away whenever the building changes shape.

const LEG_WALK := 0
const LEG_STAIRS := 1
const LEG_ESCALATOR := 2
const LEG_ELEVATOR := 3

const NO_ROUTE := []
const MAX_EXPANSIONS := 6000

var tower: Tower
var _cache: Dictionary = {}
var _cache_hits: int = 0
var _cache_misses: int = 0

func _init(p_tower: Tower) -> void:
	tower = p_tower
	tower.structure_changed.connect(clear_cache)

func clear_cache() -> void:
	_cache.clear()

## Returns an Array of legs, or an empty Array if there is no way through.
## Each leg is a Dictionary; see the LEG_* constants for "t".
func find(from_row: int, from_seg: float, to_row: int, to_seg: float,
		staff: bool = false) -> Array:
	if from_row == to_row:
		return [_walk_leg(from_row, from_seg, to_seg)]
	var key := "%d:%d:%d:%d:%d" % [from_row, int(from_seg), to_row, int(to_seg),
		1 if staff else 0]
	if _cache.has(key):
		_cache_hits += 1
		var cached: Array = _cache[key]
		return cached.duplicate(true)
	_cache_misses += 1
	var r := _search(from_row, from_seg, to_row, to_seg, staff, true)
	if r.is_empty():
		# Try again refusing stairs, in case the only route was an absurd climb.
		r = _search(from_row, from_seg, to_row, to_seg, staff, false)
	_cache[key] = r
	return r.duplicate(true)

func _walk_leg(row: int, a: float, b: float) -> Dictionary:
	return {
		"t": LEG_WALK, "row": row, "from": a, "to": b,
		"min": absf(b - a) / Rules.WALK_SEGMENTS_PER_MIN,
	}

# --- the search ------------------------------------------------------------
#
# State key packs: kind (0 floor / 1 shaft), row, seg-or-shaft-id, layer.

func _skey(kind: int, row: int, ident: int, layer: int) -> int:
	return ((kind * 200 + (row + 20)) * 100000 + ident) * 4 + layer

func _search(from_row: int, from_seg: float, to_row: int, to_seg: float,
		staff: bool, allow_stairs: bool) -> Array:
	var start_seg := int(round(from_seg))
	var goal_seg := int(round(to_seg))

	var dist: Dictionary = {}
	var prev: Dictionary = {}
	var stairs_used: Dictionary = {}
	var heap := _Heap.new()

	var start := _skey(0, from_row, start_seg, 0)
	dist[start] = 0.0
	stairs_used[start] = 0
	heap.push(0.0, start, {"kind": 0, "row": from_row, "ident": start_seg, "layer": 0})

	var best_goal := -1
	var expansions := 0

	while not heap.is_empty():
		var top: Array = heap.pop()
		var d: float = top[0]
		var k: int = top[1]
		var node: Dictionary = top[2]
		if d > float(dist.get(k, INF)) + 0.0001:
			continue
		expansions += 1
		if expansions > MAX_EXPANSIONS:
			break
		if node.kind == 0 and node.row == to_row:
			# Reached the destination floor; walk the rest.
			best_goal = k
			break

		for e in _edges(node, staff, allow_stairs):
			var nk: int = e["key"]
			var nd: float = d + float(e["cost"])
			var su: int = int(stairs_used.get(k, 0)) + int(e.get("stairs", 0))
			if su > Rules.MAX_STAIR_FLIGHTS:
				continue
			if nd < float(dist.get(nk, INF)):
				dist[nk] = nd
				prev[nk] = {"from": k, "edge": e}
				stairs_used[nk] = su
				heap.push(nd, nk, e["node"])

	if best_goal == -1:
		return []

	# Walk the chain back into legs.
	var chain := []
	var cur := best_goal
	while prev.has(cur):
		var step: Dictionary = prev[cur]
		chain.push_front(step["edge"])
		cur = step["from"]
	var legs := _legs_from_chain(chain, from_row, from_seg)
	# Final walk along the destination floor.
	var arrive_seg := float(start_seg)
	if not legs.is_empty():
		var last: Dictionary = legs[legs.size() - 1]
		arrive_seg = float(last.get("to_seg", last.get("to", arrive_seg)))
	if absf(arrive_seg - to_seg) > 0.5:
		legs.append(_walk_leg(to_row, arrive_seg, to_seg))
	return legs

func _legs_from_chain(chain: Array, from_row: int, from_seg: float) -> Array:
	var legs := []
	var cur_row := from_row
	var cur_seg := from_seg
	var pending_board := {}
	for e in chain:
		match int(e.get("leg", -1)):
			LEG_WALK:
				var t := float(e["to_seg"])
				if absf(t - cur_seg) > 0.5:
					legs.append(_walk_leg(cur_row, cur_seg, t))
				cur_seg = t
			LEG_STAIRS, LEG_ESCALATOR:
				var seg := float(e["at_seg"])
				if absf(seg - cur_seg) > 0.5:
					legs.append(_walk_leg(cur_row, cur_seg, seg))
					cur_seg = seg
				var is_esc := int(e["leg"]) == LEG_ESCALATOR
				legs.append({
					"t": LEG_ESCALATOR if is_esc else LEG_STAIRS,
					"id": e["id"], "from_row": cur_row, "to_row": int(e["to_row"]),
					"seg": seg, "to_seg": seg,
					"min": Rules.ESCALATOR_MINUTES if is_esc else Rules.STAIR_MINUTES,
				})
				cur_row = int(e["to_row"])
			LEG_ELEVATOR:
				# Boarding is recorded; riding rows collapse into one leg.
				if e.get("board", false):
					var seg2 := float(e["at_seg"])
					if absf(seg2 - cur_seg) > 0.5:
						legs.append(_walk_leg(cur_row, cur_seg, seg2))
						cur_seg = seg2
					pending_board = {"shaft": int(e["shaft"]), "from_row": cur_row,
						"seg": seg2}
				elif e.get("alight", false):
					if not pending_board.is_empty():
						legs.append({
							"t": LEG_ELEVATOR, "shaft": pending_board["shaft"],
							"from_row": pending_board["from_row"],
							"to_row": int(e["to_row"]),
							"seg": pending_board["seg"],
							"to_seg": pending_board["seg"],
							"min": 0.0,
						})
						cur_row = int(e["to_row"])
						cur_seg = float(pending_board["seg"])
						pending_board = {}
	return legs

func _edges(node: Dictionary, staff: bool, allow_stairs: bool) -> Array:
	var out := []
	if node.kind == 0:
		var row: int = node.row
		var here: int = node.ident
		var layer: int = node.layer
		for t in tower.transports_on_row(row):
			var tseg: int = int(t["seg"])
			var walk := absf(float(tseg - here)) / Rules.WALK_SEGMENTS_PER_MIN
			if t.has("shaft"):
				if layer >= 2:
					continue
				var s: Shaft = tower.shafts.get(int(t["id"]))
				if s == null:
					continue
				if s.is_service() != staff:
					continue
				var wait := _expected_wait(s)
				out.append({
					"key": _skey(1, row, s.id, layer + 1),
					"cost": walk + wait,
					"leg": LEG_ELEVATOR, "board": true, "shaft": s.id, "at_seg": tseg,
					"node": {"kind": 1, "row": row, "ident": s.id, "layer": layer + 1},
				})
			else:
				var is_esc: bool = String(t["kind"]) == "escalator"
				if not allow_stairs and not is_esc:
					continue
				if staff and is_esc:
					continue
				var to_row: int = int(t["to"])
				var ride: float = Rules.ESCALATOR_MINUTES if is_esc else Rules.STAIR_MINUTES
				out.append({
					"key": _skey(0, to_row, tseg, layer),
					"cost": walk + ride,
					"leg": LEG_ESCALATOR if is_esc else LEG_STAIRS,
					"id": int(t["id"]), "at_seg": tseg, "to_row": to_row,
					"stairs": 0 if is_esc else 1,
					"node": {"kind": 0, "row": to_row, "ident": tseg, "layer": layer},
				})
	else:
		# Inside a car: ride to the next served floor either way, or get out.
		var s: Shaft = tower.shafts.get(node.ident)
		if s == null:
			return out
		var row: int = node.row
		var layer: int = node.layer
		out.append({
			"key": _skey(0, row, s.seg, layer),
			"cost": Rules.ELEVATOR_DOOR_MINUTES,
			"leg": LEG_ELEVATOR, "alight": true, "to_row": row, "shaft": s.id,
			"node": {"kind": 0, "row": row, "ident": s.seg, "layer": layer},
		})
		var speed := s.speed_floors_per_min()
		for step in [1, -1]:
			var r: int = row + int(step)
			while s.covers_row(r):
				if s.serves_row(r):
					out.append({
						"key": _skey(1, r, s.id, layer),
						"cost": absf(float(r - row)) / speed + Rules.ELEVATOR_DOOR_MINUTES,
						"leg": LEG_ELEVATOR, "ride": true, "to_row": r, "shaft": s.id,
						"node": {"kind": 1, "row": r, "ident": s.id, "layer": layer},
					})
					break
				r += step
	return out

## How long a traveller should expect to wait for this shaft, in game minutes.
func _expected_wait(s: Shaft) -> float:
	var cars := maxi(1, s.cars.size())
	var span := maxi(1, s.span())
	var base := float(span) / (s.speed_floors_per_min() * float(cars)) * 0.9 + 0.4
	var queued := s.total_waiting()
	var seats := cars * s.car_capacity()
	if queued > 0:
		base += float(queued) / float(seats) * 1.8
	return base

# --- a small binary heap ---------------------------------------------------

class _Heap extends RefCounted:
	var _a: Array = []

	func is_empty() -> bool:
		return _a.is_empty()

	func push(d: float, key: int, node: Dictionary) -> void:
		_a.append([d, key, node])
		var i := _a.size() - 1
		while i > 0:
			var p := (i - 1) >> 1
			if _a[p][0] <= _a[i][0]:
				break
			var tmp = _a[p]
			_a[p] = _a[i]
			_a[i] = tmp
			i = p

	func pop() -> Array:
		var top: Array = _a[0]
		var last: Array = _a.pop_back()
		if not _a.is_empty():
			_a[0] = last
			var i := 0
			var n := _a.size()
			while true:
				var l := i * 2 + 1
				var r := l + 1
				var m := i
				if l < n and _a[l][0] < _a[m][0]:
					m = l
				if r < n and _a[r][0] < _a[m][0]:
					m = r
				if m == i:
					break
				var tmp = _a[m]
				_a[m] = _a[i]
				_a[i] = tmp
				i = m
		return top
