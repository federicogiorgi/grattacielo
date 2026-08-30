extends UIKit.GWindow
class_name TenantWindow

## Who they are, where they belong, where they are going and how they feel
## about it -- and the Rename button, which is how you tag someone so the
## Find Person window can hunt them down later.

var sim_id: int = -1
var name_lbl: Label
var from_lbl: Label
var eval_gauge: UIKit.Gauge
var going_lbl: Label
var stress_gauge: UIKit.Gauge
var rename_row: HBoxContainer
var name_edit: LineEdit

func _init() -> void:
	super("Tenant")
	name_lbl = UIKit.label("", 15)
	body.add_child(name_lbl)
	from_lbl = UIKit.label("", 12)
	body.add_child(from_lbl)

	var e := HBoxContainer.new()
	e.add_child(UIKit.label("Eval  ", 12))
	eval_gauge = UIKit.Gauge.new()
	e.add_child(eval_gauge)
	body.add_child(e)

	going_lbl = UIKit.label("", 12)
	body.add_child(going_lbl)

	var s := HBoxContainer.new()
	s.add_child(UIKit.label("Stress", 12))
	stress_gauge = UIKit.Gauge.new()
	s.add_child(stress_gauge)
	body.add_child(s)

	rename_row = HBoxContainer.new()
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size.x = 150
	name_edit.placeholder_text = "a name"
	rename_row.add_child(name_edit)
	rename_row.add_child(UIKit.button("Rename", _rename))
	rename_row.add_child(UIKit.button("Delete", _unname))
	body.add_child(rename_row)

func show_sim(id: int) -> void:
	sim_id = id
	refresh()
	show()
	move_to_front()

func refresh() -> void:
	var s: Sim = Game.engine.sims.get(sim_id)
	if s == null:
		hide()
		return
	name_lbl.text = s.display_name()
	var home_id := s.work_id if s.work_id != -1 else s.home_id
	var f: Facility = Game.tower.facilities.get(home_id)
	if f != null:
		from_lbl.text = "From: %s, floor %s" % [f.title(), FacilityDB.row_label(f.row)]
		eval_gauge.set_gauge(f.quality / 300.0, Rules.eval_colour(f.eval))
	else:
		from_lbl.text = "From: outside the tower"
		eval_gauge.set_gauge(1.0, Color(0.6, 0.6, 0.6))
	going_lbl.text = "Going to: " + _going(s)
	stress_gauge.set_gauge(1.0 - s.stress / Rules.STRESS_MAX,
		Rules.eval_colour(Rules.eval_of_quality(300.0 - s.stress)),
		"%d" % int(s.stress))
	name_edit.text = s.person_name

func _going(s: Sim) -> String:
	match s.state:
		Sim.State.OUTSIDE:
			return "outside the tower"
		Sim.State.WAITING:
			return "waiting for a lift on floor " + FacilityDB.row_label(s.row)
		Sim.State.RIDING:
			return "riding up to floor " + FacilityDB.row_label(s.target_row)
		Sim.State.STAIRS:
			return "on the stairs"
		Sim.State.WALKING:
			return "walking along floor " + FacilityDB.row_label(s.row)
	var d: Facility = Game.tower.facilities.get(s.dest_id)
	if d != null:
		return d.title()
	return "nowhere, for the moment"

func _rename() -> void:
	var s: Sim = Game.engine.sims.get(sim_id)
	if s == null:
		return
	var n := name_edit.text.strip_edges()
	if n == "":
		return
	if s.person_name == "" and Game.engine.named_sims.size() \
			>= FacilityDB.LIMITS["named_sims"]:
		Game.say("You can follow at most %d people." % FacilityDB.LIMITS["named_sims"])
		return
	s.person_name = n
	if not Game.engine.named_sims.has(sim_id):
		Game.engine.named_sims.append(sim_id)
	refresh()

func _unname() -> void:
	var s: Sim = Game.engine.sims.get(sim_id)
	if s == null:
		return
	s.person_name = ""
	Game.engine.named_sims.erase(sim_id)
	refresh()
