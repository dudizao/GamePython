class_name GameScreen
extends Control
## Tela da partida: liga o núcleo de regras (GameState) à interface.
## Humano = jogador `human` (-1 = só assistir). Os demais jogam com Bot.

signal exit_requested

const BATTLE_SECONDS := 15.0
const ERRORS := {
	"not_your_turn": "Não é a sua vez.", "wrong_phase": "Ação indisponível agora.",
	"unreachable": "Casa fora de alcance.", "nothing_here": "Não há itens aqui.",
	"on_cooldown": "Habilidade em recarga.", "out_of_range": "Alvo fora de alcance.",
	"invalid_target": "Alvo inválido.", "no_potion": "Você não tem essa poção.",
	"undead_cannot_collect": "Mortos-vivos não coletam itens.", "in_battle": "Termine a batalha primeiro.",
	"no_trap_kit": "Você não tem kit de armadilha.", "trap_here": "Já há uma armadilha aqui.",
	"too_many_traps": "Você já tem armadilhas demais armadas.", "undead_cannot_trap": "Mortos-vivos não armam armadilhas.",
}
const TERRAIN_INFO := {
	Defs.Terrain.PLANICIE: "Planície (custo 1)", Defs.Terrain.FLORESTA: "Floresta (custo 2, +2 defesa)",
	Defs.Terrain.MONTANHA: "Montanha (custo 3, +3 defesa)", Defs.Terrain.AGUA: "Água (intransponível)",
	Defs.Terrain.MASMORRA: "Masmorra (custo 1)", Defs.Terrain.LAVA: "Lava (custo 2, -5 de vida)",
	Defs.Terrain.GELO: "Gelo (custo 1, -5 de vida)", Defs.Terrain.BLOCO: "Bloqueado",
}
const ACTION_TIPS := {
	"roll": "Role o dado: define seus pontos de movimento neste turno.",
	"end_move": "Para de andar e passa para a fase de ação.",
	"collect": "Pega o item da casa onde você está.",
	"vida": "Bebe uma poção de vida.",
	"forca": "Bebe uma poção de força (mais ataque por algumas rodadas).",
	"end_turn": "Termina o seu turno.",
	"trap": "Arma uma armadilha escondida na sua casa (gasta um kit). Quem pisar leva %d de dano e perde o movimento." % Defs.TRAP_DAMAGE,
}

var state: GameState
var human := 0
var bot_delay := 0.5
var speed := 1.0

var board_view: BoardView
var log_label: RichTextLabel
var status_label: Label
var timer_label: Label
var hover_label: Label
var toast_label: Label
var speed_button: Button
var buttons: Dictionary = {}
var cards: Dictionary = {}

var _battle_panel: PanelContainer
var _bt_title: Label
var _bt_left: Dictionary
var _bt_right: Dictionary
var _bt_actions: RichTextLabel
var _bt_result: RichTextLabel
var _bt_buttons: Dictionary = {}
var _bt_wait: Label
var _over_panel: PanelContainer
var _over_label: RichTextLabel
var _modal: Control = null
var _root: BoxContainer
var _margin: MarginContainer
var _action_bar: GridContainer
var _log_panel: PanelContainer
var _snd_button: Button
var _help_button: Button
var _menu_button: Button
var _bt_row: GridContainer
var _portrait := false
var _touch := false
var _laid_out := false
var _dice: DiceStage
var _bt_dice: DiceStage
var _card_panel: PanelContainer
var _card_title: Label
var _card_text: Label
var _card_tween: Tween
var _flash_rect: ColorRect
var _over_center: CenterContainer
var _hold_t := 0.0
var _anim_lock := 0.0
var _panel_hold := 0.0
var _bt_a_ref = null
var _bt_d_ref = null
var _bt_last_actions: Array = ["", ""]
var _bt_session := false  # há (ou acabou de haver) uma batalha na janela
var _bar_tweens := {}

var _bot_clock := 0.0
var _deadline := 0.0
var _timer_key := ""
var _targeting := false
var _toast_time := 0.0
var _over_shown := false
var _bt_attacker := -1
var _bt_defender := -1
var _bt_monster_name := ""
var _bt_text := ""
var _bt_actions_text := ""
var _last_to := {}  # pid -> última casa de destino (para animar recuos)


func setup(cfg: Dictionary) -> void:
	var n: int = cfg.get("players", 3)
	var watch: bool = cfg.get("watch", false)
	var my_class: int = cfg.get("class", Defs.HeroClass.GUERREIRO)
	var rng := RandomNumberGenerator.new()
	rng.seed = cfg.get("seed", 1)
	var others: Array = Defs.CLASS_NAMES.keys()
	others.erase(my_class)
	for i in range(others.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = others[i]
		others[i] = others[j]
		others[j] = tmp
	var players := []
	for i in n:
		if i == 0:
			players.append({ "name": "Bot 1" if watch else "Você", "class": my_class })
		else:
			players.append({ "name": "Bot %d" % (i + 1 if watch else i), "class": others[(i - 1) % others.size()] })
	state = GameState.new()
	state.setup(cfg.get("seed", 1), cfg.get("map", 12), players)
	human = -1 if watch else 0
	bot_delay = cfg.get("bot_delay", 0.4)
	speed = float(cfg.get("bot_speed", 1))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_log_line("[b]Partida iniciada[/b] no mapa [color=#ffd23f]%s[/color]. Troféus no mapa: %d. Aperte [b]F1[/b] para ver as regras." % [Board.MAP_NAMES.get(state.board.map_id, "?"), state.trophies_total])
	_refresh()


# ---------------------------------------------------------------------------
# Construção da interface
# ---------------------------------------------------------------------------

func _build() -> void:
	_touch = Platform.is_touch()
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	_root = BoxContainer.new()
	_root.add_theme_constant_override("separation", 8)
	_margin.add_child(_root)

	# --- widgets (são criados uma vez e reposicionados por _layout) ---
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 26)
	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 18)
	speed_button = _top_button("Velocidade x%d" % int(speed), "Acelera os bots.", _on_speed)
	_snd_button = _top_button("Som", "Liga/desliga efeitos e música.", Callable())
	_snd_button.toggle_mode = true
	_snd_button.button_pressed = Sfx.instance == null or Sfx.instance.sfx_on or Sfx.instance.music_on
	_snd_button.toggled.connect(func(on):
		if Sfx.instance != null:
			Sfx.instance.set_sfx(on)
			Sfx.instance.set_music(on))
	_help_button = _top_button("? Regras", "", _open_help)
	_menu_button = _top_button("Menu", "", _confirm_exit)

	board_view = BoardView.new()
	board_view.state = state
	board_view.viewer = human
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_view.custom_minimum_size = Vector2(240, 220)
	board_view.cell_pressed.connect(_on_cell_pressed)
	board_view.cell_hovered.connect(_on_cell_hovered)
	_build_zoom_buttons()

	hover_label = Label.new()
	hover_label.add_theme_color_override("font_color", Style.MUTED)
	hover_label.custom_minimum_size = Vector2(0, 22)
	hover_label.clip_text = true

	_action_bar = GridContainer.new()
	_action_bar.add_theme_constant_override("h_separation", 6)
	_action_bar.add_theme_constant_override("v_separation", 6)
	_make_action("roll", "Rolar" + _hint("R"), func(): _act({ "type": "roll" }))
	_make_action("end_move", "Parar" + _hint("E"), func(): _act({ "type": "end_move" }))
	_make_action("collect", "Coletar" + _hint("C"), func(): _act({ "type": "collect" }))
	_make_action("ability", "Habilidade" + _hint("Q"), _on_ability)
	_make_action("vida", "Vida" + _hint("1"), func(): _act({ "type": "use_item", "potion": "vida" }))
	_make_action("forca", "Força" + _hint("2"), func(): _act({ "type": "use_item", "potion": "forca" }))
	_make_action("trap", "Armar" + _hint("T"), func(): _act({ "type": "set_trap" }))
	_make_action("end_turn", "Passar" + _hint("Esp"), func(): _act({ "type": "end_turn" }))
	for k in ACTION_TIPS:
		buttons[k].tooltip_text = ACTION_TIPS[k]
	if human >= 0:
		buttons["ability"].tooltip_text = "%s: %s" % [Texts.ability_name(state.heroes[human].hero_class), Texts.ability_desc(state.heroes[human].hero_class)]

	var ids: Array = state.heroes.keys()
	ids.sort()
	for pid in ids:
		_build_card(pid)

	_log_panel = PanelContainer.new()
	_log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.selection_enabled = false
	_log_panel.add_child(log_label)

	toast_label = Label.new()
	toast_label.add_theme_font_size_override("font_size", 24)
	toast_label.add_theme_color_override("font_color", Style.ACCENT)
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.modulate.a = 0.0
	add_child(toast_label)

	_build_battle_panel()
	_build_over_panel()
	_build_fx_layers()
	_layout()
	get_viewport().size_changed.connect(_layout)


