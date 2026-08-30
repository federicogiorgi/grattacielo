extends UIKit.GWindow
class_name FacilityWindow

## What the magnifying glass shows you about a shop, an office or a room:
## how it is doing, what you charge, and who is inside.

signal tenant_picked(sim_id: int)

var fac_id: int = -1
var title_lbl: Label
var status_lbl: Label
var eval_gauge: UIKit.Gauge
var length_lbl: Label
var rent_row: HBoxContainer
var rent_option: OptionButton
var message_lbl: Label
var occupants: ItemList
var extra: VBoxContainer

func _init() -> void:
	super("Facility")
	title_lbl = UIKit.label("", 15)
	body.add_child(title_lbl)
	status_lbl = UIKit.label("", 12)
	body.add_child(status_lbl)

	var er := HBoxContainer.new()
	body.add_child(er)
	er.add_child(UIKit.label("Eval", 12))
	eval_gauge = UIKit.Gauge.new()
	er.add_child(eval_gauge)

	length_lbl = UIKit.label("", 12)
	body.add_child(length_lbl)

	rent_row = HBoxContainer.new()
	body.add_child(rent_row)
	rent_row.add_child(UIKit.label("Rent", 12))
	rent_option = OptionButton.new()
	rent_option.focus_mode = Control.FOCUS_NONE
	rent_option.item_selected.connect(_on_rent)
	rent_row.add_child(rent_option)

	message_lbl = UIKit.label("", 12, Color(0.30, 0.28, 0.24))
	message_lbl.custom_minimum_size.x = 260
	message_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(message_lbl)

	extra = VBoxContainer.new()
	body.add_child(extra)

	occupants = ItemList.new()
	occupants.custom_minimum_size = Vector2(260, 92)
	occupants.max_columns = 4
	occupants.item_selected.connect(func(i):
		var sid := int(occupants.get_item_metadata(i))
		tenant_picked.emit(sid))
	body.add_child(occupants)

	visibility_changed.connect(func():
		Game.hold_pause("facility", visible))

func show_facility(id: int) -> void:
	fac_id = id
	refresh()
	show()
	move_to_front()

func refresh() -> void:
	var f: Facility = Game.tower.facilities.get(fac_id)
	if f == null:
		hide()
		return
	set_title("Floor " + FacilityDB.row_label(f.row))
	title_lbl.text = f.title()
	var d := f.def()

	if f.wrecked:
		status_lbl.text = "Destroyed"
	elif f.roaches:
		status_lbl.text = "Cockroach infestation -- must be demolished"
	elif f.kind() == FacilityDB.Kind.CONDO:
		status_lbl.text = "Sold" if f.sold else "For sale"
	elif f.kind() == FacilityDB.Kind.HOTEL:
		status_lbl.text = ("Occupied" if not f.occupants.is_empty() else "Vacant") \
			+ ("  (needs cleaning)" if f.dirty else "")
	elif f.kind() in [FacilityDB.Kind.FOOD, FacilityDB.Kind.SHOP]:
		status_lbl.text = "%d customers today (%d regulars)" % [f.patrons_today, f.patrons]
	else:
		status_lbl.text = "Occupied" if not f.occupants.is_empty() else "Vacant"

	var q := f.quality / 300.0
	var col := Rules.eval_colour(f.eval)
	var cap := ""
	if f.kind() in [FacilityDB.Kind.FOOD, FacilityDB.Kind.SHOP]:
		q = clampf(float(f.patrons_today) / maxf(float(f.capacity()), 1.0), 0.0, 1.0)
		col = Rules.eval_colour(f.patron_rating())
		cap = str(f.patrons_today)
	eval_gauge.set_gauge(q, col, cap)

	var age: int = maxi(0, Game._abs_quarter() - f.built_quarter)
	length_lbl.text = "Open for %d quarter%s" % [age, "" if age == 1 else "s"]

	rent_row.visible = d.has("rents") and f.kind() != FacilityDB.Kind.CONDO or \
		(f.kind() == FacilityDB.Kind.CONDO and not f.sold)
	if d.has("rents"):
		rent_option.clear()
		var per := "a quarter" if int(d["income"]) == FacilityDB.Income.QUARTERLY_RENT else ""
		if int(d["income"]) == FacilityDB.Income.DAILY_RENT:
			per = "a night"
		if int(d["income"]) == FacilityDB.Income.ONE_TIME_SALE:
			per = "sale price"
		for i in range(4):
			rent_option.add_item("%s  %s %s" % [Rules.RENT_LABELS[i],
				Economy.money(int(d["rents"][i])), per])
		rent_option.select(clampi(f.rent_tier, 0, 3))
		rent_option.disabled = f.kind() == FacilityDB.Kind.CONDO and f.sold

	message_lbl.text = _mood(f)

	for c in extra.get_children():
		c.queue_free()
	if f.type == "cinema":
		extra.add_child(UIKit.label("Now showing: " + f.movie, 12))
		extra.add_child(UIKit.label("Today's takings: "
			+ Economy.money(int(round(float(int(d["take"])) * float(f.patrons_today)
			/ maxf(float(f.capacity()), 1.0)))), 12))
		var hb := HBoxContainer.new()
		hb.add_child(UIKit.button("Latest movies  " + Economy.money(int(d["movie_new"])),
			func(): Game.change_movie(f, true); refresh()))
		hb.add_child(UIKit.button("The classics  " + Economy.money(int(d["movie_classic"])),
			func(): Game.change_movie(f, false); refresh()))
		extra.add_child(hb)
	elif f.kind() == FacilityDB.Kind.FOOD:
		extra.add_child(UIKit.label("Today's takings: " + Economy.money(f.takings_today), 12))

	occupants.clear()
	for sid in f.occupants:
		var s: Sim = Game.engine.sims.get(sid)
		if s == null:
			continue
		var i := occupants.add_item(s.display_name())
		occupants.set_item_metadata(i, sid)
		occupants.set_item_custom_fg_color(i, s.colour())
	occupants.visible = not f.occupants.is_empty()

func _mood(f: Facility) -> String:
	if f.wrecked:
		return "There is nothing left here. You can rebuild."
	if f.roaches:
		return "The cockroaches have taken the room."
	match f.kind():
		FacilityDB.Kind.FOOD:
			match f.patron_rating():
				Rules.Eval.A: return "Business is booming."
				Rules.Eval.B: return "We are getting by."
				_: return "Nobody can get up here."
		FacilityDB.Kind.SHOP:
			match f.patron_rating():
				Rules.Eval.A: return "The shop is full of people."
				Rules.Eval.B: return "Trade is fair."
				_: return "This cannot go on. The shopkeeper is threatening to leave."
		_:
			match f.eval:
				Rules.Eval.A: return "It is a pleasure to be here."
				Rules.Eval.B: return "Good enough, though it could be better."
				_: return "We are sick of waiting for the elevators."
	return ""

func _on_rent(i: int) -> void:
	var f: Facility = Game.tower.facilities.get(fac_id)
	if f == null:
		return
	if f.kind() == FacilityDB.Kind.CONDO and f.sold:
		Game.say("You cannot change the price of a sold condominium.")
		return
	f.rent_tier = i
	if f.kind() == FacilityDB.Kind.CONDO:
		f.sale_price = f.rent()
	refresh()
