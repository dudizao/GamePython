class_name Hand3D
extends Node3D
## Mão 3D estilizada: palma de caixa arredondada, quatro dedos de três falanges (cones afunilados com nós
## redondos nas juntas), polegar com base carnuda, pulso afunilado, punho branco e manga na cor do jogador.
## A mão aponta para -Z, com a palma para baixo. `set_curl(1.0)` = punho; `set_curl(0.0)` = aberta.

const SKIN := Color(0.78, 0.53, 0.4)
const SKIN_SHADE := Color(0.5, 0.29, 0.28)
const PALM_HALF := Vector3(0.52, 0.17, 0.56)
const CURL_CLOSED := [-78.0, -96.0, -62.0]
const CURL_OPEN := [-7.0, -11.0, -8.0]   # mão aberta relaxada: dedos levemente curvos, não retos
const THUMB_CLOSED := [-26.0, -34.0, -40.0]
const THUMB_OPEN := [-4.0, -8.0, -10.0]
const FINGER_BIAS := [0.06, 0.0, -0.04, 0.05]  # cada dedo tem a sua curvatura (menos robótico)
const SPLAY := [26.0, 9.0, -9.0, -26.0]

# da esquerda para a direita (o polegar fica à direita, em +X): mindinho, anelar, médio, indicador
const FINGER_X := [-0.465, -0.155, 0.155, 0.465]
const FINGER_Z := [-0.5, -0.55, -0.56, -0.53]
const FINGER_LEN := [[0.29, 0.19, 0.16], [0.36, 0.24, 0.2], [0.39, 0.26, 0.21], [0.37, 0.24, 0.2]]
const FINGER_R := [0.13, 0.145, 0.155, 0.15]
const ARM_NEAR := 0.72     # raio da manga junto ao pulso
const ARM_NEAR_MAGE := 1.05
const ARM_FAR := 0.6
const ARM_Z0 := 1.15       # onde a manga começa (lado do pulso)
const ARM_LEN := 3.2

var _fingers: Array = []
var _thumb: Array = []
var _finger_roots: Array = []
var _thumb_root: Node3D
var _skin: ShaderMaterial
var _nail: ShaderMaterial
var _glove: ShaderMaterial
var _hand_mat: ShaderMaterial   # material da palma e do pulso (luva ou pele)
var _class := -1


