class_name Dice3D
extends RefCounted
## Modelos 3D de dados, criados por código (sem arquivos de modelo):
## d6 de cantos arredondados com pontos, e d20 (icosaedro) com números em Label3D.
## Também guarda o movimento roteirizado de um dado: arremesso, quiques, giro e assentar com a face certa para cima.

const D6_HALF := 0.45
const D20_RADIUS := 0.6

# (normal, eixo u, eixo v) de cada face, com u × v = normal; valores com faces opostas somando 7.
const D6_FACES := [
	{ "value": 1, "n": Vector3(0, 1, 0), "u": Vector3(1, 0, 0), "v": Vector3(0, 0, -1) },
	{ "value": 6, "n": Vector3(0, -1, 0), "u": Vector3(1, 0, 0), "v": Vector3(0, 0, 1) },
	{ "value": 3, "n": Vector3(1, 0, 0), "u": Vector3(0, 1, 0), "v": Vector3(0, 0, 1) },
	{ "value": 4, "n": Vector3(-1, 0, 0), "u": Vector3(0, 1, 0), "v": Vector3(0, 0, -1) },
	{ "value": 2, "n": Vector3(0, 0, 1), "u": Vector3(1, 0, 0), "v": Vector3(0, 1, 0) },
	{ "value": 5, "n": Vector3(0, 0, -1), "u": Vector3(0, 1, 0), "v": Vector3(1, 0, 0) },
]

const PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
}

