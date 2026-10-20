extends SceneTree
## Pré-visualização dos personagens 3D.
## Rodar: godot --path godot -s tools/preview_models.gd
## Espaço alterna parado/andando; setas esquerda/direita giram; Esc fecha.
## Com --write-movie e `-- --shot=caminho.png` salva uma imagem e sai.

var _nodes: Array = []
var _walking := true
var _yaw := 0.45
var _shot := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot = a.substr(7)
	var world := Node3D.new()
	root.add_child(world)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.28)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 1.0)
	env.ambient_light_energy = 0.6
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30
	world.add_child(cam)
	var keys := Models3D.all_keys()
	for i in keys.size():
		var n := Models3D.make(keys[i], Models3D.WALK)
		n.position = Vector3((i % 5) * 1.9 - 3.8, 0.0 if i < 5 else -2.3, 0)
		world.add_child(n)
		_nodes.append(n)
	cam.look_at_from_position(Vector3(0, 1.2, 11.5), Vector3(0, -0.4, 0))
	root.window_input.connect(_on_input)
	if _shot != "":
		for i in 20:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(_shot)
		quit()


func _process(_delta: float) -> bool:
	for n in _nodes:
		n.rotation.y = _yaw
	return false


func _on_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	match event.keycode:
		KEY_SPACE:
			_walking = not _walking
			for n in _nodes:
				Models3D.play(n, Models3D.WALK if _walking else Models3D.IDLE)
		KEY_LEFT: _yaw -= 0.3
		KEY_RIGHT: _yaw += 0.3
		KEY_ESCAPE: quit()
