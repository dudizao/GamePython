extends SceneTree
## Rodar: godot --headless --path godot -s tests/ui_smoke.gd
## Joga partidas inteiras pela interface (humano guiado pelos botões/cliques) e confere que nada quebra.

var _fails := 0


func _initialize() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var app = packed.instantiate()
	root.add_child(app)
	await process_frame
	await _run_menus()
	await _run_dice_styles()
	await _run_modals()
	await _run_mobile()
	await _run_watch(11, 3)
	await _run_human(21, 3, Defs.HeroClass.MAGO)
	await _run_human(22, 4, Defs.HeroClass.LADINO)
	await _run_human(23, 2, Defs.HeroClass.CLERIGO)
	print("\nUI smoke: %s" % ("OK" if _fails == 0 else "%d falhas" % _fails))
	quit(1 if _fails > 0 else 0)


func _make(seed_value: int, players: int, cls: int, watch: bool) -> GameScreen:
	var g := GameScreen.new()
	g.setup({ "players": players, "class": cls, "map": 1 + seed_value % 15, "seed": seed_value, "watch": watch, "bot_delay": 0.0 })
	g.speed = 60.0  # as animações dos bots esperam tempo real: acelera nos testes
	root.add_child(g)
	g.size = Vector2(1280, 720)
	return g


func _find(app: Node, type) -> Node:
	for c in app.get_children():
		if is_instance_of(c, type):
			return c
	return null


func _run_menus() -> void:
	var app = root.get_child(root.get_child_count() - 1)
	for c in root.get_children():
		if c.name == "App":
			app = c
	await process_frame
	var splash := _find(app, SplashScreen)
	if splash == null:
		_fails += 1
		print("  FALHOU: abertura não apareceu")
		return
	splash._t = 1.0
	splash._finish()
	await process_frame
	await process_frame
	var main := _find(app, MainMenu)
	if main == null:
		_fails += 1
		print("  FALHOU: menu principal não apareceu depois da abertura")
		return
	main._open_help()
	await process_frame
	if main.get_node_or_null("Help") == null:
		_fails += 1
		print("  FALHOU: ajuda não abriu no menu")
	main.handle_back()
	await process_frame
	await process_frame
	if main.get_node_or_null("Help") != null:
		_fails += 1
		print("  FALHOU: voltar não fechou a ajuda")
	main.play_requested.emit()
	await process_frame
	await process_frame
	var setup := _find(app, SetupScreen)
	if setup == null:
		_fails += 1
		print("  FALHOU: tela de nova partida não abriu")
		return
	if setup._class_cards.size() != 4 or setup._map_tiles.size() != 16:
		_fails += 1
		print("  FALHOU: cartões/mapas faltando (%d/%d)" % [setup._class_cards.size(), setup._map_tiles.size()])
	setup._class_cards[Defs.HeroClass.LADINO].chosen.emit(Defs.HeroClass.LADINO)
	setup._map_tiles[9].chosen.emit(9)
	if not setup._class_cards[Defs.HeroClass.LADINO].selected or not setup._map_tiles[9].selected:
		_fails += 1
		print("  FALHOU: seleção de classe/mapa não marcou os cartões")
	var cfg := []
	setup.start_requested.connect(func(c): cfg.append(c))
	setup._watch = true
	setup._on_play()
	if cfg.size() != 1 or cfg[0]["class"] != Defs.HeroClass.LADINO or cfg[0]["map"] != 9:
		_fails += 1
		print("  FALHOU: configuração da partida incorreta: %s" % str(cfg))
	setup._watch = false
	# volta ao menu e abre as opções
	setup.handle_back()
	await process_frame
	await process_frame
	main = _find(app, MainMenu)
	main.options_requested.emit()
	await process_frame
	await process_frame
	var opt := _find(app, OptionsScreen)
	if opt == null:
		_fails += 1
		print("  FALHOU: opções não abriram")
		return
	var sfx := Sfx.instance
	var old_speed := sfx.bot_speed
	sfx.set_bot_speed(4)
	sfx.set_sfx_volume(0.5)
	if sfx.bot_speed != 4 or absf(sfx.sfx_volume - 0.5) > 0.001:
		_fails += 1
		print("  FALHOU: ajustes de opção não aplicados")
	sfx.set_bot_speed(old_speed)
	sfx.set_sfx_volume(1.0)
	opt.handle_back()
	await process_frame
	await process_frame
	# iniciar partida pelo app (usa a velocidade dos bots)
	app.start_game({ "players": 3, "class": Defs.HeroClass.CLERIGO, "map": 4, "seed": 5, "watch": true, "bot_speed": 2 })
	await process_frame
	await process_frame
	var g := _find(app, GameScreen) as GameScreen
	if g == null or g.speed != 2.0:
		_fails += 1
		print("  FALHOU: partida não iniciou com a velocidade configurada")
	else:
		g.exit_requested.emit()
		await process_frame
		await process_frame
		if _find(app, MainMenu) == null:
			_fails += 1
			print("  FALHOU: sair da partida não voltou ao menu")
	print("  ok: abertura, menu, nova partida, opções")


