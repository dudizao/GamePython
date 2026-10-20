class_name Confetti
extends Control
## Confete de vitória: peças douradas e coloridas caem pela tela.

const LIFETIME := 5.5

var _t := 0.0
var _pieces: Array = []
var _palette := [Color("ffd23f"), Color("ff6b6b"), Color("4ea1ff"), Color("5fd38d"), Color("ffffff")]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 90:
		_pieces.append({
			"x": rng.randf(), "start": rng.randf() * 2.2, "speed": rng.randf_range(0.16, 0.34),
			"sway": rng.randf_range(0.01, 0.04), "ph": rng.randf() * TAU, "spin": rng.randf_range(2.0, 7.0),
			"w": rng.randf_range(5.0, 10.0), "h": rng.randf_range(8.0, 15.0), "c": _palette[rng.randi() % _palette.size()],
		})


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for p in _pieces:
		var local: float = _t - p["start"]
		if local < 0.0:
			continue
		var y: float = -20.0 + local * p["speed"] * size.y
		if y > size.y + 20.0:
			continue
		var x: float = p["x"] * size.x + sin(local * 2.5 + p["ph"]) * p["sway"] * size.x
		var ang: float = local * p["spin"]
		var col: Color = p["c"]
		col.a = clampf((LIFETIME - _t) / 1.2, 0.0, 1.0)
		draw_set_transform(Vector2(x, y), ang, Vector2(1.0, absf(cos(local * 3.0 + p["ph"])) * 0.8 + 0.2))
		draw_rect(Rect2(-p["w"] / 2.0, -p["h"] / 2.0, p["w"], p["h"]), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
