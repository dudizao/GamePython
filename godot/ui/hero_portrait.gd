class_name HeroPortrait
extends TextureRect
## Retrato animado de uma classe: mostra os quadros 3D (idle ou walk) e cai nos PNGs antigos enquanto
## eles não estão prontos.

var cls := 0
var monster := ""  # se preenchido, mostra este monstro em vez da classe
var anim := Models3D.IDLE
var speed := 1.0
var _t := 0.0


static func make(hero_class: int, px: float, animation := Models3D.IDLE) -> HeroPortrait:
	var p := HeroPortrait.new()
	p.cls = hero_class
	p.anim = animation
	p.custom_minimum_size = Vector2(px, px)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.texture = Art.hero_tex(hero_class)
	return p


func set_class(hero_class: int) -> void:
	cls = hero_class
	monster = ""
	_refresh()


func set_monster(kind: String) -> void:
	monster = kind
	_refresh()


## Há imagem para mostrar (monstros não têm PNG de reserva).
func has_image() -> bool:
	return texture != null


## Toca `name` por `secs` segundos (mais rápido com `fast`) e volta ao idle.
func play_temp(name: String, secs: float, fast := 2.0) -> void:
	anim = name
	speed = fast
	await get_tree().create_timer(secs).timeout
	if is_instance_valid(self):
		anim = Models3D.IDLE
		speed = 1.0


func _refresh() -> void:
	texture = Art.monster_tex(monster, anim, _t) if monster != "" else Art.hero_tex(cls, anim, _t)


func _process(delta: float) -> void:
	_t += delta * speed
	_refresh()
