class_name BoardView
extends Control
## Desenha o tabuleiro, itens, monstros e heróis. Só lê o estado; não altera regras.

signal cell_pressed(cell: Vector2i)
signal cell_hovered(cell: Vector2i)

var state: GameState
## Casas alcançáveis com o dado atual: Vector2i -> custo.
var reach: Dictionary = {}
## Casas de alvo válido (habilidade em modo de mira).
var targets: Array[Vector2i] = []
var hover := Vector2i(-1, -1)
## Quem está olhando (-1 = vê tudo). Armadilhas armadas só aparecem para o dono e para o Ladino.
var viewer := -1
var _floaters: Array = []
var _t := 0.0
var _anims := {}  # pid -> { from, t, dur }
var _flash := {}  # pid -> tempo restante
var _fx: Array = []  # efeitos de curta duração (ver fx())
var _shake := 0.0
var _shake_dur := 0.4
var _shake_t := 0.0
var _shake_off := Vector2.ZERO
var _terrain_before := PackedInt32Array()
var _closing := {}  # Vector2i -> { delay, fired }
var _closing_t := 0.0
var _closing_on := false
var _hp_disp := {}   # pid -> vida mostrada (desce animada)
var _mhp_disp := {}  # id do monstro -> vida mostrada
var _facing := {}    # pid -> 1 (direita) / -1 (esquerda)
var _spawn := {}     # pid -> { t }  (morto-vivo surgindo)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_on_resized)
	if state != null:
		_center = Vector2(state.board.width, state.board.height) / 2.0
		_target = _center


func _on_resized() -> void:
	if state != null:
		_clamp_center()
	queue_redraw()


func add_floater(cell: Vector2i, text: String, color: Color) -> void:
	_floaters.append({ "cell": cell, "text": text, "color": color, "age": 0.0 })


## Faz o herói deslizar da casa `from` até a posição atual dele.
func animate_move(pid: int, from: Vector2i, dur: float) -> void:
	_anims[pid] = { "from": from, "t": 0.0, "dur": maxf(0.05, dur) }
	if state != null and state.heroes.has(pid):
		var dx: int = state.heroes[pid].pos.x - from.x
		if dx != 0:
			_facing[pid] = signi(dx)


func flash_hero(pid: int) -> void:
	_flash[pid] = 0.4


## Efeito visual numa célula. type: burst | ring | rise | star | death | monster_death | spawn | flashcell.
## opts: color, count, radius, dur, delay, glyph, cls, kind, seed.
func fx(type: String, cell: Vector2i, opts := {}) -> void:
	var d := { "type": type, "cell": cell, "t": -float(opts.get("delay", 0.0)), "dur": float(opts.get("dur", 0.8)) }
	d.merge(opts, true)
	_fx.append(d)


func shake(amount: float, dur := 0.35) -> void:
	if amount >= _shake * (1.0 - _shake_t / maxf(0.01, _shake_dur)):
		_shake = amount
		_shake_dur = dur
		_shake_t = 0.0


## Chamar antes de aplicar uma ação: guarda o terreno para animar o fechamento do mapa.
func snapshot_terrain() -> void:
	if state != null:
		_terrain_before = state.board.terrain_copy()


func start_ring_close(cells: Array, _ring: int) -> void:
	var cx := state.board.width / 2.0
	var cy := state.board.height / 2.0
	var sorted: Array = cells.duplicate()
	sorted.sort_custom(func(a, b): return atan2(a.y - cy, a.x - cx) < atan2(b.y - cy, b.x - cx))
	_closing = {}
	for i in sorted.size():
		_closing[sorted[i]] = { "delay": 1.05 * float(i) / maxf(1.0, sorted.size()), "fired": false }
	_closing_t = 0.0
	_closing_on = true


## O herói aparece só depois de `delay` segundos (morto-vivo levantando).
func spawn_hero(pid: int, delay: float) -> void:
	_spawn[pid] = { "t": -delay }


