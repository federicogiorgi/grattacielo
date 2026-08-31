extends RefCounted
class_name SimEngine

## The people, and the lifts that carry them.
##
## Everyone in the tower is a Sim object, but only those actually travelling
## cost anything to run: a sim on a timed leg sits in an arrival bucket until
## the minute it lands, and a sim waiting for a lift sits in that shaft's
## queue until a car takes it. Nothing iterates the whole population per tick.

var tower: Tower
var router: Router
var rng := RandomNumberGenerator.new()

var sims: Dictionary = {}                 # id -> Sim
var next_sim_id: int = 1
var named_sims: Array[int] = []

var arrivals: Dictionary = {}             # minute_of_day -> Array[sim id]
var departures: Dictionary = {}           # minute_of_day -> Array[trip dict]
var walking_by_row: Dictionary = {}       # row -> Array[sim id], for drawing

var outside_pool: Array[int] = []
var stranded_today: int = 0
var trips_today: int = 0

signal sim_left_for_good(sim: Sim)
signal message(text: String)

func _init(p_tower: Tower, p_router: Router) -> void:
	tower = p_tower
	router = p_router
	rng.randomize()

# --- population bookkeeping ------------------------------------------------

func new_sim(role: String, home: int, work: int = -1) -> Sim:
	var s := Sim.new()
	s.id = next_sim_id
	next_sim_id += 1
	s.role = role
	s.home_id = home
	s.work_id = work
	s.state = Sim.State.OUTSIDE
	sims[s.id] = s
	return s

func drop_sim(id: int) -> void:
	var s: Sim = sims.get(id)
	if s == null:
		return
	_leave_walk_index(s)
	if s.shaft_id != -1:
		var sh: Shaft = tower.shafts.get(s.shaft_id)
		if sh != null:
			sh.dequeue(id)
			for c in sh.cars:
				c.riders.erase(id)
	named_sims.erase(id)
	sims.erase(id)

func population() -> int:
	var n := 0
	for id in sims:
		if sims[id].state != Sim.State.OUTSIDE:
			n += 1
	return n

# --- the day's timetable ---------------------------------------------------

## Build every trip the day will contain, in one pass over the facilities.
func plan_day(weekend: bool, day_index: int) -> void:
	departures.clear()
	# arrivals is deliberately NOT cleared: anybody still walking when the day
	# rolls over would otherwise be stuck mid-corridor for ever. Stale entries
	# are harmless -- _run_arrivals ignores a sim that is not travelling.
	trips_today = 0
	stranded_today = 0
	for fid in tower.facilities:
		var f: Facility = tower.facilities[fid]
		match f.kind():
			FacilityDB.Kind.OFFICE:
				_plan_office(f, weekend)
			FacilityDB.Kind.CONDO:
				_plan_condo(f, weekend)
			FacilityDB.Kind.HOTEL:
				_plan_hotel(f, weekend)
			FacilityDB.Kind.SERVICE:
				_plan_service(f, weekend)
			FacilityDB.Kind.VENUE:
				_plan_venue(f, weekend, day_index)
	_plan_visitors(weekend)

func _add_trip(minute: int, sim_id: int, dest_id: int, purpose: int) -> void:
	var m := clampi(minute, 0, 24 * 60 - 1)
	if not departures.has(m):
		departures[m] = []
	departures[m].append({"sim": sim_id, "dest": dest_id, "purpose": purpose})
	trips_today += 1

func _plan_office(f: Facility, weekend: bool) -> void:
	if weekend or f.occupants.is_empty() or f.wrecked:
		return
	for sid in f.occupants:
		var arrive := 7 * 60 + 30 + rng.randi_range(0, 110)
		_add_trip(arrive, sid, f.id, Sim.Purpose.COMMUTE_IN)
		# Lunch, at a food outlet they choose when the time comes.
		var lunch := 11 * 60 + 45 + rng.randi_range(0, 80)
		_add_trip(lunch, sid, -1, Sim.Purpose.LUNCH)
		var leave := 17 * 60 + rng.randi_range(0, 140)
		_add_trip(leave, sid, -1, Sim.Purpose.COMMUTE_OUT)