func _count(log: Array, prefix: String) -> int:
	var n := 0
	for c in log:
		if str(c).begins_with(prefix):
			n += 1
	return n


func _roll_and_wait(st: DiceStage, values: Array, style: String, special: Dictionary) -> void:
	st.roll_move(values, Color("4ea1ff"), "teste", 60.0, true, style, special)
	var f := 0
	while st.is_active() and f < 900:
		f += 1
		await process_frame
	if st.is_active():
		_fails += 1
		print("  FALHOU: animação do dado (%s) não terminou" % style)


func _run_dice_styles() -> void:
	var g := _make(51, 3, Defs.HeroClass.GUERREIRO, true)
	g.set_process(false)  # a partida não joga sozinha: os bots interromperiam as rolagens medidas aqui
	await process_frame
	var st: DiceStage = g._dice
	await _roll_and_wait(st, [6, 6], "full", { "kind": "six", "text": "DOIS 6!  +2" })
	if not st.celebrated or not ("double_gold" in st.cue_log):
		_fails += 1
		print("  FALHOU: par de 6 não comemorou (%s)" % str(st.cue_log))
	if not ("rattle" in st.cue_log) or _count(st.cue_log, "whoosh") < 2:
		_fails += 1
		print("  FALHOU: a versão completa não tocou chocalho e vento (%s)" % str(st.cue_log))
	if _count(st.cue_log, "clack") < 2:
		_fails += 1
		print("  FALHOU: os quiques não tocaram batidas (%s)" % str(st.cue_log))
	await _roll_and_wait(st, [2, 5], "quick", {})
	if st.celebrated or ("rattle" in st.cue_log):
		_fails += 1
		print("  FALHOU: a versão curta não deveria ter mão nem comemoração (%s)" % str(st.cue_log))
	if _count(st.cue_log, "clack") < 2:
		_fails += 1
		print("  FALHOU: a versão curta não tocou batidas")
	await _roll_and_wait(st, [1, 1], "full", { "kind": "snake", "text": "OLHOS DE COBRA…" })
	if not ("double_one" in st.cue_log):
		_fails += 1
		print("  FALHOU: olhos de cobra sem som de azar (%s, celebrou=%s)" % [str(st.cue_log), str(st.celebrated)])
	# gestos por classe: todas terminam; o guerreiro bate com força; todas tocam chocalho
	for cls in Defs.CLASS_NAMES:
		st.roll_move([4, 2], Color("ff6b6b"), "x", 60.0, false, "full", {}, cls)
		var ff := 0
		while st.is_active() and ff < 900:
			ff += 1
			await process_frame
		if st.is_active():
			_fails += 1
			print("  FALHOU: gesto da classe %s não terminou" % Defs.CLASS_NAMES[cls])
		if not ("rattle" in st.cue_log):
			_fails += 1
			print("  FALHOU: classe %s sem chocalho" % Defs.CLASS_NAMES[cls])
		var slammed := "hit" in st.cue_log
		if (cls == Defs.HeroClass.GUERREIRO) != slammed:
			_fails += 1
			print("  FALHOU: só o guerreiro deve bater os dados com força (classe %s, bateu=%s)" % [Defs.CLASS_NAMES[cls], str(slammed)])
	# pular: terminar de uma vez
	st.roll_move([3, 4], Color("4ea1ff"), "x", 1.0, true, "full", {})
	await process_frame
	st.skip()
	var f := 0
	while st.is_active() and f < 300:
		f += 1
		await process_frame
	if st.is_active():
		_fails += 1
		print("  FALHOU: pular não encerrou a animação")
	# ajustes salvos
	var sfx := Sfx.instance
	var old_h := sfx.dice_human
	var old_b := sfx.dice_bots
	sfx.set_dice_human(2)
	sfx.set_dice_bots(0)
	if sfx.dice_human != 2 or sfx.dice_bots != 0:
		_fails += 1
		print("  FALHOU: opções de dado não aplicaram")
	sfx.set_dice_human(old_h)
	sfx.set_dice_bots(old_b)
	print("  ok: estilos de animação, sons sincronizados e comemoração de par")
	g.queue_free()


