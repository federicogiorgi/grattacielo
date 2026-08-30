extends UIKit.GWindow
class_name AskDialog

## The yes/no boxes the tower throws at you: the terrorist's demand, the fire
## helicopter. Queued, because two can arrive at once.

var text_lbl: Label
var yes_btn: Button
var no_btn: Button
var tag: String = ""
var queue: Array = []

func _init() -> void:
	super("Notice", false)
	text_lbl = UIKit.label("", 13)
	text_lbl.custom_minimum_size = Vector2(320, 0)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(text_lbl)
	var row := HBoxContainer.new()
	yes_btn = UIKit.button("Yes", func(): _answer(true))
	no_btn = UIKit.button("No", func(): _answer(false))
	yes_btn.custom_minimum_size = Vector2(70, 26)
	no_btn.custom_minimum_size = Vector2(70, 26)
	row.add_child(yes_btn)
	row.add_child(no_btn)
	body.add_child(row)
	hide()

func ask(question: String, t: String) -> void:
	queue.append({"q": question, "t": t})
	if not visible:
		_next()

func _next() -> void:
	if queue.is_empty():
		hide()
		return
	var item: Dictionary = queue.pop_front()
	text_lbl.text = String(item["q"])
	tag = String(item["t"])
	position = (get_viewport_rect().size - Vector2(360, 120)) * 0.5
	show()
	move_to_front()

func _answer(v: bool) -> void:
	Game.answer(tag, v)
	_next()
