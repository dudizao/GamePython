class_name UiBurst
extends Control
## Explosão de partículas dentro de um painel (faíscas de golpe, brilho de cura).

var color := Color.WHITE
var count := 14
var dur := 0.5
var radius := 56.0
var stars := false
## Centro da explosão; (-1,-1) = centro do controle.
var origin := Vector2(-1, -1)
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	if _t >= dur:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / dur, 0.0, 1.0)
	var c := origin if origin.x >= 0.0 else size / 2.0
	for i in count:
		var ang := TAU * i / count + 0.4
		var d := radius * (1.0 - pow(1.0 - k, 3.0)) * (0.55 + 0.45 * float((i * 7) % 5) / 4.0)
		var p := c + Vector2(cos(ang), sin(ang)) * d
		var sz := maxf(1.5, (1.0 - k) * 7.0)
		if stars:
			var pts := PackedVector2Array()
			for j in 8:
				var a2 := k * 5.0 + TAU * j / 8.0
				pts.append(p + Vector2(cos(a2), sin(a2)) * (sz * 1.5 if j % 2 == 0 else sz * 0.6))
			draw_colored_polygon(pts, Color(color, 1.0 - k))
		else:
			draw_circle(p, sz, Color(color, 1.0 - k))