func _run_modals() -> void:
	var g := _make(31, 3, Defs.HeroClass.GUERREIRO, false)
	await process_frame
	g._open_help()
	await process_frame
	if g._modal == null:
		_fails += 1
		print("  FALHOU: ajuda não abriu")
	else:
		var before := g.state.turn_number
		for i in 5:
			await process_frame  # com a ajuda aberta o jogo fica parado
		if g.state.turn_number != before:
			_fails += 1
			print("  FALHOU: jogo andou com a ajuda aberta")
		g._modal.close()
		await process_frame
		if g._modal != null:
			_fails += 1
			print("  FALHOU: ajuda não fechou")
	g._confirm_exit()
	await process_frame
	if g._modal == null:
		_fails += 1
		print("  FALHOU: confirmação de saída não abriu")
	else:
		g._modal.queue_free()
		g._modal = null
	print("  ok: ajuda e confirmação de saída")
	g.queue_free()


func _tap(g: GameScreen, p: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = p
	g.board_view._gui_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = p
	g.board_view._gui_input(up)


func _run_mobile() -> void:
	print("  (modo toque: %s)" % str(Platform.is_touch()))
	root.size = Vector2i(540, 1170)
	await process_frame
	var g := _make(41, 3, Defs.HeroClass.MAGO, false)
	g.size = Vector2(540, 1170)
	await process_frame
	await process_frame
	if not g._portrait or g._action_bar.columns != 4:
		_fails += 1
		print("  FALHOU: layout retrato não aplicado (portrait=%s, colunas=%d)" % [str(g._portrait), g._action_bar.columns])
	if g.board_view.size.y < 200 or g.board_view.size.x < 300:
		_fails += 1
		print("  FALHOU: tabuleiro pequeno demais no retrato: %s" % str(g.board_view.size))
	# toque x arrasto no tabuleiro
	g.board_view.set_zoom(2.5)
	await process_frame
	var taps := []
	g.board_view.cell_pressed.connect(func(c): taps.append(c))
	var mid: Vector2 = g.board_view.size / 2.0
	_tap(g, mid)
	if taps.size() != 1:
		_fails += 1
		print("  FALHOU: toque não gerou exatamente um clique (%d)" % taps.size())
	var before: Vector2 = g.board_view._center
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = mid
	g.board_view._gui_input(down)
	var mv := InputEventMouseMotion.new()
	mv.position = mid + Vector2(60, 0)
	mv.relative = Vector2(60, 0)
	g.board_view._gui_input(mv)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = mid + Vector2(60, 0)
	g.board_view._gui_input(up)
	if taps.size() != 1:
		_fails += 1
		print("  FALHOU: arrastar virou clique")
	if g.board_view._center.x >= before.x:
		_fails += 1
		print("  FALHOU: arrastar não moveu a câmera")
	# limites de zoom
	g.board_view.set_zoom(100.0)
	if g.board_view.cell_size() > BoardView.MAX_CELL + 0.1:
		_fails += 1
		print("  FALHOU: zoom passou do limite")
	g.board_view.set_zoom(0.1)
	if g.board_view.zoom < 1.0:
		_fails += 1
		print("  FALHOU: zoom abaixo de 1")
	# o clique em uma casa mostra informações (sem mouse)
	g.board_view.set_zoom(2.0)
	g.hover_label.text = ""
	_tap(g, g.board_view.size / 2.0)
	if g.hover_label.text == "":
		_fails += 1
		print("  FALHOU: tocar numa casa não mostrou informações")
	# toque num card abre os detalhes
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	g.cards[0]["panel"].gui_input.emit(ev)
	if g._modal == null:
		_fails += 1
		print("  FALHOU: card não abriu detalhes")
	else:
		g.handle_back()
		await process_frame
		if g._modal != null:
			_fails += 1
			print("  FALHOU: botão voltar não fechou os detalhes")
	# girar para paisagem
	root.size = Vector2i(1170, 540)
	await process_frame
	await process_frame
	if g._portrait or g._action_bar.columns != 8:
		_fails += 1
		print("  FALHOU: layout paisagem não aplicado")
	# a partida inteira em retrato, com o humano usando os controles
	root.size = Vector2i(540, 1170)
	await process_frame
	await process_frame
	await _play(g, true)
	print("  ok: layout retrato/paisagem, toque e arrasto")
	g.queue_free()
	root.size = Vector2i(1280, 720)
	await process_frame


func _run_watch(seed_value: int, players: int) -> void:
	var g := _make(seed_value, players, Defs.HeroClass.GUERREIRO, true)
	await _play(g, false)
	g.queue_free()


func _run_human(seed_value: int, players: int, cls: int) -> void:
	var g := _make(seed_value, players, cls, false)
	await _play(g, true)
	g.queue_free()


func _play(g: GameScreen, drive_human: bool) -> void:
	var frames := 0
	while not g.state.finished and frames < 6000:
		frames += 1
		if drive_human and g.state.pending_actors().has(g.human):
			_human_step(g)
		await process_frame
	if not g.state.finished:
		_fails += 1
		print("  FALHOU: partida não terminou (seed/humano=%s)" % str(drive_human))
	else:
		print("  ok: %d frames, vencedor %d, rodada %d" % [frames, g.state.winner, g.state.round_number])
	await process_frame
	if not g._over_panel.visible:
		_fails += 1
		print("  FALHOU: tela de fim de jogo não apareceu")


## Usa o Bot só para decidir, mas executa pelos controles reais da interface.
func _human_step(g: GameScreen) -> void:
	var a := Bot.choose(g.state, g.human)
	var tp: String = a["type"]
	if tp == "battle_action":
		var key: String = a["action"]
		if key == "item":
			key = a["potion"]
		var btn: Button = g._bt_buttons[key]
		if btn.disabled and g._anim_lock > 0.0:
			return  # a janela de batalha trava os botões enquanto a rodada anima
		if btn.disabled:
			_fails += 1
			print("  FALHOU: botão de batalha '%s' desabilitado" % key)
			g._do(g.human, a)
		else:
			btn.pressed.emit()
		return
	var map := { "roll": "roll", "end_move": "end_move", "collect": "collect", "end_turn": "end_turn", "set_trap": "trap" }
	if map.has(tp):
		var b: Button = g.buttons[map[tp]]
		if b.disabled:
			_fails += 1
			print("  FALHOU: botão '%s' desabilitado na fase %d" % [tp, g.state.phase])
			g._do(g.human, a)
		else:
			b.pressed.emit()
	elif tp == "move":
		if not g.board_view.reach.has(a["to"]):
			_fails += 1
			print("  FALHOU: destino fora do alcance mostrado na tela")
		g.board_view.cell_pressed.emit(a["to"])
	elif tp == "use_item":
		var b: Button = g.buttons[a["potion"]]
		if b.disabled:
			_fails += 1
			print("  FALHOU: botão de poção desabilitado")
		else:
			b.pressed.emit()
	elif tp == "ability":
		g.buttons["ability"].pressed.emit()
		if a.has("target"):
			if g._targeting:
				g.board_view.cell_pressed.emit(g.state.heroes[a["target"]].pos)
	else:
		g._do(g.human, a)
