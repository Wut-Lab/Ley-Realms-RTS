class_name UITheme
extends RefCounted
## Dark parchment-and-bronze UI theme built in code.


static func _box(bg: Color, border: Color, bw: int = 2, radius: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


static func make() -> Theme:
	var t := Theme.new()
	var panel := _box(Color(0.09, 0.075, 0.06, 0.94), Color(0.6, 0.48, 0.26), 2, 6)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("normal", "Button", _box(Color(0.22, 0.18, 0.13), Color(0.5, 0.4, 0.22)))
	t.set_stylebox("hover", "Button", _box(Color(0.32, 0.26, 0.17), Color(0.85, 0.68, 0.35)))
	t.set_stylebox("pressed", "Button", _box(Color(0.14, 0.11, 0.08), Color(1.0, 0.8, 0.4)))
	t.set_stylebox("disabled", "Button", _box(Color(0.12, 0.1, 0.08), Color(0.28, 0.23, 0.15)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color(0.96, 0.9, 0.76))
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.8))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.46, 0.4))
	t.set_font_size("font_size", "Button", 14)
	t.set_color("font_color", "Label", Color(0.96, 0.9, 0.78))
	t.set_font_size("font_size", "Label", 14)
	t.set_stylebox("normal", "OptionButton", _box(Color(0.18, 0.15, 0.11), Color(0.5, 0.4, 0.22)))
	t.set_stylebox("hover", "OptionButton", _box(Color(0.28, 0.22, 0.15), Color(0.85, 0.68, 0.35)))
	t.set_stylebox("pressed", "OptionButton", _box(Color(0.14, 0.11, 0.08), Color(1.0, 0.8, 0.4)))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "OptionButton", Color(0.96, 0.9, 0.76))
	t.set_stylebox("normal", "LineEdit", _box(Color(0.12, 0.1, 0.08), Color(0.5, 0.4, 0.22)))
	t.set_stylebox("focus", "LineEdit", _box(Color(0.14, 0.12, 0.09), Color(0.85, 0.68, 0.35)))
	t.set_color("font_color", "CheckBox", Color(0.96, 0.9, 0.78))
	t.set_stylebox("panel", "PopupMenu", panel)
	t.set_color("font_color", "PopupMenu", Color(0.96, 0.9, 0.78))
	t.set_stylebox("panel", "TooltipPanel", panel)
	t.set_color("font_color", "TooltipLabel", Color(0.96, 0.9, 0.78))
	t.set_color("default_color", "RichTextLabel", Color(0.95, 0.9, 0.8))
	return t
