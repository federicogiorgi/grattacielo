extends RefCounted
class_name Economy

## Funds, and the quarterly balance sheet the finance window shows.

var funds: int = FacilityDB.STARTING_FUNDS

# The current quarter's ledger, by line.
var income: Dictionary = {}
var maintenance: Dictionary = {}
var construction: int = 0
var other_income: int = 0
var last_quarter_balance: int = 0
var quarter_start_funds: int = FacilityDB.STARTING_FUNDS

const INCOME_LINES := ["office", "condo", "hotel", "fastfood", "restaurant",
	"shop", "party_hall", "cinema", "metro"]
const MAINT_LINES := ["lobby", "elevator", "service_elevator", "express_elevator",
	"escalator", "housekeeping", "security", "medical", "recycling",
	"parking_ramp", "metro"]

signal funds_changed(funds: int)
signal transaction(label: String, amount: int)

func _init() -> void:
	reset_quarter()

func reset_quarter() -> void:
	income.clear()
	maintenance.clear()
	for k in INCOME_LINES:
		income[k] = 0
	for k in MAINT_LINES:
		maintenance[k] = 0
	construction = 0
	other_income = 0
	quarter_start_funds = funds

func can_afford(amount: int) -> bool:
	return funds >= amount

func spend_construction(amount: int, label: String = "") -> void:
	funds -= amount
	construction += amount
	funds_changed.emit(funds)
	if label != "":
		transaction.emit(label, -amount)

func earn(line: String, amount: int, label: String = "") -> void:
	funds += amount
	if income.has(line):
		income[line] += amount
	else:
		income[line] = amount
	funds_changed.emit(funds)
	if label != "":
		transaction.emit(label, amount)

func earn_other(amount: int, label: String = "") -> void:
	funds += amount
	other_income += amount
	funds_changed.emit(funds)
	if label != "":
		transaction.emit(label, amount)

func pay(line: String, amount: int, label: String = "") -> void:
	funds -= amount
	if maintenance.has(line):
		maintenance[line] += amount
	else:
		maintenance[line] = amount
	funds_changed.emit(funds)
	if label != "":
		transaction.emit(label, -amount)

## A one-off charge that is neither construction nor routine upkeep.
func charge(amount: int, label: String = "") -> void:
	funds -= amount
	other_income -= amount
	funds_changed.emit(funds)
	if label != "":
		transaction.emit(label, -amount)

func total_income() -> int:
	var t := 0
	for k in income:
		t += income[k]
	return t

func total_maintenance() -> int:
	var t := 0
	for k in maintenance:
		t += maintenance[k]
	return t

func net_revenue() -> int:
	return total_income() + other_income - total_maintenance() - construction

func close_quarter() -> void:
	last_quarter_balance = funds - quarter_start_funds
	reset_quarter()

func to_dict() -> Dictionary:
	return {
		"funds": funds, "income": income, "maintenance": maintenance,
		"construction": construction, "other": other_income,
		"last": last_quarter_balance, "start": quarter_start_funds,
	}

func from_dict(d: Dictionary) -> void:
	funds = int(d.get("funds", FacilityDB.STARTING_FUNDS))
	income = d.get("income", {}).duplicate()
	maintenance = d.get("maintenance", {}).duplicate()
	construction = int(d.get("construction", 0))
	other_income = int(d.get("other", 0))
	last_quarter_balance = int(d.get("last", 0))
	quarter_start_funds = int(d.get("start", funds))

static func money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + "$" + out
