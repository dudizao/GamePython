class_name GameState
extends RefCounted
## Regras da partida. Sem nós, sem tela, sem tempo real: recebe ações, devolve eventos.
## O mesmo código roda no cliente (contra bots) e no servidor (online, autoritativo).
##
## Ação: Dictionary com "type": roll | move (to) | end_move | collect | ability (target) | end_turn
## Retorno de apply(): { ok, error, events }

var rng := RandomNumberGenerator.new()
var board: Board
var heroes: Dictionary = {}  # player_id -> Hero
var items: Dictionary = {}   # Vector2i -> Array[Dictionary{type, value}]
var monsters: Dictionary = {}  # monster_id -> Monster
var _next_monster_id := 0
var turn_order: Array[int] = []
var turn_index := 0
var turn_number := 1
var phase: int = Defs.Phase.ROLL
var finished := false
var winner := -1  # -1 = empate / sem vencedor
## 0 = sem limite. Útil para bots/testes e para evitar partidas eternas.
var max_turns := 0
var trophies_total := Defs.TROPHIES_TOTAL
var round_number := 1
var rings_closed := 0
## Anel que fecha no início da próxima rodada (-1 = nenhum). Interface e bots usam para alertar.
var warning_ring := -1
var close_start := Defs.CLOSE_START_ROUND
var close_every := Defs.CLOSE_EVERY_ROUNDS
var sudden_rounds := 0
var battle: Battle = null
var traps: Dictionary = {}  # Vector2i -> { owner: id }
## Terreno vivo e eventos (ver Defs). storm_next é a região avisada; storm_cells, a que caiu nesta rodada.
var storm_next := Vector2i(-1, -1)
var storm_next_cells: Array[Vector2i] = []
var storm_cells: Array[Vector2i] = []
var pending_event := ""
var last_event := ""
var truce_round := -1
## Esqueletos que ressurgem: { kind, level, pos, due }
var reviving: Array = []
var _defer_end := false
var _xp_queue: Array = []
var _dead_queue: Array[Hero] = []


## players: Array de { "name": String, "class": Defs.HeroClass }. Classes podem se repetir.
func setup(seed_value: int, map_id: int, players: Array, width: int = Defs.BOARD_WIDTH, height: int = Defs.BOARD_HEIGHT) -> void:
	assert(players.size() >= 2 and players.size() <= Defs.MAX_PLAYERS)
	rng.seed = seed_value
	board = Board.new(width, height)
	board.generate(map_id, rng)

	var anchors := [
		Vector2i(0, height / 2), Vector2i(width - 1, height / 2),
		Vector2i(width / 2, 0), Vector2i(width / 2, height - 1),
	]
	var used := {}
	for i in players.size():
		var spot := _nearest_free_main_cell(anchors[i], used)
		used[spot] = true
		heroes[i] = Hero.create(i, players[i].get("name", "Jogador %d" % (i + 1)), players[i]["class"], spot)
		turn_order.append(i)
	_shuffle(turn_order)
	_spawn_trophies()
	_refill_items()
	_refill_monsters()
	phase = Defs.Phase.ROLL
	var first: Hero = heroes[current_player()]
	first.dodge = false


func current_player() -> int:
	return turn_order[turn_index]


## Heróis realmente vivos (decidem o fim da partida). Mortos-vivos não entram.
func living_heroes() -> Array[Hero]:
	var out: Array[Hero] = []
	for id in turn_order:
		if heroes[id].is_living():
			out.append(heroes[id])
	return out


## Todos os corpos em jogo: vivos e mortos-vivos.
func alive_heroes() -> Array[Hero]:
	var out: Array[Hero] = []
	for id in turn_order:
		if heroes[id].alive:
			out.append(heroes[id])
	return out


func items_at(p: Vector2i) -> Array:
	return items.get(p, [])


## Custo de entrar na célula: terreno + tempestade ativa.
func cell_cost(p: Vector2i) -> int:
	return board.move_cost(p) + (Defs.STORM_EXTRA_COST if storm_cells.has(p) else 0)


func is_truce() -> bool:
	return truce_round == round_number


## Células que o herói consegue alcançar com os pontos de movimento atuais: pos -> custo.
func reachable(hero: Hero) -> Dictionary:
	var result := {}
	var budget := hero.move_points
	if budget <= 0:
		return result
	var dist := { hero.pos: 0 }
	var frontier: Array[Vector2i] = [hero.pos]
	while not frontier.is_empty():
		var bi := 0
		for i in frontier.size():
			if dist[frontier[i]] < dist[frontier[bi]]:
				bi = i
		var cur: Vector2i = frontier.pop_at(bi)
		for n in board.neighbors(cur):
			if not board.is_passable(n) or _occupants(n, hero).size() >= 2:
				continue
			if hero.undead and monster_at(n) != null:
				continue  # monstros ignoram o morto-vivo e bloqueiam o caminho dele
			var nc: int = dist[cur] + cell_cost(n)
			if nc > budget:
				continue
			if not dist.has(n) or nc < dist[n]:
				dist[n] = nc
				# monstros podem ser destino (luta), mas não se atravessa
				if not frontier.has(n) and monster_at(n) == null:
					frontier.append(n)
	for p in dist:
		if p != hero.pos:
			result[p] = dist[p]
	return result


func in_magic_line(from: Vector2i, to: Vector2i) -> bool:
	if from.x != to.x and from.y != to.y:
		return false
	return absi(from.x - to.x) + absi(from.y - to.y) <= Defs.MAGIC_RANGE


