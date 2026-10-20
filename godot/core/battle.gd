class_name Battle
extends RefCounted
## Batalha por rodadas com escolha simultânea de ação, contra monstro ou outro herói.
## Ações: attack | defend | ability | item (potion) | flee.
##
## Resolução de cada rodada:
##  1. Fugas (d20 + velocidade >= FLEE_DC). Quem falha perde a ação.
##  2. Itens e habilidades de suporte (cura, esquiva).
##  3. Ofensas: ataque vs ataque é um duelo (d20 + ataque/2, defensor ganha bônus de terreno);
##     ataque contra quem não ataca é um teste contra 10 + defesa; defender corta o dano pela
##     metade e, se o golpe falha, contra-ataca. Ataque Mágico ignora defesa e rolagens.
##  4. Todo o dano é aplicado junto (duas mortes na mesma rodada são possíveis).

var gs: GameState
var kind := "pvp"  # "pvp" | "monster"
var attacker: Hero
var defender: Hero
var monster: Monster
var origin := Vector2i.ZERO
var round_no := 1
var pids: Array[int] = []
var choices := {}  # player_id -> { action, potion }


static func start(p_gs: GameState, p_attacker: Hero, p_defender: Hero, p_monster: Monster, p_origin: Vector2i, events: Array) -> Battle:
	var b := Battle.new()
	b.gs = p_gs
	b.attacker = p_attacker
	b.defender = p_defender
	b.monster = p_monster
	b.origin = p_origin
	b.kind = "monster" if p_monster != null else "pvp"
	b.pids = [p_attacker.id]
	if p_defender != null:
		b.pids.append(p_defender.id)
	events.append({
		"type": "battle_started", "kind": b.kind, "attacker": p_attacker.id,
		"defender": p_defender.id if p_defender != null else -1,
		"monster": p_monster.id if p_monster != null else -1,
	})
	return b


func pending() -> Array[int]:
	var out: Array[int] = []
	for pid in pids:
		if not choices.has(pid):
			out.append(pid)
	return out


## Registra a escolha. Resolve a rodada quando todos escolheram. Retorna "" ou o código do erro.
func submit(pid: int, action: Dictionary, events: Array) -> String:
	if not pids.has(pid) or choices.has(pid):
		return "not_your_turn"
	var hero: Hero = gs.heroes[pid]
	var act: String = action.get("action", "")
	var potion := ""
	match act:
		"attack", "defend", "flee":
			pass
		"ability":
			if hero.cooldown > 0:
				return "on_cooldown"
		"item":
			potion = action.get("potion", "")
			if not Defs.POTIONS.has(potion) or hero.potions.get(potion, 0) <= 0:
				return "no_potion"
		_:
			return "unknown_action"
	choices[pid] = { "action": act, "potion": potion }
	events.append({ "type": "battle_choice_locked", "player": pid })
	if pending().is_empty():
		_resolve(events)
	return ""


## Usado pelo timeout do servidor: quem não escolheu ataca.
func fill_defaults(events: Array) -> void:
	for pid in pending():
		choices[pid] = { "action": "attack", "potion": "" }
	_resolve(events)


# ---------------------------------------------------------------------------

func _fighter(i: int):
	return attacker if i == 0 else (defender if kind == "pvp" else monster)


func _atk(f) -> int:
	return f.atk_total()


func _terrain_bonus(i: int) -> int:
	return Defs.DEFENSE_BONUS.get(gs.board.terrain_at(attacker.pos), 0) if i == 1 else 0


func _monster_choice() -> Dictionary:
	var weak := monster.hp * 100 / maxi(1, monster.max_hp) < 30
	var defend_chance := 40 if weak else 25
	var act := "defend" if gs.rng.randi_range(1, 100) <= defend_chance else "attack"
	return { "action": act, "potion": "" }