func _plan_condo(f: Facility, weekend: bool) -> void:
	if f.occupants.is_empty() or f.wrecked:
		return
	for sid in f.occupants:
		if weekend:
			if rng.randf() < 0.75:
				_add_trip(10 * 60 + rng.randi_range(0, 180), sid, -1, Sim.Purpose.SHOP)
				_add_trip(19 * 60 + rng.randi_range(0, 90), sid, -1, Sim.Purpose.DINNER)
		else:
			_add_trip(7 * 60 + rng.randi_range(0, 150), sid, -1, Sim.Purpose.COMMUTE_OUT)
			_add_trip(17 * 60 + 30 + rng.randi_range(0, 170), sid, f.id, Sim.Purpose.HOME)
			if rng.randf() < 0.4:
				_add_trip(19 * 60 + 30 + rng.randi_range(0, 80), sid, -1, Sim.Purpose.DINNER)

func _plan_hotel(f: Facility, _weekend: bool) -> void:
	if f.wrecked or f.roaches:
		return
	# Guests already in the room leave in the morning.
	for sid in f.occupants.duplicate():
		_add_trip(7 * 60 + rng.randi_range(0, 180), sid, -1, Sim.Purpose.CHECK_OUT)
	# Tonight's guests arrive in the evening, if the room is fit to sell.
	if f.dirty:
		return
	var want: int = f.capacity()
	for i in range(want):
		var arrive := 18 * 60 + rng.randi_range(0, 260)
		_add_trip(arrive, -1, f.id, Sim.Purpose.CHECK_IN)

func _plan_service(f: Facility, weekend: bool) -> void:
	if f.type != "housekeeping" or f.wrecked:
		return
	for sid in f.occupants:
		var start := 8 * 60 + rng.randi_range(0, 60)
		for k in range(6 if not weekend else 4):
			_add_trip(start + k * 70 + rng.randi_range(0, 25), sid, -1,
				Sim.Purpose.WORK_ROUND)

func _plan_venue(f: Facility, weekend: bool, _day: int) -> void:
	if f.wrecked:
		return
	if f.type == "cinema":
		var shows := [14 * 60, 17 * 60, 20 * 60] if weekend else [17 * 60, 20 * 60]
		var seats: int = f.capacity()
		for show in shows:
			var crowd := int(seats * (0.75 if weekend else 0.55))
			for i in range(crowd):
				_add_trip(show - 30 + rng.randi_range(0, 25), -1, f.id, Sim.Purpose.SHOW)
	elif f.type == "party_hall":
		# Only fills if the tower actually has hotel rooms to draw guests from.
		var rooms := tower.count_of_kind(FacilityDB.Kind.HOTEL)
		if rooms < 10:
			return
		var guests: int = mini(f.capacity(), rooms * 2)
		for i in range(guests):
			_add_trip(15 * 60 + rng.randi_range(0, 60), -1, f.id, Sim.Purpose.PARTY)

func _plan_visitors(weekend: bool) -> void:
	# People from the street and the metro, who shop and eat but do not live here.
	var shops := tower.all_of_kind(FacilityDB.Kind.SHOP)
	if shops.is_empty():
		return
	var metro := tower.count_of_type("metro") > 0
	var per_shop := (22 if weekend else 17) + (8 if metro else 0)
	for f in shops:
		if f.occupants.is_empty() or f.wrecked:
			continue
		for i in range(per_shop):
			var t := 10 * 60 + rng.randi_range(0, 9 * 60)
			_add_trip(t, -1, f.id, Sim.Purpose.SHOP)

# --- the tick --------------------------------------------------------------

## Called exactly once per minute of tower time.
func minute_tick(minute_of_day: int) -> void:
	_run_departures(minute_of_day)
	_run_arrivals(minute_of_day)

## Called every frame, in small slices, for the things that move continuously.
func step_shafts(minute_of_day: int, weekend: bool, dt_minutes: float) -> void:
	_step_shafts(minute_of_day, weekend, dt_minutes)

