extends Node

## The game. Owns the tower, the clock, the money and the people, and runs the
## daily and quarterly cycles that turn one into the other.
##
## Registered as an autoload called Game, so any window can reach it.

signal message(text: String)
signal star_changed(stars: int)
signal tower_changed()
signal ask_player(question: String, tag: String)
signal selection_changed()

var tower: Tower
var clock: GameClock
var econ: Economy
var router: Router
var engine: SimEngine
var events: TowerEvents
var rng := RandomNumberGenerator.new()

var stars: int = 1
var tool: String = "lobby"

# Pausing has two independent sources and they must not clobber one another:
# the player pressing the pause button, and a window that pauses while it is
# open (the finance window, the map's evaluation views). Setting a single flag
# from both places left the game frozen for ever the first time you closed the
# finance window, which is a very quiet way to break the whole thing.
var paused: bool = false
var manual_paused: bool = false
var _pause_holders: Dictionary = {}
var speed_index: int = 1
const SPEEDS := [0.5, 1.0, 2.0, 4.0]

var last_message: String = ""
var selected_facility: int = -1
var selected_shaft: int = -1
var selected_sim: int = -1

var vip_watch_until: int = -1
var save_path: String = "user://grattacielo.save"

## Today's weather. Scenery, and the one thing that moves trade on its own:
## "rainy days get about half the normal traffic".
## Flats are bought in the late morning, when an estate agent would actually
## be showing them -- not in the small hours with everything else. It is also
## the one move-in the player is likely to be watching.
# Flats are viewed in the late morning; everything else lets all working day.
const CONDO_SALE_FROM := 9 * 60
const CONDO_SALE_TO := 12 * 60
# Tenants are shown round in the morning and decide before lunch. Nothing is
# let in the afternoon: if you want a floor occupied today, build it early.
const LETTING_FROM := 7 * 60
const LETTING_TO := 12 * 60
const LETTING_EVERY := 30
const LETTING_SHARE := 0.34

## The last thing built, and when. You get two tower hours to change your
## mind, which is long enough to notice a mistake and short enough that it
## cannot be used to undo a decision the simulation has already acted on.
const UNDO_MINUTES := 120.0
var last_build: Dictionary = {}

var weather: String = "clear"
var _weather_bag: Array[String] = []

func _ready() -> void:
	rng.randomize()
	new_game()
	set_process(true)

func _exit_tree() -> void:
	_teardown()

func new_game() -> void:
	_teardown()
	tower = Tower.new()
	clock = GameClock.new()
	econ = Economy.new()
	router = Router.new(tower)
	engine = SimEngine.new(tower, router)
	events = TowerEvents.new(tower)
	stars = 1
	selected_facility = -1
	selected_shaft = -1
	selected_sim = -1
	tool = "lobby"
	_wire()
	say("Build a lobby to begin.")
	tower_changed.emit()

## Tower, Router, SimEngine and TowerEvents all hold each other, and Tower's
## signal holds Router back, so a discarded game would never be freed. Break
## the cycle before building a new one -- otherwise every "New tower" leaks
## the whole previous simulation.
func _teardown() -> void:
	if tower == null:
		return
	if router != null and tower.structure_changed.is_connected(router.clear_cache):
		tower.structure_changed.disconnect(router.clear_cache)
	for c in tower.structure_changed.get_connections():
		tower.structure_changed.disconnect(c["callable"])
	if clock != null:
		for sig in [clock.day_started, clock.day_ended, clock.quarter_ended,
				clock.minute_passed]:
			for c in sig.get_connections():
				sig.disconnect(c["callable"])
	if engine != null:
		for c in engine.sim_left_for_good.get_connections():
			engine.sim_left_for_good.disconnect(c["callable"])
		for c in engine.message.get_connections():
			engine.message.disconnect(c["callable"])
		engine.sims.clear()
		engine.walking_by_row.clear()
		engine.arrivals.clear()
		engine.departures.clear()
		engine.named_sims.clear()
	# The shafts hold sim ids in their queues and cars; the sims are gone, so
	# the lists are dead weight that would otherwise keep the tower alive.
	for sid in tower.shafts:
		var sh: Shaft = tower.shafts[sid]
		sh.queues.clear()
		for c in sh.cars:
			c.riders.clear()
			c.stops.clear()
	for fid in tower.facilities:
		tower.facilities[fid].occupants.clear()
	if events != null:
		for c in events.announce.get_connections():
			events.announce.disconnect(c["callable"])
		for c in events.ask.get_connections():
			events.ask.disconnect(c["callable"])
	if econ != null:
		for c in econ.transaction.get_connections():
			econ.transaction.disconnect(c["callable"])
	router = null
	engine = null
	events = null
	tower = null

