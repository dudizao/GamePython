class_name MainMenu
extends Control
## Menu principal: Jogar, Como jogar, Opções e Sair.

signal play_requested
signal options_requested

var _t := 0.0
var _title: Label
var _trophy: TextureRect
var _items: Array[Control] = []


func _ready() -> void:
	add_to_group("screen")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(340, 0)
	center.add_child(col)

	var trow := CenterContainer.new()
	col.add_child(trow)
	_trophy = TextureRect.new()
	_trophy.texture = Art.tex("ui/trofeu.png")
	_trophy.custom_minimum_size = Vector2(72, 72)
	_trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_trophy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	trow.add_child(_trophy)
	_title = Label.new()
	_title.text = "O ÚLTIMO ROUBO"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(minf(720.0, get_viewport_rect().size.x - 24.0), 0)
	Style.title(_title, 40)
	col.add_child(_title)
	var tag := Label.new()
	tag.text = "Junte todos os troféus ou derrote todos os rivais."
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", Style.MUTED)
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	col.add_child(gap)

	var play := Style.menu_button("JOGAR", true)
	play.pressed.connect(func(): play_requested.emit())
	var how := Style.menu_button("Como jogar")
	how.pressed.connect(_open_help)
	var opt := Style.menu_button("Opções")
	opt.pressed.connect(func(): options_requested.emit())
	_items = [play, how, opt]
	if _can_quit():
		var q := Style.menu_button("Sair")
		q.pressed.connect(func(): get_tree().quit())
		_items.append(q)
	for b in _items:
		b.modulate.a = 0.0
		col.add_child(b)
	var ver := Label.new()
	ver.text = "v0.1 · feito com Godot"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Color("5a6178"))
	col.add_child(ver)


func _can_quit() -> bool:
	return OS.get_name() != "iOS" and OS.get_name() != "Web"


func _process(delta: float) -> void:
	_t += delta
	var a := clampf(_t / 0.5, 0.0, 1.0)
	_title.modulate.a = a
	_trophy.modulate.a = a
	_trophy.position.y = sin(_t * 2.4) * 2.0
	# brilho pulsante do título
	var pulse := 0.5 + 0.5 * sin(_t * 2.0)
	_title.add_theme_color_override("font_color", Style.ACCENT.lerp(Color("fff3b0"), pulse * 0.55))
	for i in _items.size():
		_items[i].modulate.a = clampf((_t - 0.25 - i * 0.1) / 0.35, 0.0, 1.0)


func _open_help() -> void:
	if get_node_or_null("Help") != null:
		return
	var h := HelpScreen.new()
	h.name = "Help"
	add_child(h)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_open_help()


func handle_back() -> void:
	var h := get_node_or_null("Help")
	if h != null:
		h.close()
	elif _can_quit():
		get_tree().quit()