func _run_departures(m: int) -> void:
	if not departures.has(m):
		return
	var list: Array = departures[m]
	departures.erase(m)
	for trip in list:
		var sid: int = int(trip["sim"])
		var dest: int = int(trip["dest"])
		var purpose: int = int(trip["purpose"])
		var s: Sim = null
		if sid == -1:
			s = _spawn_visitor(purpose, dest)
			if s == null:
				continue
		else:
			s = sims.get(sid)
			if s == null:
				continue
		if dest == -1:
			dest = _choose_destination(s, purpose)
			if dest == -1 and purpose not in [Sim.Purpose.COMMUTE_OUT,
					Sim.Purpose.CHECK_OUT]:
				continue
		_begin_journey(s, dest, purpose, m)

func _spawn_visitor(purpose: int, dest: int) -> Sim:
	var role := "visitor"
	match purpose:
		Sim.Purpose.CHECK_IN: role = "hotel"
		Sim.Purpose.SHOW: role = "visitor"
		Sim.Purpose.PARTY: role = "visitor"
	var s := new_sim(role, dest, -1)
	s.state = Sim.State.OUTSIDE
	s.row = 0
	s.seg = float(_entrance_seg())
	return s

func _entrance_seg() -> int:
	var metros := tower.all_of_type("metro")
	if not metros.is_empty() and rng.randf() < 0.5:
		return metros[0].centre_seg()
	if tower.lobby_left < 0:
		return 0
	return tower.lobby_left + 2

func _choose_destination(s: Sim, purpose: int) -> int:
	match purpose:
		Sim.Purpose.LUNCH:
			# Nowhere with a free seat means going out to eat, which is exactly
			# what the manual says happens when you have not built enough.
			var r := _nearest_of(s, ["fastfood"], 40)
			return r if r != -1 else -2
		Sim.Purpose.DINNER:
			var r2 := _nearest_of(s, ["restaurant"], 60)
			if r2 == -1:
				r2 = _nearest_of(s, ["fastfood"], 60)
			return r2 if r2 != -1 else -2
		Sim.Purpose.SHOP:
			return _nearest_of(s, ["shop"], 60)
		Sim.Purpose.SHOP_AFTER_SHOW:
			# The manual is specific: the audience drops into shops within five
			# floors of the theatre, up or down.
			return _nearest_of(s, ["shop", "fastfood", "restaurant"], 5)
		Sim.Purpose.HOME:
			return s.home_id
		Sim.Purpose.WORK_ROUND:
			return _dirtiest_room(s)
		Sim.Purpose.COMMUTE_OUT, Sim.Purpose.CHECK_OUT:
			return -2   # the street
	return -1

func _nearest_of(s: Sim, types: Array, max_rows: int) -> int:
	var best := -1
	var best_d := 1e9
	for t in types:
		for f in tower.all_of_type(t):
			if f.wrecked or (f.occupants.is_empty() and f.kind() == FacilityDB.Kind.SHOP):
				continue
			if f.patrons_today >= f.capacity():
				continue      # no seats left today
			var dr: int = absi(f.row - s.row)
			if dr > max_rows:
				continue
			var d := float(dr) * 6.0 + absf(float(f.centre_seg()) - s.seg) * 0.12
			d += rng.randf() * 3.0    # people do not all pick the same shop
			if d < best_d:
				best_d = d
				best = f.id
	return best

func _dirtiest_room(s: Sim) -> int:
	var best := -1
	var best_d := 1e9
	for f in tower.all_of_kind(FacilityDB.Kind.HOTEL):
		if not f.dirty or f.roaches:
			continue
		var d := absf(float(f.row - s.row)) * 5.0 + absf(float(f.centre_seg()) - s.seg) * 0.1
		if d < best_d:
			best_d = d
			best = f.id
	return best

# --- journeys --------------------------------------------------------------

