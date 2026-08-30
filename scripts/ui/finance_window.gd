extends UIKit.GWindow
class_name FinanceWindow

## The quarterly balance sheet.
##
## The rows are built once and only their numbers change. An earlier version
## rebuilt them on every refresh with queue_free(), which does not take effect
## until the end of the frame -- so the grid held two copies of itself at all
## times and the window grew until it ran off the bottom of the screen.

const INCOME_NAMES := {
	"office": "Offices", "condo": "Condominiums", "hotel": "Hotel",
	"fastfood": "Fast food", "restaurant": "Restaurants", "shop": "Shops",
	"party_hall": "Party halls", "cinema": "Cinemas", "metro": "Metro",
}
const MAINT_NAMES := {
	"lobby": "Lobby", "elevator": "Elevators", "service_elevator": "Service lifts",
	"express_elevator": "Express lifts", "escalator": "Escalators",
	"housekeeping": "Housekeeping", "security": "Security", "medical": "Medical",
	"recycling": "Recycling", "parking_ramp": "Parking ramps", "metro": "Metro",
}

var grid: GridContainer
var header: Label
var totals: Label
var income_values: Dictionary = {}     # key -> Label
var maint_values: Dictionary = {}

func _init() -> void:
	super("Finance")
	header = UIKit.label("", 13)
	body.add_child(header)
	body.add_child(UIKit.hsep())
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	body.add_child(grid)
	_build_rows()
	body.add_child(UIKit.hsep())
	totals = UIKit.label("", 13)
	body.add_child(totals)
	visibility_changed.connect(func():
		Game.hold_pause("finance", visible)
		if visible:
			refresh())

func _build_rows() -> void:
	grid.add_child(UIKit.label("Income", 12, UIKit.ACCENT))
	grid.add_child(UIKit.label("", 12))
	grid.add_child(UIKit.label("Maintenance", 12, UIKit.ACCENT))
	grid.add_child(UIKit.label("", 12))
	var inc := INCOME_NAMES.keys()
	var mnt := MAINT_NAMES.keys()
	var n: int = maxi(inc.size(), mnt.size())
	for i in range(n):
		if i < inc.size():
			var k: String = inc[i]
			grid.add_child(UIKit.label(INCOME_NAMES[k], 12))
			var v := _num_label()
			income_values[k] = v
			grid.add_child(v)
		else:
			grid.add_child(UIKit.label("", 12))
			grid.add_child(UIKit.label("", 12))
		if i < mnt.size():
			var k2: String = mnt[i]
			grid.add_child(UIKit.label(MAINT_NAMES[k2], 12))
			var v2 := _num_label()
			maint_values[k2] = v2
			grid.add_child(v2)
		else:
			grid.add_child(UIKit.label("", 12))
			grid.add_child(UIKit.label("", 12))

func _num_label() -> Label:
	var l := UIKit.label("", 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size.x = 96
	return l

func refresh() -> void:
	var e: Economy = Game.econ
	header.text = "Quarter %d, year %d" % [Game.clock.quarter, Game.clock.year]
	for k in income_values:
		_set_num(income_values[k], int(e.income.get(k, 0)))
	for k in maint_values:
		_set_num(maint_values[k], -int(e.maintenance.get(k, 0)))
	totals.text = "Total income         %s\nTotal maintenance    %s\nOther income         %s\nConstruction costs   %s\n\nNet revenue            %s\nLast quarter's balance %s\n\nTOTAL BALANCE  %s" % [
		Economy.money(e.total_income()), Economy.money(-e.total_maintenance()),
		Economy.money(e.other_income), Economy.money(-e.construction),
		Economy.money(e.net_revenue()), Economy.money(e.last_quarter_balance),
		Economy.money(e.funds)]

func _set_num(l: Label, v: int) -> void:
	l.text = Economy.money(v)
	l.add_theme_color_override("font_color",
		Color(0.62, 0.14, 0.12) if v < 0 else UIKit.INK)
