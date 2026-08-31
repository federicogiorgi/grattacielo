extends RefCounted
class_name UIKit

## A small set of widgets with one look, so every window in the game matches
## without a theme resource on disk.

const BG := Color(0.84, 0.83, 0.79)
const BG_DARK := Color(0.66, 0.65, 0.61)
const BG_LIGHT := Color(0.93, 0.92, 0.89)
const INK := Color(0.11, 0.11, 0.13)
const ACCENT := Color(0.22, 0.34, 0.55)
const GOLD := Color(0.92, 0.74, 0.20)
const TIP_BG := Color(0.98, 0.97, 0.93)     # tooltips: paper, not smoked glass
const MONEY := Color(0.16, 0.42, 0.24)

static func panel_style(fill: Color = BG, border: Color = INK,
		width: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(3)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

static func make_theme() -> Theme:
	var th := Theme.new()
	var font := ThemeDB.fallback_font
	th.default_font = font
	th.default_font_size = 13

	var btn := panel_style(BG_LIGHT)
	btn.content_margin_left = 8
	btn.content_margin_right = 8
	btn.content_margin_top = 4
	btn.content_margin_bottom = 4
	var btn_hover := panel_style(Color(0.98, 0.97, 0.93))
	var btn_press := panel_style(BG_DARK)
	var btn_disabled := panel_style(Color(0.78, 0.78, 0.76), Color(0.55, 0.55, 0.53))
	th.set_stylebox("normal", "Button", btn)
	th.set_stylebox("hover", "Button", btn_hover)
	th.set_stylebox("pressed", "Button", btn_press)
	th.set_stylebox("disabled", "Button", btn_disabled)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", INK)
	th.set_color("font_hover_color", "Button", INK)
	th.set_color("font_pressed_color", "Button", INK)
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.5))

	th.set_stylebox("panel", "PanelContainer", panel_style())
	th.set_stylebox("panel", "Panel", panel_style())
	th.set_color("font_color", "Label", INK)

	var pop := panel_style(BG_LIGHT)
	th.set_stylebox("panel", "PopupMenu", pop)
	th.set_color("font_color", "PopupMenu", INK)
	th.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	th.set_stylebox("hover", "PopupMenu", panel_style(ACCENT, ACCENT, 0))

	th.set_stylebox("normal", "OptionButton", btn)
	th.set_stylebox("hover", "OptionButton", btn_hover)
	th.set_stylebox("pressed", "OptionButton", btn_press)
	th.set_color("font_color", "OptionButton", INK)

	th.set_stylebox("normal", "LineEdit", panel_style(Color.WHITE))
	th.set_color("font_color", "LineEdit", INK)
	th.set_color("caret_color", "LineEdit", INK)

	# Tooltips. Godot's default panel is dark and translucent, and this theme
	# paints every Label in near-black ink -- which TooltipLabel inherits,
	# because it derives from Label. The two together gave black text on a
	# dark grey wash. Both halves are set here so neither can drift.
	var tip := panel_style(TIP_BG, INK, 2)
	tip.content_margin_left = 10
	tip.content_margin_right = 10
	tip.content_margin_top = 7
	tip.content_margin_bottom = 7
	tip.shadow_color = Color(0, 0, 0, 0.32)
	tip.shadow_size = 5
	tip.shadow_offset = Vector2(1, 2)
	th.set_stylebox("panel", "TooltipPanel", tip)
	th.set_color("font_color", "TooltipLabel", INK)
	th.set_color("font_shadow_color", "TooltipLabel", Color(0, 0, 0, 0))
	th.set_font_size("font_size", "TooltipLabel", 13)

	th.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	th.set_stylebox("panel", "ItemList", panel_style(Color.WHITE))
	th.set_stylebox("background", "ItemList", panel_style(Color.WHITE))
	th.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	th.set_color("font_color", "ItemList", INK)
	th.set_stylebox("selected", "ItemList", panel_style(ACCENT, ACCENT, 0))
	th.set_stylebox("selected_focus", "ItemList", panel_style(ACCENT, ACCENT, 0))
	th.set_color("font_selected_color", "ItemList", Color.WHITE)
	return th