## Dica de atalho de teclado ("[R]"): some no celular.
func _hint(key: String) -> String:
	return "" if _touch else " [%s]" % key


func _top_button(text: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(0, Platform.button_height())
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


func _build_zoom_buttons() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -8
	box.offset_bottom = -8
	board_view.add_child(box)
	var defs := [["+", "Aproximar", func(): board_view.zoom_by(1.35)], ["−", "Afastar", func(): board_view.zoom_by(1.0 / 1.35)], ["◎", "Centralizar no seu herói", _center_on_hero]]
	for d in defs:
		var b := Button.new()
		b.text = d[0]
		b.tooltip_text = d[1]
		b.custom_minimum_size = Vector2(Platform.button_height(), Platform.button_height())
		b.pressed.connect(d[2])
		box.add_child(b)


func _make_action(key: String, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, Platform.button_height())
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	_action_bar.add_child(b)
	buttons[key] = b


## Reposiciona os mesmos widgets para paisagem (painel lateral) ou retrato (tudo empilhado).
func _layout() -> void:
	var vp := get_viewport_rect().size
	var portrait := vp.y > vp.x
	var inset := Platform.safe_insets(get_window())
	_margin.add_theme_constant_override("margin_left", 10 + int(inset.x))
	_margin.add_theme_constant_override("margin_top", 10 + int(inset.y))
	_margin.add_theme_constant_override("margin_right", 10 + int(inset.z))
	_margin.add_theme_constant_override("margin_bottom", 10 + int(inset.w))
	toast_label.custom_minimum_size = Vector2(vp.x - 40, 0)
	toast_label.size = Vector2(vp.x - 40, 30)
	toast_label.position = Vector2(20, 90 + inset.y)
	_battle_panel.custom_minimum_size = Vector2(minf(760.0, vp.x - 16), 0)
	var arena_h := clampf(vp.y * 0.26, 118.0, 180.0)
	var px := arena_h - 20.0
	for bx in [_bt_left, _bt_right]:
		bx["wrap"].custom_minimum_size = Vector2(0, arena_h)
		var ic: Control = bx["icon"]
		ic.offset_left = -px / 2.0
		ic.offset_right = px / 2.0
		ic.offset_top = 6
		ic.offset_bottom = 6 + px
	_over_panel.custom_minimum_size = Vector2(minf(520.0, vp.x - 16), 0)
	_bt_row.columns = 3 if vp.x < 640 else 6
	if _laid_out and portrait == _portrait:
		return
	_laid_out = true
	_portrait = portrait

	# solta os widgets dos contêineres antigos
	var widgets: Array[Control] = [status_label, timer_label, speed_button, _snd_button, _help_button, _menu_button, board_view, hover_label, _action_bar, _log_panel]
	for pid in cards:
		widgets.append(cards[pid]["panel"])
	for w in widgets:
		if w.get_parent() != null:
			w.get_parent().remove_child(w)
	for c in _root.get_children():
		_root.remove_child(c)
		c.queue_free()

	var ids: Array = cards.keys()
	ids.sort()
	if not portrait:
		_root.vertical = false
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_theme_constant_override("separation", 6)
		_root.add_child(left)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		left.add_child(top)
		for w in [status_label, timer_label, speed_button, _snd_button, _help_button, _menu_button]:
			top.add_child(w)
		left.add_child(board_view)
		left.add_child(hover_label)
		_action_bar.columns = 8
		left.add_child(_action_bar)
		var right := VBoxContainer.new()
		right.custom_minimum_size = Vector2(340 if not _touch else 300, 0)
		right.add_theme_constant_override("separation", 8)
		_root.add_child(right)
		for pid in ids:
			cards[pid]["panel"].custom_minimum_size = Vector2.ZERO
			right.add_child(cards[pid]["panel"])
		right.add_child(_log_panel)
	else:
		_root.vertical = true
		var col := VBoxContainer.new()
		col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 6)
		_root.add_child(col)
		col.add_child(status_label)
		var top2 := HBoxContainer.new()
		top2.add_theme_constant_override("separation", 6)
		col.add_child(top2)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for w in [timer_label, speed_button, spacer, _snd_button, _help_button, _menu_button]:
			top2.add_child(w)
		col.add_child(board_view)
		col.add_child(hover_label)
		_action_bar.columns = 4
		col.add_child(_action_bar)
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 128)
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col.add_child(scroll)
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 6)
		scroll.add_child(strip)
		for pid in ids:
			cards[pid]["panel"].custom_minimum_size = Vector2(190, 0)
			strip.add_child(cards[pid]["panel"])
		_log_panel.custom_minimum_size = Vector2(0, 90)
		_log_panel.size_flags_vertical = Control.SIZE_FILL
		col.add_child(_log_panel)
	if board_view.zoom <= 1.0 and _touch:
		board_view.set_zoom(1.8)
	_center_on_hero(true)


func _build_card(pid: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_show_info(Texts.hero_tooltip(state.heroes[pid])))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var icon := HeroPortrait.make(state.heroes[pid].hero_class, 34)
	head.add_child(icon)
	var name_l := Label.new()
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_color_override("font_color", Art.player_color(pid))
	head.add_child(name_l)
	var lvl := Label.new()
	lvl.add_theme_color_override("font_color", Style.ACCENT)
	head.add_child(lvl)
	var hp := ProgressBar.new()
	hp.custom_minimum_size = Vector2(0, 16)
	hp.show_percentage = false
	hp.add_theme_stylebox_override("fill", Style.box(Style.GOOD, 4))
	hp.add_theme_stylebox_override("background", Style.box(Color("101218"), 4))
	v.add_child(hp)
	var xp := ProgressBar.new()
	xp.custom_minimum_size = Vector2(0, 6)
	xp.show_percentage = false
	xp.add_theme_stylebox_override("fill", Style.box(Style.ACCENT, 3))
	xp.add_theme_stylebox_override("background", Style.box(Color("101218"), 3))
	v.add_child(xp)
	var info := Label.new()
	info.add_theme_color_override("font_color", Style.MUTED)
	info.add_theme_font_size_override("font_size", 13)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	cards[pid] = { "panel": p, "name": name_l, "lvl": lvl, "hp": hp, "xp": xp, "info": info }
	return p


func _fighter_box() -> Dictionary:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	var wrap := Control.new()  # contêiner livre: dá para mover/escalar o lutador nas animações
	wrap.custom_minimum_size = Vector2(0, 170)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(wrap)
	var floor_fx := Control.new()  # sombra no chão da arena
	floor_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	floor_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor_fx.draw.connect(func():
		var c := Vector2(floor_fx.size.x / 2.0, floor_fx.size.y * 0.9)
		floor_fx.draw_set_transform(c, 0.0, Vector2(1.0, 0.28))
		floor_fx.draw_circle(Vector2.ZERO, floor_fx.size.x * 0.34, Color(0.0, 0.0, 0.0, 0.28))
		floor_fx.draw_circle(Vector2.ZERO, floor_fx.size.x * 0.24, Color(0.0, 0.0, 0.0, 0.3)))
	wrap.add_child(floor_fx)
	var icon := HeroPortrait.make(0, 150)
	icon.anchor_left = 0.5
	icon.anchor_right = 0.5
	icon.anchor_top = 0.0
	icon.anchor_bottom = 0.0
	icon.offset_left = -75
	icon.offset_right = 75
	icon.offset_top = 6
	icon.offset_bottom = 156
	wrap.add_child(icon)
	var blob := Label.new()  # monstros: letra colorida no lugar do sprite
	blob.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blob.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	blob.add_theme_font_size_override("font_size", 40)
	blob.add_theme_color_override("font_color", Color.BLACK)
	blob.custom_minimum_size = Vector2(72, 72)
	blob.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	wrap.add_child(blob)
	var name_l := RichTextLabel.new()
	name_l.bbcode_enabled = true
	name_l.fit_content = true
	name_l.scroll_active = false
	v.add_child(name_l)
	var hp := ProgressBar.new()
	hp.custom_minimum_size = Vector2(0, 18)
	hp.show_percentage = false
	hp.add_theme_stylebox_override("background", Style.box(Color("101218"), 4))
	v.add_child(hp)
	var stats := RichTextLabel.new()
	stats.bbcode_enabled = true
	stats.fit_content = true
	stats.scroll_active = false
	stats.custom_minimum_size = Vector2(0, 66)
	v.add_child(stats)
	return { "root": v, "wrap": wrap, "icon": icon, "blob": blob, "name": name_l, "hp": hp, "stats": stats, "dead": false, "base_x": null, "tweens": [], "floats": [] }


