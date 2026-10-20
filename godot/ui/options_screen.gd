class_name OptionsScreen
extends Control
## Opções: volumes, vibração e velocidade dos bots.

signal back_requested


func _ready() -> void:
	add_to_group("screen")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)
	var back := Button.new()
	back.text = "‹ Voltar"
	back.custom_minimum_size = Vector2(110, Platform.button_height())
	back.pressed.connect(func(): back_requested.emit())
	head.add_child(back)
	var title := Label.new()
	title.text = "Opções"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Style.title(title, 24)
	head.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(110, 0)
	head.add_child(spacer)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(560.0, get_viewport_rect().size.x - 28.0), 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var sfx := Sfx.instance
	v.add_child(_slider_row("Efeitos sonoros", sfx.sfx_on, sfx.sfx_volume,
		func(on): sfx.set_sfx(on), func(val):
			sfx.set_sfx_volume(val)
			Sfx.play("pickup")))
	v.add_child(_slider_row("Música", sfx.music_on, sfx.music_volume,
		func(on): sfx.set_music(on), func(val): sfx.set_music_volume(val)))
	if Platform.is_touch():
		var hap := CheckButton.new()
		hap.text = "Vibração"
		hap.button_pressed = sfx.haptics_on
		hap.toggled.connect(func(on):
			sfx.set_haptics(on)
			if on:
				Input.vibrate_handheld(40))
		v.add_child(hap)

	v.add_child(_choice_row("Seus dados (3D)", ["Completa", "Rápida", "Desligada"], sfx.dice_human, func(i): sfx.set_dice_human(i)))
	v.add_child(_choice_row("Dados dos bots", ["Completa", "Curta", "Desligada"], sfx.dice_bots, func(i): sfx.set_dice_bots(i)))

	var sp := Label.new()
	sp.text = "Velocidade dos bots"
	v.add_child(sp)
	var srow := HFlowContainer.new()
	srow.add_theme_constant_override("h_separation", 8)
	v.add_child(srow)
	var group := ButtonGroup.new()
	for n in [1, 2, 4]:
		var b := Button.new()
		b.text = "x%d" % n
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(90, Platform.button_height())
		b.button_pressed = sfx.bot_speed == n
		b.pressed.connect(func(): sfx.set_bot_speed(n))
		srow.add_child(b)

	var about := RichTextLabel.new()
	about.bbcode_enabled = true
	about.fit_content = true
	about.scroll_active = false
	about.text = "[color=#8a90a0]O Último Roubo · v0.1\nSprites e regras do jogo original em Python, reescritos em Godot.\nSons e música gerados por código (tools/gen_sfx.py).[/color]"
	v.add_child(about)


func _choice_row(text: String, options: Array, current: int, on_pick: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = text
	box.add_child(l)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	box.add_child(row)
	var group := ButtonGroup.new()
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(110, Platform.button_height())
		b.button_pressed = i == current
		b.pressed.connect(func(): on_pick.call(i))
		row.add_child(b)
	return box


func _slider_row(text: String, on: bool, value: float, on_toggle: Callable, on_value: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var cb := CheckButton.new()
	cb.text = text
	cb.custom_minimum_size = Vector2(190, 0)
	cb.button_pressed = on
	cb.toggled.connect(on_toggle)
	row.add_child(cb)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = value
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.custom_minimum_size = Vector2(0, 28)
	sl.drag_ended.connect(func(changed): if changed: on_value.call(sl.value))
	sl.value_changed.connect(func(val): if not sl.has_focus() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): on_value.call(val))
	row.add_child(sl)
	return row


func handle_back() -> void:
	back_requested.emit()
