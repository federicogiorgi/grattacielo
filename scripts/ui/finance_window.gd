extends UIKit.GWindow
class_name FinanceWindow

## The quarterly balance sheet.

const INCOME_NAMES := {
	"office": "Uffici", "condo": "Appartamenti", "hotel": "Albergo",
	"fastfood": "Fast food", "restaurant": "Ristoranti", "shop": "Negozi",
	"party_hall": "Sale feste", "cinema": "Cinema", "metro": "Metropolitana",
}
const MAINT_NAMES := {
	"lobby": "Atrio", "elevator": "Ascensori", "service_elevator": "Montacarichi",
	"express_elevator": "Espressi", "escalator": "Scale mobili",
	"housekeeping": "Pulizie", "security": "Sicurezza", "medical": "Pronto soccorso",
	"recycling": "Riciclaggio", "parking_ramp": "Rampe", "metro": "Metropolitana",
}

var grid: GridContainer
var header: Label
var totals: Label

func _init() -> void:
	super("Bilancio")
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
	header.text = "Trimestre %d, anno %d" % [Game.clock.quarter, Game.clock.year]
	for c in grid.get_children():
		c.queue_free()
	grid.add_child(UIKit.label("Entrate", 12, UIKit.ACCENT))
	grid.add_child(UIKit.label("", 12))
	grid.add_child(UIKit.label("Manutenzione", 12, UIKit.ACCENT))
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
	totals.text = "Entrate totali  %s\nManutenzione   %s\nAltre entrate   %s\nCostruzioni    %s\n\nSaldo del trimestre  %s\nSaldo precedente     %s\n\nTOTALE  %s" % [
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