func _wire() -> void:
	clock.day_started.connect(_on_day_started)
	clock.day_ended.connect(_on_day_ended)
	clock.quarter_ended.connect(_on_quarter_ended)
	clock.minute_passed.connect(_on_minute)
	tower.structure_changed.connect(func(): tower_changed.emit())
	engine.sim_left_for_good.connect(_on_sim_gave_up)
	engine.message.connect(say)
	events.announce.connect(say)
	events.ask.connect(func(q, t): ask_player.emit(q, t))

func set_manual_pause(v: bool) -> void:
	manual_paused = v
	_update_pause()

## A window that should stop the clock while it is open holds a named pause.
func hold_pause(key: String, on: bool) -> void:
	if on:
		_pause_holders[key] = true
	else:
		_pause_holders.erase(key)
	_update_pause()

func _update_pause() -> void:
	paused = manual_paused or not _pause_holders.is_empty()

func say(text: String) -> void:
	last_message = text
	message.emit(text)

# --- main loop -------------------------------------------------------------

func _process(delta: float) -> void:
	if paused:
		return
	clock.speed = SPEEDS[speed_index]
	var before := clock.minute
	# Every minute of tower time is emitted one at a time, so no departure and
	# no arrival can ever be skipped however fast the clock is running. This
	# was a real bug: at night the clock moves 120 minutes a second, and whole
	# minutes' worth of people used to vanish into a journey that never ended.
	clock.advance(delta)
	var dt: float = clock.minute - before
	engine.set_now(clock.minute)
	if dt <= 0.0:
		return
	# The lifts are continuous, so they are stepped in slices small enough that
	# a car cannot sail past a floor it was meant to stop at.
	var remaining := minf(dt, 30.0)
	while remaining > 0.0:
		var slice := minf(remaining, 0.4)
		engine.step_shafts(clock.minute_of_day(), clock.is_weekend(), slice)
		remaining -= slice
	if events.fire_active():
		var wrecked := events.step_fire(minf(dt, 6.0))
		for f in wrecked:
			_evict(f)
	events.update_santa(clock, delta)

func _on_minute(m: int) -> void:
	if m % 60 == 0 and m >= 6 * 60 and m < 23 * 60 \
			and tower.count_of_type("metro") > 0:
		Audio.play("train")
	engine.set_now(clock.minute)
	engine.minute_tick(m)
	events.maybe_start_fire(m)
	var b := events.step_bomb(m)
	if b["exploded"]:
		_explode(int(b["seg"]), int(b["row"]))
	if m == 3 * 60:
		_rest_period()
	if m >= LETTING_FROM and m <= LETTING_TO and m % LETTING_EVERY == 0:
		_letting_round(m)

# --- the daily cycle -------------------------------------------------------

func _on_day_started(day_in_quarter: int, weekend: bool) -> void:
	_roll_weather()
	events.begin_day()
	engine.begin_day()
	engine.plan_day(weekend, day_in_quarter)
	if weekend:
		say("Weekend.")
		_maybe_wedding()

