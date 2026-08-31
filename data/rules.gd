extends RefCounted
class_name Rules

## The rules of the simulation that are not "what a thing costs" -- star
## ratings, stress, the shape of a day, how patrons decide to come back.
## Kept apart from FacilityDB so a rule change never touches the catalogue.

# --- Time ------------------------------------------------------------------
# A quarter is three days: two weekdays and one weekend day. Four quarters a
# year. The clock runs 00:00..24:00 but the game speeds through the small
# hours and slows down at rush hour, exactly as the manual describes.
const DAYS_PER_QUARTER := 3
const QUARTERS_PER_YEAR := 4
const WEEKEND_DAY := 2          # index within the quarter (0,1 = WD, 2 = WE)

# Minutes of game time per real second, by hour of day. The original ran fast
# at dawn and crawled through the two rush hours; this is that curve.
const HOUR_SPEED := [
	# 0     1     2     3     4     5     6     7     8     9    10    11
	120.0, 120.0, 120.0, 120.0, 120.0, 90.0, 40.0, 20.0, 10.0, 16.0, 24.0, 16.0,
	# 12    13    14    15    16    17    18    19    20    21    22    23
	10.0, 12.0, 24.0, 24.0, 20.0, 10.0, 12.0, 16.0, 20.0, 24.0, 40.0, 80.0,
]

## The whole clock was running twice as fast as it should. Rather than retune
## twenty-four hand-set numbers, the curve keeps its shape and is halved here:
## what used to be x0.5 is now x1, and every other setting follows.
const CLOCK_SCALE := 0.5

const DAY_START_MIN := 0
const DAY_END_MIN := 24 * 60

# --- Stress ----------------------------------------------------------------
# Straight from "Inside the Simulation": stress tops out at 300; under 80 the
# sim is drawn black, 80..120 pink, over 120 red.
const STRESS_MAX := 300.0
const STRESS_PINK := 80.0
const STRESS_RED := 120.0
# Stress accrues per minute of game time spent travelling or queueing.
const STRESS_PER_MIN_WAITING := 2.2
const STRESS_PER_MIN_WALKING := 0.7
const STRESS_PER_MIN_RIDING := 0.35
const STRESS_ESCALATOR := 0.0      # the manual: no wait, so no stress
const STRESS_RELIEF_AT_REST := 26.0   # shed each rest period once arrived

# --- Space quality ---------------------------------------------------------
# Quality = 300 - average stress. Over 200 is an A (blue), 150..200 a B
# (yellow), under 150 a C (red) and the tenants leave.
const QUALITY_A := 200.0
const QUALITY_B := 150.0

enum Eval { A, B, C }

# --- Patronage -------------------------------------------------------------
# Restaurants and fast food open with ten customers and drift by their rating.
const PATRON_START := 10
const FOOD_RATING_A := 25       # more than this many customers: A
const FOOD_RATING_C := 18       # fewer than this: C
const SHOP_RATING_A := 20
const SHOP_RATING_C := 15
const PATRON_DELTA_A := 3       # A: the customer brings a friend
const PATRON_DELTA_B := 0
const PATRON_DELTA_C := -4
const RAIN_PATRON_FACTOR := 0.5 # "rainy days get about half the normal traffic"

# --- Star ratings ----------------------------------------------------------
# Population thresholds and the extra conditions each level demands.
const STARS := [
	{
		"stars": 1, "name": "1 star", "pop": 0,
		"needs": [],
	},
	{
		"stars": 2, "name": "2 stars", "pop": 300,
		"needs": [],
	},
	{
		"stars": 3, "name": "3 stars", "pop": 1000,
		"needs": ["security"],
	},
	{
		"stars": 4, "name": "4 stars", "pop": 5000,
		"needs": ["hotel_suite", "medical", "recycling", "vip"],
	},
	{
		"stars": 5, "name": "5 stars", "pop": 10000,
		"needs": ["metro"],
	},
	{
		"stars": 6, "name": "TOWER", "pop": 15000,
		"needs": ["cathedral"],
	},
]

# --- Movement --------------------------------------------------------------
const MAX_STAIR_FLIGHTS := 4        # "won't use more than four sets of stairs"
const MAX_ESCALATOR_RIDES := 7      # the manual's figure
const MAX_ELEVATOR_TRANSFERS := 1   # "transfer from one elevator to another only once"
const WALK_SEGMENTS_PER_MIN := 22.0 # walking speed along a floor
const STAIR_MINUTES := 1.4          # one flight of stairs
const ESCALATOR_MINUTES := 0.7
const ELEVATOR_FLOORS_PER_MIN := 9.0
const EXPRESS_FLOORS_PER_MIN := 22.0
const ELEVATOR_DOOR_MINUTES := 0.25 # per stop, doors open and shut
const SKY_LOBBY_EVERY := 15         # sky lobbies, and express stops

# --- Noise -----------------------------------------------------------------
# Radial broadcasting: a tenant is annoyed by neighbours above, below and
# beside. These are the separations the original wanted.
const NOISE_FOOD_TO_OFFICE := 11    # empty segments between fast food and offices
const NOISE_TO_HOTEL := 21          # between an office and a hotel room
const NOISE_PENALTY := 34.0         # stress added to a badly-placed neighbour

# --- Services --------------------------------------------------------------
const ROOMS_PER_HOUSEKEEPER := 8
const DIRTY_ROOM_DAYS_TO_ROACHES := 2
const SECURITY_PER_POPULATION := 1000
const RECYCLING_PER_POPULATION := 4000
const MEDICAL_PER_POPULATION := 4000

# --- Events ----------------------------------------------------------------
const FIRE_HELICOPTER_COST := 500000
const TREASURE_VALUE := 500000
const TERRORIST_DEMAND := [100000, 250000, 500000]
const BOMB_HOUR := 13               # "the bomb will always explode at 1:00 pm"
const BOMB_RADIUS_SEGMENTS := 24    # at least three condos wide
const BOMB_RADIUS_FLOORS := 2       # five floors tall in total
const SANTA_HOUR := 21              # night of the last day of the last quarter
const SANTA_GIFT := 250000

# Odds per quarter that each event fires at all.
const P_FIRE := 0.10
const P_TERRORIST := 0.09
const P_TREASURE := 0.07
const P_VIP := 0.35

# --- Rent tiers ------------------------------------------------------------
# How a tenant feels about what you charge. Index matches FacilityDB rents.
const RENT_STRESS := [-22.0, -8.0, 0.0, 20.0]
const RENT_LABELS := ["Very Low", "Low", "Average", "High"]

static func eval_of_quality(q: float) -> int:
	if q >= QUALITY_A:
		return Eval.A
	if q >= QUALITY_B:
		return Eval.B
	return Eval.C

static func eval_colour(e: int) -> Color:
	match e:
		Eval.A: return Color(0.24, 0.48, 0.92)
		Eval.B: return Color(0.94, 0.80, 0.20)
		_: return Color(0.86, 0.20, 0.18)

static func stress_colour(s: float) -> Color:
	if s < STRESS_PINK:
		return Color(0.09, 0.09, 0.12)
	if s < STRESS_RED:
		return Color(0.92, 0.45, 0.62)
	return Color(0.88, 0.16, 0.14)

## Minutes of game time that pass per real-time second at a given clock hour.
static func speed_at(minute_of_day: int) -> float:
	var h := clampi(minute_of_day / 60, 0, 23)
	return HOUR_SPEED[h] * CLOCK_SCALE

static func is_weekend(day_in_quarter: int) -> bool:
	return day_in_quarter == WEEKEND_DAY