# ---------------------------------------------------------------------------
# API pública de ações
# ---------------------------------------------------------------------------

func apply(player_id: int, action: Dictionary) -> Dictionary:
	var events: Array = []
	if finished:
		return _fail("game_finished")
	if phase == Defs.Phase.BATTLE:
		return _apply_battle(player_id, action)
	if player_id != current_player():
		return _fail("not_your_turn")
	var hero: Hero = heroes[player_id]
	var err := ""
	match action.get("type", ""):
		"use_item": err = _do_use_item(hero, action, events)
		"set_trap": err = _do_set_trap(hero, events)
		"roll": err = _do_roll(hero, events)
		"move": err = _do_move(hero, action, events)
		"end_move": err = _do_end_move(hero)
		"collect": err = _do_collect(hero, events)
		"ability": err = _do_ability(hero, action, events)
		"end_turn": err = _do_end_turn(events)
		_: err = "unknown_action"
	if err != "":
		return _fail(err)
	if not finished and current_player() == player_id and phase != Defs.Phase.BATTLE:
		var died := events.any(func(e): return e["type"] == "died" and e["player"] == player_id)
		if died or not hero.alive:
			_advance_turn(events)
	return { "ok": true, "error": "", "events": events }


## Quem precisa agir agora: o jogador da vez, ou os que ainda não escolheram numa batalha.
func pending_actors() -> Array[int]:
	var out: Array[int] = []
	if finished:
		return out
	if phase == Defs.Phase.BATTLE and battle != null:
		return battle.pending()
	out.append(current_player())
	return out


## O servidor chama quando o tempo acaba: encerra o turno, ou resolve a rodada de batalha
## (quem não escolheu ataca).
func timeout() -> Array:
	var events: Array = []
	if finished:
		return events
	if phase == Defs.Phase.BATTLE and battle != null:
		battle.fill_defaults(events)
		return events
	_advance_turn(events)
	return events


func _apply_battle(player_id: int, action: Dictionary) -> Dictionary:
	if action.get("type", "") != "battle_action":
		return _fail("in_battle")
	var events: Array = []
	var err := battle.submit(player_id, action, events)
	if err != "":
		return _fail(err)
	return { "ok": true, "error": "", "events": events }


# ---------------------------------------------------------------------------
# Ações
# ---------------------------------------------------------------------------

func _do_roll(hero: Hero, events: Array) -> String:
	if phase != Defs.Phase.ROLL:
		return "wrong_phase"
	var dice: Array[int] = []
	var sum := 0
	for i in Defs.MOVE_DICE:
		var d := rng.randi_range(1, 6)
		dice.append(d)
		sum += d
	var base := int(ceil(float(sum) / Defs.MOVE_DICE))
	var pair := Defs.MOVE_DICE == 2 and dice[0] == dice[1]
	var bonus := 0
	if pair:
		bonus = Defs.DOUBLE_SIX_BONUS if dice[0] == 6 else (0 if dice[0] == 1 else Defs.DOUBLES_BONUS)
	var mod := hero.speed_total() - 3
	if hero.hero_class == Defs.HeroClass.LADINO:
		mod += 1
	var points := base + mod + bonus
	var status := ""
	if hero.frozen:
		points -= Defs.FREEZE_MOVE_PENALTY
		hero.frozen = false
		status = "gelo"
	points = maxi(1, points)
	if hero.snared:
		points = mini(points, Defs.SNARE_MOVE_CAP)
		hero.snared = false
		status = "prende"
	hero.move_points = points
	phase = Defs.Phase.MOVE
	events.append({ "type": "dice_rolled", "player": hero.id, "roll": base, "dice": dice, "pair": pair, "bonus": bonus, "move_points": hero.move_points, "status": status })
	if reachable(hero).is_empty():
		phase = Defs.Phase.ACTION
	return ""


func _do_move(hero: Hero, action: Dictionary, events: Array) -> String:
	if phase != Defs.Phase.MOVE:
		return "wrong_phase"
	var to = action.get("to")
	if not (to is Vector2i):
		return "invalid_destination"
	var reach := reachable(hero)
	if not reach.has(to):
		return "unreachable"
	var from := hero.pos
	var cost: int = reach[to]
	hero.move_points -= cost
	hero.pos = to
	events.append({ "type": "moved", "player": hero.id, "from": from, "to": to, "cost": cost })
	to = _slide_on_ice(hero, from, to, events)

	var undead_before := hero.undead
	var terrain_dmg: int = Defs.TERRAIN_DAMAGE.get(board.terrain_at(to), 0)
	if terrain_dmg > 0 and not hero.undead:
		_damage(hero, terrain_dmg, "terrain", events)
	if hero.alive and hero.undead == undead_before and hero.pos == to:
		_check_trap(hero, to, events)
	# se morreu agora (e virou morto-vivo), a ação acaba aqui
	var still_here: bool = hero.alive and hero.undead == undead_before and hero.pos == to
	if still_here:
		var monster := monster_at(to)
		if monster != null:
			battle = Battle.start(self, hero, null, monster, from, events)
			phase = Defs.Phase.BATTLE
			return ""
		for other in _occupants(to, hero):
			if hero.undead and other.undead:
				continue  # mortos-vivos não brigam entre si
			if is_truce():
				continue  # trégua: ninguém luta contra heróis nesta rodada
			battle = Battle.start(self, hero, other, null, from, events)
			phase = Defs.Phase.BATTLE
			return ""
	if still_here and hero.move_points <= 0 and not finished:
		phase = Defs.Phase.ACTION
	return ""


