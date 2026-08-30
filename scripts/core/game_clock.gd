extends RefCounted
class_name GameClock

## Tower time. A quarter is three days, two weekdays and a weekend; four
## quarters make a year. The clock races through the small hours and crawls
## through rush hour, which is when your design decisions actually show.

var minute: float = 6.0 * 60.0    # opens just before dawn
var day_in_quarter: int = 0
var quarter: int = 1              # 1..4
var year: int = 1
var speed: float = 1.0            # player-facing multiplier
var paused: bool = false

signal minute_passed(m: int)
signal day_started(day_in_quarter: int, weekend: bool)
signal day_ended()
signal quarter_ended(quarter: int, year: int)
signal year_ended(year: int)

var _last_int_minute: int = -1

func is_weekend() -> bool:
	return day_in_quarter == Rules.WEEKEND_DAY

func minute_of_day() -> int:
	return int(minute) % (24 * 60)

func hour() -> int:
	return minute_of_day() / 60

func clock_text() -> String:
	var m := minute_of_day()
	return "%02d:%02d" % [m / 60, m % 60]

func date_text() -> String:
	var d := "WE" if is_weekend() else "WD"
	return "%s  Q%d  Year %d" % [d, quarter, year]

## Is this the very last night of the year? Santa only comes then.
func is_last_night_of_year() -> bool:
	return quarter == Rules.QUARTERS_PER_YEAR \
		and day_in_quarter == Rules.DAYS_PER_QUARTER - 1

func advance(delta: float) -> void:
	if paused:
		return
	var rate := Rules.speed_at(minute_of_day()) * speed
	minute += rate * delta
	var m := int(minute)
	if _last_int_minute < 0:
		_last_int_minute = m
		return
	# Emit every minute crossed, but never spend forever catching up.
	var steps := mini(m - _last_int_minute, 240)
	for i in range(steps):
		_last_int_minute += 1
		var mod := _last_int_minute % (24 * 60)
		minute_passed.emit(mod)
		if mod == 0:
			_roll_day()

func _roll_day() -> void:
	day_ended.emit()
	day_in_quarter += 1
	if day_in_quarter >= Rules.DAYS_PER_QUARTER:
		day_in_quarter = 0
		quarter_ended.emit(quarter, year)
		quarter += 1
		if quarter > Rules.QUARTERS_PER_YEAR:
			quarter = 1
			year_ended.emit(year)
			year += 1
	day_started.emit(day_in_quarter, is_weekend())

func to_dict() -> Dictionary:
	return {"minute": minute, "day": day_in_quarter, "quarter": quarter, "year": year}

func from_dict(d: Dictionary) -> void:
	minute = float(d.get("minute", 360.0))
	day_in_quarter = int(d.get("day", 0))
	quarter = int(d.get("quarter", 1))
	year = int(d.get("year", 1))
	_last_int_minute = int(minute)