static func label(text: String, size: int = 13, col: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

static func button(text: String, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

## Empty a container NOW. queue_free() alone would leave the old children in
## place for the rest of the frame, which doubles anything rebuilt per tick.
static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

static func hsep() -> HSeparator:
	var s := HSeparator.new()
	return s

## A tooltip with a shape to it: the name, then what it costs, then the
## sentence about it. Three weights of the same ink rather than one, so the
## eye lands on the name first and the price second.
static func tooltip(title: String, price: String, desc: String,
		note: String = "") -> Control:
	var panel := PanelContainer.new()
	var sb := panel_style(TIP_BG, INK, 2)
	sb.content_margin_left = 11
	sb.content_margin_right = 11
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.32)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(1, 2)
	panel.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var t := label(title, 15, INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	if price != "":
		head.add_child(label(price, 14, MONEY))

	if desc != "":
		var rule := ColorRect.new()
		rule.color = Color(INK.r, INK.g, INK.b, 0.22)
		rule.custom_minimum_size.y = 1
		box.add_child(rule)
		var d := label(desc, 12, Color(0.28, 0.27, 0.25))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 300
		box.add_child(d)
	if note != "":
		box.add_child(label(note, 11, Color(0.62, 0.24, 0.18)))
	return panel

## A coloured bar, used for the Eval and Stress readouts.
class Gauge extends Control:
	var value: float = 1.0
	var colour: Color = Color(0.24, 0.48, 0.92)
	var caption: String = ""

	func _init() -> void:
		custom_minimum_size = Vector2(150, 16)

	func set_gauge(v: float, c: Color, cap: String = "") -> void:
		value = clampf(v, 0.0, 1.0)
		colour = c
		caption = cap
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color.WHITE)
		draw_rect(Rect2(r.position, Vector2(r.size.x * value, r.size.y)), colour)
		draw_rect(r, UIKit.INK, false, 1.0)
		if caption != "":
			draw_string(ThemeDB.fallback_font, Vector2(5, r.size.y - 4), caption,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color.WHITE if value > 0.35 else UIKit.INK)

## A floating window with a title bar you can drag and a close box, like the
## original's Tool Bar and Info Bar.
class GWindow extends PanelContainer:
	signal closed()

	var body: VBoxContainer
	var _drag := false
	var _grab := Vector2.ZERO
	var title_label: Label
	var can_close := true

	func _init(title: String = "", closable: bool = true) -> void:
		can_close = closable
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_theme_stylebox_override("panel", UIKit.panel_style())
		var outer := VBoxContainer.new()
		outer.add_theme_constant_override("separation", 4)
		add_child(outer)

		var bar := HBoxContainer.new()
		bar.custom_minimum_size.y = 18
		outer.add_child(bar)
		title_label = UIKit.label(title, 12)
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(title_label)
		if closable:
			var x := Button.new()
			x.text = "X"
			x.custom_minimum_size = Vector2(20, 16)
			x.focus_mode = Control.FOCUS_NONE
			x.add_theme_font_size_override("font_size", 10)
			x.pressed.connect(func(): hide(); closed.emit())
			bar.add_child(x)

		var line := ColorRect.new()
		line.color = UIKit.INK
		line.custom_minimum_size.y = 1
		outer.add_child(line)

		body = VBoxContainer.new()
		body.add_theme_constant_override("separation", 4)
		outer.add_child(body)

	func set_title(t: String) -> void:
		title_label.text = t

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed and e.position.y < 20.0:
				_drag = true
				_grab = e.position
				move_to_front()
				accept_event()
			elif not e.pressed:
				_drag = false
		elif e is InputEventMouseMotion and _drag:
			position += e.relative
			position = position.clamp(Vector2(-size.x + 60.0, 0.0),
				get_viewport_rect().size - Vector2(60, 24))
			accept_event()

	## Keep the whole window inside the viewport, with the title bar reachable.
	func clamp_into(view: Vector2) -> void:
		var s := size
		if s == Vector2.ZERO:
			s = get_combined_minimum_size()
		position.x = clampf(position.x, 0.0, maxf(view.x - s.x, 0.0))
		position.y = clampf(position.y, 0.0, maxf(view.y - s.y, 0.0))

	func open_at(p: Vector2) -> void:
		position = p
		show()
		move_to_front()

	func clear_body() -> void:
		for c in body.get_children():
			c.queue_free()
