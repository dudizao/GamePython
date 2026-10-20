class_name DiceStage
extends SubViewportContainer
## Palco 3D transparente por cima do tabuleiro: uma mão balança, solta dois dados vermelhos que
## quicam e assentam no resultado (modo MOVE); ou dados d20 que giram e param (modo BATTLE).
## Só apresentação: o resultado já foi decidido pelo núcleo de regras.

signal finished

enum Mode { MOVE, BATTLE }

const RED := Color(0.85, 0.17, 0.13)
const WHITE_PIP := Color(0.97, 0.97, 0.95)

# linha do tempo do modo MOVE (segundos; dividida pela velocidade)
const T_IN := 0.26          # a mão desce e chega com um leve exagero
const T_PREP := 0.38        # antecipação: recua e arma o pulso
const T_SHAKE_END := 0.80   # sacudida
const T_RELEASE := 0.93     # os dados saem (durante o arremesso)
const T_THROW := 0.97       # fim do arremesso (chicote do pulso)
const T_FOLLOW_END := 1.30  # passa do ponto e relaxa
const T_AWAY_END := 1.78    # sai de cena
const T_FADE := 0.25
const FINGER_DELAY := [0.055, 0.037, 0.018, 0.0]  # os dedos abrem em sequência

## Gesto de cada classe (amp/freq: sacudida; prep_up: quão alto arma; thr_y/over_y: altura do arremesso;
## flick: inclinação final do pulso; roll_f: giro do pulso (rad); speed: força do arremesso).
const GESTURES := {
	Defs.HeroClass.GUERREIRO: { "amp": 1.45, "freq": 0.9, "prep_up": 0.28, "thr_y": 1.5, "over_y": 1.35, "flick": -0.65, "roll_f": 0.0, "speed": 3.0, "slam": true },
	Defs.HeroClass.MAGO: { "amp": 0.85, "freq": 1.0, "prep_up": 0.1, "thr_y": 1.95, "over_y": 1.85, "flick": -0.35, "roll_f": 0.65, "speed": 2.3, "sparkle": Color(0.72, 0.55, 1.0) },
	Defs.HeroClass.LADINO: { "amp": 0.7, "freq": 1.6, "prep_up": 0.0, "thr_y": 1.9, "over_y": 1.75, "flick": -0.55, "roll_f": -3.0, "speed": 2.6 },
	Defs.HeroClass.CLERIGO: { "amp": 0.55, "freq": 0.8, "prep_up": 0.32, "thr_y": 2.0, "over_y": 1.9, "flick": -0.25, "roll_f": 0.0, "speed": 1.9, "aura": Color(1.0, 0.84, 0.3) },
}
const DEFAULT_GESTURE := { "amp": 1.0, "freq": 1.0, "prep_up": 0.0, "thr_y": 1.9, "over_y": 1.75, "flick": -0.45, "roll_f": 0.0, "speed": 2.3 }

var mode := Mode.MOVE
var dim: ColorRect
var label: Label

var _vp: SubViewport
var _cam: Camera3D
var _world: Node3D
var _hand: Hand3D
var _hand_shadow: MeshInstance3D
var _diag := 0.0   # ângulo da diagonal por onde a mão entra (rad); sinal = lado
var _bodies: Array = []
var _t := 0.0
var _scale := 1.0
var _total := 0.0
var _active := false
var _text := ""
var _rng := RandomNumberGenerator.new()
var _num_labels: Array = []   # números 2D sobre os d20 (legíveis em tamanho pequeno)
var _values: Array = []
var _cues: Array = []          # sons agendados na linha do tempo
var _special: Dictionary = {}  # comemoração de par: { kind, text }
var _t_land := 0.0
var _celebrating := false
var _glow_t := 0.0
var _glow_color := Color.WHITE
var _big: Label
var _cam_amp := 0.0
var _style := "full"
var _gp: Dictionary = DEFAULT_GESTURE
## Registro dos sons tocados e se a comemoração aconteceu (útil nos testes).
var cue_log: Array[String] = []
var celebrated := false
## Quando os dados da última rolagem terminam de assentar (segundos na linha do tempo).
var last_settle := 0.0