func _resolve(events: Array) -> void:
	var gsr := gs
	var rng := gsr.rng
	var acts: Array[Dictionary] = []
	acts.append(choices[attacker.id])
	acts.append(choices[defender.id] if kind == "pvp" else _monster_choice())
	events.append({
		"type": "battle_actions", "round": round_no,
		"actions": [acts[0]["action"], acts[1]["action"]],
		"potions": [acts[0]["potion"], acts[1]["potion"]],
	})

	var offense := ["none", "none"]  # none | normal | power | magic
	var stance := ["none", "none"]   # none | defend | stunned
	var fled := -1

	# 1. fugas
	for i in 2:
		if acts[i]["action"] != "flee":
			continue
		var f = _fighter(i)
		var roll := rng.randi_range(1, 20)
		var ok: bool = roll + f.speed_total() >= Defs.FLEE_DC
		events.append({ "type": "flee_attempt", "side": i, "roll": roll, "success": ok })
		if ok and fled == -1:
			fled = i
		elif not ok:
			stance[i] = "stunned"
	if fled != -1:
		_end(events, "fled", fled)
		return

	# 2. itens, suporte e intenções
	for i in 2:
		var f = _fighter(i)
		match acts[i]["action"]:
			"attack":
				offense[i] = "normal"
			"defend":
				stance[i] = "defend"
			"item":
				gsr.use_potion(f, acts[i]["potion"], events)
			"ability":
				match f.hero_class:
					Defs.HeroClass.GUERREIRO: offense[i] = "power"
					Defs.HeroClass.MAGO: offense[i] = "magic"
					Defs.HeroClass.LADINO:
						f.dodge_round = true
						events.append({ "type": "ability", "player": f.id, "ability": "esquiva" })
					Defs.HeroClass.CLERIGO:
						var healed: int = f.heal(Defs.CLERIC_HEAL + Defs.CLERIC_HEAL_PER_LEVEL * (f.level - 1))
						events.append({ "type": "ability", "player": f.id, "ability": "cura_pessoal", "healed": healed })
				gsr._set_cooldown(f)

	# 3. golpes (src, dst, dano, tipo)
	var hits: Array[Dictionary] = []
	var rolls := {}
	var contested: bool = offense[0] in ["normal", "power"] and offense[1] in ["normal", "power"]
	if contested:
		var ra := rng.randi_range(1, 20)
		var rd := rng.randi_range(1, 20)
		var sa := ra + int(ceil(_atk(attacker) / 2.0))
		var sd := rd + int(ceil(_atk(_fighter(1)) / 2.0)) + _terrain_bonus(1)
		rolls = { "ra": ra, "rd": rd, "sa": sa, "sd": sd }
		if sa != sd:
			var w := 0 if sa > sd else 1
			var l := 1 - w
			var dmg := maxi(1, _atk(_fighter(w)) - _fighter(l).def_total() / 2 + absi(sa - sd) / 4)
			hits.append({ "src": w, "dst": l, "dmg": dmg + _power_bonus(w, offense[w]), "kind": "duel" })
	else:
		for i in 2:
			var j := 1 - i
			if offense[i] == "none":
				continue
			var fi = _fighter(i)
			var fj = _fighter(j)
			if offense[i] == "magic":
				var m: int = Defs.MAGIC_DAMAGE + Defs.MAGIC_DAMAGE_PER_LEVEL * (fi.level - 1)
				if stance[j] == "defend":
					m = maxi(1, m / 2)
				hits.append({ "src": i, "dst": j, "dmg": m, "kind": "magic" })
				continue
			var roll := rng.randi_range(1, 20)
			var score := roll + int(ceil(_atk(fi) / 2.0))
			var target: int = 10 + fj.def_total() + _terrain_bonus(j) + (3 if stance[j] == "defend" else 0)
			rolls["r%d" % i] = roll
			if score > target:
				var d := maxi(1, _atk(fi) - fj.def_total() / 2 + (score - target) / 4) + _power_bonus(i, offense[i])
				if stance[j] == "defend":
					d = maxi(1, d / 2)
				hits.append({ "src": i, "dst": j, "dmg": d, "kind": "attack" })
			elif stance[j] == "defend":
				hits.append({ "src": j, "dst": i, "dmg": maxi(1, _atk(fj) / 3), "kind": "counter" })

	# Esquiva do ladino: quem tenta acertar (e acertaria) leva um contra-golpe de ataque/2
	var ripostes: Array[Dictionary] = []
	for h in hits:
		var dst = _fighter(h["dst"])
		if dst is Hero and dst.dodge_round and h["kind"] in ["attack", "duel"]:
			ripostes.append({ "src": h["dst"], "dst": h["src"], "dmg": maxi(1, _atk(dst) / 2), "kind": "riposte" })
	hits.append_array(ripostes)

	# 4. aplicar todo o dano junto
	gsr._defer_end = true
	var dealt := []
	for h in hits:
		var src = _fighter(h["src"])
		var dst = _fighter(h["dst"])
		var applied := 0
		if dst is Hero:
			applied = gsr._damage(dst, h["dmg"], "battle", events, src if src is Hero else null)
		else:
			dst.hp = maxi(0, dst.hp - h["dmg"])
			applied = h["dmg"]
		if applied > 0 and src is Hero and dst is Hero:
			gsr._add_xp(src, Defs.XP_PER_PVP_ROUND_WIN, events)
		dealt.append({ "src": h["src"], "dst": h["dst"], "damage": applied, "kind": h["kind"] })
	gsr._defer_end = false
	gsr._flush_xp(events)
	events.append({
		"type": "battle_round", "round": round_no, "rolls": rolls, "hits": dealt, "cell": attacker.pos,
		"monster_hp": monster.hp if monster != null else -1,
	})

	# 5. fim de rodada
	for i in 2:
		var f = _fighter(i)
		if f is Hero:
			f.dodge_round = false
			if f.buff_rounds > 0:
				f.buff_rounds -= 1
	var any_hero_dead := not attacker.alive or (kind == "pvp" and not defender.alive)
	var monster_dead := kind == "monster" and monster.hp <= 0
	if any_hero_dead or monster_dead:
		_end(events, "death", -1)
		return
	round_no += 1
	choices.clear()
	if round_no > Defs.BATTLE_MAX_ROUNDS:
		_end(events, "timeout", -1)