func _begin_journey(s: Sim, dest_id: int, purpose: int, now: int) -> void:
	s.purpose = purpose
	s.dest_id = dest_id
	var from_row := s.row
	var from_seg := s.seg
	if s.state == Sim.State.OUTSIDE:
		from_row = 0
		from_seg = float(_entrance_seg())
		s.row = 0
		s.seg = from_seg
	var to_row := 0
	var to_seg := float(_entrance_seg())
	if dest_id >= 0:
		var f: Facility = tower.facilities.get(dest_id)
		if f == null:
			_finish_outside(s)
			return
		to_row = f.row
		to_seg = float(f.centre_seg())
	s.route = router.find(from_row, from_seg, to_row, to_seg, s.is_staff)
	s.leg = 0
	if s.route.is_empty() and from_row != to_row:
		# Nowhere to go: badly stressed, and they may give up on the tower.
		s.add_stress(70.0)
		stranded_today += 1
		_arrive(s, now, true)
		return
	s.state = Sim.State.WALKING
	_start_leg(s, now)

func _start_leg(s: Sim, now: int) -> void:
	if s.leg >= s.route.size():
		_arrive(s, now, false)
		return
	var lg: Dictionary = s.route[s.leg]
	match int(lg["t"]):
		Router.LEG_WALK:
			s.state = Sim.State.WALKING
			s.leg_from_seg = float(lg["from"])
			s.leg_to_seg = float(lg["to"])
			s.row = int(lg["row"])
			s.seg = s.leg_from_seg
			s.leg_start_min = float(now)
			s.leg_end_min = float(now) + maxf(float(lg["min"]), 0.05)
			_enter_walk_index(s)
			_schedule_arrival(s, int(ceil(s.leg_end_min)))
		Router.LEG_STAIRS, Router.LEG_ESCALATOR:
			s.state = Sim.State.STAIRS
			s.row = int(lg["from_row"])
			s.seg = float(lg["seg"])
			s.leg_start_min = float(now)
			s.leg_end_min = float(now) + float(lg["min"])
			_enter_walk_index(s)
			_schedule_arrival(s, int(ceil(s.leg_end_min)))
		Router.LEG_ELEVATOR:
			var sh: Shaft = tower.shafts.get(int(lg["shaft"]))
			if sh == null:
				s.leg += 1
				_start_leg(s, now)
				return
			s.state = Sim.State.WAITING
			s.row = int(lg["from_row"])
			s.seg = float(lg["seg"])
			s.shaft_id = sh.id
			s.target_row = int(lg["to_row"])
			s.wait_started_min = float(now)
			sh.enqueue(s.id, s.row, s.target_row > s.row)

func _schedule_arrival(s: Sim, minute: int) -> void:
	var m := minute % (24 * 60)
	if not arrivals.has(m):
		arrivals[m] = []
	arrivals[m].append(s.id)

func _run_arrivals(m: int) -> void:
	if not arrivals.has(m):
		return
	var list: Array = arrivals[m]
	arrivals.erase(m)
	for sid in list:
		var s: Sim = sims.get(sid)
		if s == null:
			continue
		if s.state != Sim.State.WALKING and s.state != Sim.State.STAIRS:
			continue
		var lg: Dictionary = s.route[s.leg] if s.leg < s.route.size() else {}
		var mins := maxf(s.leg_end_min - s.leg_start_min, 0.0)
		if s.state == Sim.State.WALKING:
			s.add_stress(mins * Rules.STRESS_PER_MIN_WALKING)
			s.seg = s.leg_to_seg
		else:
			if not lg.is_empty() and int(lg["t"]) == Router.LEG_ESCALATOR:
				s.add_stress(Rules.STRESS_ESCALATOR)
			else:
				s.add_stress(mins * Rules.STRESS_PER_MIN_WALKING * 2.0)
			s.row = int(lg.get("to_row", s.row))
		_leave_walk_index(s)
		s.leg += 1
		_start_leg(s, m)

