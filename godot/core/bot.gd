class_name Bot
extends RefCounted
## Bot simples: usa a mesma API de ações que um jogador humano/online.


static func choose(state: GameState, pid: int) -> Dictionary:
	var hero: Hero = state.heroes[pid]
	match state.phase:
		Defs.Phase.BATTLE:
			return _choose_battle(state, hero)
		Defs.Phase.ROLL:
			return { "type": "roll" }
		Defs.Phase.MOVE:
			return _choose_move(state, hero)
		Defs.Phase.ACTION:
			return _choose_action(state, hero)
	return { "type": "end_turn" }


static func _choose_move(state: GameState, hero: Hero) -> Dictionary:
	var reach := state.reachable(hero)
	var best_score := _progress(state, hero, hero.pos) + _danger(state, hero.pos)
	var best := Vector2i(-1, -1)
	for pos in reach:
		var s: float = _cell_score(state, hero, pos) + _progress(state, hero, pos) + _danger(state, pos) - 0.1 * reach[pos]
		if s > best_score:
			best_score = s
			best = pos
	if best == Vector2i(-1, -1):
		return { "type": "end_move" }
	return { "type": "move", "to": best }


static func _choose_battle(state: GameState, hero: Hero) -> Dictionary:
	var pct := hero.hp * 100 / hero.max_hp
	if pct < 40 and hero.potions["vida"] > 0:
		return { "type": "battle_action", "action": "item", "potion": "vida" }
	if state.battle.round_no == 1 and hero.potions["forca"] > 0 and hero.buff_rounds == 0:
		return { "type": "battle_action", "action": "item", "potion": "forca" }
	if pct < 25:
		return { "type": "battle_action", "action": "flee" }
	if hero.cooldown == 0:
		match hero.hero_class:
			Defs.HeroClass.GUERREIRO, Defs.HeroClass.MAGO:
				return { "type": "battle_action", "action": "ability" }
			Defs.HeroClass.LADINO:
				if pct < 60: return { "type": "battle_action", "action": "ability" }
			Defs.HeroClass.CLERIGO:
				if pct < 65: return { "type": "battle_action", "action": "ability" }
	if pct < 50:
		return { "type": "battle_action", "action": "defend" }
	return { "type": "battle_action", "action": "attack" }


static func _choose_action(state: GameState, hero: Hero) -> Dictionary:
	if hero.hp * 100 / hero.max_hp <= 50 and hero.potions["vida"] > 0:
		return { "type": "use_item", "potion": "vida" }
	var here := state.items_at(hero.pos)
	if not hero.undead and not here.is_empty() and _worth_collecting(hero, here[0]):
		return { "type": "collect" }
	if not hero.undead and hero.traps > 0 and not state.traps.has(hero.pos) \
			and state.active_traps(hero.id) < Defs.MAX_ACTIVE_TRAPS and _enemy_near(state, hero, 6):
		return { "type": "set_trap" }
	if hero.cooldown == 0:
		match hero.hero_class:
			Defs.HeroClass.GUERREIRO:
				for o in state.alive_heroes():
					if _hostile(hero, o) and _manhattan(o.pos, hero.pos) <= 3:
						return { "type": "ability" }
			Defs.HeroClass.MAGO:
				for o in state.alive_heroes():
					if not state.is_truce() and _hostile(hero, o) and state.in_magic_line(hero.pos, o.pos):
						return { "type": "ability", "target": o.id }
			Defs.HeroClass.LADINO:
				if hero.hp < 60:
					return { "type": "ability" }
			Defs.HeroClass.CLERIGO:
				if hero.hp <= hero.max_hp - Defs.CLERIC_HEAL:
					return { "type": "ability" }
	return { "type": "end_turn" }


static func _is_upgrade(hero: Hero, id: String) -> bool:
	var cur := hero.current_in_slot(id)
	return cur == "" or Hero.equip_score(id) > Hero.equip_score(cur)