func is_animating() -> bool:
	return not _fx.is_empty() or not _anims.is_empty() or _shake > 0.0 or _closing_on or not _spawn.is_empty()


func _process(delta: float) -> void:
	_t += delta
	for pid in _anims.keys():
		_anims[pid]["t"] += delta
		if _anims[pid]["t"] >= _anims[pid]["dur"]:
			_anims.erase(pid)
	for pid in _flash.keys():
		_flash[pid] -= delta
		if _flash[pid] <= 0.0:
			_flash.erase(pid)
	for f in _floaters:
		f["age"] += delta
	_floaters = _floaters.filter(func(f): return f["age"] < 1.4)
	for e in _fx:
		e["t"] += delta
	_fx = _fx.filter(func(e): return e["t"] < e["dur"])
	for pid in _spawn.keys():
		_spawn[pid]["t"] += delta
		if _spawn[pid]["t"] > 0.7:
			_spawn.erase(pid)
	if _shake > 0.0:
		_shake_t += delta
		if _shake_t >= _shake_dur:
			_shake = 0.0
			_shake_off = Vector2.ZERO
		else:
			var amp := _shake * (1.0 - _shake_t / _shake_dur)
			_shake_off = Vector2(sin(_t * 93.0), cos(_t * 71.0)) * amp
	if _closing_on:
		_closing_t += delta
		for c in _closing:
			var a: Dictionary = _closing[c]
			if not a["fired"] and _closing_t >= a["delay"]:
				a["fired"] = true
				fx("burst", c, { "color": Color("b8aa96"), "count": 7, "radius": 0.7, "dur": 0.5 })
				shake(2.5, 0.18)
		if _closing_t > 1.05 + 0.5:
			_closing_on = false
			_closing = {}
	if state != null:
		for id in state.heroes:
			var h: Hero = state.heroes[id]
			var cur: float = _hp_disp.get(id, float(h.hp))
			_hp_disp[id] = move_toward(cur, float(h.hp), maxf(28.0, absf(cur - h.hp) * 5.0) * delta)
		for id in state.monsters:
			var m: Monster = state.monsters[id]
			var cur: float = _mhp_disp.get(id, float(m.hp))
			_mhp_disp[id] = move_toward(cur, float(m.hp), maxf(28.0, absf(cur - m.hp) * 5.0) * delta)
		if _center.distance_to(_target) > 0.001:
			_center = _center.lerp(_target, 1.0 - exp(-delta * 9.0))
	# 30 quadros/s em repouso (bateria); 60 enquanto algo anima
	_acc += delta
	if is_animating() or _acc >= 1.0 / 30.0 or _floaters.size() > 0:
		_acc = 0.0
		queue_redraw()


# --- câmera (zoom e arrasto) ----------------------------------------------------

const DRAG_THRESHOLD := 12.0
const MAX_CELL := 110.0

var zoom := 1.0
## Centro da câmera em coordenadas de tabuleiro (células, fracionário).
var _center := Vector2.ZERO
var _target := Vector2.ZERO
var _pressed := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _acc := 0.0


func fit_cell() -> float:
	if state == null:
		return 32.0
	return minf(size.x / state.board.width, size.y / state.board.height)


func cell_size() -> float:
	return maxf(8.0, minf(fit_cell() * zoom, MAX_CELL))


func set_zoom(z: float) -> void:
	zoom = clampf(z, 1.0, maxf(1.0, MAX_CELL / maxf(1.0, fit_cell())))
	_clamp_center()
	queue_redraw()


func zoom_by(factor: float) -> void:
	set_zoom(zoom * factor)


## Move a câmera suavemente até a célula.
func center_on(c: Vector2i) -> void:
	_target = Vector2(c) + Vector2(0.5, 0.5)
	_clamp_target()


