class_name MapTile
extends PanelContainer
## Miniatura clicável de um mapa. id 0 = aleatório.

signal chosen(map_id: int)

var map_id: int
var selected := false
var _hover := false


func _init(p_id: int = 0) -> void:
	map_id = p_id


func _ready() -> void:
	custom_minimum_size = Vector2(142, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _set_hover(true))
	mouse_exited.connect(func(): _set_hover(false))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	if map_id == 0:
		var q := Label.new()
		q.text = "?"
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.custom_minimum_size = Vector2(0, 72)
		q.add_theme_font_override("font", Style.title_font())
		q.add_theme_font_size_override("font_size", 44)
		q.add_theme_color_override("font_color", Style.ACCENT)
		q.add_theme_stylebox_override("normal", Style.box(Color("101218"), 6))
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(q)
	else:
		var tr := TextureRect.new()
		tr.texture = MapPreview.thumbnail(map_id)
		tr.custom_minimum_size = Vector2(0, 72)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tr)
	var l := Label.new()
	l.text = "Aleatório" if map_id == 0 else Board.MAP_NAMES[map_id]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 13)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	_restyle()


func set_selected(on: bool) -> void:
	selected = on
	_restyle()


func _set_hover(on: bool) -> void:
	_hover = on
	_restyle()


func _restyle() -> void:
	var border := Style.ACCENT if selected else (Color("55607a") if _hover else Color("2d3342"))
	var bg := Color("2b3146") if selected else (Color("23283a") if _hover else Style.PANEL)
	add_theme_stylebox_override("panel", Style.box(bg, 10, border, 3 if selected else 1))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(map_id)