func _arrive(s: Sim, now: int, stranded: bool) -> void:
	_leave_walk_index(s)
	s.shaft_id = -1
	s.route.clear()
	if s.dest_id == -2:
		_finish_outside(s)
		return
	var f: Facility = tower.facilities.get(s.dest_id)
	if f == null:
		_finish_outside(s)
		return
	s.row = f.row
	s.seg = float(f.centre_seg())
	s.state = Sim.State.RESTING
	f.note_stress(s.stress)
	if stranded:
		s.add_stress(40.0)
	_on_arrival_effects(s, f, now)
	if s.stress >= Rules.STRESS_MAX - 1.0:
		s.doomed = true
		sim_left_for_good.emit(s)
	else:
		s.relax()

func _on_arrival_effects(s: Sim, f: Facility, now: int) -> void:
	match s.purpose:
		Sim.Purpose.LUNCH, Sim.Purpose.DINNER:
			if f.patrons_today >= f.capacity():
				s.add_stress(18.0)    # turned away at the door
			else:
				f.patrons_today += 1
			# Back to where they came from once they have eaten.
			var back := s.work_id if s.work_id != -1 else s.home_id
			if back != -1 and back != f.id:
				_add_trip((now + 35 + rng.randi_range(0, 25)) % (24 * 60), s.id, back,
					Sim.Purpose.HOME if s.work_id == -1 else Sim.Purpose.COMMUTE_IN)
		Sim.Purpose.SHOP, Sim.Purpose.SHOP_AFTER_SHOW:
			if f.patrons_today < f.capacity():
				f.patrons_today += 1
			if s.role == "visitor":
				_add_trip((now + 40 + rng.randi_range(0, 40)) % (24 * 60), s.id, -2,
					Sim.Purpose.COMMUTE_OUT)
			else:
				var back := s.home_id
				if back != -1:
					_add_trip((now + 45) % (24 * 60), s.id, back, Sim.Purpose.HOME)
		Sim.Purpose.SHOW:
			f.patrons_today += 1
			# The audience spills into the shops within five floors afterwards.
			var out_at := (now + 110) % (24 * 60)
			if rng.randf() < 0.45:
				_add_trip(out_at, s.id, -1, Sim.Purpose.SHOP_AFTER_SHOW)
			else:
				_add_trip(out_at, s.id, -2, Sim.Purpose.COMMUTE_OUT)
		Sim.Purpose.PARTY:
			f.patrons_today += 1
			_add_trip((now + 150) % (24 * 60), s.id, -2, Sim.Purpose.COMMUTE_OUT)
		Sim.Purpose.CHECK_IN:
			if f.occupants.size() < f.capacity() and not f.dirty:
				f.occupants.append(s.id)
				f.checked_in = f.occupants.size()
				s.home_id = f.id
			else:
				_add_trip((now + 5) % (24 * 60), s.id, -2, Sim.Purpose.CHECK_OUT)
		Sim.Purpose.WORK_ROUND:
			if f.dirty:
				f.dirty = false
				f.dirty_since_day = -1
				f.roaches = false

func _finish_outside(s: Sim) -> void:
	_leave_walk_index(s)
	s.state = Sim.State.OUTSIDE
	s.route.clear()
	s.shaft_id = -1
	if s.purpose in [Sim.Purpose.LUNCH, Sim.Purpose.DINNER] and s.work_id != -1:
		# Out to eat because the tower had nowhere to feed them.
		s.add_stress(10.0)
		var back := int(_now_minute()) + 55 + rng.randi_range(0, 20)
		_add_trip(back % (24 * 60), s.id, s.work_id, Sim.Purpose.COMMUTE_IN)
		return
	s.relax()
	if s.role == "visitor" or (s.role == "hotel" and s.purpose == Sim.Purpose.CHECK_OUT):
		if s.home_id != -1:
			var f: Facility = tower.facilities.get(s.home_id)
			if f != null and f.occupants.has(s.id):
				f.occupants.erase(s.id)
				f.checked_in = f.occupants.size()
				f.dirty = true
				f.dirty_since_day = -1
		drop_sim(s.id)

# --- walking index, for drawing -------------------------------------------