func _build_battle_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_battle_panel = PanelContainer.new()
	_battle_panel.custom_minimum_size = Vector2(760, 0)
	_battle_panel.add_theme_stylebox_override("panel", Style.box(Color(0.1, 0.11, 0.15, 0.97), 12, Style.ACCENT, 2))
	_battle_panel.visible = false
	center.add_child(_battle_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_battle_panel.add_child(v)
	_bt_title = Label.new()
	_bt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bt_title.add_theme_font_size_override("font_size", 22)
	_bt_title.add_theme_color_override("font_color", Style.ACCENT)
	v.add_child(_bt_title)
	var arena := PanelContainer.new()  # palco da luta: fundo próprio e personagens grandes
	arena.add_theme_stylebox_override("panel", Style.box(Color(0.15, 0.19, 0.24), 10, Color(1, 1, 1, 0.08), 1))
	v.add_child(arena)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	arena.add_child(cols)
	_bt_left = _fighter_box()
	_bt_right = _fighter_box()
	_bt_right["icon"].flip_h = true  # o oponente olha para a esquerda
	cols.add_child(_bt_left["root"])
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(176, 0)
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cols.add_child(mid)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(176, 130)
	mid.add_child(holder)
	_bt_dice = DiceStage.create(holder, DiceStage.Mode.BATTLE, false)
	_bt_dice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vs := Label.new()
	vs.text = "VS"
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs.add_theme_font_size_override("font_size", 26)
	vs.add_theme_color_override("font_color", Style.ACCENT)
	mid.add_child(vs)
	cols.add_child(_bt_right["root"])
	_bt_actions = RichTextLabel.new()
	_bt_actions.bbcode_enabled = true
	_bt_actions.fit_content = true
	_bt_actions.scroll_active = false
	v.add_child(_bt_actions)
	_bt_result = RichTextLabel.new()
	_bt_result.bbcode_enabled = true
	_bt_result.fit_content = true
	_bt_result.scroll_active = false
	_bt_result.custom_minimum_size = Vector2(0, 54)
	v.add_child(_bt_result)
	_bt_row = GridContainer.new()
	_bt_row.columns = 6
	_bt_row.add_theme_constant_override("h_separation", 6)
	_bt_row.add_theme_constant_override("v_separation", 6)
	var row := _bt_row
	v.add_child(row)
	var defs := [
		["attack", "Atacar", { "action": "attack" }, "Duelo de d20 + ataque/2 contra o oponente."],
		["defend", "Defender", { "action": "defend" }, "Dano pela metade. Se o inimigo errar, você contra-ataca."],
		["ability", "Habilidade", { "action": "ability" }, ""],
		["vida", "Poção vida", { "action": "item", "potion": "vida" }, "Bebe uma poção de vida."],
		["forca", "Poção força", { "action": "item", "potion": "forca" }, "Mais ataque por algumas rodadas."],
		["flee", "Fugir", { "action": "flee" }, "d20 + velocidade precisa chegar a %d. Se falhar, você perde a ação." % Defs.FLEE_DC],
	]
	for d in defs:
		var b := Button.new()
		b.text = d[1]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, maxi(48, Platform.button_height()))
		b.tooltip_text = d[3]
		var payload: Dictionary = d[2]
		b.pressed.connect(func(): _battle_act(payload))
		row.add_child(b)
		_bt_buttons[d[0]] = b
	if human >= 0:
		_bt_buttons["ability"].tooltip_text = Texts.ability_desc(state.heroes[human].hero_class)
	_bt_wait = Label.new()
	_bt_wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bt_wait.add_theme_color_override("font_color", Style.MUTED)
	v.add_child(_bt_wait)


func _build_over_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_over_center = center
	_over_panel = PanelContainer.new()
	_over_panel.custom_minimum_size = Vector2(520, 0)
	_over_panel.add_theme_stylebox_override("panel", Style.box(Color(0.08, 0.09, 0.12, 0.98), 12, Style.ACCENT, 3))
	_over_panel.visible = false
	center.add_child(_over_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_over_panel.add_child(v)
	_over_label = RichTextLabel.new()
	_over_label.bbcode_enabled = true
	_over_label.fit_content = true
	_over_label.scroll_active = false
	v.add_child(_over_label)
	var b := Button.new()
	b.text = "Voltar ao menu"
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(func(): exit_requested.emit())
	v.add_child(b)


# ---------------------------------------------------------------------------
# Janelas (ajuda / confirmação)
# ---------------------------------------------------------------------------

func _show_info(text: String) -> void:
	if _modal != null:
		return
	var m := Control.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(460.0, get_viewport_rect().size.x - 24), 0)
	panel.add_theme_stylebox_override("panel", Style.box(Color(0.1, 0.11, 0.15, 0.99), 12, Style.ACCENT, 2))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var close := Button.new()
	close.text = "Fechar"
	close.custom_minimum_size = Vector2(0, Platform.button_height())
	close.pressed.connect(func():
		_modal = null
		m.queue_free())
	v.add_child(close)
	_modal = m
	add_child(m)


## Botão Voltar do Android: fecha a janela aberta ou pergunta se quer sair.
func handle_back() -> void:
	if _modal != null:
		if _modal is HelpScreen:
			_modal.close()
		else:
			_modal.queue_free()
			_modal = null
		return
	_confirm_exit()


func _center_on_hero(snap := false) -> void:
	var pid := human if human >= 0 else state.current_player()
	if not state.heroes.has(pid):
		return
	if snap:
		board_view.snap_to(state.heroes[pid].pos)
	else:
		board_view.center_on(state.heroes[pid].pos)


func _open_help() -> void:
	if _modal != null:
		return
	var h := HelpScreen.new()
	h.closed.connect(func(): _modal = null)
	_modal = h
	add_child(h)


func _confirm_exit() -> void:
	if _modal != null:
		return
	if state.finished:
		exit_requested.emit()
		return
	var m := Control.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.box(Color(0.1, 0.11, 0.15, 0.99), 12, Style.ACCENT, 2))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var l := Label.new()
	l.text = "Sair da partida e voltar ao menu?\nO progresso será perdido."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var no := Button.new()
	no.text = "Continuar jogando"
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.custom_minimum_size = Vector2(170, Platform.button_height())
	no.pressed.connect(func():
		_modal = null
		m.queue_free())
	row.add_child(no)
	var yes := Button.new()
	yes.text = "Sair"
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.custom_minimum_size = Vector2(120, Platform.button_height())
	yes.pressed.connect(func(): exit_requested.emit())
	row.add_child(yes)
	_modal = m
	add_child(m)


# ---------------------------------------------------------------------------
# Laço principal
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if state == null:
		return
	if _toast_time > 0.0:
		_toast_time -= delta
		toast_label.modulate.a = clampf(_toast_time / 0.6, 0.0, 1.0)
	_hold_t = maxf(0.0, _hold_t - delta)
	if _anim_lock > 0.0:
		_anim_lock -= delta
		if _anim_lock <= 0.0:
			_refresh_battle()
	if _panel_hold > 0.0:
		_panel_hold -= delta
		if _panel_hold <= 0.0:
			_refresh_battle()
	if state.finished or _modal != null:
		return
	var pending := state.pending_actors()
	if pending.is_empty():
		return
	var bot_pid := -1
	for p in pending:
		if p != human:
			bot_pid = p
			break
	if bot_pid >= 0:
		if _hold_t > 0.0:
			return  # espera as animações terminarem antes do próximo bot agir
		_bot_clock += delta * speed
		if _bot_clock >= bot_delay:
			_bot_clock = 0.0
			_do(bot_pid, Bot.choose(state, bot_pid))
		return
	# só o humano precisa agir: conta o tempo
	var key := "%d_%d" % [state.turn_number, state.battle.round_no if state.battle != null else 0]
	if key != _timer_key:
		_timer_key = key
		_deadline = BATTLE_SECONDS if state.phase == Defs.Phase.BATTLE else float(Defs.TURN_SECONDS)
	_deadline -= delta
	timer_label.text = "⏱ %ds" % maxi(0, ceili(_deadline))
	timer_label.add_theme_color_override("font_color", Style.BAD if _deadline < 8.0 else Style.TEXT)
	if _deadline <= 0.0:
		board_view.snapshot_terrain()
		_process_events(state.timeout())
		_targeting = false
		_refresh()


