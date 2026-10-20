class_name Hero
extends RefCounted

var id: int
var display_name: String
var hero_class: int
var pos := Vector2i.ZERO

var max_hp := 100
var hp := 100
var attack := 10
var defense := 5
var speed := 3

## alive = o corpo está em jogo (vivo ou morto-vivo). undead = voltou como morto-vivo.
var alive := true
var undead := false
var trophies := 0
var move_points := 0
var cooldown := 0
var dodge := false
var power_strike := false
var level := 1
var xp := 0
var potions := { "vida": 0, "forca": 0 }
var weapon := ""
var armor := ""
var traps := 0  # kits de armadilha na mochila
var buff_attack := 0
var buff_rounds := 0
## Esquiva da batalha: vale só na rodada em que foi usada.
var dodge_round := false
## Efeitos de monstros de bioma.
var frozen := false      # próxima rolagem de movimento: -FREEZE_MOVE_PENALTY
var snared := false      # próximo turno: movimento limitado a SNARE_MOVE_CAP
var burn_turns := 0      # turnos restantes de queimadura


static func create(p_id: int, p_name: String, p_class: int, p_pos: Vector2i) -> Hero:
	var h := Hero.new()
	h.id = p_id
	h.display_name = p_name
	h.hero_class = p_class
	h.pos = p_pos
	match p_class:
		Defs.HeroClass.GUERREIRO:
			h.max_hp += 30
			h.speed += 1
		Defs.HeroClass.MAGO:
			h.speed += 1
		Defs.HeroClass.LADINO:
			h.speed += 2
			h.attack += 2
		Defs.HeroClass.CLERIGO:
			h.max_hp += 10
	h.hp = h.max_hp
	return h


func _eq_sum(key: String) -> int:
	var total := 0
	for id in [weapon, armor]:
		if id != "":
			total += Defs.EQUIPMENT[id][key]
	return total


## Atributos em batalha: base + equipamento (+ bônus de poção de força no ataque).
func atk_total() -> int:
	return attack + _eq_sum("atk") + (buff_attack if buff_rounds > 0 else 0)


func def_total() -> int:
	return defense + _eq_sum("def")


func speed_total() -> int:
	return speed + _eq_sum("spd")


## Equipa e devolve o id do item que estava no mesmo slot ("" se nenhum).
func equip(id: String) -> String:
	var old := ""
	if Defs.EQUIPMENT[id]["slot"] == "weapon":
		old = weapon
		weapon = id
	else:
		old = armor
		armor = id
	return old


static func equip_score(id: String) -> int:
	var e: Dictionary = Defs.EQUIPMENT[id]
	return e["atk"] * 3 + e["def"] * 3 + e["spd"] * 2


func current_in_slot(id: String) -> String:
	return weapon if Defs.EQUIPMENT[id]["slot"] == "weapon" else armor


func is_living() -> bool:
	return alive and not undead


func potion_count() -> int:
	var n := 0
	for k in potions:
		n += potions[k]
	return n


func heal(amount: int) -> int:
	var before := hp
	hp = mini(max_hp, hp + amount)
	return hp - before


## XP total para o próximo nível (0 se já está no máximo).
func xp_to_next() -> int:
	return 0 if level >= Defs.MAX_LEVEL else Defs.XP_THRESHOLDS[level + 1]


## Aplica os ganhos de um nível. Retorna a vida curada.
func level_up() -> int:
	level += 1
	var g: Dictionary = Defs.LEVEL_GROWTH[hero_class]
	max_hp += g["hp"]
	attack += g["attack"]
	defense += g["defense"]
	speed += g["speed"]
	return heal(max_hp * Defs.LEVEL_UP_HEAL_PCT / 100)