## Gelo: quem termina a jogada numa casa de gelo desliza mais uma casa na direção do movimento,
## repetindo enquanto continuar no gelo e a casa seguinte estiver livre (até ICE_SLIDE_MAX).
func _slide_on_ice(hero: Hero, from: Vector2i, to: Vector2i, events: Array) -> Vector2i:
	var delta := to - from
	var dir := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
	var cur := to
	for i in Defs.ICE_SLIDE_MAX:
		if board.terrain_at(cur) != Defs.Terrain.GELO:
			break
		var nxt := cur + dir
		if not board.is_passable(nxt) or monster_at(nxt) != null or _cell_has_hero(nxt):
			break
		cur = nxt
	if cur != to:
		hero.pos = cur
		events.append({ "type": "slid", "player": hero.id, "from": to, "to": cur })
	return cur


func _do_end_move(_hero: Hero) -> String:
	if phase != Defs.Phase.MOVE:
		return "wrong_phase"
	phase = Defs.Phase.ACTION
	return ""


func _do_collect(hero: Hero, events: Array) -> String:
	if phase != Defs.Phase.ACTION:
		return "wrong_phase"
	if hero.undead:
		return "undead_cannot_collect"
	var here := items_at(hero.pos)
	if here.is_empty():
		return "nothing_here"
	var item: Dictionary = here[0]
	here.remove_at(0)
	if here.is_empty():
		items.erase(hero.pos)
	events.append({ "type": "item_collected", "player": hero.id, "item": item["type"], "value": item["value"], "id": item.get("id", "") })

	var skip_turn := false
	match item["type"]:
		Defs.ItemType.TESOURO:
			_add_trophies(hero, 1, events)
		Defs.ItemType.VIDA:
			_add_potion(hero, "vida", events)
		Defs.ItemType.POCAO_FORCA:
			_add_potion(hero, "forca", events)
		Defs.ItemType.KIT_ARMADILHA:
			_add_trap_kit(hero, events)
		Defs.ItemType.EQUIPAMENTO:
			_equip(hero, item["id"], events)
		Defs.ItemType.ARMADILHA:
			_damage(hero, item["value"], "trap", events)
		Defs.ItemType.CARTA:
			skip_turn = _draw_card(hero, events)
	_refill_items()
	if skip_turn and not finished and hero.alive:
		_advance_turn(events)
	return ""


func _equip(hero: Hero, id: String, events: Array) -> void:
	var old := hero.equip(id)
	events.append({ "type": "equipped", "player": hero.id, "id": id, "replaced": old })
	if old != "":
		_put_item(hero.pos, Defs.ItemType.EQUIPAMENTO, old)  # o item antigo fica no chão


func _add_trap_kit(hero: Hero, events: Array) -> void:
	if hero.traps >= Defs.MAX_TRAP_KITS:
		events.append({ "type": "inventory_full", "player": hero.id, "potion": "kit" })
		return
	hero.traps += 1
	events.append({ "type": "kit_added", "player": hero.id })


func active_traps(owner: int) -> int:
	var n := 0
	for c in traps:
		if traps[c]["owner"] == owner:
			n += 1
	return n


func _do_set_trap(hero: Hero, events: Array) -> String:
	if phase != Defs.Phase.ACTION:
		return "wrong_phase"
	if hero.undead:
		return "undead_cannot_trap"
	if hero.traps <= 0:
		return "no_trap_kit"
	if traps.has(hero.pos):
		return "trap_here"
	if active_traps(hero.id) >= Defs.MAX_ACTIVE_TRAPS:
		return "too_many_traps"
	hero.traps -= 1
	traps[hero.pos] = { "owner": hero.id }
	events.append({ "type": "trap_set", "player": hero.id, "pos": hero.pos })
	return ""


## Quem pisa numa armadilha alheia leva dano e perde o resto do movimento. O Ladino desarma.
func _check_trap(hero: Hero, cell: Vector2i, events: Array) -> void:
	if not traps.has(cell):
		return
	var t: Dictionary = traps[cell]
	if t["owner"] == hero.id:
		return
	traps.erase(cell)
	if hero.hero_class == Defs.HeroClass.LADINO and not hero.undead:
		hero.traps = mini(Defs.MAX_TRAP_KITS, hero.traps + 1)
		events.append({ "type": "trap_disarmed", "player": hero.id, "owner": t["owner"], "pos": cell })
		return
	events.append({ "type": "trap_triggered", "player": hero.id, "owner": t["owner"], "pos": cell, "damage": Defs.TRAP_DAMAGE })
	hero.move_points = 0
	var owner: Hero = heroes.get(t["owner"])
	_damage(hero, Defs.TRAP_DAMAGE, "player_trap", events, owner if owner != null and owner.alive else null)