## Cria o palco dentro de `parent` (com um escurecimento atrás quando `with_dim`).
static func create(parent: Control, p_mode: int, with_dim := true) -> DiceStage:
	var st := DiceStage.new()
	st.mode = p_mode
	if with_dim:
		var d := ColorRect.new()
		d.color = Color(0.02, 0.03, 0.06, 0.45)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		d.modulate.a = 0.0
		parent.add_child(d)
		st.dim = d
	parent.add_child(st)
	return st


func _ready() -> void:
	_rng.randomize()
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mode == Mode.MOVE:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X if Platform.is_touch() else Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)

	_world = Node3D.new()
	_vp.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 1.0)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 28, 0)
	sun.light_energy = 0.95
	_world.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3, 4, 3)
	fill.light_energy = 0.3
	fill.omni_range = 14.0
	_world.add_child(fill)

	_cam = Camera3D.new()
	_cam.fov = 38.0 if mode == Mode.MOVE else 40.0
	_cam.current = true
	_vp.add_child(_cam)
	if mode == Mode.MOVE:
		_cam.look_at_from_position(Vector3(0, 7.4, 3.2), Vector3(0, 0, 0.3), Vector3.UP)
	else:
		_cam.look_at_from_position(Vector3(0, 3.4, 1.3), Vector3(0, 0, 0.25), Vector3.UP)
	if mode == Mode.MOVE:
		label = Label.new()
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 7)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		label.offset_top = -64
		label.offset_bottom = -30
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.visible = false
		add_child(label)
		_big = Label.new()
		_big.add_theme_font_size_override("font_size", 44)
		_big.add_theme_color_override("font_outline_color", Color.BLACK)
		_big.add_theme_constant_override("outline_size", 10)
		_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_big.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_big.offset_top = 36
		_big.offset_left = -300
		_big.offset_right = 300
		_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_big.visible = false
		add_child(_big)
	visible = false


func is_active() -> bool:
	return _active


## Fecha rápido (o jogador agiu antes da animação acabar).
func skip() -> void:
	if _active:
		_t = maxf(_t, _total - T_FADE)


func _clear() -> void:
	_cues = []
	_special = {}
	_celebrating = false
	_cam_amp = 0.0
	if _big != null:
		_big.visible = false
	for l in _num_labels:
		l.queue_free()
	_num_labels = []
	_values = []
	for b in _bodies:
		b.node.queue_free()
		b.shadow.queue_free()
	_bodies = []
	if _hand != null:
		_hand.queue_free()
		_hand = null
	if _hand_shadow != null:
		_hand_shadow.queue_free()
		_hand_shadow = null


func _start(time_scale: float) -> void:
	_scale = maxf(0.5, time_scale)
	_t = 0.0
	_active = true
	visible = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _make_body(value: int, kind: String, color: Color, start: Vector3, land: Vector3, release: float, dur: float) -> Dice3D.Body:
	var b := Dice3D.Body.new()
	if kind == "d6":
		b.node = Dice3D.make_d6(color, WHITE_PIP, WHITE_PIP)
		b.rest_y = Dice3D.D6_HALF
		b.q_final = Dice3D.d6_final(value, _rng.randf() * TAU)
	else:
		b.node = Dice3D.make_d20(color)
		b.rest_y = Dice3D.D20_RADIUS * 0.8
		b.q_final = Dice3D.d20_final(value, _rng.randf() * TAU)
	b.shadow = Dice3D.make_shadow()
	_world.add_child(b.node)
	_world.add_child(b.shadow)
	b.start = start
	b.land = land
	b.t_release = release
	b.dur = dur
	b.spin_axis = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.3, 1), _rng.randf_range(-1, 1)).normalized()
	b.spin_turns = _rng.randf_range(2.3, 3.4)
	b.update(-1.0)
	return b


func _play(sound: String, vol: float, pitch := 1.0) -> void:
	cue_log.append(sound)
	Sfx.play(sound, vol, pitch)


## Roda a física e devolve a trajetória no referencial do mundo (já com a diagonal aplicada).
func _simulate(starts: Array, vels: Array, rest_y: float, bounds: Rect2, max_t: float) -> Dictionary:
	var r := DicePhysics.simulate(starts, vels, rest_y, bounds, max_t)
	var world_samples: Array = []
	for arr in r["samples"]:
		var w := PackedVector3Array()
		for p in arr:
			w.append(_to_world(p))
		world_samples.append(w)
	r["samples"] = world_samples
	for e in r["events"]:
		e["pos"] = _to_world(e["pos"])
	return r


