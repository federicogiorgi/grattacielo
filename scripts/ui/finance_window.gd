extends UIKit.GWindow
class_name FinanceWindow

## The quarterly balance sheet.

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

func _init() -> void:
	super("Finance")
	header = UIKit.label("", 13)
	body.add_child(header)
	body.add_child(UIKit.hsep())
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	body.add_child(grid)
	body.add_child(UIKit.hsep())
	totals = UIKit.label("", 13)
	body.add_child(totals)
	visibility_changed.connect(func():
		Game.hold_pause("finance", visible)
		if visible:
			refresh())

func refresh() -> void:
	var e: Economy = Game.econ
	header.text = "Quarter %d, year %d" % [Game.clock.quarter, Game.clock.year]
	for c in grid.get_children():
		c.queue_free()
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
			grid.add_child(_num(int(e.income.get(k, 0))))
		else:
			grid.add_child(UIKit.label("", 12))
			grid.add_child(UIKit.label("", 12))
		if i < mnt.size():
			var k2: String = mnt[i]
			grid.add_child(UIKit.label(MAINT_NAMES[k2], 12))
			grid.add_child(_num(-int(e.maintenance.get(k2, 0))))
		else:
			grid.add_child(UIKit.label("", 12))
			grid.add_child(UIKit.label("", 12))
	totals.text = "Total income        %s\nTotal maintenance   %s\nOther income        %s\nConstruction costs  %s\n\nNet revenue           %s\nLast quarter's balance %s\n\nTOTAL BALANCE  %s" % [
		Economy.money(e.total_income()), Economy.money(-e.total_maintenance()),
		Economy.money(e.other_income), Economy.money(-e.construction),
		Economy.money(e.net_revenue()), Economy.money(e.last_quarter_balance),
		Economy.money(e.funds)]

func _num(v: int) -> Label:
	var l := UIKit.label(Economy.money(v), 12,
		Color(0.62, 0.14, 0.12) if v < 0 else UIKit.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size.x = 96
	return l