func _do_ability(hero: Hero, action: Dictionary, events: Array) -> String:
	if phase != Defs.Phase.ACTION:
		return "wrong_phase"
	if hero.cooldown > 0:
		return "on_cooldown"
	match hero.hero_class:
		Defs.HeroClass.GUERREIRO:
			hero.power_strike = true
			events.append({ "type": "ability", "player": hero.id, "ability": "forca_extra" })
		Defs.HeroClass.MAGO:
			var tid: int = action.get("target", -1)
			if tid == hero.id or not heroes.has(tid) or not heroes[tid].alive or (hero.undead and heroes[tid].undead):
				return "invalid_target"
			var target: Hero = heroes[tid]
			if is_truce():
				return "truce"
			if not in_magic_line(hero.pos, target.pos):
				return "out_of_range"
			events.append({ "type": "ability", "player": hero.id, "ability": "ataque_magico", "target": tid })
			_damage(target, Defs.MAGIC_DAMAGE + Defs.MAGIC_DAMAGE_PER_LEVEL * (hero.level - 1), "magic", events, hero)
		Defs.HeroClass.LADINO:
			hero.dodge = true
			events.append({ "type": "ability", "player": hero.id, "ability": "esquiva" })
		Defs.HeroClass.CLERIGO:
			var healed := hero.heal(Defs.CLERIC_HEAL + Defs.CLERIC_HEAL_PER_LEVEL * (hero.level - 1))
			events.append({ "type": "ability", "player": hero.id, "ability": "cura_pessoal", "healed": healed })
	_set_cooldown(hero)
	return ""


func _set_cooldown(hero: Hero) -> void:
	var cd: int = Defs.ABILITY_COOLDOWN[hero.hero_class]
	if hero.hero_class == Defs.HeroClass.LADINO and hero.level >= Defs.DODGE_COOLDOWN_LEVEL:
		cd -= 1
	hero.cooldown = cd


func _do_use_item(hero: Hero, action: Dictionary, events: Array) -> String:
	if phase != Defs.Phase.MOVE and phase != Defs.Phase.ACTION:
		return "wrong_phase"
	var potion: String = action.get("potion", "")
	if not Defs.POTIONS.has(potion) or hero.potions.get(potion, 0) <= 0:
		return "no_potion"
	use_potion(hero, potion, events)
	return ""


func _add_potion(hero: Hero, potion: String, events: Array) -> void:
	if hero.potion_count() >= Defs.MAX_POTIONS:
		events.append({ "type": "inventory_full", "player": hero.id, "potion": potion })
		if potion == "vida":
			hero.heal(Defs.POTION_HEAL)  # sem espaço: bebe na hora para não desperdiçar
		return
	hero.potions[potion] += 1
	events.append({ "type": "potion_added", "player": hero.id, "potion": potion })


func use_potion(hero: Hero, potion: String, events: Array) -> void:
	hero.potions[potion] -= 1
	match potion:
		"vida":
			var healed := hero.heal(Defs.POTION_HEAL)
			events.append({ "type": "potion_used", "player": hero.id, "potion": potion, "healed": healed })
		"forca":
			hero.buff_attack = Defs.POTION_STRENGTH_BONUS
			hero.buff_rounds = Defs.POTION_STRENGTH_ROUNDS
			events.append({ "type": "potion_used", "player": hero.id, "potion": potion })


func _do_end_turn(events: Array) -> String:
	_advance_turn(events)
	return ""


# ---------------------------------------------------------------------------
# Combate e dano
# ---------------------------------------------------------------------------

## Aplica dano respeitando a Esquiva. Retorna o dano efetivamente aplicado.
func _damage(hero: Hero, amount: int, source: String, events: Array, killer: Hero = null, unavoidable := false) -> int:
	if not hero.alive:
		return 0
	if (hero.dodge or hero.dodge_round) and not unavoidable:
		events.append({ "type": "dodged", "player": hero.id, "source": source })
		return 0
	hero.hp = maxi(0, hero.hp - amount)
	events.append({ "type": "damage", "player": hero.id, "amount": amount, "source": source, "hp": hero.hp })
	if hero.hp <= 0:
		_kill(hero, events, killer)
	return amount


## Herói vivo que morre volta como morto-vivo (se a partida continuar). Morto-vivo que morre
## sai de jogo de vez.
func _kill(hero: Hero, events: Array, killer: Hero = null) -> void:
	var was_undead := hero.undead
	hero.alive = false
	hero.move_points = 0
	events.append({ "type": "died", "player": hero.id, "pos": hero.pos, "final": was_undead })
	if was_undead:
		hero.undead = false
		if killer != null and killer.alive:
			_add_xp(killer, Defs.XP_KILL_UNDEAD_BASE + Defs.XP_KILL_UNDEAD_PER_LEVEL * hero.level, events)
	else:
		for i in hero.trophies:
			_put_item(hero.pos, Defs.ItemType.TESOURO)
		hero.trophies = 0
		for id in [hero.weapon, hero.armor]:
			if id != "":
				_put_item(hero.pos, Defs.ItemType.EQUIPAMENTO, id)
		hero.weapon = ""
		hero.armor = ""
		hero.traps = 0
		if killer != null and killer.alive:
			_add_xp(killer, Defs.XP_KILL_HERO_BASE + Defs.XP_KILL_HERO_PER_LEVEL * hero.level, events)
		_dead_queue.append(hero)
	if not _defer_end:
		_check_end(events)


## Termina a partida se restar 0 ou 1 herói vivo; senão, levanta os mortos recentes.
func _check_end(events: Array) -> void:
	if finished:
		_dead_queue.clear()
		return
	var left := living_heroes()
	if left.size() <= 1:
		_finish(left[0].id if left.size() == 1 else -1, events)
		return
	var queue := _dead_queue
	_dead_queue = []
	for h in queue:
		_raise_undead(h, events)


func _raise_undead(hero: Hero, events: Array) -> void:
	hero.pos = _spawn_cell_near(hero.pos)
	hero.undead = true
	hero.alive = true
	hero.max_hp = maxi(10, hero.max_hp * Defs.UNDEAD_HP_PCT / 100)
	hero.hp = hero.max_hp
	hero.potions = { "vida": 0, "forca": 0 }
	hero.buff_attack = 0
	hero.buff_rounds = 0
	hero.cooldown = 0
	hero.dodge = false
	hero.power_strike = false
	hero.frozen = false
	hero.snared = false
	hero.burn_turns = 0
	hero.move_points = 0
	events.append({ "type": "undead_risen", "player": hero.id, "pos": hero.pos, "hp": hero.hp })