## Sons, poeira e brilho no instante em que acontecem na simulação.
func _cues_from_sim(r: Dictionary, release: float) -> void:
	var move := mode == Mode.MOVE
	for e in r["events"]:
		var tt: float = release + e["t"]
		if e["kind"] == "die":
			_cues.append({ "t": tt, "name": "clack%d" % (1 + _rng.randi() % 3), "vol": -1.0 if move else -5.0, "pitch": _rng.randf_range(1.25, 1.5) })
		elif e["power"] > 0.1:
			var vol := lerpf(-12.0, -2.0, e["power"]) - (0.0 if move else 4.0)
			_cues.append({ "t": tt, "name": "clack%d" % (1 + _rng.randi() % 3), "vol": vol, "pitch": _rng.randf_range(0.92, 1.15) })
			if move and e["power"] > 0.28:
				_cues.append({ "t": tt, "dust": e["pos"], "power": e["power"] })
	for i in _bodies.size():
		_cues.append({ "t": release + _bodies[i].t_stop, "flash": i, "name": "settle", "vol": -9.0 if move else -12.0, "pitch": _rng.randf_range(0.95, 1.1) })


## Movimento. style "full": a mão balança, abre e solta os dados. "quick": só os dados caem (jogadas dos bots).
## `special`: { "kind": "double" | "six" | "snake", "text": String } para a comemoração de par.
func roll_move(values: Array, color: Color, text: String, time_scale := 1.0, from_right := true, style := "full", special := {}, hero_class := -1) -> void:
	_clear()
	_gp = GESTURES.get(hero_class, DEFAULT_GESTURE)
	cue_log = []
	celebrated = false
	mode = Mode.MOVE
	_style = style
	_text = text
	_special = special
	_diag = -DIAG_ANGLE if from_right else DIAG_ANGLE
	_cam.fov = 38.0
	var n := values.size()
	var full := style == "full"
	if full:
		_hand = Hand3D.new(color, hero_class)
		_world.add_child(_hand)
		_hand_shadow = Dice3D.make_shadow()
		_world.add_child(_hand_shadow)
		_cues = [
			{ "t": 0.02, "name": "whoosh", "vol": -10.0, "pitch": 0.9 },
			{ "t": T_PREP, "name": "rattle", "vol": -3.0, "pitch": 1.0 },
			{ "t": T_SHAKE_END + 0.02, "name": "whoosh", "vol": -6.0, "pitch": 1.25 },
		]
	var release := T_RELEASE if full else 0.0
	var release_local := _hand_pos_local(T_RELEASE) + Vector3(0, -0.55, 0.55)
	if full:
		var hand_floor := _to_world(Vector3(0.0, 0.0, 1.0))
		if _gp.has("slam"):  # o guerreiro bate os dados com força
			_cues.append({ "t": T_THROW, "name": "hit", "vol": -4.0, "pitch": 0.75 })
			_cues.append({ "t": T_THROW, "dust": hand_floor, "power": 0.9 })
			_cues.append({ "t": T_THROW, "shake": 0.09 })
		if _gp.has("sparkle"):  # o mago lança com uma faísca
			_cues.append({ "t": T_RELEASE, "sparkles": _to_world(release_local), "color": _gp["sparkle"], "count": 18 })
			_cues.append({ "t": T_RELEASE + 0.18, "sparkles": _to_world(release_local + Vector3(0, -0.3, 0.9)), "color": _gp["sparkle"], "count": 10 })
		if _gp.has("aura"):  # o clérigo abençoa os dados durante a sacudida
			for k in 4:
				_cues.append({ "t": T_PREP + 0.1 * k, "sparkles": _to_world(_hand_pos_local(T_PREP + 0.1 * k) + Vector3(0, -0.2, -0.5)), "color": _gp["aura"], "count": 7 })
	var starts: Array = []
	var vels: Array = []
	for i in n:
		var side := float(i) - (n - 1) / 2.0
		if full:
			starts.append(release_local + Vector3(side * 0.95, 0.0, 0.0))
			vels.append(Vector3(-side * _rng.randf_range(0.0, 0.9) + _rng.randf_range(-0.45, 0.45), -1.0, float(_gp["speed"]) * _rng.randf_range(0.85, 1.15)))
		else:
			starts.append(Vector3(side * 1.3 + _rng.randf_range(-0.15, 0.15), 3.2, 0.2))
			vels.append(Vector3(-side * _rng.randf_range(0.1, 0.8), -2.0, _rng.randf_range(1.2, 2.2)))
	var r := _simulate(starts, vels, Dice3D.D6_HALF, Rect2(-2.4, 0.2, 4.8, 2.1), 1.3 if full else 0.8)
	for i in n:
		var smp: PackedVector3Array = r["samples"][i]
		var b := _make_body(values[i], "d6", RED, smp[0], smp[smp.size() - 1], release + (0.0 if full else 0.04 * i), 0.8)
		b.samples = smp
		b.t_stop = r["t_stop"][i]
		_bodies.append(b)
	last_settle = minf(r["duration"], 1.05 if full else 0.8)
	_t_land = release + last_settle
	_total = _t_land + (0.5 if full else 0.25) + (T_FADE if full else 0.18)
	var fade := T_FADE if full else 0.18
	for b in _bodies:
		b.fade_start = _total - fade
		b.fade_dur = fade
	_cues_from_sim(r, release)
	if label != null:
		label.text = text
		label.add_theme_color_override("font_color", color.lightened(0.3))
		label.visible = false
	_start(time_scale)
	_pose(0.0)


