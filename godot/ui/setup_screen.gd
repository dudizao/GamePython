class_name SetupScreen
extends Control
## Nova partida: jogadores, classe (cartões grandes) e mapa (miniaturas).

signal start_requested(config: Dictionary)
signal back_requested

static var _players := 3
static var _class := Defs.HeroClass.GUERREIRO
static var _map := 0
static var _watch := false

var _class_cards: Dictionary = {}
var _map_tiles: Dictionary = {}
var _count_buttons: Dictionary = {}
var _summary: Label


func _ready() -> void:
	add_to_group("screen")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# cabeçalho
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)
	var back := Button.new()
	back.text = "‹ Voltar"
	back.custom_minimum_size = Vector2(110, Platform.button_height())
	back.pressed.connect(func(): back_requested.emit())
	head.add_child(back)
	var title := Label.new()
	title.text = "Nova partida"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Style.title(title, 24)
	head.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(110, 0)
	head.add_child(spacer)

	# conteúdo rolável
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	content.add_child(_section("Quantos jogadores?  (você + bots)"))
	var prow := HFlowContainer.new()
	prow.alignment = FlowContainer.ALIGNMENT_CENTER
	prow.add_theme_constant_override("h_separation", 10)
	content.add_child(prow)
	var group := ButtonGroup.new()
	for n in [2, 3, 4]:
		var b := Button.new()
		b.text = "%d jogadores" % n
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(150, Platform.button_height() + 4)
		b.button_pressed = n == _players
		b.pressed.connect(func():
			_players = n
			_update_summary())
		prow.add_child(b)
		_count_buttons[n] = b

	content.add_child(_section("Escolha sua classe"))
	var crow := HFlowContainer.new()
	crow.alignment = FlowContainer.ALIGNMENT_CENTER
	crow.add_theme_constant_override("h_separation", 10)
	crow.add_theme_constant_override("v_separation", 10)
	content.add_child(crow)
	for c in Defs.CLASS_NAMES:
		var card := ClassCard.new(c)
		card.chosen.connect(_on_class)
		crow.add_child(card)
		_class_cards[c] = card
	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.name = "ClassDesc"
	content.add_child(desc)

	content.add_child(_section("Escolha o mapa"))
	var mrow := HFlowContainer.new()
	mrow.alignment = FlowContainer.ALIGNMENT_CENTER
	mrow.add_theme_constant_override("h_separation", 10)
	mrow.add_theme_constant_override("v_separation", 10)
	content.add_child(mrow)
	var ids: Array = [0]
	ids.append_array(Board.MAP_NAMES.keys())
	for id in ids:
		var tile := MapTile.new(id)
		tile.chosen.connect(_on_map)
		mrow.add_child(tile)
		_map_tiles[id] = tile

	var wrow := CenterContainer.new()
	content.add_child(wrow)
	var watch := CheckButton.new()
	watch.text = "Só assistir (todos os jogadores são bots)"
	watch.button_pressed = _watch
	watch.add_theme_color_override("font_color", Style.MUTED)
	watch.toggled.connect(func(on):
		_watch = on
		_update_summary())
	wrow.add_child(watch)

	# rodapé
	_summary = Label.new()
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_theme_color_override("font_color", Style.MUTED)
	root.add_child(_summary)
	var play := Style.menu_button("JOGAR", true)
	play.custom_minimum_size.x = 0
	play.pressed.connect(_on_play)
	root.add_child(play)

	_on_class(_class)
	_on_map(_map)


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Style.ACCENT)
	return l


func _on_class(c: int) -> void:
	_class = c
	for k in _class_cards:
		_class_cards[k].set_selected(k == c)
	var d: RichTextLabel = find_child("ClassDesc", true, false)
	if d != null:
		d.text = "[center][b]%s[/b] · %s\n[color=#ffd23f]%s:[/color] %s[/center]" % [Defs.CLASS_NAMES[c], Texts.CLASS_BLURB[c], Texts.ability_name(c), Texts.ability_desc(c)]
	_update_summary()


func _on_map(id: int) -> void:
	_map = id
	for k in _map_tiles:
		_map_tiles[k].set_selected(k == id)
	_update_summary()


func _update_summary() -> void:
	if _summary == null:
		return
	var map_name: String = "Mapa aleatório" if _map == 0 else Board.MAP_NAMES[_map]
	_summary.text = "%s · %d jogadores · %s" % ["Assistindo" if _watch else Defs.CLASS_NAMES[_class], _players, map_name]


func _on_play() -> void:
	var map_id := _map if _map != 0 else randi_range(1, 15)
	start_requested.emit({
		"players": _players, "class": _class, "map": map_id, "seed": randi(), "watch": _watch,
		"bot_speed": Sfx.instance.bot_speed if Sfx.instance != null else 1,
	})


func handle_back() -> void:
	back_requested.emit()