## Célula aberta mais próxima sem herói nem monstro.
func _spawn_cell_near(from: Vector2i) -> Vector2i:
	var best := from
	var best_d := 1 << 30
	for c in board.main_cells:
		if _cell_has_hero(c) or monster_at(c) != null:
			continue
		var d := absi(c.x - from.x) + absi(c.y - from.y)
		if d < best_d:
			best_d = d
			best = c
	return best


func _add_trophies(hero: Hero, amount: int, events: Array) -> void:
	hero.trophies += amount
	if hero.trophies >= trophies_total:
		_finish(hero.id, events)


func _finish(winner_id: int, events: Array) -> void:
	_dead_queue.clear()
	finished = true
	winner = winner_id
	phase = Defs.Phase.FINISHED
	events.append({ "type": "game_over", "winner": winner_id })


func _finish_by_score(events: Array) -> void:
	var best: Hero = null
	var tie := false
	for h in living_heroes():
		if best == null or h.trophies > best.trophies or (h.trophies == best.trophies and h.hp > best.hp):
			best = h
			tie = false
		elif h.trophies == best.trophies and h.hp == best.hp:
			tie = true
	_finish(-1 if best == null or tie else best.id, events)


# ---------------------------------------------------------------------------
# Monstros e progressão
# ---------------------------------------------------------------------------

func _flush_xp(events: Array) -> void:
	var queue := _xp_queue
	_xp_queue = []
	for entry in queue:
		_add_xp(entry[0], entry[1], events)


func monster_at(p: Vector2i) -> Monster:
	for id in monsters:
		if monsters[id].pos == p:
			return monsters[id]
	return null


func _add_xp(hero: Hero, amount: int, events: Array) -> void:
	if _defer_end:  # dano simultâneo: o XP (e a cura do level up) só vale depois que todos os golpes caíram
		_xp_queue.append([hero, amount])
		return
	if not hero.alive or hero.level >= Defs.MAX_LEVEL:
		return
	hero.xp += amount
	events.append({ "type": "xp_gained", "player": hero.id, "amount": amount, "xp": hero.xp })
	while hero.level < Defs.MAX_LEVEL and hero.xp >= Defs.XP_THRESHOLDS[hero.level + 1]:
		var healed := hero.level_up()
		events.append({ "type": "level_up", "player": hero.id, "level": hero.level, "healed": healed })


func _average_level() -> int:
	var total := 0
	var n := 0
	for h in living_heroes():
		total += h.level
		n += 1
	return clampi(int(round(float(total) / maxf(1.0, n))), 1, Defs.MAX_LEVEL)


func _refill_monsters() -> void:
	var guard := 0
	while monsters.size() < Defs.MONSTERS_ON_MAP and guard < 200:
		guard += 1
		var spot := _random_monster_cell()
		if spot == Vector2i(-1, -1):
			break
		var m := Monster.create(_next_monster_id, _roll_monster_kind(spot), _average_level(), spot)
		_next_monster_id += 1
		monsters[m.id] = m


## Sorteia o tipo pelo peso base; monstros de bioma entram com peso extra se a casa combina.
func _roll_monster_kind(cell: Vector2i = Vector2i(-1, -1)) -> String:
	var weights := {}
	var total := 0
	for k in Defs.MONSTER_KINDS:
		var w: int = Defs.MONSTER_KINDS[k]["weight"]
		if cell != Vector2i(-1, -1) and _fits_biome(k, cell):
			w += Defs.BIOME_SPAWN_WEIGHT
		weights[k] = w
		total += w
	var roll := rng.randi_range(1, total)
	var acc := 0
	for k in weights:
		acc += weights[k]
		if roll <= acc:
			return k
	return "slime"


func _fits_biome(kind: String, cell: Vector2i) -> bool:
	var biome: int = Defs.MONSTER_KINDS[kind].get("biome", -1)
	if biome < 0:
		return false
	if biome == Defs.Terrain.AGUA:  # polvo: na margem
		for n in board.neighbors(cell):
			if board.terrain_at(n) == Defs.Terrain.AGUA:
				return true
		return false
	return board.terrain_at(cell) == biome


func _random_monster_cell() -> Vector2i:
	var options: Array[Vector2i] = []
	for c in board.main_cells:
		if board.is_border(c) or monster_at(c) != null or _cell_has_hero(c):
			continue
		var far := true
		for h in alive_heroes():
			if absi(h.pos.x - c.x) + absi(h.pos.y - c.y) < Defs.MONSTER_MIN_DISTANCE_FROM_HEROES:
				far = false
				break
		if far:
			options.append(c)
	if options.is_empty():
		return Vector2i(-1, -1)
	return options[rng.randi_range(0, options.size() - 1)]


# ---------------------------------------------------------------------------
# Cartas e itens
# ---------------------------------------------------------------------------