func _do(pid: int, action: Dictionary) -> void:
	if pid == human and _dice != null and _dice.is_active():
		_dice.skip()  # o jogador agiu: fecha a animação do dado
	board_view.snapshot_terrain()
	var res := state.apply(pid, action)
	if not res["ok"]:
		if pid == human:
			_toast(ERRORS.get(res["error"], res["error"]))
			Sfx.play("error")
		return
	_process_events(res["events"])
	_targeting = false
	_refresh()


## Comemoração de par nos dados de movimento (vazio se não houve par).
func _dice_special(e: Dictionary) -> Dictionary:
	if not e.get("pair", false):
		return {}
	var face: int = e["dice"][0]
	if face == 1:
		return { "kind": "snake", "text": "OLHOS DE COBRA…" }
	if face == 6:
		return { "kind": "six", "text": "DOIS 6!  +%d" % e["bonus"] }
	return { "kind": "double", "text": "PAR DE %d!  +%d" % [face, e["bonus"]] }


## d20 mostrados na batalha: o duelo mostra os dois; um ataque sem oposição mostra só o do atacante.
func _battle_dice_items(e: Dictionary) -> Array:
	var rolls: Dictionary = e["rolls"]
	var ca := Art.player_color(_bt_attacker)
	var cd := Color("c0392b")
	if _bt_defender >= 0:
		cd = Art.player_color(_bt_defender)
	elif _bt_d_ref is Monster:
		cd = Art.MONSTER_COLORS.get(_bt_d_ref.kind, Color.GRAY).darkened(0.25)
	if rolls.has("ra"):
		return [{ "value": rolls["ra"], "color": ca }, { "value": rolls["rd"], "color": cd }]
	if rolls.has("r0"):
		return [{ "value": rolls["r0"], "color": ca }]
	if rolls.has("r1"):
		return [{ "value": rolls["r1"], "color": cd }]
	return []


func _act(action: Dictionary) -> void:
	if human >= 0 and _modal == null and state.pending_actors().has(human) and not state.finished:
		_do(human, action)


func _battle_act(payload: Dictionary) -> void:
	var a := { "type": "battle_action" }
	a.merge(payload, true)
	_act(a)


func _on_speed() -> void:
	speed = 1.0 if speed >= 4.0 else speed * 2.0
	speed_button.text = "Velocidade x%d" % int(speed)


# ---------------------------------------------------------------------------
# Entrada
# ---------------------------------------------------------------------------

func _my_turn() -> bool:
	return human >= 0 and _modal == null and not state.finished and state.phase != Defs.Phase.BATTLE and state.current_player() == human


func _on_cell_pressed(c: Vector2i) -> void:
	if not _my_turn():
		return
	if _targeting:
		for o in _ability_targets():
			if o.pos == c:
				_do(human, { "type": "ability", "target": o.id })
				return
		_targeting = false
		_refresh()
		return
	if state.phase == Defs.Phase.MOVE and board_view.reach.has(c):
		_do(human, { "type": "move", "to": c })


func _on_cell_hovered(c: Vector2i) -> void:
	if c == Vector2i(-1, -1):
		hover_label.text = ""
		return
	var parts: Array[String] = [TERRAIN_INFO.get(state.board.terrain_at(c), "")]
	for it in state.items_at(c):
		parts.append(Texts.item_name(it))
	if state.traps.has(c) and board_view._can_see_trap(state.traps[c]):
		parts.append("Armadilha armada por %s" % state.heroes[state.traps[c]["owner"]].display_name)
	var m := state.monster_at(c)
	if m != null:
		parts.append("%s nv%d  HP %d/%d  ATK %d  DEF %d" % [m.display_name, m.level, m.hp, m.max_hp, m.attack, m.defense])
	for h in state.alive_heroes():
		if h.pos == c:
			parts.append("%s%s nv%d  HP %d/%d  ATK %d  DEF %d" % [h.display_name, " (morto-vivo)" if h.undead else "", h.level, h.hp, h.max_hp, h.atk_total(), h.def_total()])
	hover_label.text = "  ·  ".join(parts)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F1:
		_open_help()
		return
	if _modal != null:
		return
	match event.keycode:
		KEY_ESCAPE:
			_targeting = false
			_refresh()
		KEY_R: _try_button("roll")
		KEY_E: _try_button("end_move")
		KEY_C: _try_button("collect")
		KEY_Q: _try_button("ability")
		KEY_1: _try_button("vida")
		KEY_2: _try_button("forca")
		KEY_T: _try_button("trap")
		KEY_SPACE: _try_button("end_turn")


func _try_button(key: String) -> void:
	if _my_turn() and not buttons[key].disabled:
		buttons[key].pressed.emit()


func _ability_targets() -> Array[Hero]:
	var out: Array[Hero] = []
	var me: Hero = state.heroes[human]
	for o in state.alive_heroes():
		if o != me and not (me.undead and o.undead) and state.in_magic_line(me.pos, o.pos):
			out.append(o)
	return out


func _on_ability() -> void:
	if not _my_turn():
		return
	var me: Hero = state.heroes[human]
	if me.hero_class != Defs.HeroClass.MAGO:
		_do(human, { "type": "ability" })
		return
	var t := _ability_targets()
	if t.is_empty():
		_toast("Nenhum alvo na mesma linha/coluna a até %d casas." % Defs.MAGIC_RANGE)
	elif t.size() == 1:
		_do(human, { "type": "ability", "target": t[0].id })
	else:
		_targeting = true
		_toast("Clique no alvo (Esc cancela).")
		_refresh()


# ---------------------------------------------------------------------------
# Eventos -> log, animações e efeitos
# ---------------------------------------------------------------------------

func _log_line(text: String) -> void:
	log_label.append_text(text + "\n")


func _toast(text: String) -> void:
	toast_label.text = text
	_toast_time = 2.4
	toast_label.modulate.a = 1.0


func _hero_cell(pid: int) -> Vector2i:
	return state.heroes[pid].pos if state.heroes.has(pid) else Vector2i.ZERO


func _action_label(act: String, potion: String, f) -> String:
	match act:
		"attack": return "Atacar"
		"defend": return "Defender"
		"flee": return "Fugir"
		"item": return "Poção de %s" % ("vida" if potion == "vida" else "força")
		"ability":
			return Texts.ability_name(f.hero_class) if f is Hero else "Habilidade"
	return act


# ---------------------------------------------------------------------------
# Animações
# ---------------------------------------------------------------------------

## Os bots esperam este tempo antes da próxima ação (as animações precisam terminar).
const HOLD_SCALE := 0.8  # ajuste fino do ritmo: menor = bots mais rápidos


func _hold(seconds: float) -> void:
	_hold_t = maxf(_hold_t, seconds * HOLD_SCALE / maxf(1.0, speed))


func _later(seconds: float, cb: Callable) -> void:
	var tw := create_tween()  # preso a este nó: some junto com a tela
	tw.tween_interval(seconds / maxf(1.0, speed))
	tw.tween_callback(cb)


func _screen_flash(color: Color) -> void:
	_flash_rect.color = color
	_flash_rect.modulate.a = 1.0
	create_tween().tween_property(_flash_rect, "modulate:a", 0.0, 0.7)


func _build_fx_layers() -> void:
	_dice = DiceStage.create(board_view, DiceStage.Mode.MOVE)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card_panel = PanelContainer.new()
	_card_panel.custom_minimum_size = Vector2(300, 0)
	_card_panel.visible = false
	_card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_card_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_panel.add_child(v)
	_card_title = Label.new()
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.add_theme_font_size_override("font_size", 24)
	v.add_child(_card_title)
	_card_text = Label.new()
	_card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.custom_minimum_size = Vector2(270, 0)
	v.add_child(_card_text)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 0, 0, 0)
	_flash_rect.modulate.a = 0.0
	add_child(_flash_rect)


func _show_card(e: Dictionary) -> void:
	var lucky: bool = e["kind"] == "SORTE"
	var col := Style.GOOD if lucky else Style.BAD
	_card_title.text = "Carta de sorte" if lucky else "Carta de azar"
	_card_title.add_theme_color_override("font_color", col)
	_card_text.text = e["text"]
	_card_panel.add_theme_stylebox_override("panel", Style.box(Color(0.1, 0.11, 0.15, 0.97), 14, col, 3))
	_card_panel.visible = true
	_card_panel.pivot_offset = _card_panel.size / 2.0
	_card_panel.scale = Vector2(0.4, 0.4)
	_card_panel.modulate.a = 0.0
	if _card_tween != null and _card_tween.is_valid():
		_card_tween.kill()
	var tw := create_tween()
	_card_tween = tw
	tw.tween_property(_card_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_card_panel, "modulate:a", 1.0, 0.18)
	tw.tween_interval(1.1)
	tw.tween_property(_card_panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): _card_panel.visible = false)


