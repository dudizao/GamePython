class_name SplashScreen
extends Control
## Abertura curta: troféu, título e "toque para começar".

signal finished

const AUTO_SECONDS := 3.4

var _t := 0.0
var _done := false
var _box: VBoxContainer
var _trophy: TextureRect
var _title: Label
var _tag: Label
var _hint: Label


func _ready() -> void:
	add_to_group("screen")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_box)
	var trow := CenterContainer.new()
	trow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(trow)
	_trophy = TextureRect.new()
	_trophy.texture = Art.tex("ui/trofeu.png")
	_trophy.custom_minimum_size = Vector2(104, 104)
	_trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_trophy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_trophy.pivot_offset = Vector2(52, 52)
	trow.add_child(_trophy)
	_title = Label.new()
	_title.text = "O ÚLTIMO ROUBO"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Style.title(_title, 44)
	_box.add_child(_title)
	_tag = Label.new()
	_tag.text = "Troféus, armadilhas e um mapa que não perdoa."
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.add_theme_color_override("font_color", Style.MUTED)
	_box.add_child(_tag)
	_hint = Label.new()
	_hint.text = "Toque para começar"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Style.TEXT)
	_box.add_child(_hint)
	_trophy.modulate.a = 0.0
	_title.modulate.a = 0.0
	_tag.modulate.a = 0.0
	_hint.modulate.a = 0.0
	Sfx.play("trophy", -4.0)


func _process(delta: float) -> void:
	_t += delta
	var a1 := clampf(_t / 0.6, 0.0, 1.0)
	_trophy.modulate.a = a1
	_trophy.scale = Vector2.ONE * (0.6 + 0.4 * ease(a1, 0.3) + 0.03 * sin(_t * 3.0))
	var a2 := clampf((_t - 0.35) / 0.6, 0.0, 1.0)
	_title.modulate.a = a2
	_title.pivot_offset = _title.size / 2.0
	_title.scale = Vector2.ONE * lerpf(1.18, 1.0, ease(a2, 0.3))
	_tag.modulate.a = clampf((_t - 0.9) / 0.6, 0.0, 1.0)
	_hint.modulate.a = clampf((_t - 1.5) / 0.4, 0.0, 1.0) * (0.55 + 0.45 * sin(_t * 4.0))
	if _t >= AUTO_SECONDS:
		_finish()


func _input(event: InputEvent) -> void:
	if _t < 0.4:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventScreenTouch and event.pressed):
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()


func handle_back() -> void:
	_finish()
