extends Control
## Raiz: abertura -> menu principal -> nova partida / opções -> partida.

var _bg: MenuBackground
var _fade: ColorRect


func _ready() -> void:
	theme = Style.make_theme()
	add_child(Sfx.new())
	add_child(HeroSprites.new())
	get_tree().node_added.connect(_on_node_added)
	get_window().size_changed.connect(_update_scale)
	_update_scale()
	var base := ColorRect.new()
	base.color = Style.BG
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	_bg = MenuBackground.new()
	add_child(_bg)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)
	show_splash()


## Mantém o tamanho dos botões legível: no celular o lado curto da tela vale 540 unidades (≈ 2 pixels por
## unidade em telas Full HD); no desktop, 720. Retrato e paisagem trocam a base.
func _update_scale() -> void:
	var w := get_window()
	var touch := Platform.is_touch()
	var short := 540 if touch else 720
	var long := 960 if touch else 1280
	var portrait := w.size.y > w.size.x
	w.content_scale_size = Vector2i(short, long) if portrait else Vector2i(long, short)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		for c in get_tree().get_nodes_in_group("screen"):
			if c.has_method("handle_back"):
				c.handle_back()
				return


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		n.pressed.connect(func(): Sfx.play("click", -6.0))


func _clear_screens() -> void:
	for c in get_tree().get_nodes_in_group("screen"):
		c.queue_free()


## Troca a tela e faz um fade-in curto.
func _go(screen: Control, menu_background := true) -> void:
	_clear_screens()
	_bg.visible = menu_background
	add_child(screen)
	move_child(_fade, get_child_count() - 1)
	_fade.modulate.a = 1.0
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.28)


func show_splash() -> void:
	var s := SplashScreen.new()
	s.finished.connect(show_menu)
	_go(s)


func show_menu() -> void:
	var m := MainMenu.new()
	m.play_requested.connect(show_setup)
	m.options_requested.connect(show_options)
	_go(m)


func show_setup() -> void:
	var s := SetupScreen.new()
	s.start_requested.connect(start_game)
	s.back_requested.connect(show_menu)
	_go(s)


func show_options() -> void:
	var o := OptionsScreen.new()
	o.back_requested.connect(show_menu)
	_go(o)


func start_game(cfg: Dictionary) -> void:
	var g := GameScreen.new()
	g.setup(cfg)
	g.add_to_group("screen")
	g.exit_requested.connect(show_menu)
	_go(g, false)
