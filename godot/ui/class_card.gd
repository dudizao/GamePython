class_name ClassCard
extends PanelContainer
## Cartão de classe: sprite grande, atributos em barras e a habilidade.

signal chosen(cls: int)

const COLORS := {
	Defs.HeroClass.GUERREIRO: Color("e0584f"), Defs.HeroClass.MAGO: Color("a77bff"),
	Defs.HeroClass.LADINO: Color("5fd38d"), Defs.HeroClass.CLERIGO: Color("ffd23f"),
}
const STAT_MAX := { "Vida": 140.0, "Ataque": 14.0, "Defesa": 8.0, "Velocid.": 6.0 }

var cls: int
var selected := false
var _hover := false


func _init(p_cls: int = 0) -> void:
	cls = p_cls


func _ready() -> void:
	custom_minimum_size = Vector2(196, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _set_hover(true))
	mouse_exited.connect(func(): _set_hover(false))
	var h := Hero.create(0, "", cls, Vector2i.ZERO)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var row := CenterContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var icon := HeroPortrait.make(cls, 96)
	row.add_child(icon)
	var name_l := Label.new()
	name_l.text = Defs.CLASS_NAMES[cls]
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", COLORS[cls])
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_l)
	var vals := { "Vida": h.max_hp, "Ataque": h.attack, "Defesa": h.defense, "Velocid.": h.speed }
	for k in vals:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(r)
		var l := Label.new()
		l.text = k
		l.custom_minimum_size = Vector2(52, 0)
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Style.MUTED)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(l)
		var bar := ProgressBar.new()
		bar.max_value = STAT_MAX[k]
		bar.value = vals[k]
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("fill", Style.box(COLORS[cls], 3))
		bar.add_theme_stylebox_override("background", Style.box(Color("101218"), 3))
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(bar)
		var n := Label.new()
		n.text = str(vals[k])
		n.custom_minimum_size = Vector2(28, 0)
		n.add_theme_font_size_override("font_size", 12)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(n)
	var ab := Label.new()
	ab.text = "★ %s" % Texts.ability_name(cls)
	ab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ab.add_theme_font_size_override("font_size", 13)
	ab.add_theme_color_override("font_color", Style.ACCENT)
	ab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ab)
	_restyle()


func set_selected(on: bool) -> void:
	selected = on
	_restyle()


func _set_hover(on: bool) -> void:
	_hover = on
	_restyle()


func _restyle() -> void:
	var border: Color = COLORS[cls] if selected else (Color("55607a") if _hover else Color("2d3342"))
	var bg := Color("2b3146") if selected else (Color("23283a") if _hover else Style.PANEL)
	add_theme_stylebox_override("panel", Style.box(bg, 12, border, 3 if selected else 1))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(cls)
