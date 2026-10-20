class_name Style
extends RefCounted

const BG := Color("14161c")
const PANEL := Color("1f232d")
const PANEL_LIGHT := Color("2a2f3c")
const ACCENT := Color("ffd23f")
const TEXT := Color("e8eaf0")
const MUTED := Color("8a90a0")
const GOOD := Color("5fd38d")
const BAD := Color("ff6b6b")


static func box(color: Color, radius := 8, border := Color(0, 0, 0, 0), border_w := 0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.border_color = border
	b.set_border_width_all(border_w)
	b.content_margin_left = 12
	b.content_margin_right = 12
	b.content_margin_top = 8
	b.content_margin_bottom = 8
	return b


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	t.set_stylebox("normal", "Button", box(PANEL_LIGHT, 8, Color("3a4152"), 1))
	t.set_stylebox("hover", "Button", box(Color("37405a"), 8, ACCENT, 1))
	t.set_stylebox("pressed", "Button", box(Color("4a5578"), 8, ACCENT, 2))
	t.set_stylebox("disabled", "Button", box(Color("1b1e27"), 8, Color("262b38"), 1))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color("4b5163"))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 10, Color("2d3342"), 1))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	return t


static func title_font() -> Font:
	var f = load("res://assets/ui/joystix.otf") if ResourceLoader.exists("res://assets/ui/joystix.otf") else null
	return f if f != null else ThemeDB.fallback_font


static func title(l: Label, size: int, color := ACCENT) -> void:
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(4, size / 8))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 4)


## Botão grande de menu (o primário ganha destaque dourado).
static func menu_button(text: String, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, Platform.button_height() + (16 if primary else 8))
	b.add_theme_font_size_override("font_size", 22 if primary else 18)
	if primary:
		b.add_theme_stylebox_override("normal", box(Color("4a3d12"), 10, ACCENT, 2))
		b.add_theme_stylebox_override("hover", box(Color("6a5818"), 10, Color("fff0a0"), 3))
		b.add_theme_stylebox_override("pressed", box(Color("86701e"), 10, Color("fff0a0"), 3))
		b.add_theme_color_override("font_color", Color("fff0a0"))
	return b
