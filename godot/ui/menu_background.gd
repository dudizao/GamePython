class_name MenuBackground
extends Control
## Fundo animado dos menus: o mapa rola devagar, heróis passeiam, brasas douradas sobem.

const CELL := 56.0

var _t := 0.0
var _acc := 0.0
var _board: Board
var _heroes: Array = []
var _embers: Array = []
var _vignette: GradientTexture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 20241
	_board = Board.new(40, 24)
	_board.generate(12, rng)
	var classes := Defs.CLASS_NAMES.keys()
	for i in 6:
		_heroes.append({
			"cls": classes[i % classes.size()], "x": rng.randf_range(0.0, 1.0), "lane": rng.randf_range(0.18, 0.88),
			"speed": rng.randf_range(0.012, 0.03) * (1.0 if i % 2 == 0 else -1.0), "phase": rng.randf() * TAU,
		})
	for i in 30:
		_embers.append({ "x": rng.randf(), "y": rng.randf(), "v": rng.randf_range(0.02, 0.07), "s": rng.randf_range(1.5, 3.5), "ph": rng.randf() * TAU })
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0.02, 0.02, 0.04, 0.9)])
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	_vignette = GradientTexture2D.new()
	_vignette.gradient = g
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.0, 0.5)
	_vignette.width = 256
	_vignette.height = 256


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	for h in _heroes:
		h["x"] = fposmod(h["x"] + h["speed"] * delta, 1.2)
	for e in _embers:
		e["y"] -= e["v"] * delta
		if e["y"] < -0.05:
			e["y"] = 1.05
	_acc += delta
	if _acc >= 1.0 / 30.0:
		_acc = 0.0
		queue_redraw()


func _draw() -> void:
	if _board == null:
		return
	var w := size.x
	var h := size.y
	var drift := Vector2(_t * 9.0, _t * 3.0)
	var bw := _board.width
	var bh := _board.height
	var x0 := int(floor(drift.x / CELL))
	var y0 := int(floor(drift.y / CELL))
	var cols := int(ceil(w / CELL)) + 2
	var rows := int(ceil(h / CELL)) + 2
	for ry in rows:
		for rx in cols:
			var cx := posmod(x0 + rx, bw)
			var cy := posmod(y0 + ry, bh)
			var t := _board.terrain_at(Vector2i(cx, cy))
			var tx := Art.tex(Art.TERRAIN.get(t, "terreno/planicie.png"))
			var p := Vector2((x0 + rx) * CELL - drift.x, (y0 + ry) * CELL - drift.y)
			if tx != null:
				draw_texture_rect(tx, Rect2(p, Vector2(CELL, CELL)), false)
	draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.06, 0.1, 0.74))
	# heróis passeando
	for hd in _heroes:
		var px: float = (hd["x"] - 0.1) * (w + 120.0) - 60.0
		var py: float = hd["lane"] * h + sin(_t * 4.0 + hd["phase"]) * 3.0
		var sz := 84.0
		var tx := Art.hero_tex(hd["cls"], Models3D.WALK, _t + hd["phase"])
		draw_circle(Vector2(px, py + sz * 0.45), sz * 0.3, Color(0, 0, 0, 0.35))
		if tx != null:
			var flip: bool = hd["speed"] < 0.0
			var r := Rect2(Vector2(px - sz / 2.0, py - sz / 2.0), Vector2(sz, sz))
			if flip:
				r = Rect2(Vector2(px + sz / 2.0, py - sz / 2.0), Vector2(-sz, sz))
			draw_texture_rect(tx, r, false, Color(1, 1, 1, 0.55))
	# brasas
	for e in _embers:
		var a := 0.25 + 0.35 * sin(_t * 2.0 + e["ph"])
		draw_circle(Vector2(e["x"] * w + sin(_t + e["ph"]) * 10.0, e["y"] * h), e["s"], Color(1.0, 0.82, 0.25, clampf(a, 0.05, 0.6)))
	draw_texture_rect(_vignette, Rect2(0, 0, w, h), false)