## Batalha: dados d20 caem do alto, quicam, às vezes se batem, e assentam. items: [{ "value": int, "color": Color }].
func roll_battle(items: Array, time_scale := 1.0) -> void:
	_clear()
	cue_log = []
	mode = Mode.BATTLE
	_style = "battle"
	_cam.fov = 40.0
	var n := items.size()
	var starts: Array = []
	var vels: Array = []
	for i in n:
		var side := float(i) - (n - 1) / 2.0
		starts.append(Vector3(side * 1.2 + _rng.randf_range(-0.15, 0.15), 3.0, -0.9))
		vels.append(Vector3(-side * _rng.randf_range(0.1, 0.7) + _rng.randf_range(-0.3, 0.3), -1.5, _rng.randf_range(1.3, 2.3)))
	var rest := Dice3D.D20_RADIUS * 0.8
	var r := _simulate(starts, vels, rest, Rect2(-1.9, -0.9, 3.8, 2.5), 0.72)
	for i in n:
		var smp: PackedVector3Array = r["samples"][i]
		var b := _make_body(items[i]["value"], "d20", items[i]["color"], smp[0], smp[smp.size() - 1], 0.0, 0.8)
		b.samples = smp
		b.t_stop = r["t_stop"][i]
		_bodies.append(b)
		var l := Label.new()
		l.text = str(items[i]["value"])
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 8)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.visible = false
		add_child(l)
		_num_labels.append(l)
	last_settle = minf(r["duration"], 0.72)
	_t_land = last_settle
	_total = last_settle + 0.5 + 0.22
	for b in _bodies:
		b.fade_start = _total - 0.22
		b.fade_dur = 0.22
	_cues_from_sim(r, 0.0)
	_start(time_scale)