static func _worth_collecting(hero: Hero, item: Dictionary) -> bool:
	match item["type"]:
		Defs.ItemType.ARMADILHA:
			return false
		Defs.ItemType.EQUIPAMENTO:
			return _is_upgrade(hero, item["id"])
		Defs.ItemType.KIT_ARMADILHA:
			return hero.traps < Defs.MAX_TRAP_KITS
	return true


static func _enemy_near(state: GameState, hero: Hero, dist: int) -> bool:
	for o in state.alive_heroes():
		if _hostile(hero, o) and _manhattan(o.pos, hero.pos) <= dist:
			return true
	return false


## Inimigo: todo mundo, menos mortos-vivos entre si.
static func _hostile(hero: Hero, other: Hero) -> bool:
	return other != hero and not (hero.undead and other.undead)


static func _cell_score(state: GameState, hero: Hero, pos: Vector2i) -> float:
	var s := 0.0
	if hero.undead:
		for o in state.alive_heroes():
			if _hostile(hero, o) and o.pos == pos:
				return 45.0
		return 0.0
	for item in state.items_at(pos):
		match item["type"]:
			Defs.ItemType.TESOURO: s += 100.0
			Defs.ItemType.VIDA: s += 40.0 if hero.hp < 70 else 5.0
			Defs.ItemType.CARTA: s += 25.0
			Defs.ItemType.POCAO_FORCA: s += 20.0
			Defs.ItemType.KIT_ARMADILHA: s += 15.0 if hero.traps < Defs.MAX_TRAP_KITS else 0.0
			Defs.ItemType.EQUIPAMENTO: s += 45.0 if _is_upgrade(hero, item["id"]) else 0.0
			Defs.ItemType.ARMADILHA: s -= 90.0
	var m := state.monster_at(pos)
	if m != null:
		s += float(m.xp) if _can_beat(hero, m) else -70.0
	var terrain_dmg: int = Defs.TERRAIN_DAMAGE.get(state.board.terrain_at(pos), 0)
	if terrain_dmg > 0:
		s -= 40.0 if hero.hp <= 10 else 15.0
	for o in state.alive_heroes():
		if o != hero and o.pos == pos:
			s += (35.0 + 20.0 * o.trophies) if hero.hp > o.hp + 15 else -60.0
	return s


## Anel que vai fechar na próxima rodada: sair dele vale mais que quase qualquer coisa.
static func _danger(state: GameState, pos: Vector2i) -> float:
	var d := 0.0
	if state.warning_ring >= 0 and state.board.ring_of(pos) <= state.warning_ring:
		d -= 150.0
	if state.storm_next_cells.has(pos):
		d -= 40.0  # tempestade avisada: sai da região
	return d


static func _can_beat(hero: Hero, m: Monster) -> bool:
	return hero.hp > m.attack * 3 + 10


## Quanto mais perto do alvo mais próximo (tesouro, ou monstro que dá para vencer), melhor.
static func _progress(state: GameState, hero: Hero, pos: Vector2i) -> float:
	var best := 1000
	if hero.undead:  # só caça heróis vivos
		for o in state.living_heroes():
			best = mini(best, _manhattan(o.pos, pos))
		return -0.5 * best
	for cell in state.items:
		for item in state.items[cell]:
			if item["type"] == Defs.ItemType.TESOURO:
				best = mini(best, _manhattan(cell, pos))
	for id in state.monsters:
		var m: Monster = state.monsters[id]
		if _can_beat(hero, m):
			best = mini(best, _manhattan(m.pos, pos) + 2)
	# troféus divididos: caça quem os carrega (ou o mais fraco, se não há troféu no chão)
	var trophy_on_ground := best < 1000 and _trophy_on_ground(state)
	for o in state.alive_heroes():
		if _hostile(hero, o) and hero.hp > o.hp + 10 and (o.trophies > 0 or not trophy_on_ground):
			best = mini(best, _manhattan(o.pos, pos) + 1)
	return -0.5 * best


static func _trophy_on_ground(state: GameState) -> bool:
	for cell in state.items:
		for item in state.items[cell]:
			if item["type"] == Defs.ItemType.TESOURO:
				return true
	return false


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
