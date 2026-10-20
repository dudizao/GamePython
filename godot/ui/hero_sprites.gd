class_name HeroSprites
extends Node
## Renderiza os modelos 3D dos heróis em quadros 2D (idle e walk) uma única vez, na abertura.
## O tabuleiro, os cartões e os menus desenham esses quadros; enquanto não ficam prontos (ou sem
## renderizador, como nos testes headless) a interface usa os PNGs antigos.

signal ready_all

const SIZE := 192
const FRAMES := 8
const YAW := 0.6  # ~35°: de três quartos, olhando para a direita
const ANIMS := [Models3D.IDLE, Models3D.WALK]

## chave -> anim -> { "frames": Array[Texture2D], "len": float }
static var _data := {}
static var done := false


## Quadro do herói `cls` na animação `anim` no instante `t` (segundos). null se ainda não existe.
static func frame(cls: int, anim: String, t: float) -> Texture2D:
	return frame_key(Models3D.key_for(cls), anim, t)


## Mesmo que `frame`, pela chave do modelo (heróis ou monstros).
static func frame_key(key: String, anim: String, t: float) -> Texture2D:
	var d: Dictionary = _data.get(key, {}).get(anim, {})
	if d.is_empty():
		return null
	var frames: Array = d["frames"]
	var i := int(floorf(fposmod(t, d["len"]) / d["len"] * frames.size())) % frames.size()
	return frames[i]


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_render_all()


func _render_all() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.95, 1.0)
	env.ambient_light_energy = 0.65
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.75
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.25, 4.0), Vector3(0, 0.72, 0))
	var keys: Array = Models3D.all_keys()
	keys.append_array(Models3D.monster_keys())
	for key in keys:
		var node := Models3D.make(key, Models3D.IDLE)
		if node == null:
			continue
		node.rotation.y = YAW
		vp.add_child(node)
		# enquadra pelo tamanho do modelo: monstros grandes (golem, yeti, polvo) não são cortados
		var box := Models3D.bounds(node)
		var span := maxf(1.75, maxf(box.size.y, box.size.x) * 1.12)
		cam.size = span
		var mid_y := maxf(0.72, box.get_center().y) if span > 1.75 else 0.72
		cam.look_at_from_position(Vector3(0, mid_y + 0.5, 4.0), Vector3(0, mid_y, 0))
		var ap := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var per := {}
		for anim in ANIMS:
			if ap == null or not ap.has_animation(anim):
				continue
			var length := ap.get_animation(anim).length
			ap.play(anim)
			ap.pause()
			var frames: Array = []
			for i in FRAMES:
				ap.seek(length * i / FRAMES, true)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var img := vp.get_texture().get_image()
				frames.append(ImageTexture.create_from_image(img))
			per[anim] = { "frames": frames, "len": maxf(length, 0.1) }
		_data[key] = per
		node.queue_free()
	vp.queue_free()
	done = true
	ready_all.emit()