func _enter_walk_index(s: Sim) -> void:
	if not walking_by_row.has(s.row):
		walking_by_row[s.row] = [] as Array[int]
	var a: Array = walking_by_row[s.row]
	if not a.has(s.id):
		a.append(s.id)

func _leave_walk_index(s: Sim) -> void:
	for r in walking_by_row:
		walking_by_row[r].erase(s.id)

## Where a walking sim is right now, interpolated. Only the renderer asks.
func walk_position(s: Sim, now_min: float) -> float:
	var span := maxf(s.leg_end_min - s.leg_start_min, 0.001)
	var t := clampf((now_min - s.leg_start_min) / span, 0.0, 1.0)
	return lerpf(s.leg_from_seg, s.leg_to_seg, t)

# --- elevators -------------------------------------------------------------

func _step_shafts(minute_of_day: int, weekend: bool, dt: float) -> void:
	for sid in tower.shafts:
		var s: Shaft = tower.shafts[sid]
		_dispatch(s, minute_of_day, weekend)
		for c in s.cars:
			_step_car(s, c, minute_of_day, weekend, dt)
		_age_queues(s, dt)

func _age_queues(s: Shaft, dt: float) -> void:
	for r in s.queues:
		for key in ["up", "down"]:
			for sid in s.queues[r][key]:
				var sim: Sim = sims.get(sid)
				if sim != null:
					sim.add_stress(dt * Rules.STRESS_PER_MIN_WAITING)

func _dispatch(s: Shaft, minute_of_day: int, weekend: bool) -> void:
	var mode := s.mode_at(minute_of_day, weekend)
	if s.is_express():
		mode = Shaft.Mode.LOCAL
	for r in s.queues:
		if s.queues[r]["up"].is_empty() and s.queues[r]["down"].is_empty():
			continue
		if not s.serves_row(r):
			continue
		var already := false
		for c in s.cars:
			if c.stops.has(r):
				already = true
				break
		if already:
			continue
		var best: Shaft.Car = null
		var best_score := 1e9
		for c in s.cars:
			if c.riders.size() >= s.car_capacity():
				continue
			var d := absf(c.pos - float(r))
			var score := d
			if c.state == Shaft.CarState.IDLE:
				score = d - float(s.wait_response) * 0.5
			elif (c.dir > 0 and r < int(c.pos)) or (c.dir < 0 and r > int(c.pos)):
				score = d + float(s.span())     # heading away
			score += float(c.stops.size()) * 0.8
			if score < best_score:
				best_score = score
				best = c
		if best != null:
			best.stops[r] = true
			if mode == Shaft.Mode.EXPRESS_TOP and best.dir > 0:
				best.stops[s.top_row] = true
			elif mode == Shaft.Mode.EXPRESS_BOTTOM and best.dir < 0:
				best.stops[s.bottom_row] = true

func _step_car(s: Shaft, c: Shaft.Car, minute_of_day: int, weekend: bool,
		dt: float) -> void:
	var mode := s.mode_at(minute_of_day, weekend)
	if s.is_express():
		mode = Shaft.Mode.LOCAL

	if c.state == Shaft.CarState.DOORS:
		c.door_minutes -= dt
		if c.door_minutes <= 0.0:
			c.state = Shaft.CarState.IDLE
		return

	# Pick something to do.
	if c.state == Shaft.CarState.IDLE:
		var target := _next_target(s, c, mode)
		if target == -9999:
			if int(round(c.pos)) != c.home_row:
				c.dir = signi(c.home_row - int(round(c.pos)))
				c.state = Shaft.CarState.MOVING
			else:
				c.dir = 0
			return
		c.dir = signi(target - int(round(c.pos)))
		if c.dir == 0:
			_service_floor(s, c, int(round(c.pos)), mode)
			return
		c.state = Shaft.CarState.MOVING

	if c.state == Shaft.CarState.MOVING:
		var speed := s.speed_floors_per_min()
		var before := c.pos
		c.pos += float(c.dir) * speed * dt
		c.pos = clampf(c.pos, float(s.bottom_row), float(s.top_row))
		# Did it pass a floor it must serve?
		var lo := minf(before, c.pos)
		var hi := maxf(before, c.pos)
		for r in range(int(floor(lo)), int(ceil(hi)) + 1):
			if float(r) < lo - 0.001 or float(r) > hi + 0.001:
				continue
			if not s.covers_row(r):
				continue
			var must := c.stops.has(r)
			if not must:
				continue
			if mode == Shaft.Mode.EXPRESS_TOP and c.dir > 0 and r != s.top_row:
				continue
			if mode == Shaft.Mode.EXPRESS_BOTTOM and c.dir < 0 and r != s.bottom_row:
				continue
			c.pos = float(r)
			_service_floor(s, c, r, mode)
			return
		if (c.dir > 0 and c.pos >= float(s.top_row)) \
				or (c.dir < 0 and c.pos <= float(s.bottom_row)):
			_service_floor(s, c, int(round(c.pos)), mode)