func snap_to(c: Vector2i) -> void:
	center_on(c)
	_center = _target
	queue_redraw()


func _view_cells() -> Vector2:
	var cs := cell_size()
	return Vector2(size.x / cs, size.y / cs)


func _clamp_axis(v: float, board: float, view: float) -> float:
	if board <= view:
		return board / 2.0
	return clampf(v, view / 2.0, board - view / 2.0)


func _clamp_target() -> void:
	var v := _view_cells()
	_target = Vector2(_clamp_axis(_target.x, state.board.width, v.x), _clamp_axis(_target.y, state.board.height, v.y))


func _clamp_center() -> void:
	if state == null:
		return
	var v := _view_cells()
	_center = Vector2(_clamp_axis(_center.x, state.board.width, v.x), _clamp_axis(_center.y, state.board.height, v.y))
	_target = _center


func origin() -> Vector2:
	var cs := cell_size()
	return size / 2.0 - _center * cs


func cell_rect(c: Vector2i) -> Rect2:
	var cs := cell_size()
	var p := (origin() + Vector2(c) * cs).round()
	return Rect2(p, Vector2(cs, cs).ceil())


func pos_to_cell_clamped(p: Vector2) -> Vector2i:
	var cs := cell_size()
	var rel := (p - origin()) / cs
	return Vector2i(clampi(floori(rel.x), 0, state.board.width - 1), clampi(floori(rel.y), 0, state.board.height - 1))


func pos_to_cell(p: Vector2) -> Vector2i:
	var cs := cell_size()
	var rel := (p - origin()) / cs
	var c := Vector2i(floori(rel.x), floori(rel.y))
	return c if state.board.in_bounds(c) else Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if state == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_dragging = false
				_press_pos = event.position
			else:
				if _pressed and not _dragging:
					var c := pos_to_cell(event.position)
					if c != Vector2i(-1, -1):
						hover = c
						cell_hovered.emit(c)  # no toque não há "passar o mouse": tocar também mostra as informações
						cell_pressed.emit(c)
				_pressed = false
				_dragging = false
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.15)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0 / 1.15)
	elif event is InputEventMouseMotion:
		if _pressed:
			if not _dragging and event.position.distance_to(_press_pos) > DRAG_THRESHOLD:
				_dragging = true
			if _dragging:
				_center -= event.relative / cell_size()
				_clamp_center()
				queue_redraw()
		else:
			var c := pos_to_cell(event.position)
			if c != hover:
				hover = c
				cell_hovered.emit(c)
	elif event is InputEventMagnifyGesture:
		zoom_by(event.factor)
	elif event is InputEventPanGesture:
		_center += event.delta * 4.0 / cell_size()
		_clamp_center()
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover != Vector2i(-1, -1) and not _pressed:
		hover = Vector2i(-1, -1)
		cell_hovered.emit(hover)


# --- desenho -----------------------------------------------------------------

