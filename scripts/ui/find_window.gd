extends UIKit.GWindow
class_name FindWindow

## Find Person: everyone you have named, and a button that scrolls the Edit
## window to wherever they happen to be.

signal locate(sim_id: int)

var list: ItemList

func _init() -> void:
	super("Find Person")
	list = ItemList.new()
	list.custom_minimum_size = Vector2(200, 160)
	body.add_child(list)
	var row := HBoxContainer.new()
	row.add_child(UIKit.button("Find", _find))
	row.add_child(UIKit.button("Close", func(): hide()))
	body.add_child(row)
	visibility_changed.connect(func():
		if visible:
			refresh())

func refresh() -> void:
	list.clear()
	for sid in Game.engine.named_sims:
		var s: Sim = Game.engine.sims.get(sid)
		if s == null:
			continue
		var i := list.add_item(s.person_name)
		list.set_item_metadata(i, sid)
	if list.item_count == 0:
		list.add_item("(nobody yet -- use Rename)")
		list.set_item_disabled(0, true)

func _find() -> void:
	var sel := list.get_selected_items()
	if sel.is_empty():
		return
	var md = list.get_item_metadata(sel[0])
	if md == null:
		return
	locate.emit(int(md))