## Nuvem de poeira onde o dado bate no chão.
func _spawn_dust(pos: Vector3, power: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 7 + int(power * 9.0)
	p.lifetime = 0.55
	p.explosiveness = 1.0
	var sph := SphereMesh.new()
	sph.radius = 0.08
	sph.height = 0.16
	sph.radial_segments = 6
	sph.rings = 3
	p.mesh = sph
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.82, 0.76, 0.64)
	p.material_override = m
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	p.color_ramp = g
	p.direction = Vector3(0, 1, 0)
	p.spread = 80.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.1 + 1.4 * power
	p.gravity = Vector3(0, -2.5, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.position = Vector3(pos.x, 0.06, pos.z)
	_world.add_child(p)
	p.emitting = true
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(p.queue_free)


## Faíscas de cor (magia e bênção).
func _spawn_sparkles(pos: Vector3, color: Color, count: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = count
	p.lifetime = 0.8
	p.explosiveness = 0.85
	var sph := SphereMesh.new()
	sph.radius = 0.05
	sph.height = 0.1
	sph.radial_segments = 6
	sph.rings = 3
	p.mesh = sph
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	p.material_override = m
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	p.color_ramp = g
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.7
	p.gravity = Vector3(0, -0.8, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	p.position = pos
	_world.add_child(p)
	p.emitting = true
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(p.queue_free)


## Brilho curto quando o dado para.
func _flash_body(i: int) -> void:
	if i >= _bodies.size():
		return
	_bodies[i].flash_end = _t + 0.35
	var sp := _cam.unproject_position(_bodies[i].node.position + Vector3(0, 0.55, 0))
	var burst := UiBurst.new()
	burst.color = Color(1.0, 0.95, 0.75)
	burst.count = 7
	burst.radius = 34.0
	burst.stars = true
	burst.dur = 0.4
	add_child(burst)
	burst.origin = sp


## Zoom suave sobre os dados no instante em que assentam (só na versão completa).
func _update_camera() -> void:
	if mode != Mode.MOVE or _style != "full":
		return
	var k_in := clampf((_t - (_t_land - 0.3)) / 0.35, 0.0, 1.0)
	var k_out := clampf((_t - (_total - T_FADE - 0.2)) / 0.3, 0.0, 1.0)
	var k := _smooth(k_in) * (1.0 - _smooth(k_out))
	_cam.fov = lerpf(38.0, 33.5, k)


func _process(delta: float) -> void:
	if not _active:
		return
	# câmera lenta curta no último quique (só na versão completa)
	var rate := 1.0
	if _style == "full" and mode == Mode.MOVE and _t > _t_land - 0.3 and _t < _t_land + 0.12:
		rate = 0.45
	_t += delta * _scale * rate
	if mode == Mode.MOVE and _hand != null:
		_pose(_t)
	for b in _bodies:
		b.update(_t)
	for c in _cues:
		if c.get("fired", false) or _t < c["t"]:
			continue
		c["fired"] = true
		if c.has("name"):
			_play(c["name"], c["vol"], c.get("pitch", 1.0) * clampf(_scale, 1.0, 1.5))
		if c.has("dust"):
			_spawn_dust(c["dust"], c["power"])
		if c.has("flash"):
			_flash_body(c["flash"])
		if c.has("sparkles"):
			_spawn_sparkles(c["sparkles"], c["color"], c["count"])
		if c.has("shake"):
			_cam_amp = maxf(_cam_amp, c["shake"])
	_update_camera()
	_update_celebration(delta)
	if dim != null:
		var a := 1.0
		if _t < 0.25:
			a = _t / 0.25
		elif _t > _total - T_FADE:
			a = clampf((_total - _t) / T_FADE, 0.0, 1.0)
		dim.modulate.a = a
	if label != null:
		label.visible = mode == Mode.MOVE and _t > _t_land and _t < _total - 0.1
	for i in _num_labels.size():
		var b: Dice3D.Body = _bodies[i]
		var settled := _t >= b.t_release + (b.t_stop if b.samples.size() > 1 else b.dur) and _t < _total - 0.2
		_num_labels[i].visible = settled
		if settled:
			var sp := _cam.unproject_position(b.node.position + Vector3(0, 0.9, 0))
			_num_labels[i].position = sp - _num_labels[i].size / 2.0
	if _t >= _total:
		_active = false
		visible = false
		if dim != null:
			dim.modulate.a = 0.0
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_clear()
		finished.emit()


# ---------------------------------------------------------------------------
# comemoração de par
# ---------------------------------------------------------------------------

func _update_celebration(delta: float) -> void:
	# tremor de câmera
	if _cam_amp > 0.001:
		_cam_amp = maxf(0.0, _cam_amp - delta * 3.5)
		_cam.h_offset = sin(_t * 90.0) * _cam_amp
		_cam.v_offset = cos(_t * 77.0) * _cam_amp
	elif _cam.h_offset != 0.0 or _cam.v_offset != 0.0:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
	if not _celebrating:
		var aura: Color = _gp.get("sparkle", _gp.get("aura", Color(0, 0, 0, 0)))
		for b in _bodies:
			if aura.a > 0.0 and b.flash_end < 0.0 and _style == "full" and _t < _t_land + 0.1:
				b.glow(aura, 0.55)  # halo de magia/bênção enquanto os dados voam
			if b.flash_end > 0.0:
				var left: float = b.flash_end - _t
				b.glow(Color(1.0, 0.95, 0.8), 1.3 * clampf(left / 0.35, 0.0, 1.0) if left > 0.0 else 0.0)
				if left <= 0.0:
					b.flash_end = -1.0
	if _special.is_empty():
		return
	if not _celebrating and _t >= _t_land:
		_celebrating = true
		celebrated = true
		_glow_t = 0.0
		_start_celebration()
	if _celebrating:
		_glow_t += delta * _scale
		var pulse := 0.55 + 0.45 * sin(_glow_t * 11.0)
		var energy := 1.6 * pulse * clampf(1.0 - maxf(0.0, _t - (_total - 0.5)) / 0.25, 0.0, 1.0)
		for b in _bodies:
			b.glow(_glow_color, energy)


func _start_celebration() -> void:
	var kind: String = _special.get("kind", "double")
	var bad := kind == "snake"
	var col := Color("ff5a4d") if bad else (Color("ffd23f") if kind == "six" else Color("ffe27a"))
	_glow_color = col
	_play("double_one" if bad else "double_gold", -3.0)
	_cam_amp = 0.09 if bad else (0.06 if kind == "six" else 0.025)
	if _big != null:
		_big.text = _special.get("text", "")
		_big.add_theme_color_override("font_color", col)
		_big.visible = true
		_big.pivot_offset = _big.size / 2.0
		_big.scale = Vector2(0.4, 0.4)
		_big.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_big, "scale", Vector2(1.15, 1.15), 0.18 / maxf(1.0, _scale)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_big, "modulate:a", 1.0, 0.12)
		tw.tween_property(_big, "scale", Vector2.ONE, 0.12 / maxf(1.0, _scale))
		tw.tween_interval(maxf(0.1, _total - _t - 0.45) / maxf(1.0, _scale))
		tw.tween_property(_big, "modulate:a", 0.0, 0.2)
	# faíscas sobre cada dado (estrelas douradas; no azar, brasas vermelhas)
	for b in _bodies:
		var sp := _cam.unproject_position(b.node.position + Vector3(0, 0.5, 0))
		var burst := UiBurst.new()
		burst.color = col
		burst.count = 16 if kind == "six" else 11
		burst.radius = 85.0 if kind == "six" else 60.0
		burst.stars = not bad
		burst.dur = 0.8
		add_child(burst)
		burst.origin = sp


# ---------------------------------------------------------------------------
# a mão
# ---------------------------------------------------------------------------

static func _smooth(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


static func _ease_in(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * k


static func _ease_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)


## Chega ao destino, passa um pouco e volta (exagero de mola).
static func _ease_out_back(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	var c1 := 1.4
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(k - 1.0, 3.0) + c1 * pow(k - 1.0, 2.0)


## 0 → sobe → 1 → desce → 0 durante a sacudida.
func _shake_env(s: float) -> float:
	var dur := T_SHAKE_END - T_PREP
	return minf(1.0, s / 0.08) * minf(1.0, maxf(0.0, dur - s) / 0.08)


const DIAG_ANGLE := 0.72   # ≈ 41° em relação à vertical
const DIAG_PIVOT := Vector3(0.0, 0.0, 1.7)        # no referencial da mão: onde os dados terminam
const DIAG_TARGET := Vector3(0.0, 0.0, 0.55)       # no mundo: o centro do tabuleiro, onde queremos que terminem


## Do referencial "mão vindo de cima" para o da diagonal escolhida (os dados terminam no meio do tabuleiro).
func _to_world(v: Vector3) -> Vector3:
	return DIAG_TARGET + Basis(Vector3.UP, _diag) * (v - DIAG_PIVOT)


func _hand_pos(t: float) -> Vector3:
	return _to_world(_hand_pos_local(t))


func _hand_pos_local(t: float) -> Vector3:
	var away := Vector3(0.0, 3.3, -3.8)
	var hover := Vector3(0.0, 2.35, 0.5)
	var prep := Vector3(0.0, 2.6 + float(_gp["prep_up"]), 0.05)
	var thr := Vector3(0.0, float(_gp["thr_y"]), 1.0)
	var over := Vector3(0.0, float(_gp["over_y"]), 1.3)
	var amp: float = _gp["amp"]
	var fr: float = _gp["freq"]
	if t < T_IN:
		return away.lerp(hover, _ease_out_back(t / T_IN))
	if t < T_PREP:
		return hover.lerp(prep, _smooth((t - T_IN) / (T_PREP - T_IN)))
	if t < T_SHAKE_END:
		var s := t - T_PREP
		var env := _shake_env(s)
		return prep + Vector3(sin(s * 34.0 * fr) * 0.09, absf(sin(s * 30.0 * fr)) * 0.17, sin(s * 26.0 * fr + 1.0) * 0.14) * env * amp
	if t < T_THROW:
		return prep.lerp(thr, _ease_in((t - T_SHAKE_END) / (T_THROW - T_SHAKE_END)))
	if t < T_FOLLOW_END:
		return thr.lerp(over, _ease_out((t - T_THROW) / (T_FOLLOW_END - T_THROW)))
	return over.lerp(away, _ease_in((t - T_FOLLOW_END) / (T_AWAY_END - T_FOLLOW_END)))


func _pose(t: float) -> void:
	if _hand == null:
		return
	var pos := _hand_pos(t)
	_hand.position = pos
	var pitch := 0.0
	var roll := 0.0
	var away_k := clampf((t - T_FOLLOW_END) / (T_AWAY_END - T_FOLLOW_END), 0.0, 1.0)
	if t < T_IN:
		pitch = lerpf(0.12, 0.0, _smooth(t / T_IN))
	elif t < T_PREP:
		pitch = lerpf(0.0, 0.30, _smooth((t - T_IN) / (T_PREP - T_IN)))  # pulso armado para trás
	elif t < T_SHAKE_END:
		var s := t - T_PREP
		var env := _shake_env(s)
		pitch = 0.30 + sin(s * 28.0 * float(_gp["freq"])) * 0.12 * env * float(_gp["amp"])
		roll = sin(s * 21.0 * float(_gp["freq"])) * 0.10 * env * float(_gp["amp"])
	elif t < T_THROW:
		pitch = lerpf(0.30, float(_gp["flick"]), _ease_in((t - T_SHAKE_END) / (T_THROW - T_SHAKE_END)))  # chicote
	elif t < T_FOLLOW_END:
		pitch = lerpf(float(_gp["flick"]), -0.12, _ease_out((t - T_THROW) / (T_FOLLOW_END - T_THROW)))
	else:
		pitch = lerpf(-0.12, 0.12, _ease_in(away_k))
	# floreio do pulso (o ladino gira a mão num truque; o mago faz um arco gracioso)
	var flourish_k := clampf((t - T_SHAKE_END) / (T_FOLLOW_END - T_SHAKE_END), 0.0, 1.0)
	roll += float(_gp["roll_f"]) * sin(PI * flourish_k)
	# a mão aponta para +Z (rumo à parte de baixo da tela): giro de 180° em Y
	_hand.rotation = Vector3(pitch, PI + _diag, roll)

	# dedos: punho com tremor, depois abrem em sequência com um pequeno exagero e relaxam
	var open_start := T_RELEASE - 0.04
	for i in 4:
		var tau: float = t - open_start - FINGER_DELAY[i]
		var curl := 1.0
		var splay := 0.0
		if tau < 0.0:
			if t >= T_PREP and t < T_SHAKE_END:
				curl = 1.0 + 0.04 * sin(t * 55.0 + i * 1.7)
		else:
			curl = 0.12 + 0.88 * exp(-9.0 * tau) * cos(18.0 * tau)
			splay = 1.0 - exp(-10.0 * tau) * cos(14.0 * tau)
			curl = lerpf(curl, 0.42, _ease_in(away_k))
		_hand.set_finger_curl(i, curl)
		_hand.set_finger_splay(i, splay)
	var tt := t - (open_start - 0.03)  # o polegar abre primeiro
	if tt < 0.0:
		_hand.set_thumb_curl(1.0)
		_hand.set_thumb_splay(0.0)
	else:
		_hand.set_thumb_curl(lerpf(0.1 + 0.9 * exp(-8.0 * tt) * cos(16.0 * tt), 0.4, _ease_in(away_k)))
		_hand.set_thumb_splay(1.0 - exp(-9.0 * tt) * cos(12.0 * tt))

	# sombra da mão no tabuleiro (some quando a mão vai embora)
	if _hand_shadow != null:
		var h := maxf(0.0, pos.y)
		_hand_shadow.position = Vector3(pos.x, 0.02, pos.z + 0.55 + h * 0.12)
		_hand_shadow.scale = Vector3.ONE * (2.2 + h * 0.25)
		var a := clampf(1.0 - (h - 1.4) / 3.0, 0.15, 0.7)
		(_hand_shadow.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, a)