func _draw() -> void:
	if state == null:
		return
	var b := state.board
	var cs := cell_size()
	var font := ThemeDB.fallback_font

	draw_set_transform(_shake_off, 0.0, Vector2.ONE)
	var first := pos_to_cell_clamped(Vector2.ZERO)
	var last := pos_to_cell_clamped(size)
	var have_before := _terrain_before.size() == b.width * b.height
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var c := Vector2i(x, y)
			var r := cell_rect(c)
			var t := b.terrain_at(c)
			var drop := -1.0  # progresso da queda do bloco (0..1); <0 = sem animação
			if _closing_on and _closing.has(c) and have_before:
				var local: float = _closing_t - _closing[c]["delay"]
				var before: int = _terrain_before[y * b.width + x]
				if local < 0.0:
					t = before
				elif local < 0.35:
					_draw_terrain(before, r, cs)
					drop = local / 0.35
			if t == Defs.Terrain.BLOCO:
				_draw_block(r, cs, 1.0 if drop < 0.0 else drop, drop >= 0.0)
			elif drop < 0.0 or t != Defs.Terrain.BLOCO:
				_draw_terrain(t, r, cs)
			draw_rect(r, Color(0, 0, 0, 0.18), false, 1.0)

	# anel que vai fechar
	if state.warning_ring >= 0:
		var pulse := 0.25 + 0.15 * sin(_t * 5.0)
		for c in b.main_cells:
			if b.ring_of(c) <= state.warning_ring:
				draw_rect(cell_rect(c), Color(1, 0.15, 0.1, pulse))

	# alcance
	for c in reach:
		var r: Rect2 = cell_rect(c)
		draw_rect(r, Color(0.3, 0.65, 1.0, 0.38))
		draw_rect(r, Color(0.5, 0.8, 1.0, 0.9), false, 1.5)
		draw_string(font, r.position + Vector2(3, 12), str(reach[c]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9))
	for c in targets:
		var r: Rect2 = cell_rect(c)
		draw_rect(r, Color(1.0, 0.3, 0.9, 0.35))
		draw_rect(r, Color(1.0, 0.5, 1.0, 1.0), false, 2.5)

	# itens
	for c in state.items:
		var list: Array = state.items[c]
		if list.is_empty():
			continue
		_draw_item(list[0], cell_rect(c), font)
		if list.size() > 1:
			var rr := cell_rect(c)
			draw_string(font, rr.position + Vector2(cs - 12, cs - 3), "+%d" % (list.size() - 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

	# armadilhas armadas
	for c in state.traps:
		if _can_see_trap(state.traps[c]):
			_draw_trap(c, state.traps[c]["owner"], font)

	# monstros
	for id in state.monsters:
		_draw_monster(state.monsters[id], font)

	# heróis
	var stacked := {}
	for id in state.turn_order:
		var h: Hero = state.heroes[id]
		if not h.alive:
			continue
		var n: int = stacked.get(h.pos, 0)
		stacked[h.pos] = n + 1
		_draw_hero(h, n, font)

	_draw_fx(font)
	draw_set_transform(_shake_off, 0.0, Vector2.ONE)

	# hover
	if hover != Vector2i(-1, -1):
		draw_rect(cell_rect(hover), Color(1, 1, 1, 0.9), false, 2.0)

	# números flutuantes
	for f in _floaters:
		var r := cell_rect(f["cell"])
		var a: float = f["age"]
		var col: Color = f["color"]
		col.a = clampf(1.6 - a, 0.0, 1.0)
		var p := r.position + Vector2(cs / 2.0, -a * 26.0 + 6)
		draw_string(font, p + Vector2(1, 1), f["text"], HORIZONTAL_ALIGNMENT_CENTER, cs * 2, 16, Color(0, 0, 0, col.a), 3)
		draw_string(font, p, f["text"], HORIZONTAL_ALIGNMENT_CENTER, cs * 2, 16, col)


func _draw_terrain(t: int, r: Rect2, cs: float) -> void:
	if t == Defs.Terrain.BLOCO:
		_draw_block(r, cs, 1.0, false)
		return
	var tx := Art.tex(Art.TERRAIN.get(t, "terreno/planicie.png"))
	if tx != null:
		draw_texture_rect(tx, r, false)
	else:
		draw_rect(r, Color("3d6b3d"))


## Bloco de pedra. Em queda (animado), aparece grande e transparente e assenta com sombra.
func _draw_block(r: Rect2, cs: float, k: float, falling: bool) -> void:
	if not falling:
		draw_rect(r, Color("2b2622"))
		draw_rect(r.grow(-2), Color("3a332d"))
		draw_line(r.position + Vector2(0, cs / 2), r.position + Vector2(cs, cs / 2), Color("221d19"), 1.0)
		return
	var e := 1.0 - pow(1.0 - k, 3.0)
	var sc := lerpf(1.7, 1.0, e)
	var rr := Rect2(r.get_center() - r.size * sc / 2.0, r.size * sc)
	draw_rect(r, Color(0, 0, 0, 0.35 * e))  # sombra no chão
	draw_rect(rr, Color(0.17, 0.15, 0.13, clampf(e * 1.4, 0.0, 1.0)))
	draw_rect(rr.grow(-2.0 * sc), Color(0.23, 0.2, 0.18, clampf(e * 1.4, 0.0, 1.0)))


func _star_points(c: Vector2, rad: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 8:
		var ang := rot + TAU * i / 8.0
		var rr := rad if i % 2 == 0 else rad * 0.38
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	return pts


func _draw_fx(font: Font) -> void:
	for e in _fx:
		if e["t"] < 0.0:
			continue
		var k: float = clampf(e["t"] / e["dur"], 0.0, 1.0)
		var r := cell_rect(e["cell"])
		var c := r.get_center()
		var cs := r.size.x
		var col: Color = e.get("color", Color.WHITE)
		match e["type"]:
			"burst":
				var n: int = e.get("count", 10)
				var rad: float = e.get("radius", 1.0) * cs
				for i in n:
					var ang := TAU * i / n + float(e.get("seed", 0))
					var d := rad * (1.0 - pow(1.0 - k, 3.0)) * (0.6 + 0.4 * float((i * 7) % 5) / 4.0)
					var sz := maxf(1.0, (1.0 - k) * cs * 0.13)
					draw_circle(c + Vector2(cos(ang), sin(ang)) * d, sz, Color(col, 1.0 - k))
			"ring":
				var rad := cs * lerpf(0.2, float(e.get("radius", 0.9)), 1.0 - pow(1.0 - k, 2.0))
				draw_arc(c, rad, 0, TAU, 36, Color(col, 1.0 - k), maxf(1.5, cs * 0.07) * (1.0 - k * 0.6))
			"rise":
				var n: int = e.get("count", 6)
				var glyph: String = e.get("glyph", "")
				for i in n:
					var ox := (float(i) / maxf(1.0, n - 1.0) - 0.5) * cs * 0.95
					var kk := clampf(k * 1.25 - float(i) * 0.05, 0.0, 1.0)
					var y := -kk * cs * 1.15 - float((i * 13) % 5) * cs * 0.04
					if glyph != "":
						draw_string(font, c + Vector2(ox - 5, y + 6), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, int(cs * 0.34), Color(col, 1.0 - kk))
					else:
						draw_circle(c + Vector2(ox, y), maxf(1.0, cs * 0.07 * (1.0 - kk)), Color(col, 1.0 - kk))
			"star":
				var n: int = e.get("count", 6)
				var rad: float = e.get("radius", 1.2) * cs
				for i in n:
					var ang := TAU * i / n + float(e.get("seed", 0))
					var d := rad * (1.0 - pow(1.0 - k, 2.5))
					var p := c + Vector2(cos(ang), sin(ang)) * d
					draw_colored_polygon(_star_points(p, maxf(2.0, (1.0 - k) * cs * 0.22), k * 6.0 + i), Color(col, 1.0 - k * k))
			"flashcell":
				draw_rect(r, Color(col, 0.55 * (1.0 - k)))
			"death":
				var tx := Art.hero_tex(e.get("cls", 0))
				var sc := lerpf(1.0, 0.1, k * k)
				var rot := k * 2.4
				draw_set_transform(_shake_off + c, rot, Vector2.ONE)
				if tx != null:
					var sz := cs * 0.64 * sc
					draw_texture_rect(tx, Rect2(Vector2(-sz, -sz) / 2.0, Vector2(sz, sz)), false, Color(1, 1, 1, 1.0 - k))
				draw_set_transform(_shake_off, 0.0, Vector2.ONE)
				var n := 9
				for i in n:
					var ang := TAU * i / n
					var d := cs * 0.9 * (1.0 - pow(1.0 - k, 3.0))
					draw_circle(c + Vector2(cos(ang), sin(ang)) * d, maxf(1.0, (1.0 - k) * cs * 0.1), Color(col, 1.0 - k))
			"monster_death":
				var mc: Color = Art.MONSTER_COLORS.get(e.get("kind", ""), Color.GRAY)
				var rad := cs * 0.32 * (1.0 - k * 0.8)
				var mtx := Art.monster_tex(e.get("kind", ""))
				if mtx != null:
					var msz := cs * (1.0 - k * 0.7)
					draw_texture_rect(mtx, Rect2(c - Vector2(msz, msz) / 2.0, Vector2(msz, msz)), false, Color(1, 1, 1, 1.0 - k))
				else:
					draw_circle(c, rad, Color(mc, 1.0 - k))
				var n := 10
				for i in n:
					var ang := TAU * i / n + 0.3
					var d := cs * 0.85 * (1.0 - pow(1.0 - k, 3.0))
					draw_circle(c + Vector2(cos(ang), sin(ang)) * d, maxf(1.0, (1.0 - k) * cs * 0.12), Color(mc.lightened(0.3), 1.0 - k))
			"spawn":
				var gcol := Color("7be07b")
				var beam := Rect2(c + Vector2(-cs * 0.25, -cs * 1.4), Vector2(cs * 0.5, cs * 1.4))
				draw_rect(beam, Color(gcol, 0.28 * sin(k * PI)))
				draw_arc(c, cs * lerpf(0.9, 0.2, k), 0, TAU, 32, Color(gcol, 0.9 * (1.0 - k * 0.3)), maxf(2.0, cs * 0.07))
				draw_arc(c, cs * lerpf(1.3, 0.4, k), 0, TAU, 32, Color(gcol, 0.5 * (1.0 - k * 0.3)), maxf(1.5, cs * 0.05))
				for i in 6:
					var ox := (float(i) / 5.0 - 0.5) * cs * 0.8
					draw_circle(c + Vector2(ox, -k * cs * 1.1 + float((i * 3) % 4) * cs * 0.05), maxf(1.0, cs * 0.06), Color(gcol, 1.0 - k))


func _can_see_trap(t: Dictionary) -> bool:
	if viewer < 0 or t["owner"] == viewer:
		return true
	var v: Hero = state.heroes.get(viewer)
	return v != null and v.hero_class == Defs.HeroClass.LADINO and not v.undead


func _draw_trap(c: Vector2i, owner: int, font: Font) -> void:
	var r := cell_rect(c)
	var ctr := r.get_center()
	var k := r.size.x
	draw_circle(ctr, k * 0.3, Color(0.1, 0.05, 0.05, 0.75))
	draw_arc(ctr, k * 0.3, 0, TAU, 20, Art.player_color(owner), 2.0)
	for a in range(0, 8):  # dentes
		var ang := a * TAU / 8.0
		draw_line(ctr + Vector2(cos(ang), sin(ang)) * k * 0.12, ctr + Vector2(cos(ang), sin(ang)) * k * 0.27, Color("ff9f43"), 2.0)


func _equip_tier_color(id: String) -> Color:
	var e: Dictionary = Defs.EQUIPMENT.get(id, {})
	var power: int = maxi(e.get("atk", 0), e.get("def", 0))
	if power >= 6:
		return Color("ffd23f")
	if power >= 4:
		return Color("4ea1ff")
	return Color("c0c6d4")


func _draw_item(item: Dictionary, r: Rect2, font: Font) -> void:
	var inner := r.grow(-r.size.x * 0.2)
	var c := r.get_center()
	var k := r.size.x
	match item["type"]:
		Defs.ItemType.POCAO_FORCA:
			draw_circle(c, k * 0.26, Color("9b59b6"))
			draw_circle(c, k * 0.26, Color("d7b0f0"), false, 2.0)
			draw_string(font, c + Vector2(-5, 5), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		Defs.ItemType.KIT_ARMADILHA:
			draw_rect(Rect2(c - Vector2(k, k) * 0.24, Vector2(k, k) * 0.48), Color("3b4a5a"))
			draw_rect(Rect2(c - Vector2(k, k) * 0.24, Vector2(k, k) * 0.48), Color("ff9f43"), false, 2.0)
			draw_string(font, c + Vector2(-5, 5), "T", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ff9f43"))
		Defs.ItemType.EQUIPAMENTO:
			var col := _equip_tier_color(item.get("id", ""))
			if Defs.EQUIPMENT.get(item.get("id", ""), {}).get("slot", "") == "weapon":
				draw_line(c + Vector2(-k * 0.22, k * 0.24), c + Vector2(k * 0.22, -k * 0.24), col, 4.0)
				draw_line(c + Vector2(-k * 0.08, k * 0.0), c + Vector2(k * 0.08, k * 0.16), Color("8a5a2b"), 4.0)
				draw_circle(c + Vector2(-k * 0.24, k * 0.26), k * 0.06, Color("8a5a2b"))
			else:
				var pts := PackedVector2Array([c + Vector2(-k * 0.2, -k * 0.22), c + Vector2(k * 0.2, -k * 0.22), c + Vector2(k * 0.2, k * 0.04), c + Vector2(0, k * 0.28), c + Vector2(-k * 0.2, k * 0.04)])
				draw_colored_polygon(pts, col.darkened(0.35))
				draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]]), col, 2.5)
		Defs.ItemType.VIDA:
			draw_circle(c, k * 0.26, Color("e74c3c"))
			draw_circle(c, k * 0.26, Color("ffb3ab"), false, 2.0)
			draw_string(font, c + Vector2(-5, 5), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		Defs.ItemType.ARMADILHA:
			var pts := PackedVector2Array([c + Vector2(0, -k * 0.3), c + Vector2(k * 0.3, k * 0.24), c + Vector2(-k * 0.3, k * 0.24)])
			draw_colored_polygon(pts, Color("2b2b33"))
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color("ff8c42"), 2.0)
			draw_string(font, c + Vector2(-3, 8), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ff8c42"))
		_:
			var tx := Art.tex(Art.ITEM.get(item["type"], ""))
			if tx != null:
				draw_texture_rect(tx, inner, false)
			else:
				draw_circle(r.get_center(), r.size.x * 0.2, Color.WHITE)
	if item["type"] == Defs.ItemType.TESOURO:
		draw_rect(r.grow(-1), Color(1, 0.85, 0.2, 0.45 + 0.25 * sin(_t * 4.0)), false, 2.0)


func _draw_monster(m: Monster, font: Font) -> void:
	var r := cell_rect(m.pos)
	var col: Color = Art.MONSTER_COLORS.get(m.kind, Color.GRAY)
	var c := r.get_center() + Vector2(0, sin(_t * 2.6 + m.id * 1.3) * r.size.x * 0.03)
	var tx := Art.monster_tex(m.kind, Models3D.IDLE, _t + m.id * 0.53)
	if tx != null:
		var cs := r.size.x
		var big := 1.1 if m.kind == "ogro" else 0.95
		draw_circle(c + Vector2(0, cs * 0.3), cs * 0.3, Color(0, 0, 0, 0.35))
		draw_circle(c, cs * 0.4, Color(col, 0.22))
		draw_arc(c, cs * 0.4, 0, TAU, 28, Color(col.lightened(0.2), 0.9), 2.0)
		draw_texture_rect(tx, Rect2(c - Vector2(cs, cs) * big * 0.5 + Vector2(0, -cs * 0.04), Vector2(cs, cs) * big), false)
	else:
		draw_circle(c, r.size.x * 0.36, Color(0, 0, 0, 0.5))
		draw_circle(c, r.size.x * 0.32, col)
		draw_circle(c, r.size.x * 0.32, col.lightened(0.5), false, 2.0)
		draw_string(font, c + Vector2(-5, 6), Art.MONSTER_LETTER.get(m.kind, "?"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
	_draw_bar(Rect2(r.position + Vector2(3, r.size.y - 6), Vector2(r.size.x - 6, 4)), float(_mhp_disp.get(m.id, float(m.hp))) / m.max_hp, Color("e74c3c"))


func _draw_hero(h: Hero, stack: int, font: Font) -> void:
	var alpha := 1.0
	if _spawn.has(h.id):
		var st: float = _spawn[h.id]["t"]
		if st < 0.0:
			return  # ainda não surgiu
		alpha = clampf(st / 0.6, 0.0, 1.0)
	var r := cell_rect(h.pos)
	var hop := 0.0
	if _anims.has(h.id):
		var a: Dictionary = _anims[h.id]
		var k: float = clampf(a["t"] / a["dur"], 0.0, 1.0)
		hop = sin(k * PI)
		k = k * k * (3.0 - 2.0 * k)
		r.position = cell_rect(a["from"]).position.lerp(r.position, k)
	var cs := r.size.x
	var off := Vector2(stack * 6, stack * 6)
	var col := Art.player_color(h.id)
	var ground := r.get_center() + off
	var bob := sin(_t * 3.2 + h.id * 1.7) * cs * 0.022
	var c := ground + Vector2(0, bob - hop * cs * 0.18)
	var is_current := h.id == state.current_player() and state.phase != Defs.Phase.BATTLE
	# sombra no chão e anel do jogador
	draw_circle(ground + Vector2(0, cs * 0.34), cs * 0.26 * (1.0 - hop * 0.25), Color(0, 0, 0, 0.3 * alpha))
	draw_circle(c, cs * 0.42, Color(0.82, 0.85, 0.95, 0.38 * alpha).lerp(Color(col, 0.38 * alpha), 0.35))
	var ring := col
	if h.undead:
		ring = col.lerp(Color("7be07b"), 0.6)
	ring.a = alpha
	draw_arc(c, cs * 0.4, 0, TAU, 28, ring, 3.0)
	if is_current:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		draw_arc(c, cs * (0.46 + 0.04 * pulse), 0, TAU, 28, Color(1, 1, 1, 0.9), 2.0)
	var tx := Art.hero_tex(h.hero_class, Models3D.WALK if _anims.has(h.id) else Models3D.IDLE, _t + h.id * 0.37)
	var sprite_r := Rect2(c - Vector2(cs, cs) * 0.5 + Vector2(0, -cs * 0.06), Vector2(cs, cs))
	if tx != null:
		var mod := Color(0.55, 1.0, 0.65, 0.78 * alpha) if h.undead else Color(1, 1, 1, alpha)
		if _facing.get(h.id, 1) < 0:
			sprite_r = Rect2(sprite_r.position + Vector2(sprite_r.size.x, 0), Vector2(-sprite_r.size.x, sprite_r.size.y))
		draw_texture_rect(tx, sprite_r, false, mod)
	else:
		draw_circle(c, cs * 0.28, col)
	if _flash.has(h.id):
		draw_circle(c, cs * 0.38, Color(1, 0.3, 0.3, clampf(_flash[h.id] / 0.4, 0.0, 1.0) * 0.6))
	if h.undead:
		draw_string(font, c + Vector2(-6, -cs * 0.28), "☠", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c8ffc8"))
	_draw_bar(Rect2(r.position + off + Vector2(3, r.size.y - 5), Vector2(cs - 6, 4)), float(_hp_disp.get(h.id, float(h.hp))) / h.max_hp, Color("5fd38d") if not h.undead else Color("7be07b"))


func _draw_bar(r: Rect2, frac: float, color: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.7))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), color)