func _init(sleeve_color: Color = Color("4ea1ff"), p_class: int = -1) -> void:
	_class = p_class
	_skin = Toon.make(SKIN, SKIN_SHADE, 0.022)
	_hand_mat = _skin
	if _class == Defs.HeroClass.LADINO:
		# luva sem dedos: couro escuro até a base da última falange
		_glove = Toon.make(Color(0.2, 0.2, 0.25), Color(0.07, 0.07, 0.1), 0.022)
		_hand_mat = _glove
	_nail = Toon.make(Color(0.95, 0.76, 0.7), Color(0.7, 0.5, 0.5), 0.0)

	# palma
	var palm := MeshInstance3D.new()
	palm.mesh = _rounded_box(PALM_HALF, 0.15, 10, 0.8)
	palm.material_override = _hand_mat
	add_child(palm)

	# dedos
	for i in 4:
		var root := Node3D.new()
		root.position = Vector3(FINGER_X[i], 0.0, FINGER_Z[i])
		add_child(root)
		_finger_roots.append(root)
		_fingers.append(_chain(root, FINGER_LEN[i], FINGER_R[i]))
		var knuckle := _sphere(FINGER_R[i] * 1.08)  # nó do dedo: relevo no dorso da mão
		knuckle.material_override = _hand_mat
		knuckle.position = Vector3(0, 0.015, 0.0)
		root.add_child(knuckle)

	# polegar, saindo de uma base carnuda perto do pulso
	var tbase := Node3D.new()
	tbase.position = Vector3(0.5, -0.02, 0.1)
	tbase.rotation_degrees = Vector3(0, -38, 0)
	add_child(tbase)
	_thumb_root = tbase
	_thumb = _chain(tbase, [0.3, 0.27, 0.22], 0.175)
	var thenar := _sphere(0.3)
	thenar.position = Vector3(0.36, -0.03, 0.18)
	thenar.scale = Vector3(1.0, 0.62, 1.25)
	thenar.material_override = _hand_mat
	add_child(thenar)

	# pulso afunilado, punho branco, faixa e antebraço (manga)
	var wrist := MeshInstance3D.new()
	var wrist_mesh := CylinderMesh.new()
	wrist_mesh.top_radius = 0.44
	wrist_mesh.bottom_radius = 0.54
	wrist_mesh.height = 0.34
	wrist_mesh.radial_segments = 24
	wrist.mesh = wrist_mesh
	wrist.rotation.x = PI / 2.0
	wrist.position = Vector3(0, 0, 0.7)
	wrist.material_override = _hand_mat
	add_child(wrist)
	var cuff := MeshInstance3D.new()
	var cuff_mesh := CylinderMesh.new()
	cuff_mesh.top_radius = 0.52
	cuff_mesh.bottom_radius = 0.52
	cuff_mesh.height = 0.34
	cuff_mesh.radial_segments = 24
	cuff.mesh = cuff_mesh
	cuff.rotation.x = PI / 2.0
	cuff.position = Vector3(0, 0, 0.98)
	if _class == Defs.HeroClass.CLERIGO:
		cuff.material_override = Toon.make(Color(1.0, 0.82, 0.3), Color(0.64, 0.44, 0.12), 0.02)  # punho dourado
	else:
		cuff.material_override = Toon.make(Color(0.97, 0.97, 0.95), Color(0.74, 0.76, 0.84), 0.02)
	add_child(cuff)
	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.545
	band_mesh.bottom_radius = 0.545
	band_mesh.height = 0.09
	band_mesh.radial_segments = 24
	band.mesh = band_mesh
	band.rotation.x = PI / 2.0
	band.position = Vector3(0, 0, 1.17)
	band.material_override = Toon.make(sleeve_color.darkened(0.3), sleeve_color.darkened(0.6), 0.02)
	add_child(band)
	var sleeve := Toon.make(sleeve_color, sleeve_color.darkened(0.5), 0.025)  # a manga segue a cor do jogador
	var arm := MeshInstance3D.new()
	var arm_mesh := CylinderMesh.new()
	arm_mesh.top_radius = ARM_FAR
	arm_mesh.bottom_radius = ARM_NEAR_MAGE if _class == Defs.HeroClass.MAGO else ARM_NEAR  # túnica larga do mago
	arm_mesh.height = 3.2
	arm_mesh.radial_segments = 24
	arm.mesh = arm_mesh
	arm.rotation.x = PI / 2.0
	arm.position = Vector3(0, 0, 2.75)
	arm.material_override = sleeve
	add_child(arm)
	_decorate(sleeve_color)
	set_curl(1.0)
	set_splay(0.0)


## Raio da manga na posição z (varia ao longo do antebraço).
func _sleeve_radius(z: float) -> float:
	var near := ARM_NEAR_MAGE if _class == Defs.HeroClass.MAGO else ARM_NEAR
	return lerpf(near, ARM_FAR, clampf((z - ARM_Z0) / ARM_LEN, 0.0, 1.0))