## Retorna true se a carta faz o jogador perder o turno.
func _draw_card(hero: Hero, events: Array) -> bool:
	var card: Dictionary = Cards.DECK[rng.randi_range(0, Cards.DECK.size() - 1)]
	events.append({ "type": "card_drawn", "player": hero.id, "kind": card["kind"], "effect": card["effect"], "value": card["value"], "text": card["text"] })
	match card["effect"]:
		"heal":
			hero.heal(card["value"])
		"damage":
			_damage(hero, card["value"], "card", events)
		"xp":
			_add_xp(hero, card["value"], events)
		"teleport":
			var spot := _random_free_cell()
			if spot != Vector2i(-1, -1):
				var from := hero.pos
				hero.pos = spot
				events.append({ "type": "teleported", "player": hero.id, "from": from, "to": spot })
		"skip_turn":
			return true
	return false


func _spawn_trophies() -> void:
	for i in trophies_total:
		var spot := _random_item_cell()
		if spot == Vector2i(-1, -1):
			break
		_put_item(spot, Defs.ItemType.TESOURO)


func _refill_items() -> void:
	var count := 0
	for k in items:
		for it in items[k]:
			if it["type"] != Defs.ItemType.TESOURO:
				count += 1
	var guard := 0
	while count < Defs.ITEMS_ON_MAP and guard < 1000:
		guard += 1
		var spot := _random_item_cell()
		if spot == Vector2i(-1, -1):
			break
		_put_item(spot, _roll_item_type())
		count += 1


func _roll_item_type() -> int:
	var roll := rng.randi_range(1, 100)
	var acc := 0
	for t in Defs.ITEM_WEIGHTS:
		acc += Defs.ITEM_WEIGHTS[t]
		if roll <= acc:
			return t
	return Defs.ItemType.ARMADILHA


func _put_item(p: Vector2i, type: int, equip_id := "") -> void:
	if not items.has(p):
		items[p] = []
	var item := { "type": type, "value": Defs.ITEM_VALUE[type] }
	if type == Defs.ItemType.EQUIPAMENTO:
		item["id"] = equip_id if equip_id != "" else _roll_equipment_id()
	items[p].append(item)


func _roll_equipment_id() -> String:
	var total := 0
	for id in Defs.EQUIPMENT:
		total += Defs.EQUIPMENT[id]["weight"]
	var roll := rng.randi_range(1, total)
	var acc := 0
	for id in Defs.EQUIPMENT:
		acc += Defs.EQUIPMENT[id]["weight"]
		if roll <= acc:
			return id
	return "adaga"


## Butim de monstro derrotado.
func _drop_loot(p: Vector2i, events: Array) -> void:
	if rng.randi_range(1, 100) > Defs.MONSTER_DROP_PCT:
		return
	var total := 0
	for t in Defs.MONSTER_DROPS:
		total += Defs.MONSTER_DROPS[t]
	var roll := rng.randi_range(1, total)
	var acc := 0
	for t in Defs.MONSTER_DROPS:
		acc += Defs.MONSTER_DROPS[t]
		if roll <= acc:
			_put_item(p, t)
			events.append({ "type": "loot_dropped", "pos": p, "item": t })
			return


# ---------------------------------------------------------------------------
# Turnos
# ---------------------------------------------------------------------------

func _advance_turn(events: Array) -> void:
	heroes[current_player()].move_points = 0
	var n := turn_order.size()
	var old_index := turn_index
	for i in n:
		turn_index = (turn_index + 1) % n
		if heroes[turn_order[turn_index]].alive:
			break
	turn_number += 1
	if max_turns > 0 and turn_number > max_turns:
		_finish_by_score(events)
		return
	if turn_index <= old_index:
		round_number += 1
		_on_new_round(events)
		if finished:
			return
	if not heroes[current_player()].alive:
		_advance_turn(events)  # o fechamento do mapa matou quem seria o próximo
		return
	var next: Hero = heroes[current_player()]
	next.cooldown = maxi(0, next.cooldown - 1)
	next.dodge = false
	next.move_points = 0
	if next.burn_turns > 0:
		next.burn_turns -= 1
		var burn := mini(Defs.BURN_DAMAGE, maxi(0, next.hp - 1))  # queimadura nunca mata
		next.hp -= burn
		events.append({ "type": "damage", "player": next.id, "amount": burn, "source": "burn", "hp": next.hp })
	phase = Defs.Phase.ROLL
	events.append({ "type": "turn_started", "player": next.id, "turn": turn_number })


# ---------------------------------------------------------------------------
# Mapa que fecha
# ---------------------------------------------------------------------------

func _closes_in_round(r: int) -> bool:
	return r >= close_start and (r - close_start) % close_every == 0 and rings_closed < board.max_rings()


func _on_new_round(events: Array) -> void:
	events.append({ "type": "round_started", "round": round_number })
	if _closes_in_round(round_number):
		_close_ring(events)
	elif rings_closed >= board.max_rings() and round_number >= close_start:
		_sudden_death(events)
	if finished:
		return
	if _closes_in_round(round_number + 1):
		warning_ring = rings_closed
		events.append({ "type": "ring_warning", "ring": warning_ring, "closes_in_round": round_number + 1 })
	_world_tick(events)


# ---------------------------------------------------------------------------
# Terreno vivo, eventos de rodada e ressurreições (início de cada rodada)
# ---------------------------------------------------------------------------

func _world_tick(events: Array) -> void:
	_revive_monsters(events)
	_spread_lava(events)
	_storm_tick(events)
	if finished:
		return
	_round_event_tick(events)


func _change_terrain(cells: Array[Vector2i], to: int, cause: String, events: Array) -> void:
	if cells.is_empty():
		return
	for c in cells:
		board.set_terrain(c, to)
	events.append({ "type": "terrain_changed", "cells": cells, "to": to, "cause": cause })


