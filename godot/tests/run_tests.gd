extends SceneTree
## Rodar: godot --headless --path godot -s tests/run_tests.gd

var _fails := 0
var _checks := 0

const G := Defs.HeroClass


func _init() -> void:
	test_models3d()
	test_dice_faces()
	test_doubles()
	test_dice_physics()
	test_maps()
	test_class_bonuses_apply_to_all()
	test_initial_items()
	test_movement_costs()
	test_terrain_damage()
	test_battle_basics()
	test_battle_actions()
	test_battle_endings()
	test_potions()
	test_dodge()
	test_death_and_victory()
	test_trophy_victory()
	test_abilities()
	test_cooldown()
	test_cards()
	test_turn_rules()
	test_levels()
	test_monsters()
	test_equipment()
	test_traps()
	test_undead()
	test_closing_map()
	test_sudden_death_tiebreak()
	test_bot_games()
	print("\n%d verificações, %d falhas" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FALHOU: ", msg)


func duel(seed_value := 1, a := G.GUERREIRO, b := G.MAGO, map_id := 12) -> GameState:
	var s := GameState.new()
	s.setup(seed_value, map_id, [{ "class": a }, { "class": b }], 43, 25)
	return s


## Deixa o jogador pid como jogador da vez, em fase ACTION.
func make_current(s: GameState, pid: int, phase := Defs.Phase.ACTION) -> Hero:
	s.turn_index = s.turn_order.find(pid)
	s.phase = phase
	return s.heroes[pid]


## Coloca tudo em planície e heróis em posições conhecidas.
func flatten(s: GameState) -> void:
	for y in s.board.height:
		for x in s.board.width:
			s.board.set_terrain(Vector2i(x, y), Defs.Terrain.PLANICIE)
	s.items.clear()
	s.monsters.clear()


func place(s: GameState, pid: int, p: Vector2i) -> void:
	s.heroes[pid].pos = p


# ---------------------------------------------------------------------------

func test_models3d() -> void:
	print("personagens 3D (.glb)")
	var keys := Models3D.all_keys()
	check(keys.size() == 10, "10 modelos listados (%d)" % keys.size())
	for hc in Defs.CLASS_NAMES:
		check(Models3D.key_for(hc) != "" and Models3D.exists(Models3D.key_for(hc)), "classe %s tem modelo" % Defs.CLASS_NAMES[hc])
	for k in keys:
		check(Models3D.exists(k), "arquivo de %s existe e foi importado" % k)
		var n := Models3D.make(k, Models3D.WALK)
		check(n != null, "%s instancia" % k)
		if n == null:
			continue
		root.add_child(n)
		var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
		check(ap != null and ap.has_animation(Models3D.IDLE) and ap.has_animation(Models3D.WALK), "%s tem as animações idle e walk" % k)
		if ap != null:
			check(ap.is_playing() and ap.current_animation == Models3D.WALK, "%s toca a animação pedida" % k)
			check(ap.get_animation(Models3D.WALK).loop_mode != Animation.LOOP_NONE, "%s: andar é em loop" % k)
		var box := Models3D.bounds(n)
		check(box.size.y > 1.1 and box.size.y < 2.1 and box.size.x < 2.0, "%s tem tamanho de célula (%.2f x %.2f)" % [k, box.size.x, box.size.y])
		var colored := false
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh.surface_get_material(0)
			if m is BaseMaterial3D and m.vertex_color_use_as_albedo:
				colored = true
		check(colored, "%s usa a cor dos vértices" % k)
		n.queue_free()
	check(Models3D.make("naoexiste") == null, "modelo inexistente devolve null")
	for kind in Defs.MONSTER_KINDS:
		check(Models3D.exists(Models3D.key_for_monster(kind)), "monstro %s tem modelo" % kind)
	for k in Models3D.monster_keys():
		var n := Models3D.make(k, Models3D.IDLE)
		check(n != null, "monstro %s instancia" % k)
		if n == null:
			continue
		root.add_child(n)
		var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
		check(ap != null and ap.has_animation(Models3D.IDLE) and ap.has_animation(Models3D.WALK), "monstro %s tem idle e walk" % k)
		var box := Models3D.bounds(n)
		check(box.size.y > 0.5 and box.size.y < 3.0 and box.size.x < 3.2, "monstro %s cabe na célula (%.2f x %.2f)" % [k, box.size.x, box.size.y])
		n.queue_free()


func test_dice_faces() -> void:
	print("dados 3D: a face sorteada fica para cima")
	for value in range(1, 7):
		for yaw in [0.0, 1.3, 4.0]:
			var q := Dice3D.d6_final(value, yaw)
			var up_normal := Vector3.ZERO
			for f in Dice3D.D6_FACES:
				if f["value"] == value:
					up_normal = f["n"]
			check((q * up_normal).dot(Vector3.UP) > 0.999, "d6 face %d fica para cima (yaw %.1f)" % [value, yaw])
	# faces opostas do d6 somam 7
	for f in Dice3D.D6_FACES:
		for g2 in Dice3D.D6_FACES:
			if f["n"].dot(g2["n"]) < -0.99:
				check(f["value"] + g2["value"] == 7, "faces opostas do d6 somam 7")
	for value in range(1, 21):
		var q2 := Dice3D.d20_final(value, 0.7)
		var n20 := Vector3.ZERO
		for fi in 20:
			if Dice3D._d20_numbers[fi] == value:
				n20 = Dice3D._d20_normals[fi]
		check((q2 * n20).dot(Vector3.UP) > 0.999, "d20 face %d fica para cima" % value)
	var seen := {}
	for fi in 20:
		seen[Dice3D._d20_numbers[fi]] = true
	check(seen.size() == 20, "d20 tem os 20 números, sem repetir")
	# movimento com dois dados: média arredondada para cima
	var s := duel(3)
	s.heroes[s.current_player()].speed = 3
	var r := s.apply(s.current_player(), { "type": "roll" })
	var ev: Dictionary = r.events[0]
	check(ev["dice"].size() == Defs.MOVE_DICE, "evento traz os dados")
	var expect := int(ceil(float(ev["dice"][0] + ev["dice"][-1]) / Defs.MOVE_DICE))
	check(ev["roll"] == expect and ev["move_points"] >= 1, "movimento = média dos dados arredondada para cima")


func test_dice_physics() -> void:
	print("física dos dados (só apresentação)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var bounds := Rect2(-2.6, 0.3, 5.2, 2.6)
	var collisions := 0
	var longest := 0.0
	for k in 300:
		var starts := [Vector3(-0.95, 2.0, -0.4), Vector3(0.95, 2.0, -0.4)]
		var vels := []
		for i in 2:
			vels.append(Vector3(rng.randf_range(-1.6, 1.6), -1.0, rng.randf_range(2.4, 5.5)))
		var r := DicePhysics.simulate(starts, vels, 0.45, bounds)
		longest = maxf(longest, r["duration"])
		for e in r["events"]:
			if e["kind"] == "die":
				collisions += 1
		for i in 2:
			var arr: PackedVector3Array = r["samples"][i]
			var last := arr[arr.size() - 1]
			check(not is_nan(last.x) and not is_nan(last.y) and not is_nan(last.z), "trajetória sem NaN")
			check(absf(last.y - 0.45) < 0.001, "dado termina apoiado no chão (y=%.3f)" % last.y)
			check(last.x >= bounds.position.x - 0.01 and last.x <= bounds.end.x + 0.01 and last.z >= bounds.position.y - 0.01 and last.z <= bounds.end.y + 0.01, "dado termina dentro da área visível")
			check(r["t_stop"][i] <= 1.31, "dado para dentro do limite de tempo (%.2f)" % r["t_stop"][i])
		var a: Vector3 = r["samples"][0][r["samples"][0].size() - 1]
		var b: Vector3 = r["samples"][1][r["samples"][1].size() - 1]
		check(a.distance_to(b) > 0.85, "dados não terminam sobrepostos (%.2f)" % a.distance_to(b))
	check(collisions > 10, "há colisões entre os dados (%d em 300 lançamentos)" % collisions)
	print("  mais longo: %.2fs, colisões: %d" % [longest, collisions])


func test_doubles() -> void:
	print("par nos dados")
	var seen := {}
	for sd in 4000:
		var g := duel(sd)
		var h: Hero = g.heroes[g.current_player()]
		h.speed = 3
		var e: Dictionary = g.apply(g.current_player(), { "type": "roll" }).events[0]
		var a: int = e["dice"][0]
		var b: int = e["dice"][1]
		if a != b:
			check(not e["pair"] and e["bonus"] == 0, "sem par, sem bônus")
			continue
		var expect := Defs.DOUBLE_SIX_BONUS if a == 6 else (0 if a == 1 else Defs.DOUBLES_BONUS)
		check(e["pair"] and e["bonus"] == expect, "par de %d dá bônus %d" % [a, expect])
		check(e["move_points"] == maxi(1, a + expect), "movimento do par de %d = %d" % [a, a + expect])
		seen[a] = true
	check(seen.size() == 6, "todos os pares apareceram (%d)" % seen.size())


func test_maps() -> void:
	print("mapas")
	for map_id in range(1, 16):
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var b := Board.new()
		b.generate(map_id, rng)
		check(b.main_cells.size() >= 80, "mapa %d tem região jogável grande (%d)" % [map_id, b.main_cells.size()])
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 7
		var b2 := Board.new()
		b2.generate(map_id, rng2)
		check(b._terrain == b2._terrain, "mapa %d é reproduzível pela seed" % map_id)
		for c in b.main_cells:
			if b.terrain_at(c) == Defs.Terrain.AGUA:
				check(false, "mapa %d: célula jogável é água" % map_id)
				break
	# spawns distintos e dentro da região jogável
	for map_id in range(1, 16):
		var s := duel(3, G.GUERREIRO, G.MAGO, map_id)
		check(s.heroes[0].pos != s.heroes[1].pos, "mapa %d: spawns distintos" % map_id)
		check(s.board.main_cells.has(s.heroes[0].pos) and s.board.main_cells.has(s.heroes[1].pos), "mapa %d: spawns jogáveis" % map_id)


func test_class_bonuses_apply_to_all() -> void:
	print("bônus de classe (bug do Python: só o último herói recebia)")
	var s := GameState.new()
	s.setup(1, 12, [{ "class": G.GUERREIRO }, { "class": G.MAGO }, { "class": G.LADINO }, { "class": G.CLERIGO }], 43, 25)
	check(s.heroes[0].max_hp == 130 and s.heroes[0].speed == 4, "guerreiro +30 vida +1 vel")
	check(s.heroes[1].max_hp == 100 and s.heroes[1].speed == 4, "mago +1 vel")
	check(s.heroes[2].max_hp == 100 and s.heroes[2].speed == 5, "ladino +2 vel")
	check(s.heroes[3].max_hp == 110 and s.heroes[3].speed == 3, "clérigo +10 vida")
	var d := duel(1, G.GUERREIRO, G.GUERREIRO)
	check(d.heroes[0].max_hp == 130 and d.heroes[1].max_hp == 130, "duas classes iguais na mesma sala")


func test_initial_items() -> void:
	print("itens iniciais (bug do Python: só cartas e armadilhas)")
	var types := {}
	for seed_value in 30:
		var s := duel(seed_value)
		var n := 0
		var tr := 0
		for k in s.items:
			for it in s.items[k]:
				types[it["type"]] = true
				if it["type"] == Defs.ItemType.TESOURO: tr += 1
				else: n += 1
				check(not s.board.is_border(k), "item fora da borda")
		check(n == Defs.ITEMS_ON_MAP, "seed %d: %d itens aleatórios" % [seed_value, n])
		check(tr == Defs.TROPHIES_TOTAL, "seed %d: %d troféus no mapa" % [seed_value, tr])
	check(types.has(Defs.ItemType.VIDA), "nascem poções")
	check(types.has(Defs.ItemType.CARTA) and types.has(Defs.ItemType.ARMADILHA), "nascem cartas e armadilhas")


func test_movement_costs() -> void:
	print("movimento")
	var s := duel()
	flatten(s)
	var h := make_current(s, 0, Defs.Phase.MOVE)
	place(s, 0, Vector2i(10, 10))
	place(s, 1, Vector2i(30, 20))
	s.board.set_terrain(Vector2i(11, 10), Defs.Terrain.FLORESTA)
	s.board.set_terrain(Vector2i(9, 10), Defs.Terrain.MONTANHA)
	s.board.set_terrain(Vector2i(10, 11), Defs.Terrain.AGUA)
	h.move_points = 2
	var r := s.reachable(h)
	check(r.get(Vector2i(11, 10)) == 2, "floresta custa 2")
	check(not r.has(Vector2i(9, 10)), "montanha (3) fora de alcance com 2 pontos")
	check(not r.has(Vector2i(10, 11)), "água intransponível")
	check(r.get(Vector2i(10, 9)) == 1, "planície custa 1")
	h.move_points = 3
	check(s.reachable(h).get(Vector2i(9, 10)) == 3, "montanha alcançável com 3")
	# rota mais barata (Dijkstra): contornar montanha
	h.move_points = 4
	check(s.reachable(h).get(Vector2i(8, 10)) == 4, "(8,10) via montanha custa 4")
	# gastar pontos ao mover e passar à ação
	h.move_points = 1
	var res := s.apply(0, { "type": "move", "to": Vector2i(10, 9) })
	check(res.ok and h.pos == Vector2i(10, 9) and h.move_points == 0, "move gasta pontos")
	check(s.phase == Defs.Phase.ACTION, "sem pontos -> fase de ação")
	check(not s.apply(0, { "type": "move", "to": Vector2i(10, 8) }).ok, "não move fora da fase")
	# célula com 2 ocupantes bloqueia
	var s2 := GameState.new()
	s2.setup(1, 12, [{ "class": G.GUERREIRO }, { "class": G.MAGO }, { "class": G.LADINO }], 43, 25)
	flatten(s2)
	place(s2, 0, Vector2i(10, 10))
	place(s2, 1, Vector2i(11, 10))
	place(s2, 2, Vector2i(11, 10))
	var h2 := make_current(s2, 0, Defs.Phase.MOVE)
	h2.move_points = 3
	check(not s2.reachable(h2).has(Vector2i(11, 10)), "célula com 2 heróis é bloqueada")


func test_terrain_damage() -> void:
	print("terreno")
	var s := duel()
	flatten(s)
	var h := make_current(s, 0, Defs.Phase.MOVE)
	place(s, 0, Vector2i(10, 10))
	place(s, 1, Vector2i(30, 20))
	s.board.set_terrain(Vector2i(11, 10), Defs.Terrain.LAVA)
	h.move_points = 5
	var hp := h.hp
	s.apply(0, { "type": "move", "to": Vector2i(11, 10) })
	check(h.hp == hp - 5, "lava causa 5 de dano")


func submit_all(s: GameState, acts: Dictionary = {}) -> Array:
	var ev: Array = []
	for pid in s.pending_actors():
		var d := { "type": "battle_action", "action": "attack" }
		d.merge(acts.get(pid, {}), true)
		var r := s.apply(pid, d)
		check(r.ok, "ação de batalha aceita (%s)" % r.error)
		ev.append_array(r.events)
	return ev


func finish_battle(s: GameState, act := "attack") -> Array:
	var all: Array = []
	var guard := 0
	while s.phase == Defs.Phase.BATTLE and guard < 20:
		guard += 1
		all.append_array(submit_all(s, { 0: { "action": act }, 1: { "action": act } }))
	return all


## Herói 0 entra na casa do herói 1 e a batalha começa. Atributos podem ser ajustados antes.
func pvp(sd := 1, ca := G.GUERREIRO, cb := G.MAGO, terrain := Defs.Terrain.PLANICIE) -> GameState:
	var s := duel(sd, ca, cb)
	flatten(s)
	s.board.set_terrain(Vector2i(11, 10), terrain)
	s.turn_index = s.turn_order.find(0)
	s.phase = Defs.Phase.MOVE
	place(s, 0, Vector2i(10, 10))
	place(s, 1, Vector2i(11, 10))
	for h in s.heroes.values():
		h.hp = 100000
		h.max_hp = 100000
	s.heroes[0].move_points = 3
	s.apply(0, { "type": "move", "to": Vector2i(11, 10) })
	check(s.phase == Defs.Phase.BATTLE and s.battle != null, "movimento para casa de herói abre batalha")
	return s


func last_round(ev: Array) -> Dictionary:
	for i in range(ev.size() - 1, -1, -1):
		if ev[i]["type"] == "battle_round":
			return ev[i]
	return {}


func test_battle_basics() -> void:
	print("batalha: fluxo")
	var s := pvp(5)
	check(s.pending_actors() == [0, 1], "os dois precisam escolher")
	check(s.apply(0, { "type": "roll" }).error == "in_battle", "ações normais bloqueadas durante a batalha")
	check(s.apply(0, { "type": "battle_action", "action": "dance" }).error == "unknown_action", "ação inválida")
	check(s.apply(0, { "type": "battle_action", "action": "attack" }).ok, "primeira escolha")
	check(s.apply(0, { "type": "battle_action", "action": "attack" }).error == "not_your_turn", "não escolhe duas vezes")
	check(s.pending_actors() == [1], "só falta o defensor")
	var ev: Array = s.apply(1, { "type": "battle_action", "action": "attack" }).events
	check(not last_round(ev).is_empty(), "rodada resolvida quando ambos escolhem")
	# determinismo
	var a := pvp(5)
	var b := pvp(5)
	check(str(submit_all(a)) == str(submit_all(b)), "mesma seed, mesma rodada")
	# 4 rodadas e termina sem mortes: atacante recua
	var t := pvp(7)
	finish_battle(t, "defend")
	check(t.phase == Defs.Phase.ACTION and t.battle == null, "após o limite de rodadas a batalha acaba")
	check(t.heroes[0].pos == Vector2i(10, 10) and t.heroes[0].move_points == 0, "atacante recua e perde o movimento")
	# timeout do servidor: quem não escolheu ataca
	var u := pvp(8)
	u.apply(0, { "type": "battle_action", "action": "defend" })
	var tev := u.timeout()
	check(not last_round(tev).is_empty(), "timeout resolve a rodada")
	check(u.battle == null or u.battle.round_no == 2, "avança para a rodada 2")
	# defensor com vantagem de terreno vence mais duelos
	var forest := 0
	var plain := 0
	for sd in 300:
		for terrain in [Defs.Terrain.PLANICIE, Defs.Terrain.FLORESTA]:
			var g := pvp(sd, G.GUERREIRO, G.GUERREIRO, terrain)
			for h in last_round(submit_all(g)).get("hits", []):
				if h["kind"] == "duel" and h["src"] == 1:
					if terrain == Defs.Terrain.FLORESTA: forest += 1
					else: plain += 1
	check(forest > plain, "defensor na floresta vence mais duelos (%d > %d)" % [forest, plain])


func test_battle_actions() -> void:
	print("batalha: ações")
	# defender corta o golpe sem oposição pela metade
	var s := pvp(1, G.GUERREIRO, G.GUERREIRO)
	s.heroes[0].attack = 40
	s.heroes[1].defense = 5
	var rd := last_round(submit_all(s, { 1: { "action": "defend" } }))
	var r0: int = rd["rolls"]["r0"]
	var score := r0 + 20
	var raw := 40 - 2 + (score - 18) / 4
	check(rd["hits"].size() == 1 and rd["hits"][0]["kind"] == "attack" and rd["hits"][0]["damage"] == maxi(1, raw / 2), "defender reduz o dano pela metade (%s)" % str(rd["hits"]))

	# golpe que falha contra quem defende leva contra-ataque
	var c := pvp(2, G.GUERREIRO, G.GUERREIRO)
	c.heroes[0].attack = 1
	c.heroes[1].defense = 30
	c.heroes[1].attack = 30
	var rc := last_round(submit_all(c, { 1: { "action": "defend" } }))
	check(rc["hits"].size() == 1 and rc["hits"][0]["kind"] == "counter" and rc["hits"][0]["dst"] == 0 and rc["hits"][0]["damage"] == 10, "contra-ataque de ataque/3 (%s)" % str(rc["hits"]))

	# Ataque Mágico ignora defesa e rolagens; defender reduz à metade
	var m := pvp(3, G.MAGO, G.GUERREIRO)
	m.heroes[1].defense = 1000
	var rm := last_round(submit_all(m, { 0: { "action": "ability" }, 1: { "action": "attack" } }))
	var magic_hit: Array = rm["hits"].filter(func(h): return h["kind"] == "magic")
	check(magic_hit.size() == 1 and magic_hit[0]["damage"] == Defs.MAGIC_DAMAGE, "mago atinge ignorando defesa (%s)" % str(rm["hits"]))
	check(m.heroes[0].cooldown == Defs.ABILITY_COOLDOWN[G.MAGO], "habilidade em batalha gasta a recarga")
	var m2 := pvp(3, G.MAGO, G.GUERREIRO)
	var rm2 := last_round(submit_all(m2, { 0: { "action": "ability" }, 1: { "action": "defend" } }))
	var mh: Array = rm2["hits"].filter(func(h): return h["kind"] == "magic")
	check(mh[0]["damage"] == Defs.MAGIC_DAMAGE / 2, "defender reduz magia")
	check(m2.apply(0, { "type": "battle_action", "action": "ability" }).error == "on_cooldown", "habilidade em recarga")

	# Golpe Poderoso do guerreiro soma o bônus quando acerta
	var p := pvp(4, G.GUERREIRO, G.LADINO)
	p.heroes[0].attack = 50
	p.heroes[1].speed = -1000
	var rp := last_round(submit_all(p, { 0: { "action": "ability" }, 1: { "action": "flee" } }))
	var sp: int = rp["rolls"]["r0"] + 25
	var tgt: int = 10 + p.heroes[1].defense
	var exp_dmg := maxi(1, 50 - p.heroes[1].defense / 2 + (sp - tgt) / 4) + Defs.POWER_STRIKE_BONUS
	check(rp["hits"][0]["damage"] == exp_dmg, "golpe poderoso: +%d (%d esperado, %d real)" % [Defs.POWER_STRIKE_BONUS, exp_dmg, rp["hits"][0]["damage"]])

	# Esquiva vale só na rodada e anula o dano
	var d := pvp(5, G.GUERREIRO, G.LADINO)
	d.heroes[0].attack = 500
	var hp1: int = d.heroes[1].hp
	var rdg := last_round(submit_all(d, { 1: { "action": "ability" } }))
	check(d.heroes[1].hp == hp1 and rdg["hits"][0]["damage"] == 0, "esquiva anula o golpe")
	check(not d.heroes[1].dodge_round and not d.heroes[1].dodge, "esquiva da batalha só dura uma rodada")
	var hp2: int = d.heroes[1].hp
	submit_all(d, { 1: { "action": "defend" } })
	check(d.heroes[1].hp < hp2 or d.battle == null, "na rodada seguinte já leva dano")

	# Cura do clérigo
	var h := pvp(6, G.CLERIGO, G.GUERREIRO)
	h.heroes[0].max_hp = 200
	h.heroes[0].hp = 100
	h.heroes[0].defense = 100000
	h.heroes[1].attack = 1
	submit_all(h, { 0: { "action": "ability" }, 1: { "action": "defend" } })
	check(h.heroes[0].hp == 100 + Defs.CLERIC_HEAL, "clérigo cura em batalha (%d)" % h.heroes[0].hp)


func test_battle_endings() -> void:
	print("batalha: finais")
	# fuga do atacante
	var s := pvp(1)
	s.heroes[0].speed = 1000
	var ev := submit_all(s, { 0: { "action": "flee" } })
	check(s.battle == null and s.phase == Defs.Phase.ACTION, "fuga encerra a batalha")
	check(s.heroes[0].pos == Vector2i(10, 10) and s.heroes[0].move_points == 0, "atacante volta à origem")
	check(ev.any(func(e): return e["type"] == "flee_attempt" and e["success"]), "evento de fuga")
	check(s.heroes[0].hp == 100000 and s.heroes[1].hp == 100000, "sem dano")
	# fuga do defensor: sai da casa; atacante fica e ainda pode andar
	var t := pvp(2)
	t.heroes[1].speed = 1000
	submit_all(t, { 1: { "action": "flee" } })
	check(t.heroes[1].pos != Vector2i(11, 10) and t.board.is_passable(t.heroes[1].pos), "defensor foge para casa vizinha")
	check(t.heroes[0].pos == Vector2i(11, 10) and t.phase == Defs.Phase.MOVE, "atacante fica e continua o movimento")
	# fuga que falha perde a ação
	var u := pvp(3)
	u.heroes[1].speed = -1000
	u.heroes[0].attack = 500
	var ru := last_round(submit_all(u, { 1: { "action": "flee" } }))
	check(u.battle != null and ru["hits"].size() == 1 and ru["hits"][0]["dst"] == 1, "fuga falha e leva o golpe")

	# morte do defensor: atacante fica na casa
	var d := pvp(4)
	d.heroes[0].attack = 100000
	d.heroes[1].hp = 5
	d.heroes[1].max_hp = 5
	d.heroes[1].trophies = 1
	finish_battle(d)
	check(not d.heroes[1].alive and d.finished and d.winner == 0, "defensor morre, atacante vence (2 jogadores)")
	check(d.items_at(Vector2i(11, 10)).size() == 1, "troféu do morto cai na casa")

	# morte do atacante passa a vez
	var k := GameState.new()
	k.setup(1, 12, [{ "class": G.GUERREIRO }, { "class": G.MAGO }, { "class": G.LADINO }], 43, 25)
	flatten(k)
	k.turn_index = k.turn_order.find(0)
	k.phase = Defs.Phase.MOVE
	place(k, 0, Vector2i(10, 10))
	place(k, 1, Vector2i(11, 10))
	place(k, 2, Vector2i(30, 20))
	k.heroes[0].hp = 1
	k.heroes[0].move_points = 3
	k.heroes[1].attack = 100000
	k.apply(0, { "type": "move", "to": Vector2i(11, 10) })
	finish_battle(k)
	check(k.heroes[0].undead and not k.finished and k.current_player() != 0 and k.phase == Defs.Phase.ROLL, "atacante morto vira morto-vivo e o turno passa")

	# duas mortes na mesma rodada
	var b := pvp(5, G.MAGO, G.MAGO)
	b.heroes[0].hp = 1
	b.heroes[1].hp = 1
	submit_all(b, { 0: { "action": "ability" }, 1: { "action": "ability" } })
	check(not b.heroes[0].alive and not b.heroes[1].alive and b.finished and b.winner == -1, "magos se matam juntos: empate")

	# monstro: ações
	var e := duel(2)
	flatten(e)
	var h := make_current(e, 0, Defs.Phase.MOVE)
	place(e, 0, Vector2i(10, 10))
	place(e, 1, Vector2i(30, 20))
	h.hp = 100000
	h.max_hp = 100000
	var mon := Monster.create(950, "ogro", 1, Vector2i(11, 10))
	mon.hp = 99999
	mon.max_hp = 99999
	e.monsters[950] = mon
	h.move_points = 3
	e.apply(0, { "type": "move", "to": Vector2i(11, 10) })
	check(e.phase == Defs.Phase.BATTLE and e.pending_actors() == [0], "contra monstro só o herói escolhe")
	var fl := e.apply(0, { "type": "battle_action", "action": "flee" })
	check(fl.ok, "tenta fugir do monstro")


func test_potions() -> void:
	print("poções")
	var s := duel()
	flatten(s)
	var h := make_current(s, 0, Defs.Phase.ACTION)
	place(s, 1, Vector2i(30, 20))
	s._put_item(h.pos, Defs.ItemType.VIDA)
	s.apply(0, { "type": "collect" })
	check(h.potions["vida"] == 1, "coletar poção de vida guarda no inventário")
	s._put_item(h.pos, Defs.ItemType.POCAO_FORCA)
	s.apply(0, { "type": "collect" })
	check(h.potions["forca"] == 1, "poção de força")
	h.hp = 40
	var r := s.apply(0, { "type": "use_item", "potion": "vida" })
	check(r.ok and h.hp == 40 + Defs.POTION_HEAL and h.potions["vida"] == 0, "beber poção de vida")
	check(s.apply(0, { "type": "use_item", "potion": "vida" }).error == "no_potion", "sem poção")
	s.apply(0, { "type": "use_item", "potion": "forca" })
	check(h.buff_attack == Defs.POTION_STRENGTH_BONUS and h.buff_rounds == Defs.POTION_STRENGTH_ROUNDS, "poção de força dá bônus")
	# inventário cheio
	h.potions = { "vida": 3, "forca": 0 }
	h.hp = 10
	s._put_item(h.pos, Defs.ItemType.VIDA)
	var cr := s.apply(0, { "type": "collect" })
	check(h.potion_count() == Defs.MAX_POTIONS and h.hp == 10 + Defs.POTION_HEAL, "inventário cheio: poção de vida é bebida na hora")
	check(cr.events.any(func(e): return e["type"] == "inventory_full"), "evento inventory_full")
	# poção em batalha
	var b := pvp(3, G.GUERREIRO, G.GUERREIRO)
	b.heroes[0].max_hp = 200
	b.heroes[0].hp = 50
	b.heroes[0].potions["vida"] = 1
	b.heroes[1].attack = 1
	b.heroes[0].defense = 100000
	submit_all(b, { 0: { "action": "item", "potion": "vida" }, 1: { "action": "defend" } })
	check(b.heroes[0].hp == 50 + Defs.POTION_HEAL and b.heroes[0].potions["vida"] == 0, "poção de vida em batalha")
	check(b.apply(0, { "type": "battle_action", "action": "item", "potion": "vida" }).error == "no_potion", "sem poção na batalha")
	# força aumenta o dano e dura rodadas
	var f := pvp(4, G.GUERREIRO, G.GUERREIRO)
	f.heroes[0].attack = 10
	f.heroes[0].potions["forca"] = 1
	submit_all(f, { 0: { "action": "item", "potion": "forca" } })
	check(f.heroes[0].buff_attack == Defs.POTION_STRENGTH_BONUS and f.heroes[0].buff_rounds == Defs.POTION_STRENGTH_ROUNDS - 1, "força: rodada de uso conta")
	finish_battle(f)
	check(f.heroes[0].buff_rounds == 0, "força expira")


func test_dodge() -> void:
	print("Esquiva")
	var s := duel()
	flatten(s)
	var t := make_current(s, 0, Defs.Phase.ACTION)
	s.heroes[0] = Hero.create(0, "L", G.LADINO, t.pos)
	t = s.heroes[0]
	s.apply(0, { "type": "ability" })
	check(t.dodge, "esquiva ativa")
	var hp := t.hp
	var ev: Array = []
	check(s._damage(t, 50, "trap", ev) == 0 and t.hp == hp, "dano ignorado")
	s.apply(0, { "type": "end_turn" })
	s.apply(1, { "type": "end_turn" })
	check(not t.dodge, "esquiva termina no início do próximo turno do dono")


func test_death_and_victory() -> void:
	print("morte e vitória por sobrevivência")
	var s := duel()
	flatten(s)
	var a := make_current(s, 0, Defs.Phase.ACTION)
	var d: Hero = s.heroes[1]
	d.trophies = 2
	d.pos = Vector2i(15, 15)
	var ev: Array = []
	s._damage(d, 9999, "test", ev)
	check(not d.alive, "morreu")
	check(s.items_at(Vector2i(15, 15)).size() == 2, "troféus caem no chão")
	check(s.finished and s.winner == 0, "último vivo vence")
	check(a.alive, "vencedor vivo")
	check(not s.apply(0, { "type": "end_turn" }).ok, "sem ações após o fim")
	# morte fora da coleta já remove o herói (bug do Python)
	var s2 := duel()
	flatten(s2)
	var h := make_current(s2, 0, Defs.Phase.MOVE)
	place(s2, 0, Vector2i(10, 10))
	place(s2, 1, Vector2i(30, 20))
	s2.board.set_terrain(Vector2i(11, 10), Defs.Terrain.LAVA)
	h.hp = 3
	h.move_points = 3
	s2.apply(0, { "type": "move", "to": Vector2i(11, 10) })
	check(not h.alive and s2.finished and s2.winner == 1, "morrer na lava elimina na hora")
	# empate: todos morrem
	var s3 := duel()
	var e3: Array = []
	s3._damage(s3.heroes[0], 9999, "x", e3)
	check(s3.finished and s3.winner == 1, "um morre, outro vence")


func test_trophy_victory() -> void:
	print("troféus")
	var s := duel()
	flatten(s)
	var h := make_current(s, 0, Defs.Phase.ACTION)
	h.trophies = s.trophies_total - 1
	s._put_item(h.pos, Defs.ItemType.TESOURO)
	var res := s.apply(0, { "type": "collect" })
	check(res.ok and s.finished and s.winner == 0, "juntar todos os troféus vence")
	# troféus divididos não vencem
	var t := duel()
	flatten(t)
	var h2 := make_current(t, 0, Defs.Phase.ACTION)
	h2.trophies = t.trophies_total - 2
	t.heroes[1].trophies = 1
	t._put_item(h2.pos, Defs.ItemType.TESOURO)
	t.apply(0, { "type": "collect" })
	check(not t.finished, "com troféu na mão do rival ninguém ganha por troféus")
	# matar o portador devolve o troféu ao chão
	var d: Hero = t.heroes[1]
	d.pos = Vector2i(15, 15)
	t._damage(d, 9999, "x", [], h2)
	check(t.items_at(Vector2i(15, 15)).size() == 1 and t.finished and t.winner == 0, "troféu cai ao morrer e último vivo vence")


func test_abilities() -> void:
	print("habilidades")
	var s := duel(1, G.MAGO, G.GUERREIRO)
	flatten(s)
	var m := make_current(s, 0, Defs.Phase.ACTION)
	place(s, 0, Vector2i(10, 10))
	place(s, 1, Vector2i(13, 10))
	var hp: int = s.heroes[1].hp
	check(s.apply(0, { "type": "ability", "target": 1 }).ok, "mago acerta em linha a 3 células")
	check(s.heroes[1].hp == hp - Defs.MAGIC_DAMAGE, "dano mágico 15")
	m.cooldown = 0
	place(s, 1, Vector2i(14, 10))
	check(s.apply(0, { "type": "ability", "target": 1 }).error == "out_of_range", "fora de alcance")
	place(s, 1, Vector2i(12, 11))
	check(s.apply(0, { "type": "ability", "target": 1 }).error == "out_of_range", "fora da linha")
	check(s.apply(0, { "type": "ability", "target": 0 }).error == "invalid_target", "não pode mirar em si")
	check(m.cooldown == 0, "falha não gasta cooldown")

	var c := duel(1, G.CLERIGO, G.MAGO)
	var ch := make_current(c, 0, Defs.Phase.ACTION)
	ch.hp = 50
	c.apply(0, { "type": "ability" })
	check(ch.hp == 50 + Defs.CLERIC_HEAL, "clérigo cura")
	var c2 := duel(1, G.CLERIGO, G.MAGO)
	var ch2 := make_current(c2, 0, Defs.Phase.ACTION)
	ch2.hp = ch2.max_hp - 5
	c2.apply(0, { "type": "ability" })
	check(ch2.hp == ch2.max_hp, "cura não passa do máximo")


func test_cooldown() -> void:
	print("cooldown em turnos")
	var s := duel(1, G.CLERIGO, G.MAGO)
	var h := make_current(s, 0, Defs.Phase.ACTION)
	check(s.apply(0, { "type": "ability" }).ok, "usa")
	s.phase = Defs.Phase.ACTION
	check(s.apply(0, { "type": "ability" }).error == "on_cooldown", "bloqueada em recarga")
	s.apply(0, { "type": "end_turn" })
	s.apply(1, { "type": "end_turn" })
	s.phase = Defs.Phase.ACTION
	check(s.apply(0, { "type": "ability" }).error == "on_cooldown", "ainda em recarga (1 turno)")
	s.apply(0, { "type": "end_turn" })
	s.apply(1, { "type": "end_turn" })
	s.apply(0, { "type": "end_turn" })
	s.apply(1, { "type": "end_turn" })
	s.phase = Defs.Phase.ACTION
	check(s.turn_order[s.turn_index] == 0, "volta a vez do clérigo")
	check(s.apply(0, { "type": "ability" }).ok, "liberada após recarga")


func test_cards() -> void:
	print("cartas")
	var s := duel()
	flatten(s)
	var h := make_current(s, 0, Defs.Phase.ACTION)
	place(s, 1, Vector2i(30, 20))
	h.hp = 50
	var ev: Array = []
	var skip := false
	# percorre todo o baralho forçando cada carta
	for card in Cards.DECK:
		var before_hp := h.hp
		var before_xp := h.xp
		var before_pos := h.pos
		match card["effect"]:
			"heal":
				h.heal(card["value"])
				check(h.hp > before_hp, "heal aplica")
			"damage":
				s._damage(h, card["value"], "card", ev)
				check(h.hp == before_hp - card["value"], "damage aplica")
				h.hp = 50
			"xp":
				s._add_xp(h, card["value"], ev)
				check(h.xp == before_xp + card["value"] or h.level > 1, "carta de XP")
			"teleport":
				h.pos = s._random_free_cell()
				check(s.board.main_cells.has(h.pos), "teleporte cai em célula jogável")
			"skip_turn":
				skip = true
	check(skip, "baralho tem carta de perder turno")
	# perder turno passa a vez
	var s2 := duel()
	flatten(s2)
	make_current(s2, 0, Defs.Phase.ACTION)
	var fed := false
	for sd in 200:
		var t := duel(sd)
		flatten(t)
		var c := make_current(t, 0, Defs.Phase.ACTION)
		place(t, 1, Vector2i(30, 20))
		t._put_item(c.pos, Defs.ItemType.CARTA)
		var res := t.apply(0, { "type": "collect" })
		for e in res.events:
			if e["type"] == "card_drawn" and e["effect"] == "skip_turn":
				check(t.current_player() == 1, "carta de perder turno passa a vez")
				fed = true
		if fed:
			break
	check(fed, "algum sorteio caiu em perder turno")


func test_turn_rules() -> void:
	print("regras de turno")
	var s := duel()
	var cur := s.current_player()
	var other := 1 - cur
	check(s.apply(other, { "type": "roll" }).error == "not_your_turn", "fora da vez")
	check(s.apply(cur, { "type": "move", "to": Vector2i(0, 0) }).error == "wrong_phase", "mover antes de rolar")
	check(s.apply(cur, { "type": "roll" }).ok, "rola")
	check(s.apply(cur, { "type": "roll" }).error == "wrong_phase", "não rola duas vezes")
	var h: Hero = s.heroes[cur]
	check(h.move_points >= 1, "dado dá ao menos 1 ponto")
	check(s.apply(cur, { "type": "move", "to": Vector2i(-5, -5) }).error == "unreachable", "destino inválido")
	check(s.apply(cur, { "type": "collect" }).error == "wrong_phase", "coletar só na fase de ação")
	s.timeout()
	check(s.current_player() == other and s.phase == Defs.Phase.ROLL, "timeout passa a vez")
	# turno pula heróis mortos
	var t := GameState.new()
	t.setup(2, 12, [{ "class": G.GUERREIRO }, { "class": G.MAGO }, { "class": G.LADINO }], 43, 25)
	var order := t.turn_order.duplicate()
	t.heroes[order[1]].alive = false
	t.apply(order[0], { "type": "end_turn" })
	check(t.current_player() == order[2], "pula morto")
	# limite de turnos
	var u := duel()
	u.max_turns = 3
	for i in 5:
		if not u.finished:
			u.apply(u.current_player(), { "type": "end_turn" })
	check(u.finished, "limite de turnos encerra a partida")


func test_levels() -> void:
	print("níveis e XP")
	var s := duel(1, G.GUERREIRO, G.MAGO)
	var h: Hero = s.heroes[0]
	var ev: Array = []
	var hp0 := h.max_hp
	s._add_xp(h, Defs.XP_THRESHOLDS[2] - 1, ev)
	check(h.level == 1, "um XP antes do nível 2 continua no nível 1")
	s._add_xp(h, 1, ev)
	check(h.level == 2 and h.max_hp == hp0 + 15 and h.attack == 12 and h.defense == 6, "nível 2 do guerreiro: +15 vida +2 atk +1 def")
	check(ev.any(func(e): return e["type"] == "level_up"), "evento level_up")
	s._add_xp(h, 5000, ev)
	check(h.level == Defs.MAX_LEVEL, "nível máximo %d" % Defs.MAX_LEVEL)
	var xp := h.xp
	s._add_xp(h, 100, ev)
	check(h.xp == xp, "XP não acumula no nível máximo")
	var m: Hero = s.heroes[1]
	var mage_atk := m.attack
	s._add_xp(m, Defs.XP_THRESHOLDS[2], ev)
	check(m.attack == mage_atk + 3, "mago ganha +3 de ataque")
	# subir de nível cura parte da vida
	var gs := duel(1, G.CLERIGO, G.MAGO)
	var c: Hero = gs.heroes[0]
	c.hp = 10
	gs._add_xp(c, Defs.XP_THRESHOLDS[2], [])
	check(c.hp > 10, "level up cura")
	# escala das habilidades
	var a := duel(1, G.MAGO, G.GUERREIRO)
	flatten(a)
	var mage := make_current(a, 0, Defs.Phase.ACTION)
	mage.level = 3
	place(a, 0, Vector2i(10, 10))
	place(a, 1, Vector2i(12, 10))
	var hp: int = a.heroes[1].hp
	a.apply(0, { "type": "ability", "target": 1 })
	check(a.heroes[1].hp == hp - (Defs.MAGIC_DAMAGE + 2 * Defs.MAGIC_DAMAGE_PER_LEVEL), "ataque mágico escala com o nível")
	# matar herói dá XP
	var k := duel()
	flatten(k)
	var killer: Hero = k.heroes[0]
	var xp_before := killer.xp
	k._damage(k.heroes[1], 9999, "x", [], killer)
	check(killer.xp == xp_before + Defs.XP_KILL_HERO_BASE + Defs.XP_KILL_HERO_PER_LEVEL, "XP por matar herói")
	# ladino sobe de nível: esquiva recarrega mais rápido
	var l := duel(1, G.LADINO, G.MAGO)
	var lad := make_current(l, 0, Defs.Phase.ACTION)
	lad.level = Defs.DODGE_COOLDOWN_LEVEL
	l.apply(0, { "type": "ability" })
	check(lad.cooldown == Defs.ABILITY_COOLDOWN[G.LADINO] - 1, "esquiva recarrega 1 turno mais rápido")


func test_monsters() -> void:
	print("monstros")
	var s := GameState.new()
	s.setup(11, 12, [{ "class": G.GUERREIRO }, { "class": G.MAGO }])
	check(s.monsters.size() == Defs.MONSTERS_ON_MAP, "monstros iniciais")
	for id in s.monsters:
		var m: Monster = s.monsters[id]
		check(not s.board.is_border(m.pos) and s.board.main_cells.has(m.pos), "monstro em célula jogável")
		for hid in s.heroes:
			check(s.heroes[hid].pos != m.pos, "monstro não nasce em cima de herói")
	var og := Monster.create(0, "ogro", 3, Vector2i.ZERO)
	check(og.max_hp == 68 and og.attack == 18 and og.xp == 60, "ogro nível 3 = base x1.5 (%d/%d/%d)" % [og.max_hp, og.attack, og.xp])

	# matar monstro
	var d := duel(2)
	flatten(d)
	var h := make_current(d, 0, Defs.Phase.MOVE)
	place(d, 0, Vector2i(10, 10))
	place(d, 1, Vector2i(30, 20))
	var weak := Monster.create(900, "slime", 1, Vector2i(11, 10))
	weak.hp = 1
	d.monsters[900] = weak
	h.move_points = 3
	h.attack = 1000
	var res := d.apply(0, { "type": "move", "to": Vector2i(11, 10) })
	res.events.append_array(finish_battle(d))
	check(res.ok and not d.monsters.has(900), "monstro derrotado some")
	check(h.pos == Vector2i(11, 10) and h.alive, "herói ocupa a casa")
	check(h.xp == weak.xp or h.level > 1, "herói ganhou XP")
	check(d.monsters.size() == Defs.MONSTERS_ON_MAP, "monstro reaparece")
	check(res.events.any(func(e): return e["type"] == "monster_killed"), "evento monster_killed")

	# monstro forte: herói recua
	var e := duel(3)
	flatten(e)
	var h2 := make_current(e, 0, Defs.Phase.MOVE)
	place(e, 0, Vector2i(10, 10))
	place(e, 1, Vector2i(30, 20))
	var tank := Monster.create(901, "ogro", 1, Vector2i(11, 10))
	tank.hp = 99999
	tank.max_hp = 99999
	e.monsters[901] = tank
	h2.move_points = 3
	h2.hp = 100000
	h2.max_hp = 100000
	e.apply(0, { "type": "move", "to": Vector2i(11, 10) })
	finish_battle(e)
	check(e.monsters.has(901), "monstro sobrevive")
	check(h2.pos == Vector2i(10, 10) and h2.move_points == 0 and e.phase == Defs.Phase.ACTION, "herói recua e fica sem movimento")

	# monstro bloqueia passagem mas pode ser alvo
	var f := duel(4)
	flatten(f)
	var h3 := make_current(f, 0, Defs.Phase.MOVE)
	place(f, 0, Vector2i(10, 10))
	place(f, 1, Vector2i(30, 20))
	f.monsters[902] = Monster.create(902, "slime", 1, Vector2i(11, 10))
	h3.move_points = 6
	var reach := f.reachable(h3)
	check(reach.has(Vector2i(11, 10)), "monstro é destino válido")
	check(reach.get(Vector2i(12, 10)) == 4, "contorna o monstro (custo 4, não 2)")

	# herói morre para o monstro
	var g := duel(5)
	flatten(g)
	var h4 := make_current(g, 0, Defs.Phase.MOVE)
	place(g, 0, Vector2i(10, 10))
	place(g, 1, Vector2i(30, 20))
	var killer := Monster.create(903, "ogro", 1, Vector2i(11, 10))
	killer.attack = 9999
	killer.defense = 9999
	g.monsters[903] = killer
	h4.hp = 5
	h4.move_points = 3
	g.apply(0, { "type": "move", "to": Vector2i(11, 10) })
	finish_battle(g)
	check(not h4.alive and g.finished and g.winner == 1, "morrer para monstro elimina o herói")


func test_bot_games() -> void:
	print("partidas completas só com bots")
	var finished_by_win := 0
	var kills := 0
	var level_ups := 0
	var by_trophies := 0
	var total_turns := 0
	var games := 0
	var classes := [G.GUERREIRO, G.MAGO, G.LADINO, G.CLERIGO]
	for map_id in range(1, 16):
		for sd in 4:
			var s := GameState.new()
			s.max_turns = 800
			var players := []
			for i in 2 + (sd % 3):
				players.append({ "class": classes[(i + sd) % 4] })
			s.setup(map_id * 100 + sd, map_id, players)
			var steps := 0
			var ok := true
			while not s.finished and steps < 50000:
				steps += 1
				var pid: int = s.pending_actors()[0]
				var res := s.apply(pid, Bot.choose(s, pid))
				for e in res.events:
					if e["type"] == "monster_killed": kills += 1
					elif e["type"] == "level_up": level_ups += 1
				if not res.ok:
					check(false, "bot gerou ação inválida (mapa %d seed %d): %s" % [map_id, sd, res.error])
					ok = false
					break
				if not _invariants(s):
					ok = false
					break
			games += 1
			total_turns += s.turn_number
			if ok:
				check(s.finished, "mapa %d seed %d terminou" % [map_id, sd])
			if s.winner != -1:
				finished_by_win += 1
	print("  %d partidas, %d com vencedor, média %d turnos totais, %.1f monstros e %.1f level-ups por partida" % [games, finished_by_win, total_turns / games, float(kills) / games, float(level_ups) / games])


func _invariants(s: GameState) -> bool:
	var count := 0
	for k in s.items:
		count += s.items[k].size()
		if not s.board.is_passable(k):
			check(false, "item em célula intransponível")
			return false
	for c in s.traps:
		if not s.board.is_passable(c):
			check(false, "armadilha em célula intransponível")
			return false
	var trophies := 0
	for k in s.items:
		for it in s.items[k]:
			if it["type"] == Defs.ItemType.TESOURO: trophies += 1
	for id in s.heroes:
		trophies += s.heroes[id].trophies
	if trophies != s.trophies_total:
		check(false, "troféus não conservados: %d/%d" % [trophies, s.trophies_total])
		return false
	for id in s.heroes:
		var h: Hero = s.heroes[id]
		if h.undead and (h.trophies > 0 or not h.alive):
			check(false, "morto-vivo com estado inválido")
			return false
		if h.hp > h.max_hp or h.hp < 0 or (h.alive and h.hp == 0):
			check(false, "hp inválido: %d/%d alive=%s" % [h.hp, h.max_hp, h.alive])
			return false
		if h.alive and not s.board.is_passable(h.pos):
			check(false, "herói em célula intransponível")
			return false
	return true


func three(sd := 1, classes := [G.GUERREIRO, G.MAGO, G.LADINO]) -> GameState:
	var s := GameState.new()
	var players := []
	for c in classes:
		players.append({ "class": c })
	s.setup(sd, 12, players, 43, 25)
	flatten(s)
	return s


func test_equipment() -> void:
	print("equipamentos")
	var s := duel()
	flatten(s)
	var h := make_current(s, 0, Defs.Phase.ACTION)
	place(s, 1, Vector2i(30, 20))
	var base_atk := h.attack
	var base_def := h.defense
	s._put_item(h.pos, Defs.ItemType.EQUIPAMENTO, "espada")
	var r := s.apply(0, { "type": "collect" })
	check(r.ok and h.weapon == "espada", "coletar equipa a arma")
	check(h.atk_total() == base_atk + 4 and h.attack == base_atk, "ataque total soma a arma (base intacta)")
	check(r.events.any(func(e): return e["type"] == "equipped" and e["id"] == "espada"), "evento equipped")
	s._put_item(h.pos, Defs.ItemType.EQUIPAMENTO, "placas")
	s.apply(0, { "type": "collect" })
	check(h.armor == "placas" and h.def_total() == base_def + 6, "armadura soma na defesa")
	check(h.speed_total() == h.speed - 1, "armadura pesada reduz velocidade")
	# trocar devolve o item antigo ao chão
	s._put_item(h.pos, Defs.ItemType.EQUIPAMENTO, "machado")
	s.apply(0, { "type": "collect" })
	check(h.weapon == "machado" and s.items_at(h.pos).size() == 1 and s.items_at(h.pos)[0]["id"] == "espada", "troca deixa a arma antiga no chão")
	# morrer solta o equipamento
	var t := three(2)
	var v: Hero = t.heroes[1]
	v.weapon = "adaga"
	v.armor = "cota"
	v.pos = Vector2i(15, 15)
	t._damage(v, 99999, "x", [], null)
	check(t.items_at(Vector2i(15, 15)).size() == 2 and v.weapon == "" and v.armor == "", "morto solta arma e armadura")
	# o morto-vivo volta sem equipamento
	check(v.atk_total() == v.attack, "morto-vivo sem equipamento")
	# efeito real na batalha: armadura reduz dano contra-ataque
	var dmg_plain := 0
	var dmg_armor := 0
	for sd in 40:
		for armored in [false, true]:
			var b := pvp(sd, G.GUERREIRO, G.GUERREIRO)
			b.heroes[1].attack = 40
			if armored:
				b.heroes[0].armor = "placas"
			var rr := last_round(submit_all(b, { 0: { "action": "defend" } }))
			for hit in rr["hits"]:
				if hit["dst"] == 0 and hit["damage"] > 0:
					if armored: dmg_armor += hit["damage"]
					else: dmg_plain += hit["damage"]
	check(dmg_armor < dmg_plain, "armadura reduz o dano recebido (%d < %d)" % [dmg_armor, dmg_plain])
	# velocidade no dado de movimento
	var m := duel(5)
	var f1: Hero = m.heroes[m.current_player()]
	f1.weapon = "adaga"
	var m2 := duel(5)
	m.apply(m.current_player(), { "type": "roll" })
	m2.apply(m2.current_player(), { "type": "roll" })
	check(f1.move_points == m2.heroes[m2.current_player()].move_points + 1, "adaga dá +1 de movimento")
	# monstro derrotado pode largar equipamento
	var seen := false
	for sd in 400:
		var g := duel(sd)
		var ev: Array = []
		g._drop_loot(Vector2i(10, 10), ev)
		for it in g.items_at(Vector2i(10, 10)):
			if it["type"] == Defs.ItemType.EQUIPAMENTO and Defs.EQUIPMENT.has(it["id"]):
				seen = true
	check(seen, "monstros largam equipamentos")


func test_traps() -> void:
	print("armadilhas armadas")
	var s := three(1, [G.GUERREIRO, G.MAGO, G.LADINO])
	var a: Hero = s.heroes[0]
	s.turn_index = s.turn_order.find(0)
	s.phase = Defs.Phase.ACTION
	place(s, 0, Vector2i(10, 10))
	place(s, 1, Vector2i(30, 20))
	place(s, 2, Vector2i(35, 3))
	check(s.apply(0, { "type": "set_trap" }).error == "no_trap_kit", "sem kit não arma")
	a.traps = 2
	var r := s.apply(0, { "type": "set_trap" })
	check(r.ok and s.traps.has(Vector2i(10, 10)) and a.traps == 1, "arma e gasta o kit")
	check(s.apply(0, { "type": "set_trap" }).error == "trap_here", "uma por casa")
	s.phase = Defs.Phase.MOVE
	check(s.apply(0, { "type": "set_trap" }).error == "wrong_phase", "só na fase de ação")
	# dono é imune
	s.phase = Defs.Phase.MOVE
	a.move_points = 4
	place(s, 0, Vector2i(10, 11))
	s.apply(0, { "type": "move", "to": Vector2i(10, 10) })
	check(s.traps.has(Vector2i(10, 10)) and a.hp == a.max_hp, "dono pisa sem efeito")
	# outro herói cai: dano, perde movimento, consome a armadilha
	var b: Hero = s.heroes[1]
	place(s, 0, Vector2i(20, 20))
	s.turn_index = s.turn_order.find(1)
	s.phase = Defs.Phase.MOVE
	place(s, 1, Vector2i(10, 12))
	b.move_points = 5
	var hp := b.hp
	var rb := s.apply(1, { "type": "move", "to": Vector2i(10, 10) })
	check(b.hp == hp - Defs.TRAP_DAMAGE, "armadilha causa %d de dano" % Defs.TRAP_DAMAGE)
	check(b.move_points == 0 and s.phase == Defs.Phase.ACTION, "perde o resto do movimento")
	check(not s.traps.has(Vector2i(10, 10)), "armadilha é consumida")
	check(rb.events.any(func(e): return e["type"] == "trap_triggered" and e["owner"] == 0), "evento trap_triggered")
	# ladino desarma e recupera o kit
	var s2 := three(2, [G.GUERREIRO, G.MAGO, G.LADINO])
	s2.traps[Vector2i(10, 10)] = { "owner": 0 }
	var lad: Hero = s2.heroes[2]
	s2.turn_index = s2.turn_order.find(2)
	s2.phase = Defs.Phase.MOVE
	place(s2, 0, Vector2i(30, 20))
	place(s2, 1, Vector2i(35, 3))
	place(s2, 2, Vector2i(10, 12))
	lad.move_points = 4
	var lhp := lad.hp
	var rl := s2.apply(2, { "type": "move", "to": Vector2i(10, 10) })
	check(lad.hp == lhp and lad.traps == 1 and not s2.traps.has(Vector2i(10, 10)), "ladino desarma sem dano e ganha o kit")
	check(rl.events.any(func(e): return e["type"] == "trap_disarmed"), "evento trap_disarmed")
	check(s2.phase == Defs.Phase.MOVE or lad.move_points > 0, "ladino segue andando")
	# morto-vivo também cai
	var s3 := three(3)
	s3.traps[Vector2i(10, 10)] = { "owner": 1 }
	var und: Hero = s3.heroes[0]
	und.undead = true
	s3.turn_index = s3.turn_order.find(0)
	s3.phase = Defs.Phase.MOVE
	place(s3, 0, Vector2i(10, 12))
	place(s3, 1, Vector2i(30, 20))
	place(s3, 2, Vector2i(35, 3))
	und.move_points = 4
	var uhp := und.hp
	s3.apply(0, { "type": "move", "to": Vector2i(10, 10) })
	check(und.hp == uhp - Defs.TRAP_DAMAGE, "morto-vivo também sofre")
	check(not und.undead or und.alive, "estado consistente")
	var s4 := three(4)
	s4.heroes[0].undead = true
	s4.heroes[0].traps = 1
	s4.turn_index = s4.turn_order.find(0)
	s4.phase = Defs.Phase.ACTION
	check(s4.apply(0, { "type": "set_trap" }).error == "undead_cannot_trap", "morto-vivo não arma")
	# limite de armadilhas ativas
	var s5 := three(5)
	s5.turn_index = s5.turn_order.find(0)
	s5.phase = Defs.Phase.ACTION
	s5.heroes[0].traps = 2
	for i in Defs.MAX_ACTIVE_TRAPS:
		s5.traps[Vector2i(i, 0)] = { "owner": 0 }
	check(s5.apply(0, { "type": "set_trap" }).error == "too_many_traps", "limite de armadilhas ativas")
	# kit na mochila: limite e coleta
	var s6 := three(6)
	var k: Hero = s6.heroes[0]
	s6.turn_index = s6.turn_order.find(0)
	s6.phase = Defs.Phase.ACTION
	s6._put_item(k.pos, Defs.ItemType.KIT_ARMADILHA)
	s6.apply(0, { "type": "collect" })
	check(k.traps == 1, "coletar kit")
	k.traps = Defs.MAX_TRAP_KITS
	s6._put_item(k.pos, Defs.ItemType.KIT_ARMADILHA)
	s6.apply(0, { "type": "collect" })
	check(k.traps == Defs.MAX_TRAP_KITS, "mochila cheia: kit se perde")
	# fechamento do mapa remove armadilhas do anel
	var s7 := three(7)
	for y in s7.board.height:
		for x in s7.board.width:
			var p := Vector2i(x, y)
			if not s7.board.main_cells.has(p):
				s7.board.main_cells.append(p)
	s7.traps[Vector2i(0, 5)] = { "owner": 0 }
	s7.traps[Vector2i(10, 10)] = { "owner": 0 }
	s7._close_ring([])
	check(not s7.traps.has(Vector2i(0, 5)) and s7.traps.has(Vector2i(10, 10)), "anel que fecha leva as armadilhas dele")


func test_undead() -> void:
	print("morto-vivo")
	var s := three()
	var victim: Hero = s.heroes[1]
	victim.level = 3
	victim.trophies = 1
	victim.pos = Vector2i(15, 15)
	var max_before := victim.max_hp
	var ev: Array = []
	s._damage(victim, 99999, "x", ev, s.heroes[0])
	check(victim.alive and victim.undead and not victim.is_living(), "morto vira morto-vivo")
	check(victim.max_hp == max_before / 2 and victim.hp == victim.max_hp, "volta com metade da vida")
	check(victim.level == 3, "mantém o nível")
	check(victim.trophies == 0 and s.items_at(Vector2i(15, 15)).size() == 1, "troféu fica no chão")
	check(ev.any(func(e): return e["type"] == "undead_risen"), "evento undead_risen")
	check(not s.finished, "partida segue com 2 vivos")
	check(s.living_heroes().size() == 2 and s.alive_heroes().size() == 3, "contagem de vivos x corpos")
	check(s.heroes[0].xp == Defs.XP_KILL_HERO_BASE + Defs.XP_KILL_HERO_PER_LEVEL * 3, "assassino ganha XP")

	# morto-vivo joga o turno, mas não coleta
	s.turn_index = s.turn_order.find(1)
	s.phase = Defs.Phase.ACTION
	s._put_item(victim.pos, Defs.ItemType.VIDA)
	check(s.apply(1, { "type": "collect" }).error == "undead_cannot_collect", "não coleta itens")

	# imune a terreno, bloqueado por monstros
	var t := three(2)
	var u: Hero = t.heroes[1]
	u.undead = true
	t.turn_index = t.turn_order.find(1)
	t.phase = Defs.Phase.MOVE
	place(t, 0, Vector2i(30, 20))
	place(t, 1, Vector2i(10, 10))
	place(t, 2, Vector2i(35, 3))
	t.board.set_terrain(Vector2i(11, 10), Defs.Terrain.LAVA)
	t.monsters[800] = Monster.create(800, "slime", 1, Vector2i(9, 10))
	u.move_points = 3
	check(not t.reachable(u).has(Vector2i(9, 10)), "morto-vivo não entra em casa de monstro")
	var hp := u.hp
	t.apply(1, { "type": "move", "to": Vector2i(11, 10) })
	check(u.hp == hp, "morto-vivo ignora lava")

	# morto-vivo ataca herói vivo
	var a := three(3)
	var und: Hero = a.heroes[1]
	und.undead = true
	a.turn_index = a.turn_order.find(1)
	a.phase = Defs.Phase.MOVE
	place(a, 0, Vector2i(11, 10))
	place(a, 1, Vector2i(10, 10))
	place(a, 2, Vector2i(35, 3))
	und.move_points = 3
	a.apply(1, { "type": "move", "to": Vector2i(11, 10) })
	check(a.phase == Defs.Phase.BATTLE and a.battle.attacker == und, "morto-vivo inicia batalha contra vivo")

	# vivo ataca morto-vivo; morto-vivo derrotado sai de vez e dá XP
	var b := three(4)
	var ud: Hero = b.heroes[1]
	ud.undead = true
	ud.hp = 5
	ud.max_hp = 5
	ud.level = 2
	b.turn_index = b.turn_order.find(0)
	b.phase = Defs.Phase.MOVE
	place(b, 0, Vector2i(10, 10))
	place(b, 1, Vector2i(11, 10))
	place(b, 2, Vector2i(35, 3))
	b.heroes[0].attack = 100000
	b.heroes[0].move_points = 3
	b.apply(0, { "type": "move", "to": Vector2i(11, 10) })
	finish_battle(b)
	check(not ud.alive and not ud.undead, "morto-vivo derrotado sai de vez")
	check(b.heroes[0].xp >= Defs.XP_KILL_UNDEAD_BASE + Defs.XP_KILL_UNDEAD_PER_LEVEL * 2, "XP por derrotar morto-vivo")
	check(not b.finished, "partida continua (2 vivos)")
	check(ud.hp == 0 or not ud.alive, "não ressuscita de novo")

	# partida acaba quando sobra 1 vivo, mesmo com mortos-vivos em jogo
	var c := three(5)
	c._damage(c.heroes[1], 99999, "x", [], null)
	check(not c.finished and c.heroes[1].undead, "1ª morte: continua")
	c._damage(c.heroes[2], 99999, "x", [], null)
	check(c.finished and c.winner == 0, "2ª morte: o único vivo vence")
	check(not c.heroes[2].undead, "sem levantar mortos-vivos depois do fim")

	# mortos-vivos entram na ordem de turnos
	var d := three(6)
	d._damage(d.heroes[1], 99999, "x", [], null)
	var seen := {}
	for i in 6:
		seen[d.current_player()] = true
		d.timeout()
	check(seen.has(1), "morto-vivo recebe turnos")

	# morrer no próprio turno (lava) vira morto-vivo e passa o turno
	var e := three(7)
	e.turn_index = e.turn_order.find(0)
	e.phase = Defs.Phase.MOVE
	place(e, 0, Vector2i(10, 10))
	place(e, 1, Vector2i(30, 20))
	place(e, 2, Vector2i(35, 3))
	e.board.set_terrain(Vector2i(11, 10), Defs.Terrain.LAVA)
	e.heroes[0].hp = 3
	e.heroes[0].move_points = 3
	e.apply(0, { "type": "move", "to": Vector2i(11, 10) })
	check(e.heroes[0].undead and e.current_player() != 0 and e.phase == Defs.Phase.ROLL, "morte por lava: vira morto-vivo e o turno passa")

	# cadeia: morto-vivo mata um vivo, que também vira morto-vivo
	var f := three(8, [G.GUERREIRO, G.MAGO, G.LADINO, G.CLERIGO])
	f.heroes[3].undead = true
	f.heroes[1].hp = 1
	f._damage(f.heroes[1], 50, "x", [], f.heroes[3])
	check(f.heroes[1].undead and f.heroes[3].xp > 0, "vítima do morto-vivo também levanta")

	# morte súbita não machuca morto-vivo
	var g := three(9)
	g._damage(g.heroes[1], 99999, "x", [], null)
	var uhp: int = g.heroes[1].hp
	g._sudden_death([])
	check(g.heroes[1].hp == uhp, "morte súbita só atinge vivos")

	# fechamento do mapa atinge morto-vivo
	var h := three(10)
	h._damage(h.heroes[1], 99999, "x", [], null)
	h.heroes[1].pos = Vector2i(0, 5)
	h.heroes[1].max_hp = 100
	h.heroes[1].hp = 100
	for y in h.board.height:
		for x in h.board.width:
			var p := Vector2i(x, y)
			if not h.board.main_cells.has(p):
				h.board.main_cells.append(p)
	h._close_ring([])
	check(h.heroes[1].hp == 100 - Defs.CLOSE_DAMAGE, "fechamento do mapa fere morto-vivo")


func test_closing_map() -> void:
	print("mapa que fecha")
	var b := Board.new(21, 13)
	check(b.ring_of(Vector2i(0, 5)) == 0 and b.ring_of(Vector2i(1, 1)) == 1 and b.ring_of(Vector2i(10, 6)) == 6, "ring_of")
	check(b.max_rings() == 5, "5 anéis fecham, sobra arena central")

	var s := duel(1, G.GUERREIRO, G.MAGO)
	s.close_start = 2
	s.close_every = 2
	flatten(s)
	for y in s.board.height:
		for x in s.board.width:
			var p := Vector2i(x, y)
			if not s.board.main_cells.has(p) and s.board.terrain_at(p) == Defs.Terrain.PLANICIE:
				s.board.main_cells.append(p)
	# troféu, item comum e herói no anel 0
	var edge := Vector2i(0, 5)
	s._put_item(edge, Defs.ItemType.TESOURO)
	s._put_item(Vector2i(0, 6), Defs.ItemType.VIDA)
	place(s, 0, Vector2i(0, 7))
	place(s, 1, Vector2i(20, 12))
	s.heroes[0].hp = 100
	var order := s.turn_order.duplicate()
	var seen_warning := false
	var closed_event := false
	var hp_before: int = s.heroes[0].hp
	# primeira rodada: nada; ao virar a rodada 2 -> aviso para a rodada 3? close_start=2: fecha na rodada 2
	for i in 4:
		var ev := s.timeout()
		for e in ev:
			if e["type"] == "ring_warning": seen_warning = true
			if e["type"] == "ring_closed": closed_event = true
	check(closed_event, "anel fechou")
	check(s.rings_closed >= 1, "contador de anéis")
	check(s.board.terrain_at(edge) == Defs.Terrain.BLOCO and not s.board.is_passable(edge), "borda virou bloco")
	check(not s.board.main_cells.has(edge), "main_cells atualizado")
	check(s.items_at(Vector2i(0, 6)).is_empty(), "item comum no anel some")
	var trophies := 0
	for k in s.items:
		for it in s.items[k]:
			if it["type"] == Defs.ItemType.TESOURO:
				trophies += 1
				check(s.board.is_passable(k), "troféu realocado para célula aberta")
	check(trophies == 1, "troféu preservado")
	check(s.heroes[0].pos.x >= 1 and s.board.is_passable(s.heroes[0].pos), "herói empurrado para dentro")
	check(s.heroes[0].hp == hp_before - Defs.CLOSE_DAMAGE, "dano de %d ao ser empurrado" % Defs.CLOSE_DAMAGE)
	check(s.monsters.size() == Defs.MONSTERS_ON_MAP, "monstros repostos")

	# aviso vem uma rodada antes
	var w := duel(2, G.GUERREIRO, G.MAGO)
	for h in w.heroes.values():
		h.hp = 100000
		h.max_hp = 100000
	w.close_start = 4
	var warned_round := -1
	var closed_round := -1
	for i in 120:
		for e in w.timeout():
			if e["type"] == "ring_warning" and warned_round == -1: warned_round = w.round_number
			if e["type"] == "ring_closed" and closed_round == -1: closed_round = w.round_number
	check(warned_round == 3 and closed_round == 4, "aviso na rodada 3, fecha na 4 (aviso %d, fecha %d)" % [warned_round, closed_round])
	check(w.rings_closed == w.board.max_rings(), "todos os anéis possíveis fecharam")
	check(w.sudden_rounds > 0, "morte súbita depois do último anel")

	# esquiva não protege do fechamento
	var d := duel(3, G.LADINO, G.MAGO)
	flatten(d)
	var lad: Hero = d.heroes[0]
	lad.dodge = true
	place(d, 0, Vector2i(0, 0))
	var hp0 := lad.hp
	d._damage(lad, 10, "closing", [], null, true)
	check(lad.hp == hp0 - 10, "dano inevitável ignora esquiva")

	# o último herói do anel pode morrer no fechamento
	var k := duel(4)
	k.close_start = 1
	flatten(k)
	k.board.main_cells.clear()
	for y in k.board.height:
		for x in k.board.width:
			k.board.main_cells.append(Vector2i(x, y))
	place(k, 0, Vector2i(0, 0))
	place(k, 1, Vector2i(42, 24))
	k.heroes[0].hp = 5
	k.heroes[1].hp = 5
	k._close_ring([])
	check(k.finished and k.winner == -1, "ambos morrem no fechamento -> empate")


func test_sudden_death_tiebreak() -> void:
	print("morte súbita")
	var s := duel(1)
	flatten(s)
	s.heroes[0].hp = 20
	s.heroes[1].hp = 12
	var ev: Array = []
	s._sudden_death(ev)
	check(s.sudden_rounds == 1 and ev[0]["damage"] == Defs.SUDDEN_DEATH_BASE, "dano base na 1ª rodada")
	check(not s.finished, "ninguém morreu ainda")
	s._sudden_death(ev)
	check(s.heroes[1].alive == false and s.finished and s.winner == 0, "quem tem menos vida cai primeiro")
	var t := duel(1)
	flatten(t)
	t.heroes[0].hp = 8
	t.heroes[1].hp = 6
	t._sudden_death([])
	check(t.finished and t.winner == 0, "caem juntos: vence quem tinha mais vida")
	var u := duel(1)
	u.heroes[0].hp = 7
	u.heroes[1].hp = 7
	u._sudden_death([])
	check(u.finished and u.winner == -1, "empate real sem vencedor")