const ICO_FACES := [
	[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
	[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
	[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
	[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
]

static var _d20_numbers: Array = []   # índice da face -> número
static var _d20_normals: Array = []   # índice da face -> normal
static var _shadow_tex: GradientTexture2D


# ---------------------------------------------------------------------------
# d6
# ---------------------------------------------------------------------------

static func rounded_cube_mesh(extent: float, radius: float, seg := 9) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var rad_unit := radius / extent
	var h := 1.0 - rad_unit
	for f in D6_FACES:
		var base := verts.size()
		for i in seg + 1:
			for j in seg + 1:
				var a := float(i) / seg * 2.0 - 1.0
				var b := float(j) / seg * 2.0 - 1.0
				var p: Vector3 = f["n"] + f["u"] * a + f["v"] * b
				var q := Vector3(clampf(p.x, -h, h), clampf(p.y, -h, h), clampf(p.z, -h, h))
				var d := p - q
				var nrm: Vector3 = d.normalized() if d.length() > 0.0001 else f["n"]
				verts.append((q + nrm * rad_unit) * extent)
				norms.append(nrm)
		for i in seg:
			for j in seg:
				var i0 := base + i * (seg + 1) + j
				var i1 := i0 + 1
				var i2 := i0 + seg + 1
				var i3 := i2 + 1
				# Godot considera frente a ordem horária (vista de fora)
				idx.append_array([i0, i1, i2, i1, i3, i2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func make_d6(color: Color, pip_color := Color(0.1, 0.1, 0.14), one_color := Color(0.78, 0.12, 0.1)) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = rounded_cube_mesh(D6_HALF, 0.13)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.32
	mat.metallic_specular = 0.7
	mat.next_pass = Toon.outline(0.02, color.darkened(0.78))  # contorno escuro, como no desenho
	body.material_override = mat
	root.set_meta("mat", mat)  # para o brilho de comemoração
	root.add_child(body)
	var pip_mat := StandardMaterial3D.new()
	pip_mat.albedo_color = pip_color
	pip_mat.roughness = 0.5
	var red_mat := StandardMaterial3D.new()
	red_mat.albedo_color = one_color
	red_mat.roughness = 0.5
	for f in D6_FACES:
		var value: int = f["value"]
		var m := red_mat if value == 1 else pip_mat
		for p in PIPS[value]:
			var pip := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			var r := 0.115 if value == 1 else 0.085
			cyl.top_radius = r
			cyl.bottom_radius = r
			cyl.height = 0.03
			cyl.radial_segments = 14
			pip.mesh = cyl
			pip.material_override = m
			var n: Vector3 = f["n"]
			var u: Vector3 = f["u"]
			var v: Vector3 = f["v"]
			pip.transform = Transform3D(Basis(u, n, -v), n * (D6_HALF - 0.004) + u * p.x * 0.22 + v * p.y * 0.22)
			root.add_child(pip)
	return root


## Orientação em que a face `value` fica para cima (com giro aleatório em torno da vertical).
static func d6_final(value: int, yaw: float) -> Quaternion:
	var normal := Vector3.UP
	for f in D6_FACES:
		if f["value"] == value:
			normal = f["n"]
	return Quaternion(Vector3.UP, yaw) * Quaternion(normal, Vector3.UP)


# ---------------------------------------------------------------------------
# d20
# ---------------------------------------------------------------------------

static func _ico_vertices() -> Array[Vector3]:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var raw: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	var out: Array[Vector3] = []
	for v in raw:
		out.append(v.normalized() * D20_RADIUS)
	return out


static func _ensure_d20_numbers() -> void:
	if not _d20_numbers.is_empty():
		return
	var verts := _ico_vertices()
	_d20_normals = []
	for f in ICO_FACES:
		var c: Vector3 = (verts[f[0]] + verts[f[1]] + verts[f[2]]) / 3.0
		_d20_normals.append(c.normalized())
	_d20_numbers = []
	_d20_numbers.resize(20)
	_d20_numbers.fill(0)
	var next_n := 1
	for i in 20:
		if _d20_numbers[i] != 0:
			continue
		var opp := -1
		for j in 20:
			if j != i and _d20_normals[i].dot(_d20_normals[j]) < -0.99:
				opp = j
		_d20_numbers[i] = next_n
		_d20_numbers[opp] = 21 - next_n   # faces opostas somam 21
		next_n += 1


static func make_d20(color: Color) -> Node3D:
	_ensure_d20_numbers()
	var verts := _ico_vertices()
	var root := Node3D.new()
	var pos := PackedVector3Array()
	var norms := PackedVector3Array()
	for fi in 20:
		var f: Array = ICO_FACES[fi]
		var n: Vector3 = _d20_normals[fi]
		for k in [0, 2, 1]:  # horário visto de fora
			pos.append(verts[f[k]])
			norms.append(n)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var body := MeshInstance3D.new()
	body.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.3
	mat.metallic_specular = 0.8
	body.material_override = mat
	root.add_child(body)
	for fi in 20:
		var f: Array = ICO_FACES[fi]
		var n: Vector3 = _d20_normals[fi]
		var c: Vector3 = (verts[f[0]] + verts[f[1]] + verts[f[2]]) / 3.0
		var up_dir: Vector3 = (verts[f[0]] - c).normalized()
		var x_axis := up_dir.cross(n).normalized()
		var y_axis := n.cross(x_axis).normalized()
		var label := Label3D.new()
		var number: int = _d20_numbers[fi]
		label.text = "%d%s" % [number, "." if number == 6 or number == 9 else ""]
		label.font_size = 56
		label.pixel_size = 0.0042
		label.outline_size = 6
		label.modulate = Color(1, 1, 1)
		label.outline_modulate = color.darkened(0.6)
		label.double_sided = false
		label.shaded = false
		label.transform = Transform3D(Basis(x_axis, y_axis, n), c + n * 0.006)
		root.add_child(label)
	return root


static func d20_final(value: int, yaw: float) -> Quaternion:
	_ensure_d20_numbers()
	var normal := Vector3.UP
	for fi in 20:
		if _d20_numbers[fi] == value:
			normal = _d20_normals[fi]
	return Quaternion(Vector3.UP, yaw) * Quaternion(normal, Vector3.UP)


# ---------------------------------------------------------------------------
# sombra e movimento
# ---------------------------------------------------------------------------

static func make_shadow() -> MeshInstance3D:
	if _shadow_tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.0)])
		g.offsets = PackedFloat32Array([0.0, 1.0])
		_shadow_tex = GradientTexture2D.new()
		_shadow_tex.gradient = g
		_shadow_tex.fill = GradientTexture2D.FILL_RADIAL
		_shadow_tex.fill_from = Vector2(0.5, 0.5)
		_shadow_tex.fill_to = Vector2(1.0, 0.5)
		_shadow_tex.width = 128
		_shadow_tex.height = 128
	var quad := QuadMesh.new()
	quad.size = Vector2(1.7, 1.7)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _shadow_tex
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = m
	mi.rotation.x = -PI / 2.0
	return mi


## Um dado em movimento. `update(t)` posiciona o dado no instante t da linha do tempo.
class Body:
	var node: Node3D
	var shadow: MeshInstance3D
	var rest_y := 0.45
	var t_release := 0.0
	var dur := 0.8
	var start := Vector3.ZERO
	var land := Vector3.ZERO
	var spin_axis := Vector3.UP
	var spin_turns := 3.0
	var q_final := Quaternion.IDENTITY
	var fade_start := 99.0
	var fade_dur := 0.3
	var _hits := [false, false, false]
	var mat: StandardMaterial3D
	# trajetória vinda da física (60 amostras/s a partir de t_release); vazia = trajetória parametrizada
	var samples := PackedVector3Array()
	var t_stop := 0.8
	var flash_end := -1.0
	var on_hit: Callable = Callable()

	func height(u: float, h0: float) -> float:
		if u < 0.45:
			var k := u / 0.45
			return h0 * (1.0 - k * k)
		if u < 0.75:
			var k2 := (u - 0.45) / 0.30
			return 0.5 * h0 * 4.0 * k2 * (1.0 - k2)
		if u < 0.92:
			var k3 := (u - 0.75) / 0.17
			return 0.18 * h0 * 4.0 * k3 * (1.0 - k3)
		return 0.0

	## Brilho colorido do dado (comemoração). 0 desliga.
	func glow(color: Color, energy: float) -> void:
		if mat == null:
			return
		mat.emission_enabled = energy > 0.01
		mat.emission = color
		mat.emission_energy_multiplier = energy

	func update(t: float) -> void:
		var shown := t >= t_release
		node.visible = shown
		shadow.visible = shown
		if not shown:
			return
		var u: float
		var pos: Vector3
		var h0: float
		var h: float
		if samples.size() > 1:
			var local := t - t_release
			u = clampf(local / maxf(0.05, t_stop), 0.0, 1.0)
			var f := clampf(local * 60.0, 0.0, float(samples.size() - 1))
			var i0 := int(f)
			var i1 := mini(i0 + 1, samples.size() - 1)
			pos = samples[i0].lerp(samples[i1], f - i0)
			h0 = maxf(0.05, samples[0].y - rest_y)
			h = pos.y - rest_y
		else:
			u = clampf((t - t_release) / dur, 0.0, 1.0)
			var uh := 1.0 - pow(1.0 - u, 2.2)
			h0 = maxf(0.05, start.y - rest_y)
			h = height(u, h0)
			pos = start.lerp(land, uh)
			pos.y = rest_y + h
		node.position = pos
		var e := 1.0 - pow(1.0 - u, 3.0)
		node.basis = Basis(Quaternion(spin_axis, TAU * spin_turns * (1.0 - e)) * q_final)
		var s := 1.0
		if t > fade_start:
			s = clampf(1.0 - (t - fade_start) / fade_dur, 0.0, 1.0)
		node.scale = Vector3.ONE * s
		shadow.position = Vector3(pos.x, 0.012, pos.z)
		var sh := clampf(1.0 - h / (h0 * 1.4), 0.25, 1.0)
		shadow.scale = Vector3.ONE * (0.75 + 0.45 * sh) * s
		(shadow.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, sh)
		# toque no chão (som) — só na trajetória parametrizada; com física os sons vêm dos eventos
		if samples.size() <= 1 and on_hit.is_valid():
			if not _hits[0] and u >= 0.45:
				_hits[0] = true
				on_hit.call(1.0)
			elif not _hits[1] and u >= 0.75:
				_hits[1] = true
				on_hit.call(0.5)
			elif not _hits[2] and u >= 0.92:
				_hits[2] = true
				on_hit.call(0.25)