## Drawn from a shuffled bag rather than rolled, so a week of solid rain
## cannot happen by accident.
func _roll_weather() -> void:
	if _weather_bag.is_empty():
		_weather_bag = ["clear", "clear", "clear", "clear", "clear",
			"cloudy", "cloudy", "cloudy", "rain", "rain", "rain", "snow"]
		for i in range(_weather_bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := _weather_bag[i]
			_weather_bag[i] = _weather_bag[j]
			_weather_bag[j] = t
	weather = _weather_bag.pop_back()

## On Sundays people gather in the cathedral, and once -- if your soul is pure
## and your lifts are well greased -- there is a wedding.
func _maybe_wedding() -> void:
	if stars < 6 or events.wedding_done:
		return
	if tower.count_of_type("cathedral") == 0:
		return
	events.wedding_done = true
	Audio.play("church")
	econ.earn_other(1000000, "Cathedral wedding")
	say("A wedding in the cathedral! The bells carry right across the city.")

func _on_day_ended() -> void:
	_collect_daily_income()
	_update_patronage()
	_hotel_housekeeping()
	_evaluate_all()

func _collect_daily_income() -> void:
	var food_take := 0
	for f in tower.all_of_kind(FacilityDB.Kind.FOOD):
		if f.wrecked:
			continue
		var take: int = f.food_takings()
		f.takings_today = take
		econ.earn(f.type, take)
		food_take += take
	var hotel := 0
	for f in tower.all_of_kind(FacilityDB.Kind.HOTEL):
		if f.wrecked or f.occupants.is_empty():
			continue
		var amount: int = f.rent() * f.occupants.size()
		econ.earn("hotel", amount)
		hotel += amount
	for f in tower.all_of_kind(FacilityDB.Kind.VENUE):
		if f.wrecked or f.patrons_today <= 0:
			continue
		var per: int = int(f.def().get("take", 0))
		var amount2 := int(round(float(per) * float(f.patrons_today)
			/ maxf(float(f.capacity()), 1.0)))
		econ.earn(f.type, amount2)
	if food_take != 0 or hotel != 0:
		say("Today's takings: " + Economy.money(food_take + hotel))

func _update_patronage() -> void:
	_share_across_escalators()
	for f in tower.all_of_kind(FacilityDB.Kind.FOOD):
		_drift_patrons(f)
	for f in tower.all_of_kind(FacilityDB.Kind.SHOP):
		_drift_patrons(f)

## "If two commercial areas are connected with escalators, they will share
## customers, and revenue." Both ends move towards their average.
func _share_across_escalators() -> void:
	for e in tower.all_of_type("escalator"):
		var lower := _commercial_near(e.seg, e.row)
		var upper := _commercial_near(e.seg, e.row + 1)
		for a in lower:
			for b in upper:
				var mean := float(a.patrons_today + b.patrons_today) * 0.5
				a.patrons_today = mini(a.capacity(),
					int(round(lerpf(float(a.patrons_today), mean, 0.30))))
				b.patrons_today = mini(b.capacity(),
					int(round(lerpf(float(b.patrons_today), mean, 0.30))))

func _commercial_near(seg: int, row: int) -> Array:
	var out := []
	var c := maxi(0, seg - 24)
	var last := mini(Tower.COLS - 1, seg + 32)
	while c <= last:
		var f := tower.facility_at(c, row)
		if f == null:
			c += 1
			continue
		if f.kind() in [FacilityDB.Kind.FOOD, FacilityDB.Kind.SHOP] and not f.wrecked:
			out.append(f)
		c = maxi(c + 1, f.seg + f.w)
	return out

func _drift_patrons(f: Facility) -> void:
	if weather == "rain":
		f.patrons_today = int(round(float(f.patrons_today) * Rules.RAIN_PATRON_FACTOR))
	var rating := f.patron_rating()
	match rating:
		Rules.Eval.A: f.patrons += Rules.PATRON_DELTA_A
		Rules.Eval.B: f.patrons += Rules.PATRON_DELTA_B
		_: f.patrons += Rules.PATRON_DELTA_C
	f.patrons = clampi(f.patrons, 0, f.capacity())
	f.eval = rating

func _hotel_housekeeping() -> void:
	for f in tower.all_of_kind(FacilityDB.Kind.HOTEL):
		if not f.dirty:
			continue
		if f.dirty_since_day == -1:
			f.dirty_since_day = _absolute_day()
		elif _absolute_day() - f.dirty_since_day >= Rules.DIRTY_ROOM_DAYS_TO_ROACHES:
			if not f.roaches:
				f.roaches = true
				Audio.play("bad")
				say("Cockroaches on floor " + FacilityDB.row_label(f.row)
					+ ". The room must be demolished.")

func _absolute_day() -> int:
	return ((clock.year - 1) * Rules.QUARTERS_PER_YEAR + (clock.quarter - 1)) \
		* Rules.DAYS_PER_QUARTER + clock.day_in_quarter

func _evaluate_all() -> void:
	for fid in tower.facilities:
		var f: Facility = tower.facilities[fid]
		if f.kind() in [FacilityDB.Kind.OFFICE, FacilityDB.Kind.CONDO,
				FacilityDB.Kind.HOTEL]:
			_apply_noise(f)
			f.recompute_eval()
	# Did the VIP enjoy the stay?
	if events.vip_room != -1 and events.vip_visited:
		var suite: Facility = tower.facilities.get(events.vip_room)
		if suite != null:
			events.vip_happy = suite.eval == Rules.Eval.A and not suite.dirty
			if events.vip_happy:
				say("The VIP is delighted with your tower.")
			else:
				say("The VIP is not impressed. No promotion for you.")
				Audio.play("bad")
		events.vip_room = -1

## Radial broadcasting: noisy neighbours above, below and beside.
func _apply_noise(f: Facility) -> void:
	var penalty := 0.0
	var want := Rules.NOISE_TO_HOTEL if f.kind() == FacilityDB.Kind.HOTEL \
		else Rules.NOISE_FOOD_TO_OFFICE
	for dr in [-1, 0, 1]:
		var r: int = f.row + int(dr)
		var lo := f.seg - want
		var hi := f.seg + f.w + want
		var c := lo
		while c < hi:
			var n := tower.facility_at(c, r)
			if n == null:
				c += 1
				continue
			if n.id != f.id and n.kind() in [FacilityDB.Kind.FOOD,
					FacilityDB.Kind.VENUE]:
				penalty += Rules.NOISE_PENALTY * (0.5 if dr != 0 else 1.0)
				break
			c += maxi(1, n.w)
	if penalty > 0.0 and f.stress_n > 0:
		f.stress_sum += penalty * float(f.stress_n) / 6.0

# --- the rest period: who moves in, who moves out -------------------------

## Three in the morning is when tenants LEAVE -- the manual is explicit that
## the C-rated give up "at the end of the rest period". Nobody moves IN here
## any more; letting happens during the working day, where you can see it.
func _rest_period() -> void:
	var moved_out := 0
	for fid in tower.facilities.keys():
		var f: Facility = tower.facilities.get(fid)
		if f == null or f.wrecked:
			continue
		match f.kind():
			FacilityDB.Kind.OFFICE, FacilityDB.Kind.SHOP:
				if not f.occupants.is_empty() and f.eval == Rules.Eval.C:
					_evict(f)
					moved_out += 1
			FacilityDB.Kind.CONDO:
				if f.sold and f.eval == Rules.Eval.C:
					econ.charge(f.sale_price, "Condominium refunded")
					f.sold = false
					_evict(f)
					moved_out += 1
			FacilityDB.Kind.SERVICE:
				if f.occupants.is_empty() and f.capacity() > 0:
					_staff(f)
	if moved_out > 0:
		say("%d tenants have left the tower." % moved_out)
	_check_stars()
	_check_demands()

## Letting rounds run through the working day. Anything you build in the
## morning is taken the same morning, if the tower has earned it -- it used to
## wait for the next three a.m., so everything built during the day sat empty
## until you had stopped looking. Only a share of the vacancies goes each
## round, so a floor of new offices fills over an afternoon rather than at once.
func _letting_round(now: int) -> void:
	var n := _let_kind(FacilityDB.Kind.OFFICE, now)
	n += _let_kind(FacilityDB.Kind.SHOP, now)
	# Flats are viewed in the late morning and nowhere else in the day.
	if now >= CONDO_SALE_FROM and now < CONDO_SALE_TO:
		n += _let_kind(FacilityDB.Kind.CONDO, now)
	if n > 0:
		say("%d new tenant%s moved in." % [n, "" if n == 1 else "s"])
		_check_stars()

func _let_kind(kind: int, now: int) -> int:
	if not _letting_allowed(kind):
		return 0
	var vacant := []
	for f in tower.all_of_kind(kind):
		if f.wrecked:
			continue
		if kind == FacilityDB.Kind.CONDO:
			if f.sold:
				continue
		elif not f.occupants.is_empty():
			continue
		vacant.append(f)
	if vacant.is_empty():
		return 0
	var take := maxi(1, int(ceil(float(vacant.size()) * LETTING_SHARE)))
	var done := 0
	for f in vacant:
		if done >= take:
			break
		if not _reachable(f):
			continue
		match kind:
			FacilityDB.Kind.OFFICE:
				_lease_office(f)
				engine.welcome(f, now, clock.is_weekend())
			FacilityDB.Kind.SHOP:
				_lease_shop(f)
			FacilityDB.Kind.CONDO:
				_sell_condo(f)
		done += 1
	return done

## Word gets round. The manual: "if there is a lot of complaint ... the
## Simtenants will advise others about it and the rumours will spread". Once
## half of what is let is in crisis, nothing new lets until you fix it. That,
## and whether a place can be reached at all, is what gates a tower's growth --
## an arbitrary quota was doing it before, and two lettings a day meant fifty
## offices would have taken twenty-five days to fill.
func _letting_allowed(kind: int) -> bool:
	var occupied := 0
	var bad := 0
	for f in tower.all_of_kind(kind):
		if f.wrecked:
			continue
		if kind == FacilityDB.Kind.CONDO:
			if not f.sold:
				continue
		elif f.occupants.is_empty():
			continue
		occupied += 1
		if f.eval == Rules.Eval.C:
			bad += 1
	if occupied == 0:
		return true                       # somebody has to be first
	return bad * 2 < occupied

func _reachable(f: Facility) -> bool:
	if f.row == 0:
		return true
	var entrance := maxi(tower.lobby_left + 2, 0)
	var legs := router.find(0, float(entrance), f.row, float(f.centre_seg()))
	return not legs.is_empty()

func _lease_office(f: Facility) -> void:
	for i in range(f.capacity()):
		var s := engine.new_sim("office", -1, f.id)
		s.work_id = f.id
		s.row = f.row
		s.seg = float(f.centre_seg())
		s.state = Sim.State.OUTSIDE
		f.occupants.append(s.id)
	f.vacant = false
	f.built_quarter = _abs_quarter()

func _lease_shop(f: Facility) -> void:
	if f.brand == "":
		var brands: Array = f.def().get("brands", [])
		if not brands.is_empty():
			f.brand = brands[rng.randi() % brands.size()]
	for i in range(2):
		var s := engine.new_sim("shop", -1, f.id)
		s.row = f.row
		s.seg = float(f.centre_seg())
		s.state = Sim.State.RESTING
		f.occupants.append(s.id)
	f.vacant = false
	f.patrons = Rules.PATRON_START
	f.built_quarter = _abs_quarter()

func _sell_condo(f: Facility) -> void:
	f.sale_price = f.rent()
	f.sold = true
	econ.earn("condo", f.sale_price, "Condominium sold")
	for i in range(f.capacity()):
		var s := engine.new_sim("condo", f.id, -1)
		s.row = f.row
		s.seg = float(f.centre_seg())
		s.state = Sim.State.RESTING
		f.occupants.append(s.id)
	f.vacant = false
	f.built_quarter = _abs_quarter()

func _staff(f: Facility) -> void:
	var role := "housekeeping"
	if f.type == "security":
		role = "security"
	elif f.type == "medical":
		role = "medical"
	for i in range(f.capacity()):
		var s := engine.new_sim(role, f.id, f.id)
		s.is_staff = f.type == "housekeeping"
		s.row = f.row
		s.seg = float(f.centre_seg())
		s.state = Sim.State.RESTING
		f.occupants.append(s.id)
	f.vacant = false

func _evict(f: Facility) -> void:
	for sid in f.occupants:
		engine.drop_sim(sid)
	f.occupants.clear()
	f.checked_in = 0
	f.vacant = true

func _on_sim_gave_up(s: Sim) -> void:
	var f: Facility = tower.facilities.get(s.work_id if s.work_id != -1 else s.home_id)
	if f != null and f.kind() in [FacilityDB.Kind.OFFICE, FacilityDB.Kind.SHOP]:
		f.stress_sum += Rules.STRESS_MAX
		f.stress_n += 1

# --- quarterly -------------------------------------------------------------

func _abs_quarter() -> int:
	return (clock.year - 1) * Rules.QUARTERS_PER_YEAR + clock.quarter

func _on_quarter_ended(quarter: int, year: int) -> void:
	# Rents in.
	for f in tower.all_of_kind(FacilityDB.Kind.OFFICE):
		if not f.occupants.is_empty() and not f.wrecked:
			econ.earn("office", f.rent())
	for f in tower.all_of_kind(FacilityDB.Kind.SHOP):
		if not f.occupants.is_empty() and not f.wrecked:
			econ.earn("shop", f.rent())
	# Maintenance out.
	for fid in tower.facilities:
		var f: Facility = tower.facilities[fid]
		var up: int = int(f.def().get("upkeep", 0))
		if up > 0:
			econ.pay(f.type, up)
	for sid in tower.shafts:
		var s: Shaft = tower.shafts[sid]
		econ.pay(s.type, int(s.def().get("upkeep", 0))
			+ int(s.def().get("car_upkeep", 0)) * s.cars.size())
	var lobby_cells := tower.lobby_width()
	if lobby_cells > 0:
		econ.pay("lobby", lobby_cells * 300)

	if events.pending_treasure:
		events.pending_treasure = false
		econ.earn_other(Rules.TREASURE_VALUE, "Hidden treasure")

	econ.close_quarter()
	events.roll_quarter(quarter, year, tower.population())
	_check_stars()
	say("Quarter closed. Balance: " + Economy.money(econ.last_quarter_balance))

# --- stars -----------------------------------------------------------------

func _check_stars() -> void:
	var pop := tower.population()
	while stars < Rules.STARS.size():
		var next: Dictionary = Rules.STARS[stars]   # index stars == next level
		if pop < int(next["pop"]):
			break
		if not _needs_met(next["needs"]):
			break
		stars = int(next["stars"])
		say("Your tower has risen to " + String(next["name"]) + "!")
		star_changed.emit(stars)

func _needs_met(needs: Array) -> bool:
	for n in needs:
		match String(n):
			"vip":
				if not events.vip_happy:
					return false
			"security":
				if tower.count_of_type("security") == 0:
					return false
			"hotel_suite":
				if tower.count_of_type("hotel_suite") < 2:
					return false
			_:
				if tower.count_of_type(String(n)) == 0:
					return false
	return true

func star_name() -> String:
	for s in Rules.STARS:
		if int(s["stars"]) == stars:
			return String(s["name"])
	return str(stars)

## What the tower is nagging you for right now.
func _check_demands() -> void:
	var pop := tower.population()
	if pop <= 0:
		return
	var need_sec := pop / Rules.SECURITY_PER_POPULATION
	if tower.count_of_type("security") < need_sec:
		say("The tower needs more security.")
		return
	var need_rec := pop / Rules.RECYCLING_PER_POPULATION
	if stars >= 3 and tower.count_of_type("recycling") < need_rec:
		say("The tower needs a recycling centre.")
		return
	var need_med := pop / Rules.MEDICAL_PER_POPULATION
	if stars >= 3 and tower.count_of_type("medical") < need_med:
		say("The tower needs a medical centre.")
		return
	var rooms := tower.count_of_kind(FacilityDB.Kind.HOTEL)
	var keepers := tower.count_of_type("housekeeping") * 6
	if rooms > keepers * Rules.ROOMS_PER_HOUSEKEEPER:
		say("You do not have enough housekeeping staff.")
		return
	if tower.count_of_type("recycling") > 0 and not _recycling_served():
		say("A recycling centre has no service elevator reaching it.")

## The manual: "Service elevators must stop at recycling centers."
func _recycling_served() -> bool:
	for f in tower.all_of_type("recycling"):
		var ok := false
		for sid in tower.shafts:
			var s: Shaft = tower.shafts[sid]
			if s.is_service() and s.covers_row(f.row):
				ok = true
				break
		if not ok:
			return false
	return true

# --- construction API ------------------------------------------------------

func can_use_tool(id: String) -> bool:
	return FacilityDB.stars_for(id) <= stars

func try_place(type: String, seg: int, row: int, drag_w: int = -1,
		drag_top: int = -9999) -> Dictionary:
	if not can_use_tool(type):
		return _fail("Not available at this star rating")
	if FacilityDB.is_elevator(type):
		return _place_shaft(type, seg, row, drag_top)
	var limit := _limit_check(type)
	if limit != "":
		return _fail(limit)
	var w: int = drag_w if drag_w > 0 else FacilityDB.size_of(type).x
	var chk := tower.check_place(type, seg, row, w)
	if not chk["ok"]:
		return _fail(String(chk["reason"]))
	var total: int = int(chk["cost"]) + int(chk["floor_cost"])
	if not econ.can_afford(total):
		if econ.can_afford(int(chk["cost"])):
			return _fail("Not enough money to build floor")
		return _fail("Not enough money for construction")
	econ.spend_construction(total)
	Audio.play("build")
	var f := tower.place(type, seg, row, w)
	if f != null:
		_after_place(f)
		_remember_build({"what": "facility", "id": f.id, "cost": total,
			"name": String(FacilityDB.DEFS[type]["name"])})
	else:
		_remember_build({"what": "structure", "type": type, "seg": seg, "row": row,
			"w": w, "cost": total, "name": String(FacilityDB.DEFS[type]["name"])})
	say("%s  %s" % [FacilityDB.DEFS[type]["name"], Economy.money(total)])
	return {"ok": true, "reason": ""}

func _after_place(f: Facility) -> void:
	f.built_quarter = _abs_quarter()
	match f.kind():
		FacilityDB.Kind.SERVICE:
			# You paid for the guards; they are on duty now, not at 3am.
			if f.capacity() > 0:
				_staff(f)
		FacilityDB.Kind.HOTEL:
			# The day's timetable was drawn up at midnight and knows nothing
			# about a room built since, so tonight's guests are booked here.
			engine.book_tonight(f, clock.minute_of_day())
		FacilityDB.Kind.FOOD:
			var brands: Array = f.def().get("brands", [])
			if not brands.is_empty():
				f.brand = brands[rng.randi() % brands.size()]
			f.patrons = Rules.PATRON_START
		FacilityDB.Kind.VENUE:
			if f.type == "cinema":
				f.movie = Names.MOVIES_CLASSIC[rng.randi() % Names.MOVIES_CLASSIC.size()]
				f.movie_is_new = false
		FacilityDB.Kind.CONDO:
			f.rent_tier = 2
			f.sale_price = f.rent()

func _place_shaft(type: String, seg: int, row: int, top: int) -> Dictionary:
	var bottom := row
	var t := top if top != -9999 else row + 1
	if t < bottom:
		var tmp := bottom
		bottom = t
		t = tmp
	var d: Dictionary = FacilityDB.DEFS[type]
	var w: int = int(d["w"])
	# An existing shaft clicked on gets another car instead of a new shaft.
	var existing := tower.shaft_at(seg, row)
	if existing != null and existing.type == type:
		if existing.cars.size() >= FacilityDB.LIMITS["cars_per_shaft"]:
			return _fail("At most %d cars a shaft" % FacilityDB.LIMITS["cars_per_shaft"])
		var cc: int = int(d["car_cost"])
		if not econ.can_afford(cc):
			return _fail("Not enough money for another car")
		econ.spend_construction(cc)
		existing.add_car(row)
		tower.mark_dirty()
		tower_changed.emit()
		_remember_build({"what": "car", "id": existing.id, "cost": cc,
			"name": "Elevator car"})
		say("Car added  " + Economy.money(cc))
		return {"ok": true, "reason": ""}

	var chk := tower.check_place(type, seg, bottom, w)
	if not chk["ok"]:
		return _fail(String(chk["reason"]))
	if t - bottom + 1 > int(d.get("max_span", 30)):
		return _fail("At most %d floors" % int(d.get("max_span", 30)))
	for r in range(bottom, t + 1):
		if not tower.range_built(seg, r, w):
			return _fail("No floor at " + FacilityDB.row_label(r))
		if not tower.range_free(seg, r, w):
			return _fail("Floor " + FacilityDB.row_label(r) + " is occupied")
	var cost: int = int(chk["cost"])
	if not econ.can_afford(cost):
		return _fail("Not enough money for construction")
	econ.spend_construction(cost)
	var s := tower.place_shaft(type, seg, bottom, t)
	_remember_build({"what": "shaft", "id": s.id, "cost": cost,
		"name": String(d["name"])})
	say("%s  %s" % [d["name"], Economy.money(cost)])
	selected_shaft = s.id
	return {"ok": true, "reason": ""}

func _limit_check(type: String) -> String:
	match type:
		"stairs", "escalator":
			if tower.count_transport() >= FacilityDB.LIMITS["stairs_escalators"]:
				return "At most %d stairs and escalators" % FacilityDB.LIMITS["stairs_escalators"]
		"fastfood", "restaurant", "shop":
			if tower.count_retail() >= FacilityDB.LIMITS["retail"]:
				return "Too many retail units"
		"parking":
			if tower.count_of_type("parking") >= FacilityDB.LIMITS["parking"]:
				return "Too many parking spaces"
		"medical":
			if tower.count_of_type("medical") >= FacilityDB.LIMITS["medical"]:
				return "At most %d medical centres" % FacilityDB.LIMITS["medical"]
		"security":
			if tower.count_of_type("security") >= FacilityDB.LIMITS["security"]:
				return "At most %d security offices" % FacilityDB.LIMITS["security"]
		"cinema", "party_hall":
			if tower.count_venues() >= FacilityDB.LIMITS["venues"]:
				return "At most %d theatres and halls" % FacilityDB.LIMITS["venues"]
		"metro":
			if tower.count_of_type("metro") >= FacilityDB.LIMITS["metro"]:
				return "Only one metro station"
		"cathedral":
			if tower.count_of_type("cathedral") >= FacilityDB.LIMITS["cathedral"]:
				return "Only one cathedral"
	return ""

func _remember_build(entry: Dictionary) -> void:
	entry["at"] = clock.absolute_minute()
	last_build = entry

## How long is left to take the last build back, in tower minutes.
func undo_left() -> float:
	if last_build.is_empty():
		return 0.0
	return maxf(UNDO_MINUTES - (clock.absolute_minute() - float(last_build["at"])), 0.0)

func can_undo() -> bool:
	return undo_left() > 0.0

## Take the last thing back and hand the money over. Tenants who moved in
## during those two hours go with it -- you are unbuilding the room they are
## standing in, which is the same as bulldozing it.
func undo_build() -> void:
	if not can_undo():
		say("There is nothing left to undo.")
		return
	var e := last_build
	last_build = {}
	match String(e["what"]):
		"facility":
			var f: Facility = tower.facilities.get(int(e["id"]))
			if f == null:
				return
			if f.type == "condo" and f.sold:
				econ.charge(f.sale_price, "Condominium refunded")
			_evict(f)
			tower.bulldoze(f.seg, f.row)
		"shaft":
			var s: Shaft = tower.shafts.get(int(e["id"]))
			if s == null:
				return
			tower.bulldoze(s.seg, s.bottom_row)
		"car":
			var s2: Shaft = tower.shafts.get(int(e["id"]))
			if s2 == null or s2.cars.size() <= 1:
				return
			s2.cars.pop_back()
		"structure":
			tower.unbuild(String(e["type"]), int(e["seg"]), int(e["row"]), int(e["w"]))
	econ.earn_other(int(e["cost"]), "Undone: " + String(e["name"]))
	Audio.play("wreck")
	say("Undone: %s, %s refunded." % [String(e["name"]), Economy.money(int(e["cost"]))])
	tower_changed.emit()

func _fail(reason: String) -> Dictionary:
	Audio.play("deny")
	say(reason)
	return {"ok": false, "reason": reason}

func try_bulldoze(seg: int, row: int) -> void:
	var res := tower.bulldoze(seg, row)
	if String(res.get("kind", "")) == "refuse":
		say("The cinema cannot be demolished.")
		return
	if not res["ok"]:
		return
	Audio.play("wreck")
	if String(res["kind"]) == "facility":
		var refund: int = int(res.get("refund", 0))
		if refund < 0:
			econ.charge(-refund, "Condominium refunded")
		say("Demolished.")
	else:
		say("Elevator shaft demolished.")
	tower_changed.emit()

# --- explosions ------------------------------------------------------------

func _explode(seg: int, row: int) -> void:
	var r0 := row - Rules.BOMB_RADIUS_FLOORS
	var r1 := row + Rules.BOMB_RADIUS_FLOORS
	var s0 := seg - Rules.BOMB_RADIUS_SEGMENTS / 2
	var s1 := seg + Rules.BOMB_RADIUS_SEGMENTS / 2
	var hit := {}
	for r in range(r0, r1 + 1):
		for c in range(s0, s1 + 1):
			var f := tower.facility_at(c, r)
			if f != null:
				hit[f.id] = f
	for fid in hit:
		var f: Facility = hit[fid]
		_evict(f)
		f.wrecked = true
	tower_changed.emit()

# --- cinema ----------------------------------------------------------------

func change_movie(f: Facility, latest: bool) -> void:
	var price: int = int(f.def()["movie_new"] if latest else f.def()["movie_classic"])
	if not econ.can_afford(price):
		say("Not enough money to change the film.")
		return
	econ.spend_construction(price)
	var pool := Names.MOVIES_NEW if latest else Names.MOVIES_CLASSIC
	f.movie = pool[rng.randi() % pool.size()]
	f.movie_is_new = latest
	f.movie_since_quarter = _abs_quarter()
	say("Now showing: " + f.movie)

# --- answers to dialogs ----------------------------------------------------

func answer(tag: String, yes: bool) -> void:
	match tag:
		"fire_heli":
			if yes:
				if econ.can_afford(Rules.FIRE_HELICOPTER_COST):
					econ.charge(Rules.FIRE_HELICOPTER_COST, "Fire helicopter")
					events.call_helicopter()
				else:
					say("Not enough money for the helicopter.")
		"bomb_pay":
			if yes:
				var d := events.pay_terrorist()
				if d > 0:
					econ.charge(d, "Blackmail")
			else:
				say("You refused. Security is searching for the bomb.")

func claim_santa() -> void:
	var gift := events.claim_santa()
	if gift > 0:
		econ.earn_other(gift, "A present from Santa")

# --- save / load -----------------------------------------------------------

func save_game(path: String = "") -> bool:
	var p := path if path != "" else save_path
	var d := {
		"version": 1,
		"tower": tower.to_dict(),
		"clock": clock.to_dict(),
		"econ": econ.to_dict(),
		"events": events.to_dict(),
		"stars": stars, "weather": weather,
	}
	var fh := FileAccess.open(p, FileAccess.WRITE)
	if fh == null:
		say("Could not save.")
		return false
	fh.store_string(JSON.stringify(d))
	fh.close()
	say("Game saved.")
	return true

func load_game(path: String = "") -> bool:
	var p := path if path != "" else save_path
	if not FileAccess.file_exists(p):
		say("No saved game found.")
		return false
	var fh := FileAccess.open(p, FileAccess.READ)
	var parsed = JSON.parse_string(fh.get_as_text())
	fh.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		say("That save file is damaged.")
		return false
	new_game()
	var d: Dictionary = parsed
	tower.from_dict(d["tower"])
	clock.from_dict(d["clock"])
	econ.from_dict(d["econ"])
	events.from_dict(d.get("events", {}))
	stars = int(d.get("stars", 1))
	weather = String(d.get("weather", "clear"))
	# Repopulate: leases are re-established at the next rest period.
	for fid in tower.facilities:
		var f: Facility = tower.facilities[fid]
		f.occupants.clear()
		f.checked_in = 0
		f.vacant = true
	engine.plan_day(clock.is_weekend(), clock.day_in_quarter)
	tower_changed.emit()
	star_changed.emit(stars)
	say("Game loaded.")
	return true