func _next_target(s: Shaft, c: Shaft.Car, mode: int) -> int:
	if not c.stops.is_empty():
		var here := int(round(c.pos))
		var best := -9999
		var best_d := 1e9
		for r in c.stops:
			var d := absf(float(r - here))
			if c.dir > 0 and r < here:
				d += float(s.span())
			if c.dir < 0 and r > here:
				d += float(s.span())
			if d < best_d:
				best_d = d
				best = r
		return best
	if mode == Shaft.Mode.EXPRESS_TOP and s.total_waiting() > 0:
		return s.top_row
	if mode == Shaft.Mode.EXPRESS_BOTTOM and s.total_waiting() > 0:
		return s.bottom_row
	return -9999

func _service_floor(s: Shaft, c: Shaft.Car, r: int, _mode: int) -> void:
	if not c.riders.is_empty() or s.waiting_at(r) > 0:
		Audio.play("doors" if s.is_service() else "ding")
	c.stops.erase(r)
	c.state = Shaft.CarState.DOORS
	c.door_minutes = Rules.ELEVATOR_DOOR_MINUTES + float(s.floor_departure) / 60.0

	# Everybody whose stop this is gets out.
	var staying: Array[int] = []
	for sid in c.riders:
		var sim: Sim = sims.get(sid)
		if sim == null:
			continue
		if sim.target_row == r:
			sim.row = r
			sim.seg = float(s.seg)
			sim.shaft_id = -1
			sim.add_stress(absf(float(sim.target_row - r)) * 0.0)
			sim.leg += 1
			_start_leg(sim, int(round(_now_minute())))
		else:
			staying.append(sid)
	c.riders = staying

	# And whoever is waiting here, in the direction the car is going.
	if not s.serves_row(r):
		return
	var q := s.queue_at(r)
	var order := ["up", "down"] if c.dir >= 0 else ["down", "up"]
	for key in order:
		while not q[key].is_empty() and c.riders.size() < s.car_capacity():
			var sid: int = q[key][0]
			var sim: Sim = sims.get(sid)
			if sim == null:
				q[key].pop_front()
				continue
			if not s.serves_row(sim.target_row):
				q[key].pop_front()
				continue
			q[key].pop_front()
			c.riders.append(sid)
			sim.state = Sim.State.RIDING
			var wait := _now_minute() - sim.wait_started_min
			sim.add_stress(maxf(wait, 0.0) * 0.0)   # already charged while queueing
			sim.add_stress(absf(float(sim.target_row - r)) / s.speed_floors_per_min()
				* Rules.STRESS_PER_MIN_RIDING)
			c.stops[sim.target_row] = true
	c.full = c.riders.size() >= s.car_capacity()

var _now_min: float = 0.0

func set_now(m: float) -> void:
	_now_min = m

func _now_minute() -> float:
	return _now_min

# --- nightly bookkeeping ---------------------------------------------------

## Reset the counters a new day starts from.
func begin_day() -> void:
	for fid in tower.facilities:
		var f: Facility = tower.facilities[fid]
		f.patrons_today = 0
		f.reset_stress_window()