func _fx_for(e: Dictionary) -> void:
	var bv := board_view
	match e["type"]:
		"dice_rolled":
			var hn: String = state.heroes[e["player"]].display_name
			var mine: bool = e["player"] == human
			var idx: int = 0 if Sfx.instance == null else (Sfx.instance.dice_human if mine else Sfx.instance.dice_bots)
			if Sfx.instance == null and not mine:
				idx = 1
			var style: String = ["full", "quick", "off"][clampi(idx, 0, 2)]
			var special := _dice_special(e)
			if style == "off":
				_hold(0.15)
				if not special.is_empty():
					_toast(special["text"])
			else:
				_dice.roll_move(e["dice"], Art.player_color(e["player"]), "%s · %d pontos" % [hn, e["move_points"]], speed, e["player"] % 2 == 0, style, special, state.heroes[e["player"]].hero_class)
				_hold((1.85 if style == "full" else 0.95) + (0.5 if not special.is_empty() else 0.0))
		"battle_started":
			_bt_session = true
			_bt_reset(_bt_left)
			_bt_reset(_bt_right)
			var b := state.battle
			if b != null:
				_bt_a_ref = b.attacker
				_bt_d_ref = b.defender if b.kind == "pvp" else b.monster
			_bt_last_actions = ["", ""]
			var cell := _hero_cell(e["attacker"])
			bv.fx("ring", cell, { "color": Style.ACCENT, "radius": 1.3, "dur": 0.55 })
			bv.fx("flashcell", cell, { "color": Color.WHITE, "dur": 0.35 })
			_hold(0.5)
		"battle_actions":
			_bt_last_actions = e["actions"]
		"battle_round":
			# os d20 rolam primeiro; o golpe só acontece quando eles assentam
			var items := _battle_dice_items(e)
			var delay := 0.0
			if not items.is_empty():
				_bt_dice.roll_battle(items, speed)
				Sfx.play("dice", -7.0)
				delay = clampf(_bt_dice.last_settle, 0.4, 0.72)
			_later(delay, func():
				bv.shake(3.0, 0.25)
				for h in e["hits"]:
					if h["damage"] > 0:
						bv.fx("burst", e["cell"], { "color": Color("ff6b6b"), "count": 12, "radius": 0.9, "dur": 0.45, "seed": float(h["src"]) })
				_bt_play_round(e))
			_anim_lock = (delay + 0.9) / maxf(1.0, speed)
			_hold(delay + 1.15)
		"battle_ended":
			_panel_hold = 1.25 if e["outcome"] == "death" else 0.35
			_hold(_panel_hold + 0.25)
		"damage":
			if e["source"] != "battle":
				bv.fx("burst", _hero_cell(e["player"]), { "color": Color("ff6b6b"), "count": 10, "radius": 0.9, "dur": 0.45 })
				bv.shake(2.5, 0.25)
		"dodged":
			bv.fx("ring", _hero_cell(e["player"]), { "color": Color("8be9fd"), "radius": 1.0, "dur": 0.5 })
		"potion_used":
			if e.get("healed", 0) > 0:
				bv.fx("rise", _hero_cell(e["player"]), { "color": Style.GOOD, "glyph": "+", "count": 5, "dur": 0.9 })
				_bt_float_pid(e["player"], "+%d" % e["healed"], Style.GOOD)
			_bt_pulse_pid(e["player"], Color(0.5, 1.0, 0.6))
		"ability":
			if e.get("healed", 0) > 0:
				bv.fx("rise", _hero_cell(e["player"]), { "color": Style.GOOD, "glyph": "+", "count": 6, "dur": 1.0 })
				_bt_float_pid(e["player"], "+%d" % e["healed"], Style.GOOD)
		"item_collected":
			var cell := _hero_cell(e["player"])
			match e["item"]:
				Defs.ItemType.TESOURO:
					bv.fx("star", cell, { "color": Style.ACCENT, "count": 8, "radius": 1.6, "dur": 0.9 })
					bv.fx("ring", cell, { "color": Style.ACCENT, "radius": 1.3, "dur": 0.6 })
					board_view.add_floater(cell + Vector2i(0, -1), "TROFÉU!", Style.ACCENT)
					_hold(0.7)
				Defs.ItemType.VIDA:
					bv.fx("burst", cell, { "color": Style.GOOD, "count": 8, "radius": 0.8, "dur": 0.5 })
				Defs.ItemType.POCAO_FORCA:
					bv.fx("burst", cell, { "color": Color("d7b0f0"), "count": 8, "radius": 0.8, "dur": 0.5 })
				Defs.ItemType.KIT_ARMADILHA:
					bv.fx("burst", cell, { "color": Color("ff9f43"), "count": 8, "radius": 0.8, "dur": 0.5 })
		"equipped":
			var cell2 := _hero_cell(e["player"])
			bv.fx("burst", cell2, { "color": Color("8be9fd"), "count": 10, "radius": 0.9, "dur": 0.55 })
			bv.fx("ring", cell2, { "color": Color("8be9fd"), "radius": 1.0, "dur": 0.5 })
			bv.add_floater(cell2 + Vector2i(0, -1), Defs.EQUIPMENT[e["id"]]["name"], Color("8be9fd"))
		"trap_set":
			if human < 0 or e["player"] == human:
				bv.fx("ring", e["pos"], { "color": Color("ff9f43"), "radius": 1.0, "dur": 0.55 })
		"trap_triggered":
			bv.fx("burst", e["pos"], { "color": Color("ff9f43"), "count": 18, "radius": 1.5, "dur": 0.6 })
			bv.fx("flashcell", e["pos"], { "color": Color("ffb86b"), "dur": 0.4 })
			bv.shake(6.0, 0.4)
			_hold(0.9)
		"trap_disarmed":
			bv.fx("burst", e["pos"], { "color": Style.GOOD, "count": 8, "radius": 0.9, "dur": 0.5 })
		"teleported":
			bv.fx("ring", e["from"], { "color": Color("8be9fd"), "radius": 1.1, "dur": 0.55 })
			bv.fx("ring", e["to"], { "color": Color("8be9fd"), "radius": 1.1, "dur": 0.55, "delay": 0.15 })
			bv.fx("burst", e["to"], { "color": Color("8be9fd"), "count": 10, "radius": 1.0, "dur": 0.6, "delay": 0.15 })
		"level_up":
			var cell3 := _hero_cell(e["player"])
			bv.fx("rise", cell3, { "color": Style.ACCENT, "count": 8, "dur": 1.0 })
			bv.fx("ring", cell3, { "color": Style.ACCENT, "radius": 1.4, "dur": 0.7 })
			bv.fx("star", cell3, { "color": Style.ACCENT, "count": 6, "radius": 1.3, "dur": 0.9 })
			_hold(0.9)
		"died":
			bv.fx("death", e["pos"], { "cls": state.heroes[e["player"]].hero_class, "color": Style.BAD, "dur": 0.85 })
			bv.shake(5.0, 0.35)
			_bt_die_pid(e["player"])
			_hold(1.0)
		"undead_risen":
			bv.fx("spawn", e["pos"], { "delay": 0.75, "dur": 1.0 })
			bv.spawn_hero(e["player"], 0.75)
			_hold(1.7)
		"monster_killed":
			bv.fx("monster_death", e["pos"], { "kind": e["kind"], "dur": 0.7 })
			bv.shake(3.0, 0.25)
			_bt_die_monster()
			_hold(0.8)
		"ring_closed":
			bv.start_ring_close(e["cells"], e["ring"])
			bv.shake(6.0, 1.0)
			_hold(1.9)
		"sudden_death":
			_screen_flash(Color(1.0, 0.12, 0.08, 0.45))
			bv.shake(6.0, 0.5)
			_hold(0.8)
		"card_drawn":
			_show_card(e)
			_hold(1.6)


# --- janela de batalha ---------------------------------------------------------

func _visual(box: Dictionary) -> Control:
	return box["icon"] if box["icon"].visible else box["blob"]


func _bt_box_for_pid(pid: int) -> Variant:
	if pid == _bt_attacker:
		return _bt_left
	if pid == _bt_defender:
		return _bt_right
	return null


