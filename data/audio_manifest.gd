extends RefCounted
class_name AudioManifest

## Every sound in the game, by logical name.
##
## Game code says `Audio.play("cash")`; it never names a file, a bus or a
## level. Replacing a sound is an edit here and nowhere else -- the same rule
## the facility catalogue follows, for the same reason.
##
## Provenance for every recording is in assets/audio/CREDITS.md.

const SFX_DIR := "res://assets/audio/sfx/"
const AMB_DIR := "res://assets/audio/ambience/"
const MUSIC_DIR := "res://assets/audio/music/"

# --- one-shots -------------------------------------------------------------
# db is the level this sound plays at, relative to its bus. They were matched
# on RMS when they were cut, so these are small taste adjustments only.
const SFX := {
	"ding":     {"file": "ding.ogg", "db": -16.0, "channel": "elevators"},
	"doors":    {"file": "doors.ogg", "db": -18.0, "channel": "elevators"},
	"cash":     {"file": "cash.ogg", "db": -14.0, "channel": "events"},
	"spend":    {"file": "spend.ogg", "db": -17.0, "channel": "events"},
	"build":    {"file": "build.ogg", "db": -12.0, "channel": "background"},
	"wreck":    {"file": "wreck.ogg", "db": -11.0, "channel": "background"},
	"click":    {"file": "click.ogg", "db": -15.0, "channel": "events"},
	"deny":     {"file": "deny.ogg", "db": -13.0, "channel": "events"},
	"bad":      {"file": "bad.ogg", "db": -11.0, "channel": "events"},
	"fanfare":  {"file": "fanfare.ogg", "db": -5.0, "channel": "events"},
	"alarm":    {"file": "alarm.ogg", "db": -7.0, "channel": "events"},
	"boom":     {"file": "boom.ogg", "db": -4.0, "channel": "events"},
	"treasure": {"file": "treasure.ogg", "db": -6.0, "channel": "events"},
	"church":   {"file": "church.ogg", "db": -8.0, "channel": "events"},
	"bells":    {"file": "bells.ogg", "db": -6.0, "channel": "events"},
	"sleigh":   {"file": "sleigh.ogg", "db": -12.0, "channel": "events"},
	"train":    {"file": "train.ogg", "db": -14.0, "channel": "background"},
}

# --- looping beds ----------------------------------------------------------
# Each one fades independently to whatever level the tower currently justifies,
# so the mix changes with the clock, the weather and how busy the place is.
const BEDS := {
	"amb_day":   {"file": "amb_day.ogg", "db": -14.0},
	"amb_night": {"file": "amb_night.ogg", "db": -17.0},
	"amb_lobby": {"file": "amb_lobby.ogg", "db": -15.0},
	"amb_rain":  {"file": "amb_rain.ogg", "db": -13.0},
	"amb_fire":  {"file": "amb_fire.ogg", "db": -9.0},
}

# --- music -----------------------------------------------------------------
const MUSIC := {
	"day":   {"file": "day.ogg", "db": -18.0},
	"night": {"file": "night.ogg", "db": -20.0},
	"rush":  {"file": "rush.ogg", "db": -18.0},
}

const FADE_MUSIC := 3.5      # seconds to cross-fade one track into another
const FADE_BED := 2.5
const OFF_DB := -60.0

static func sfx_path(name: String) -> String:
	return SFX_DIR + String(SFX[name]["file"])

static func bed_path(name: String) -> String:
	return AMB_DIR + String(BEDS[name]["file"])

static func music_path(name: String) -> String:
	return MUSIC_DIR + String(MUSIC[name]["file"])

## Which music the tower should be playing right now.
static func track_for(minute_of_day: int, weekend: bool) -> String:
	var h := float(minute_of_day) / 60.0
	if h < 6.0 or h >= 20.0:
		return "night"
	if not weekend and ((h >= 7.5 and h < 9.5) or (h >= 17.0 and h < 19.0)):
		return "rush"
	return "day"