## Argola fina (toro, vazada: não fecha a boca da manga). `solid` = faixa larga de cilindro (braçadeira).
func _ring(radius: float, height: float, z: float, mat: Material, solid := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if solid:
		var c := CylinderMesh.new()
		c.top_radius = radius
		c.bottom_radius = radius
		c.height = height
		c.radial_segments = 28
		mi.mesh = c
	else:
		var tr := maxf(0.02, height / 2.0)
		var t := TorusMesh.new()
		t.inner_radius = radius - tr
		t.outer_radius = radius + tr
		t.rings = 32
		t.ring_segments = 8
		mi.mesh = t
	mi.rotation.x = PI / 2.0
	mi.position = Vector3(0, 0, z)
	mi.material_override = mat
	add_child(mi)
	return mi


## Detalhes de cada classe: braçadeira do guerreiro, estrelas do mago, luva do ladino, ouro do clérigo.
func _decorate(sleeve_color: Color) -> void:
	var gold := Toon.make(Color(1.0, 0.8, 0.25), Color(0.62, 0.42, 0.1), 0.02)
	match _class:
		Defs.HeroClass.GUERREIRO:
			var leather := Toon.make(Color(0.5, 0.31, 0.18), Color(0.22, 0.12, 0.07), 0.022)
			_ring(_sleeve_radius(1.8) + 0.07, 0.8, 1.8, leather, true)
			_ring(_sleeve_radius(1.35) + 0.1, 0.1, 1.38, Toon.make(Color(0.3, 0.18, 0.1), Color(0.14, 0.08, 0.05), 0.02))
			for z in [1.55, 1.8, 2.05]:
				var rivet := _sphere(0.055)
				rivet.material_override = gold
				rivet.position = Vector3(0, _sleeve_radius(z) + 0.09, z)
				add_child(rivet)
		Defs.HeroClass.MAGO:
			_ring(ARM_NEAR_MAGE + 0.015, 0.05, ARM_Z0 + 0.02, gold)  # barra dourada na boca da manga
			var zs := [1.55, 1.9, 2.25, 2.6, 2.95]
			var xs := [-0.3, 0.28, -0.22, 0.26, -0.1]
			for i in zs.size():
				var star := Label3D.new()
				star.text = "★"
				star.font_size = 110
				star.pixel_size = 0.0055
				star.modulate = Color(1.0, 0.86, 0.3)
				star.outline_size = 6
				star.outline_modulate = Color(0.45, 0.3, 0.05)
				star.shaded = false
				star.double_sided = false
				star.rotation_degrees = Vector3(-90, 0, 0)  # o texto passa a olhar para cima
				star.position = Vector3(xs[i], _sleeve_radius(zs[i]) + 0.012, zs[i])
				add_child(star)
		Defs.HeroClass.LADINO:
			var strap := MeshInstance3D.new()
			strap.mesh = _rounded_box(Vector3(0.5, 0.045, 0.075), 0.025, 4)
			strap.material_override = Toon.make(Color(0.32, 0.2, 0.12), Color(0.15, 0.09, 0.05), 0.018)
			strap.position = Vector3(0, PALM_HALF.y + 0.015, 0.12)
			add_child(strap)
			var buckle := _sphere(0.065)
			buckle.material_override = gold
			buckle.position = Vector3(0.24, PALM_HALF.y + 0.06, 0.12)
			add_child(buckle)
		Defs.HeroClass.CLERIGO:
			for z in [2.0, 3.4]:
				_ring(_sleeve_radius(z) + 0.035, 0.1, z, gold)
			var cross_v := MeshInstance3D.new()
			cross_v.mesh = _rounded_box(Vector3(0.05, 0.03, 0.26), 0.015, 3)
			cross_v.material_override = gold
			cross_v.position = Vector3(0, _sleeve_radius(2.7) + 0.02, 2.7)
			add_child(cross_v)
			var cross_h := MeshInstance3D.new()
			cross_h.mesh = _rounded_box(Vector3(0.18, 0.03, 0.05), 0.015, 3)
			cross_h.material_override = gold
			cross_h.position = Vector3(0, _sleeve_radius(2.7) + 0.02, 2.62)
			add_child(cross_h)


func _sphere(radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 20
	m.rings = 10
	mi.mesh = m
	mi.material_override = _skin
	return mi


## Cadeia de falanges. Cada junta gira em torno de X. O osso é um cone afunilado ao longo de -Z,
## com uma esfera na junta distal (o nó do dedo); a última leva unha.
func _chain(parent: Node3D, lens: Array, base_radius: float) -> Array:
	var gloved := _glove != null
	var joints: Array = []
	var cur := parent
	var n := lens.size()
	for k in n:
		var r0 := base_radius * pow(0.92, k)
		var r1 := base_radius * pow(0.92, k + 1)
		var joint := Node3D.new()
		cur.add_child(joint)
		var bone := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.bottom_radius = r0
		cone.top_radius = r1
		cone.height = lens[k]
		cone.radial_segments = 16
		bone.mesh = cone
		bone.rotation.x = -PI / 2.0  # topo (+Y) passa a apontar para -Z
		bone.position = Vector3(0, 0, -lens[k] / 2.0)
		var seg_mat := _glove if (gloved and k < n - 1) else _skin
		bone.material_override = seg_mat
		joint.add_child(bone)
		var tip := _sphere(r1)
		tip.material_override = seg_mat
		tip.position = Vector3(0, 0, -lens[k])
		joint.add_child(tip)
		if k == n - 1:
			var nail := MeshInstance3D.new()
			var nm := SphereMesh.new()
			nm.radius = r1 * 0.8
			nm.height = r1 * 1.6
			nail.mesh = nm
			nail.scale = Vector3(0.95, 0.3, 1.35)
			nail.position = Vector3(0, r1 * 0.82, -lens[k] - r1 * 0.15)
			nail.material_override = _nail
			joint.add_child(nail)
		var next := Node3D.new()
		next.position = Vector3(0, 0, -lens[k])
		joint.add_child(next)
		cur = next
		joints.append(joint)
	return joints


## Caixa de cantos arredondados com normais corretas (sem escala no nó, que distorce a luz).
static func _rounded_box(half: Vector3, radius: float, seg: int, taper := 1.0) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var inner := half - Vector3(radius, radius, radius)
	for f in Dice3D.D6_FACES:
		var base := verts.size()
		for i in seg + 1:
			for j in seg + 1:
				var a := float(i) / seg * 2.0 - 1.0
				var b := float(j) / seg * 2.0 - 1.0
				var unit: Vector3 = f["n"] + f["u"] * a + f["v"] * b
				var p := Vector3(unit.x * half.x, unit.y * half.y, unit.z * half.z)
				var q := Vector3(clampf(p.x, -inner.x, inner.x), clampf(p.y, -inner.y, inner.y), clampf(p.z, -inner.z, inner.z))
				var d := p - q
				var nrm: Vector3 = d.normalized() if d.length() > 0.0001 else f["n"]
				var pos := q + nrm * radius
				# afunila para o pulso (z positivo = lado do pulso)
				pos.x *= lerpf(1.0, taper, clampf((pos.z + half.z) / (2.0 * half.z), 0.0, 1.0))
				verts.append(pos)
				norms.append(nrm)
		for i in seg:
			for j in seg:
				var i0 := base + i * (seg + 1) + j
				var i1 := i0 + 1
				var i2 := i0 + seg + 1
				var i3 := i2 + 1
				idx.append_array([i0, i1, i2, i1, i3, i2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 1 = punho fechado, 0 = mão aberta (todos os dedos iguais).
func set_curl(c: float) -> void:
	for i in 4:
		set_finger_curl(i, c)
	set_thumb_curl(c)


## Dedo i (0..3). Valores acima de 1 fecham mais; abaixo de 0 estendem além do reto (efeito de mola).
func set_finger_curl(i: int, c: float) -> void:
	var cc: float = c + FINGER_BIAS[i] * clampf(1.0 - c, 0.0, 1.0)
	for k in 3:
		_fingers[i][k].rotation_degrees.x = CURL_OPEN[k] + (CURL_CLOSED[k] - CURL_OPEN[k]) * cc


func set_thumb_curl(c: float) -> void:
	if _thumb.size() == 3:
		for k in 3:
			_thumb[k].rotation_degrees.x = THUMB_OPEN[k] + (THUMB_CLOSED[k] - THUMB_OPEN[k]) * c


## 0 = dedos juntos, 1 = dedos bem abertos (como na mão que solta os dados).
func set_splay(s: float) -> void:
	for i in 4:
		set_finger_splay(i, s)
	set_thumb_splay(s)


func set_finger_splay(i: int, s: float) -> void:
	_finger_roots[i].rotation_degrees.y = SPLAY[i] * s


func set_thumb_splay(s: float) -> void:
	_thumb_root.rotation_degrees.y = lerpf(-38.0, -72.0, s)