## Tween preso ao lutador: pode ser cancelado quando uma batalha nova começa.
func _box_tween(box: Dictionary) -> Tween:
	var tw := create_tween()
	box["tweens"].append(tw)
	return tw


func _bt_reset(box: Dictionary) -> void:
	for tw in box["tweens"]:
		if tw.is_valid():
			tw.kill()
	box["tweens"] = []
	for l in box["floats"]:
		if is_instance_valid(l):
			l.queue_free()
	box["floats"] = []
	box["dead"] = false
	for k in ["icon", "blob"]:
		var n: Control = box[k]
		if box["base_x"] != null:
			n.position.x = box["base_x"]
		n.scale = Vector2.ONE
		n.rotation = 0.0
		n.modulate = Color.WHITE
	box["base_x"] = null


func _bt_open_anim() -> void:
	_bt_reset(_bt_left)
	_bt_reset(_bt_right)
	_battle_panel.pivot_offset = _battle_panel.size / 2.0
	_battle_panel.scale = Vector2(0.86, 0.86)
	_battle_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_battle_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_battle_panel, "modulate:a", 1.0, 0.18)


func _bt_base_x(box: Dictionary) -> float:
	var n := _visual(box)
	if box["base_x"] == null:
		box["base_x"] = n.position.x
	return box["base_x"]


func _bt_strike(box: Dictionary, dir: int) -> void:
	var n := _visual(box)
	n.pivot_offset = n.size / 2.0
	var base := _bt_base_x(box)
	if n is HeroPortrait:
		n.play_temp(Models3D.WALK, 0.55, 2.6)  # corre até o oponente
	var tw := _box_tween(box)
	# recua um pouco (antecipação), avança com tudo e volta
	tw.tween_property(n, "position:x", base - dir * 12.0, 0.1).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "rotation", -dir * 0.08, 0.1)
	tw.tween_property(n, "position:x", base + dir * 78.0, 0.12).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(n, "scale", Vector2.ONE * 1.18, 0.12)
	tw.parallel().tween_property(n, "rotation", dir * 0.16, 0.12)
	tw.tween_interval(0.06)
	tw.tween_property(n, "position:x", base, 0.28).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(n, "scale", Vector2.ONE, 0.28)
	tw.parallel().tween_property(n, "rotation", 0.0, 0.28)


func _bt_pulse(box: Dictionary, color: Color) -> void:
	if box["dead"]:
		return
	var n := _visual(box)
	var tw := _box_tween(box)
	tw.tween_property(n, "modulate", color, 0.1)
	tw.tween_property(n, "modulate", Color.WHITE, 0.35)


func _bt_pulse_pid(pid: int, color: Color) -> void:
	var box = _bt_box_for_pid(pid)
	if box != null and _bt_session:
		_bt_pulse(box, color)


