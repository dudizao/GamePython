class_name Monster
extends RefCounted

var id: int
var kind: String
var display_name: String
var level := 1
var pos := Vector2i.ZERO
var max_hp: int
var hp: int
var attack: int
var defense: int
var xp: int


func atk_total() -> int:
	return attack


func def_total() -> int:
	return defense


## Atributos base escalados pelo nível dos heróis na hora do surgimento.
static func create(p_id: int, p_kind: String, p_level: int, p_pos: Vector2i) -> Monster:
	var base: Dictionary = Defs.MONSTER_KINDS[p_kind]
	var k := 1.0 + Defs.MONSTER_SCALE_PER_LEVEL * (p_level - 1)
	var m := Monster.new()
	m.id = p_id
	m.kind = p_kind
	m.display_name = base["name"]
	m.level = p_level
	m.pos = p_pos
	m.max_hp = int(round(base["hp"] * k))
	m.hp = m.max_hp
	m.attack = int(round(base["attack"] * k))
	m.defense = int(round(base["defense"] * k))
	m.xp = int(round(base["xp"] * k))
	return m
