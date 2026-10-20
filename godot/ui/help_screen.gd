class_name HelpScreen
extends Control
## Janela de regras. Fecha com o botão ou com Esc/F1.

signal closed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var vp := get_viewport_rect().size
	panel.custom_minimum_size = Vector2(minf(760.0, vp.x - 20.0), minf(640.0, vp.y - 20.0))
	panel.add_theme_stylebox_override("panel", Style.box(Color(0.1, 0.11, 0.15, 0.99), 12, Style.ACCENT, 2))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.text = Texts.help()
	v.add_child(text)
	var b := Button.new()
	b.text = "Fechar"
	b.custom_minimum_size = Vector2(0, Platform.button_height())
	b.pressed.connect(close)
	v.add_child(b)


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_F1):
		get_viewport().set_input_as_handled()
		close()