func _bt_float(box: Dictionary, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w: Control = box["wrap"]
	box["floats"].append(l)
	w.add_child(l)
	l.position = Vector2(w.size.x / 2.0 - 30.0, 6.0)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", -34.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _bt_float_pid(pid: int, text: String, color: Color) -> void:
	var box = _bt_box_for_pid(pid)
	if box != null and _bt_session:
		_bt_float(box, text, color)


func _bt_hit(box: Dictionary, dmg: int, dodged: bool) -> void:
	var n := _visual(box)
	var base := _bt_base_x(box)
	if dmg <= 0:
		_bt_float(box, "Esquivou!" if dodged else "0", Color("8be9fd") if dodged else Style.MUTED)
		return
	var tw := _box_tween(box)
	tw.tween_property(n, "modulate", Color(1, 0.3, 0.3), 0.04)
	tw.tween_property(n, "modulate", Color.WHITE, 0.3)
	# empurrão para trás, tremida e volta
	var away := -1.0 if box == _bt_left else 1.0
	var tw2 := _box_tween(box)
	tw2.tween_property(n, "position:x", base + away * 26.0, 0.06).set_ease(Tween.EASE_OUT)
	tw2.parallel().tween_property(n, "rotation", away * 0.2, 0.06)
	for dx in [-6.0, 6.0, -3.0, 0.0]:
		tw2.tween_property(n, "position:x", base + away * 14.0 + dx, 0.05)
	tw2.tween_property(n, "position:x", base, 0.16).set_ease(Tween.EASE_OUT)
	tw2.parallel().tween_property(n, "rotation", 0.0, 0.16)
	_bt_slash(box, away)
	_bt_float(box, "-%d" % dmg, Style.BAD)
	var burst := UiBurst.new()
	burst.color = Color("ff9b6b")
	burst.count = 14
	burst.radius = 48.0
	box["wrap"].add_child(burst)


## Corte rápido cruzando o lutador atingido.
func _bt_slash(box: Dictionary, away: float) -> void:
	var w: Control = box["wrap"]
	var c := Vector2(w.size.x / 2.0, w.size.y * 0.42)
	var l := Line2D.new()
	l.width = 7.0
	l.default_color = Color(1, 1, 1, 0.95)
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.points = PackedVector2Array([c + Vector2(-away * 46.0, -44.0), c + Vector2(away * 46.0, 44.0)])
	box["floats"].append(l)
	w.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "width", 1.0, 0.22)
	tw.tween_property(l, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(l.queue_free)


func _bt_play_round(e: Dictionary) -> void:
	var boxes: Array = [_bt_left, _bt_right]
	var acts: Array = _bt_last_actions
	for i in 2:
		match acts[i]:
			"defend": _bt_pulse(boxes[i], Color(0.5, 0.75, 1.0))
			"item": _bt_pulse(boxes[i], Color(0.5, 1.0, 0.6))
			"ability": _bt_pulse(boxes[i], Color(1.0, 0.85, 0.3))
			"flee": _bt_pulse(boxes[i], Color(0.8, 0.8, 0.8))
	var struck := {}
	for h in e["hits"]:
		var src: int = h["src"]
		var dst: int = h["dst"]
		var dmg: int = h["damage"]
		if not struck.has(src):
			struck[src] = true
			_bt_strike(boxes[src], 1 if src == 0 else -1)
		var dodged: bool = acts[dst] == "ability" and dmg <= 0
		_later(0.1, func(): _bt_hit(boxes[dst], dmg, dodged))


func _bt_die(box: Dictionary) -> void:
	if box["dead"]:
		return
	box["dead"] = true
	var n := _visual(box)
	n.pivot_offset = n.size / 2.0
	var tw := _box_tween(box).set_parallel(true)
	tw.tween_property(n, "scale", Vector2.ONE * 0.35, 0.6).set_delay(0.25).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(n, "rotation", 0.9, 0.6).set_delay(0.25)
	tw.tween_property(n, "modulate:a", 0.0, 0.6).set_delay(0.25)
	_later(0.2, func(): _bt_float(box, "Derrotado!", Style.BAD))


func _bt_die_pid(pid: int) -> void:
	var box = _bt_box_for_pid(pid)
	if box != null and _bt_session:
		_bt_die(box)


func _bt_die_monster() -> void:
	if _bt_defender < 0 and _bt_session:
		_bt_die(_bt_right)


func _tween_bar(bar: ProgressBar, v: float) -> void:
	if absf(bar.value - v) < 0.01:
		return
	if _bar_tweens.has(bar) and _bar_tweens[bar].is_valid():
		_bar_tweens[bar].kill()
	var tw := bar.create_tween()
	tw.tween_property(bar, "value", v, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bar_tweens[bar] = tw


func _haptic_for(e: Dictionary) -> void:
	match e["type"]:
		"damage":
			if e["player"] == human:
				Platform.vibrate(40)
		"battle_round":
			for h in e["hits"]:
				if h["damage"] > 0 and ((h["dst"] == 0 and _bt_attacker == human) or (h["dst"] == 1 and _bt_defender == human)):
					Platform.vibrate(50)
					break
		"died":
			if e["player"] == human:
				Platform.vibrate(200)
		"level_up", "equipped":
			if e["player"] == human:
				Platform.vibrate(60)
		"trap_triggered":
			if e["player"] == human:
				Platform.vibrate(120)
		"ring_closed", "sudden_death":
			Platform.vibrate(90)


func _sound_for(e: Dictionary) -> void:
	match e["type"]:
		"dice_rolled": Sfx.play("dice")
		"moved": Sfx.play("step", -2.0 if e["player"] == human else -7.0)
		"battle_started": Sfx.play("battle_start")
		"battle_round":
			var any := false
			var magic := false
			for h in e["hits"]:
				if h["damage"] > 0:
					any = true
				if h["kind"] == "magic":
					magic = true
			if magic:
				Sfx.play("magic")
			if any:
				Sfx.play("hit")
		"damage":
			if e["source"] != "battle":
				Sfx.play("hit")
		"dodged": Sfx.play("dodge")
		"potion_used":
			Sfx.play("potion")
			if e.get("healed", 0) > 0:
				Sfx.play("heal", -3.0)
		"potion_added", "kit_added", "trap_disarmed": Sfx.play("pickup")
		"ability":
			if e.get("healed", 0) > 0:
				Sfx.play("heal")
			elif e["ability"] == "esquiva":
				Sfx.play("dodge")
		"item_collected":
			if e["item"] == Defs.ItemType.TESOURO:
				Sfx.play("trophy")
		"card_drawn": Sfx.play("card")
		"equipped": Sfx.play("equip")
		"level_up": Sfx.play("level_up")
		"died": Sfx.play("death")
		"undead_risen": Sfx.play("undead")
		"trap_set":
			if human < 0 or e["player"] == human:
				Sfx.play("trap_set")
		"trap_triggered": Sfx.play("trap_trigger")
		"ring_warning": Sfx.play("ring_warning")
		"ring_closed", "sudden_death": Sfx.play("ring_close")
		"turn_started":
			if e["player"] == human:
				Sfx.play("turn")
		"flee_attempt":
			if e["success"]:
				Sfx.play("flee")
		"game_over":
			Sfx.play("victory" if (e["winner"] == human or (human < 0 and e["winner"] >= 0)) else "defeat")


func _process_events(events: Array) -> void:
	var anim_dur := 0.22 / speed
	for e in events:
		_sound_for(e)
		_haptic_for(e)
		_fx_for(e)
		var t := EventText.describe(e, state)
		if t != "":
			_log_line(t)
		match e["type"]:
			"moved":
				board_view.animate_move(e["player"], e["from"], anim_dur)
				_last_to[e["player"]] = e["to"]
				if human < 0 or e["player"] == human:
					board_view.center_on(e["to"])
			"retreated":
				board_view.animate_move(e["player"], _last_to.get(e["player"], e["to"]), anim_dur)
			"turn_started":
				if e["player"] == human:
					_toast("Sua vez!")
					board_view.center_on(state.heroes[human].pos)
				elif human < 0:
					board_view.center_on(state.heroes[e["player"]].pos)
			"battle_started":
				_bt_attacker = e["attacker"]
				_bt_defender = e["defender"]
				var m = state.monsters.get(e["monster"])
				_bt_monster_name = m.display_name if m != null else ""
				_bt_text = ""
				_bt_actions_text = ""
			"battle_actions":
				var left = state.heroes[_bt_attacker]
				var right = state.heroes[_bt_defender] if _bt_defender >= 0 else null
				var la := _action_label(e["actions"][0], e["potions"][0], left)
				var ra := _action_label(e["actions"][1], e["potions"][1], right)
				var rn := EventText.nm(state, _bt_defender) if _bt_defender >= 0 else "[b]%s[/b]" % _bt_monster_name
				_bt_actions_text = "%s: [color=#ffd23f]%s[/color]   ·   %s: [color=#ffd23f]%s[/color]" % [EventText.nm(state, _bt_attacker), la, rn, ra]
			"battle_round":
				_bt_text = EventText.round_summary(e, state, _bt_attacker, _bt_defender, _bt_monster_name)
				var k := 0
				for h in e["hits"]:
					if h["damage"] > 0:
						board_view.add_floater(e["cell"] + Vector2i(0, k), "-%d" % h["damage"], Style.BAD)
						var victim := _bt_attacker if h["dst"] == 0 else _bt_defender
						if victim >= 0:
							board_view.flash_hero(victim)
					k += 1
			"damage":
				if e["source"] != "battle":
					board_view.add_floater(_hero_cell(e["player"]), "-%d" % e["amount"], Style.BAD)
					board_view.flash_hero(e["player"])
			"dodged":
				board_view.add_floater(_hero_cell(e["player"]), "Esquivou!", Color("8be9fd"))
			"potion_used":
				if e.get("healed", 0) > 0:
					board_view.add_floater(_hero_cell(e["player"]), "+%d" % e["healed"], Style.GOOD)
			"ability":
				if e.get("healed", 0) > 0:
					board_view.add_floater(_hero_cell(e["player"]), "+%d" % e["healed"], Style.GOOD)
			"xp_gained":
				board_view.add_floater(_hero_cell(e["player"]) + Vector2i(0, -1), "+%d XP" % e["amount"], Style.ACCENT)
			"level_up":
				_toast("%s subiu para o nível %d!" % [state.heroes[e["player"]].display_name, e["level"]])
			"ring_warning":
				_toast("⚠ O anel externo fecha na próxima rodada!")
			"ring_closed":
				_toast("O mapa fechou mais um anel!")
			"sudden_death":
				_toast("MORTE SÚBITA!")
			"undead_risen":
				_toast("☠ %s voltou como morto-vivo!" % state.heroes[e["player"]].display_name)


# ---------------------------------------------------------------------------
# Atualização da interface
# ---------------------------------------------------------------------------

func _refresh() -> void:
	var cur: Hero = state.heroes[state.current_player()]
	var phase_text := ""
	match state.phase:
		Defs.Phase.ROLL: phase_text = "role o dado"
		Defs.Phase.MOVE: phase_text = "mova-se (%d pontos)" % cur.move_points
		Defs.Phase.ACTION: phase_text = "colete, aja ou passe o turno"
		Defs.Phase.BATTLE: phase_text = "BATALHA!"
		Defs.Phase.FINISHED: phase_text = "fim de jogo"
	var warn := ""
	if state.warning_ring >= 0:
		warn = "   ⚠ anel fechando"
	elif state.rings_closed >= state.board.max_rings():
		warn = "   ☠ MORTE SÚBITA"
	status_label.text = "Rodada %d · %s: %s%s" % [state.round_number, cur.display_name, phase_text, warn] if not state.finished else "Rodada %d · Fim de jogo" % state.round_number
	status_label.add_theme_color_override("font_color", Art.player_color(cur.id) if state.phase != Defs.Phase.BATTLE else Style.ACCENT)
	if human < 0 or not state.pending_actors().has(human):
		timer_label.text = ""

	board_view.reach = {}
	board_view.targets = []
	if _my_turn() and state.phase == Defs.Phase.MOVE:
		board_view.reach = state.reachable(state.heroes[human])
	if _targeting and _my_turn():
		for o in _ability_targets():
			board_view.targets.append(o.pos)

	_refresh_cards()
	_refresh_buttons()
	_refresh_battle()
	if state.finished and not _over_shown:
		_show_game_over()


func _refresh_cards() -> void:
	for pid in cards:
		var h: Hero = state.heroes[pid]
		var c: Dictionary = cards[pid]
		c["name"].text = h.display_name + "  ·  " + Defs.CLASS_NAMES[h.hero_class]
		c["lvl"].text = "Nv %d" % h.level
		c["hp"].max_value = h.max_hp
		_tween_bar(c["hp"], h.hp)
		var xp_floor: int = Defs.XP_THRESHOLDS[h.level]
		var xp_next := h.xp_to_next()
		c["xp"].max_value = maxi(1, xp_next - xp_floor)
		c["xp"].value = (h.xp - xp_floor) if xp_next > 0 else 1
		var bits: Array[String] = ["%d/%d vida" % [h.hp, h.max_hp], "Troféus %d/%d" % [h.trophies, state.trophies_total]]
		if h.potions["vida"] + h.potions["forca"] > 0:
			bits.append("Poções V%d F%d" % [h.potions["vida"], h.potions["forca"]])
		if h.cooldown > 0:
			bits.append("recarga %d" % h.cooldown)
		if h.weapon != "":
			bits.append("Arma: %s" % Defs.EQUIPMENT[h.weapon]["name"])
		if h.armor != "":
			bits.append("Armadura: %s" % Defs.EQUIPMENT[h.armor]["name"])
		if h.traps > 0:
			bits.append("Kits %d" % h.traps)
		if h.undead:
			bits.insert(0, "MORTO-VIVO")
		elif not h.alive:
			bits = ["ELIMINADO"]
		c["info"].text = "  ·  ".join(bits)
		c["panel"].tooltip_text = Texts.hero_tooltip(h)
		var is_cur: bool = pid == state.current_player() and not state.finished
		var border := Style.ACCENT if is_cur else Color("2d3342")
		c["panel"].add_theme_stylebox_override("panel", Style.box(Style.PANEL if h.alive else Color("15171d"), 10, border, 2 if is_cur else 1))
		c["panel"].modulate.a = 1.0 if h.alive else 0.5
		c["hp"].add_theme_stylebox_override("fill", Style.box(Color("7be07b") if h.undead else Style.GOOD, 4))


func _refresh_buttons() -> void:
	var mine := _my_turn()
	var hero: Hero = state.heroes[human] if human >= 0 else null
	var ph := state.phase
	buttons["roll"].disabled = not (mine and ph == Defs.Phase.ROLL)
	buttons["end_move"].disabled = not (mine and ph == Defs.Phase.MOVE)
	buttons["collect"].disabled = not (mine and ph == Defs.Phase.ACTION and hero != null and not hero.undead and not state.items_at(hero.pos).is_empty())
	var can_ability: bool = mine and ph == Defs.Phase.ACTION and hero != null and hero.cooldown == 0
	buttons["ability"].disabled = not can_ability
	var ability_names := { Defs.HeroClass.GUERREIRO: "Golpe", Defs.HeroClass.MAGO: "Magia", Defs.HeroClass.LADINO: "Esquiva", Defs.HeroClass.CLERIGO: "Cura" }
	if hero == null:
		buttons["ability"].text = "Habilidade" + _hint("Q")
	elif hero.cooldown == 0:
		buttons["ability"].text = ability_names[hero.hero_class] + _hint("Q")
	else:
		buttons["ability"].text = "%s (%d)" % [ability_names[hero.hero_class], hero.cooldown]
	for k in ["vida", "forca"]:
		var n: int = hero.potions[k] if hero != null else 0
		buttons[k].disabled = not (mine and (ph == Defs.Phase.MOVE or ph == Defs.Phase.ACTION) and n > 0)
		buttons[k].text = "%s x%d%s" % ["Vida" if k == "vida" else "Força", n, _hint("1" if k == "vida" else "2")]
	var can_trap: bool = mine and ph == Defs.Phase.ACTION and hero != null and not hero.undead and hero.traps > 0 and not state.traps.has(hero.pos) and state.active_traps(hero.id) < Defs.MAX_ACTIVE_TRAPS
	buttons["trap"].disabled = not can_trap
	buttons["trap"].text = "Armar x%d%s" % [hero.traps if hero != null else 0, _hint("T")]
	buttons["end_turn"].disabled = not mine


func _update_fighter_box(box: Dictionary, f) -> void:
	var is_hero: bool = f is Hero
	box["blob"].visible = false
	box["icon"].visible = true
	if is_hero:
		box["icon"].set_class(f.hero_class)
		if not box["dead"] and f.undead:
			box["icon"].modulate = Color(0.55, 1.0, 0.65, 0.85)
		box["name"].text = "[center]%s%s[/center]" % [EventText.nm(state, f.id), " ☠" if f.undead else ""]
		box["hp"].add_theme_stylebox_override("fill", Style.box(Color("7be07b") if f.undead else Style.GOOD, 4))
		var s := "[center]%s nv%d\nVida %d/%d\nAtaque %d · Defesa %d[/center]" % [Defs.CLASS_NAMES[f.hero_class], f.level, f.hp, f.max_hp, f.atk_total(), f.def_total()]
		if f.buff_rounds > 0:
			s += "\n[center][color=#d7b0f0]Força +%d (%d rodadas)[/color][/center]" % [f.buff_attack, f.buff_rounds]
		box["stats"].text = s
	else:
		var col: Color = Art.MONSTER_COLORS.get(f.kind, Color.GRAY)
		box["icon"].set_monster(f.kind)
		box["icon"].modulate = Color.WHITE
		if not box["icon"].has_image():
			box["icon"].visible = false
			box["blob"].visible = true
		box["blob"].text = Art.MONSTER_LETTER.get(f.kind, "?")
		box["blob"].add_theme_stylebox_override("normal", Style.box(col, 36))
		box["name"].text = "[center][b]%s[/b][/center]" % f.display_name
		box["hp"].add_theme_stylebox_override("fill", Style.box(Style.BAD, 4))
		box["stats"].text = "[center]nv%d\nVida %d/%d\nAtaque %d · Defesa %d[/center]" % [f.level, f.hp, f.max_hp, f.attack, f.defense]
	box["hp"].max_value = f.max_hp
	_tween_bar(box["hp"], f.hp)


func _refresh_battle() -> void:
	var b := state.battle
	var live: bool = state.phase == Defs.Phase.BATTLE and b != null
	var show: bool = live or (_panel_hold > 0.0 and _bt_a_ref != null)
	var opening: bool = show and not _battle_panel.visible
	_battle_panel.visible = show
	if not show:
		_bt_session = false
		return
	if opening:
		_bt_open_anim.call_deferred()
	if not live:
		# a batalha acabou, mas o painel fica um instante para mostrar o desfecho
		_update_fighter_box(_bt_left, _bt_a_ref)
		_update_fighter_box(_bt_right, _bt_d_ref)
		for k in _bt_buttons:
			_bt_buttons[k].visible = false
		_bt_wait.text = ""
		return
	_bt_title.text = "⚔  Rodada %d de %d" % [b.round_no, Defs.BATTLE_MAX_ROUNDS]
	_update_fighter_box(_bt_left, b.attacker)
	_update_fighter_box(_bt_right, b.defender if b.kind == "pvp" else b.monster)
	_bt_actions.text = "[center]%s[/center]" % _bt_actions_text if _bt_actions_text != "" else ""
	_bt_result.text = "[center]%s[/center]" % _bt_text if _bt_text != "" else "[center][color=#8a90a0]Escolha sua ação.[/color][/center]"
	var me: Hero = state.heroes[human] if human >= 0 else null
	var mine: bool = me != null and b.pids.has(human)
	var must_choose: bool = mine and b.pending().has(human) and _anim_lock <= 0.0
	for k in _bt_buttons:
		_bt_buttons[k].visible = mine
		_bt_buttons[k].disabled = not must_choose
	if mine:
		_bt_buttons["ability"].disabled = not must_choose or me.cooldown > 0
		_bt_buttons["ability"].text = Texts.ability_name(me.hero_class) if me.cooldown == 0 else "%s (%d)" % [Texts.ability_name(me.hero_class), me.cooldown]
		_bt_buttons["vida"].disabled = not must_choose or me.potions["vida"] <= 0
		_bt_buttons["vida"].text = "Poção vida (%d)" % me.potions["vida"]
		_bt_buttons["forca"].disabled = not must_choose or me.potions["forca"] <= 0
		_bt_buttons["forca"].text = "Poção força (%d)" % me.potions["forca"]
	if not mine:
		_bt_wait.text = "Você está assistindo a batalha."
	elif must_choose:
		_bt_wait.text = "Sua vez de escolher."
	else:
		_bt_wait.text = "Aguardando o oponente…"


func _show_game_over() -> void:
	_over_shown = true
	_battle_panel.visible = false
	var text := ""
	if state.winner < 0:
		text = "[center][font_size=34][color=#ffd23f]EMPATE[/color][/font_size]\nNinguém sobreviveu.[/center]"
	else:
		var w: Hero = state.heroes[state.winner]
		var how := "juntou todos os troféus" if w.trophies >= state.trophies_total else "foi o último de pé"
		var you := ""
		if human >= 0:
			you = "\n%s" % ("[color=#5fd38d]Você venceu![/color]" if state.winner == human else "[color=#ff6b6b]Você perdeu.[/color]")
		text = "[center][font_size=34][color=#ffd23f]VITÓRIA[/color][/font_size]\n%s %s.%s[/center]" % [EventText.nm(state, state.winner), how, you]
	text += "\n\n"
	var ids: Array = state.heroes.keys()
	ids.sort()
	for pid in ids:
		var h: Hero = state.heroes[pid]
		var status := "vivo"
		if h.undead:
			status = "morto-vivo"
		elif not h.alive:
			status = "eliminado"
		text += "%s · %s nv%d · %d troféu(s) · %s\n" % [EventText.nm(state, pid), Defs.CLASS_NAMES[h.hero_class], h.level, h.trophies, status]
	text += "\n[color=#8a90a0]Rodadas: %d · Turnos: %d[/color]" % [state.round_number, state.turn_number]
	_over_label.text = text
	_over_panel.visible = true
	_over_panel.pivot_offset = _over_panel.size / 2.0
	_over_panel.scale = Vector2(0.8, 0.8)
	_over_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_over_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_over_panel, "modulate:a", 1.0, 0.25)
	if state.winner >= 0 and (human < 0 or state.winner == human):
		var cf := Confetti.new()
		add_child(cf)
		move_child(cf, _over_center.get_index())