func _power_bonus(i: int, off: String) -> int:
	var f = _fighter(i)
	if not (f is Hero):
		return 0
	var b := 0
	if off == "power" or f.power_strike:
		b = Defs.POWER_STRIKE_BONUS + Defs.POWER_STRIKE_PER_LEVEL * (f.level - 1)
	f.power_strike = false
	return b


func _end(events: Array, outcome: String, fleer: int) -> void:
	var g := gs
	g.battle = null
	for h in [attacker, defender]:
		if h != null:
			h.dodge_round = false
	events.append({ "type": "battle_ended", "outcome": outcome, "kind": kind, "attacker": attacker.id, "defender": defender.id if defender != null else -1 })
	# quem morreu pode voltar como morto-vivo no _check_end; guardamos antes quem caiu
	var attacker_died := not attacker.alive
	var defender_died := defender != null and not defender.alive
	g._check_end(events)

	var monster_killed := kind == "monster" and monster.hp <= 0
	if monster_killed:
		events.append({ "type": "monster_killed", "player": attacker.id, "monster": monster.id, "kind": monster.kind, "pos": monster.pos })
		g.monsters.erase(monster.id)
		g._drop_loot(monster.pos, events)
		if not attacker_died:
			g._add_xp(attacker, monster.xp, events)
		g._refill_monsters()

	if g.finished:
		return
	if attacker_died:
		g._advance_turn(events)
		return
	# sem mortes: o atacante recua, exceto se o defensor fugiu (aí ele sai da casa)
	var retreat := outcome == "timeout" or (outcome == "fled" and fleer == 0)
	if outcome == "death" and kind == "monster" and not monster_killed:
		retreat = true
	if defender_died:
		retreat = false
	if outcome == "fled" and fleer == 1 and kind == "pvp":
		defender.pos = g._free_neighbor(defender.pos)
		events.append({ "type": "fled_to", "player": defender.id, "to": defender.pos })
	if retreat:
		attacker.pos = origin
		attacker.move_points = 0
		events.append({ "type": "retreated", "player": attacker.id, "to": origin })
	g.phase = Defs.Phase.MOVE if attacker.move_points > 0 else Defs.Phase.ACTION