func _count_terrain(t: int) -> int:
	var n := 0
	for c in board.main_cells:
		if board.terrain_at(c) == t:
			n += 1
	return n


## A lava avança para casas vizinhas sem herói, monstro ou item (nunca passa de LAVA_MAX_PCT).
func _spread_lava(events: Array) -> void:
	var lava := _count_terrain(Defs.Terrain.LAVA)
	if lava == 0 or lava * 100 >= board.main_cells.size() * Defs.LAVA_MAX_PCT:
		return
	var options: Array[Vector2i] = []
	for c in board.main_cells:
		if board.terrain_at(c) == Defs.Terrain.LAVA or options.has(c):
			continue
		if items.has(c) or _cell_has_hero(c) or monster_at(c) != null:
			continue
		for n in board.neighbors(c):
			if board.terrain_at(n) == Defs.Terrain.LAVA:
				options.append(c)
				break
	var picked: Array[Vector2i] = []
	for i in Defs.LAVA_SPREAD_PER_ROUND:
		if options.is_empty():
			break
		picked.append(options.pop_at(rng.randi_range(0, options.size() - 1)))
	_change_terrain(picked, Defs.Terrain.LAVA, "lava_spread", events)


func storm_area(center: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-Defs.STORM_HALF_H, Defs.STORM_HALF_H + 1):
		for dx in range(-Defs.STORM_HALF_W, Defs.STORM_HALF_W + 1):
			var p := center + Vector2i(dx, dy)
			if board.is_passable(p):
				out.append(p)
	return out


## A tempestade avisada cai (dano a quem ficou nela, +1 de custo durante a rodada) e a próxima é sorteada.
func _storm_tick(events: Array) -> void:
	storm_cells = []
	if round_number < Defs.STORM_START_ROUND:
		return
	if storm_next != Vector2i(-1, -1):
		storm_cells = storm_next_cells
		events.append({ "type": "storm_struck", "center": storm_next, "cells": storm_cells })
		_defer_end = true
		for h in alive_heroes():
			if storm_cells.has(h.pos):
				_damage(h, Defs.STORM_DAMAGE, "storm", events)
		_defer_end = false
		_check_end(events)
		if finished:
			return
	# próxima: perto de um herói em jogo, para ameaçar de verdade
	var pool := alive_heroes()
	if pool.is_empty():
		return
	var anchor: Vector2i = pool[rng.randi_range(0, pool.size() - 1)].pos
	var center := anchor + Vector2i(rng.randi_range(-Defs.STORM_HALF_W, Defs.STORM_HALF_W), rng.randi_range(-Defs.STORM_HALF_H, Defs.STORM_HALF_H))
	center = Vector2i(clampi(center.x, 1, board.width - 2), clampi(center.y, 1, board.height - 2))
	storm_next = center
	storm_next_cells = storm_area(center)
	events.append({ "type": "storm_warning", "center": center, "cells": storm_next_cells })


## Eventos de rodada: o sorteio é avisado na rodada anterior e acontece no início da seguinte.
func _round_event_tick(events: Array) -> void:
	if round_number % Defs.ROUND_EVENT_EVERY == 0 and pending_event != "":
		var kind := pending_event
		pending_event = ""
		last_event = kind
		_apply_round_event(kind, events)
	if (round_number + 1) % Defs.ROUND_EVENT_EVERY == 0:
		var options: Array = Defs.ROUND_EVENTS.filter(func(k): return k != last_event)
		pending_event = options[rng.randi_range(0, options.size() - 1)]
		events.append({ "type": "round_event_announced", "kind": pending_event, "round": round_number + 1 })


func _apply_round_event(kind: String, events: Array) -> void:
	var cells: Array[Vector2i] = []
	match kind:
		"chuva_itens":
			for i in Defs.EVENT_RAIN_ITEMS:
				var spot := _random_item_cell()
				if spot == Vector2i(-1, -1):
					break
				_put_item(spot, _roll_item_type())
				cells.append(spot)
		"caravana":
			for i in Defs.EVENT_CARAVAN_MONSTERS:
				var spot := _random_monster_cell()
				if spot == Vector2i(-1, -1):
					break
				var m := Monster.create(_next_monster_id, _roll_monster_kind(spot), _average_level(), spot)
				_next_monster_id += 1
				monsters[m.id] = m
				cells.append(spot)
		"tregua":
			truce_round = round_number
		"erupcao":
			var spots: Array[Vector2i] = []
			for c in board.main_cells:
				if board.terrain_at(c) != Defs.Terrain.LAVA and not items.has(c) and not board.is_border(c) and monster_at(c) == null:
					var far := true
					for h in alive_heroes():
						if absi(h.pos.x - c.x) + absi(h.pos.y - c.y) < 3:
							far = false
							break
					if far:
						spots.append(c)
			if not spots.is_empty():
				var center: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
				cells.append(center)
				for n in board.neighbors(center):
					if cells.size() < 3 and board.is_passable(n) and not items.has(n) and not _cell_has_hero(n) and monster_at(n) == null:
						cells.append(n)
				_change_terrain(cells, Defs.Terrain.LAVA, "erupcao", events)
		"nevasca":
			var spots: Array[Vector2i] = []
			for c in board.main_cells:
				if board.terrain_at(c) in [Defs.Terrain.PLANICIE, Defs.Terrain.FLORESTA, Defs.Terrain.MASMORRA] and not _cell_has_hero(c) and monster_at(c) == null:
					spots.append(c)
			for i in Defs.EVENT_SNOW_CELLS:
				if spots.is_empty():
					break
				cells.append(spots.pop_at(rng.randi_range(0, spots.size() - 1)))
			_change_terrain(cells, Defs.Terrain.GELO, "nevasca", events)
	events.append({ "type": "round_event", "kind": kind, "cells": cells })


## Esqueletos derrotados voltam depois de SKELETON_REVIVE_ROUNDS rodadas, uma única vez.
func _revive_monsters(events: Array) -> void:
	var still: Array = []
	for r in reviving:
		if round_number < r["due"]:
			still.append(r)
			continue
		var spot: Vector2i = r["pos"]
		if not board.is_passable(spot) or monster_at(spot) != null or _cell_has_hero(spot):
			spot = _spawn_cell_near(spot)
		var m := Monster.create(_next_monster_id, r["kind"], r["level"], spot)
		_next_monster_id += 1
		m.revived = true
		m.xp = m.xp / 2
		m.hp = maxi(1, m.max_hp * Defs.SKELETON_REVIVE_HP_PCT / 100)
		monsters[m.id] = m
		events.append({ "type": "monster_revived", "monster": m.id, "kind": m.kind, "pos": spot })
	reviving = still


func _sudden_death(events: Array) -> void:
	sudden_rounds += 1
	var dmg := Defs.SUDDEN_DEATH_BASE + Defs.SUDDEN_DEATH_STEP * (sudden_rounds - 1)
	events.append({ "type": "sudden_death", "damage": dmg })
	var hp_before := {}
	for h in living_heroes():
		hp_before[h.id] = h.hp
	_defer_end = true
	for h in living_heroes():
		_damage(h, dmg, "sudden_death", events, null, true)
	_defer_end = false
	if living_heroes().is_empty():
		# todos caíram na mesma rodada: vence quem tinha mais vida antes (empate real = sem vencedor)
		var best := -1
		var tie := false
		for id in hp_before:
			if best == -1 or hp_before[id] > hp_before[best]:
				best = id
				tie = false
			elif hp_before[id] == hp_before[best]:
				tie = true
		_finish(-1 if tie else best, events)
	else:
		_check_end(events)


func _close_ring(events: Array) -> void:
	var ring := rings_closed
	var cells := board.close_ring(ring)
	rings_closed += 1
	warning_ring = -1
	var closed := {}
	for c in cells:
		closed[c] = true
	events.append({ "type": "ring_closed", "ring": ring, "cells": cells })

	# itens: troféus são realocados (o conjunto é fixo), o resto some
	for c in cells:
		traps.erase(c)
	var trophy_spots: Array[Vector2i] = []
	for c in cells:
		if items.has(c):
			for it in items[c]:
				if it["type"] == Defs.ItemType.TESOURO:
					trophy_spots.append(c)
			items.erase(c)
	for id in monsters.keys():
		if closed.has(monsters[id].pos):
			monsters.erase(id)
	for spot in trophy_spots:
		_put_item(_nearest_open_cell(spot), Defs.ItemType.TESOURO)
	_defer_end = true  # quem estiver no anel cai junto: o fim é avaliado depois de todos
	for h in alive_heroes():
		if closed.has(h.pos):
			var from := h.pos
			h.pos = _nearest_open_cell(from)
			events.append({ "type": "pushed", "player": h.id, "from": from, "to": h.pos })
			_damage(h, Defs.CLOSE_DAMAGE, "closing", events, null, true)
	_defer_end = false
	_check_end(events)
	if finished:
		return
	_refill_items()
	_refill_monsters()


## Casa vizinha livre (sem herói nem monstro); se não houver, a mais próxima.
func _free_neighbor(from: Vector2i) -> Vector2i:
	for n in board.neighbors(from):
		if board.is_passable(n) and not _cell_has_hero(n) and monster_at(n) == null:
			return n
	return _nearest_open_cell(from)


func _nearest_open_cell(from: Vector2i) -> Vector2i:
	var best := from
	var best_d := 1 << 30
	for c in board.main_cells:
		if monster_at(c) != null:
			continue
		var d := absi(c.x - from.x) + absi(c.y - from.y)
		if d < best_d:
			best_d = d
			best = c
	return best


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

func _fail(error: String) -> Dictionary:
	return { "ok": false, "error": error, "events": [] }


func _occupants(p: Vector2i, except: Hero) -> Array[Hero]:
	var out: Array[Hero] = []
	for id in heroes:
		var h: Hero = heroes[id]
		if h.alive and h != except and h.pos == p:
			out.append(h)
	return out


func _cell_has_hero(p: Vector2i) -> bool:
	return not _occupants(p, null).is_empty()


func _random_item_cell() -> Vector2i:
	var options: Array[Vector2i] = []
	for c in board.main_cells:
		if not board.is_border(c) and not items.has(c) and not _cell_has_hero(c) and monster_at(c) == null:
			options.append(c)
	if options.is_empty():
		return Vector2i(-1, -1)
	return options[rng.randi_range(0, options.size() - 1)]


func _random_free_cell() -> Vector2i:
	var options: Array[Vector2i] = []
	for c in board.main_cells:
		if not _cell_has_hero(c) and monster_at(c) == null:
			options.append(c)
	if options.is_empty():
		return Vector2i(-1, -1)
	return options[rng.randi_range(0, options.size() - 1)]


func _nearest_free_main_cell(target: Vector2i, used: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for c in board.main_cells:
		if used.has(c):
			continue
		var d := absi(c.x - target.x) + absi(c.y - target.y)
		if d < best_d:
			best_d = d
			best = c
	return best


func _shuffle(arr: Array[int]) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
