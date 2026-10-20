class_name EventText
extends RefCounted
## Converte eventos do núcleo em texto (BBCode) para o log e para a janela de batalha.

const ABILITY_NAMES := {
	"forca_extra": "Força Extra", "ataque_magico": "Ataque Mágico", "esquiva": "Esquiva", "cura_pessoal": "Cura Pessoal",
}
const SOURCE_NAMES := {
	"battle": "batalha", "terrain": "o terreno", "trap": "uma armadilha", "magic": "magia", "card": "uma carta",
	"closing": "o mapa fechando", "sudden_death": "a morte súbita", "monster": "um monstro", "player_trap": "uma armadilha armada",
	"storm": "a tempestade", "burn": "queimadura",
}


static func nm(s: GameState, pid: int) -> String:
	if pid < 0 or not s.heroes.has(pid):
		return "?"
	var col := Art.player_color(pid).to_html(false)
	return "[color=#%s][b]%s[/b][/color]" % [col, s.heroes[pid].display_name]


static func describe(e: Dictionary, s: GameState) -> String:
	match e["type"]:
		"round_started":
			return "[color=#8a90a0]— Rodada %d —[/color]" % e["round"]
		"ring_warning":
			return "[color=#ff9f43]⚠ O anel externo vai fechar na próxima rodada![/color]"
		"ring_closed":
			return "[color=#ff6b6b]O anel %d fechou.[/color]" % (e["ring"] + 1)
		"pushed":
			return "%s foi empurrado pelo mapa que fecha." % nm(s, e["player"])
		"sudden_death":
			return "[color=#ff6b6b]MORTE SÚBITA! Todos perdem %d de vida.[/color]" % e["damage"]
		"storm_warning":
			return "[color=#c8a0ff]⛈ Tempestade à vista: a região roxa será atingida na próxima rodada.[/color]"
		"storm_struck":
			return "[color=#c8a0ff]⛈ A tempestade caiu![/color]"
		"round_event_announced":
			return "[color=#8be9fd]◆ Rodada %d: %s (%s).[/color]" % [e["round"], Texts.event_name(e["kind"]), Texts.EVENT_DESCS.get(e["kind"], "")]
		"round_event":
			return "[color=#8be9fd][b]◆ %s![/b][/color]" % Texts.event_name(e["kind"])
		"terrain_changed":
			var what: String = { Defs.Terrain.LAVA: "lava", Defs.Terrain.GELO: "gelo" }.get(e["to"], "novo terreno")
			if e["cause"] == "lava_spread":
				return "[color=#ff9f43]A lava se espalhou.[/color]"
			return "[color=#8a90a0]%d casas viraram %s.[/color]" % [e["cells"].size(), what]
		"slid":
			return "%s escorregou no gelo." % nm(s, e["player"])
		"status_applied":
			var msg: String = { "gelo": "congelou", "queimadura": "está queimando", "prende": "está preso" }.get(e["status"], "foi afetado")
			return "[color=#c8a0ff]%s %s![/color]" % [nm(s, e["player"]), msg]
		"monster_will_revive":
			return "[color=#8a90a0]Os ossos se mexem... ele volta na rodada %d.[/color]" % e["round"]
		"monster_revived":
			return "[color=#e8dfc0]☠ Um esqueleto ressurgiu![/color]"
		"turn_started":
			return "Vez de %s." % nm(s, e["player"])
		"dice_rolled":
			var faces := " e ".join(e["dice"].map(func(d): return str(d))) if e.has("dice") else str(e["roll"])
			var extra := ""
			if e.get("pair", false):
				extra = " [color=#ffd23f](par! +%d)[/color]" % e["bonus"] if e["bonus"] > 0 else " [color=#ff6b6b](olhos de cobra)[/color]"
			if e.get("status", "") == "gelo":
				extra += " [color=#8ecdf0](congelado)[/color]"
			elif e.get("status", "") == "prende":
				extra += " [color=#c8a0ff](preso)[/color]"
			return "%s rolou %s%s: %d pontos de movimento." % [nm(s, e["player"]), faces, extra, e["move_points"]]
		"damage":
			return "%s perdeu [color=#ff6b6b]%d[/color] de vida (%s)." % [nm(s, e["player"]), e["amount"], SOURCE_NAMES.get(e["source"], e["source"])]
		"dodged":
			return "%s esquivou!" % nm(s, e["player"])
		"died":
			if e.get("final", false):
				return "[color=#ff6b6b]%s foi destruído de vez.[/color]" % nm(s, e["player"])
			return "[color=#ff6b6b]%s morreu![/color]" % nm(s, e["player"])
		"undead_risen":
			return "[color=#7be07b]☠ %s voltou como morto-vivo![/color]" % nm(s, e["player"])
		"battle_started":
			if e["kind"] == "monster":
				var m = s.monsters.get(e["monster"])
				return "⚔ %s enfrenta %s!" % [nm(s, e["attacker"]), m.display_name if m != null else "um monstro"]
			return "⚔ %s ataca %s!" % [nm(s, e["attacker"]), nm(s, e["defender"])]
		"battle_actions":
			return ""
		"flee_attempt":
			return "Tentativa de fuga (%d): %s" % [e["roll"], "[color=#5fd38d]conseguiu[/color]" if e["success"] else "[color=#ff6b6b]falhou[/color]"]
		"retreated":
			return "%s recuou." % nm(s, e["player"])
		"fled_to":
			return "%s fugiu para outra casa." % nm(s, e["player"])
		"monster_killed":
			return "[color=#5fd38d]Monstro derrotado![/color]"
		"xp_gained":
			return "%s ganhou [color=#ffd23f]%d XP[/color]." % [nm(s, e["player"]), e["amount"]]
		"level_up":
			return "[color=#ffd23f]★ %s subiu para o nível %d![/color]" % [nm(s, e["player"]), e["level"]]
		"item_collected":
			var names := { Defs.ItemType.TESOURO: "um troféu", Defs.ItemType.VIDA: "uma poção de vida", Defs.ItemType.CARTA: "uma carta", Defs.ItemType.ARMADILHA: "uma armadilha", Defs.ItemType.POCAO_FORCA: "uma poção de força", Defs.ItemType.KIT_ARMADILHA: "um kit de armadilha" }
			if e["item"] == Defs.ItemType.EQUIPAMENTO:
				return ""  # o evento 'equipped' descreve
			return "%s pegou %s." % [nm(s, e["player"]), names.get(e["item"], "um item")]
		"equipped":
			var extra := "" if e["replaced"] == "" else " (deixou %s no chão)" % Defs.EQUIPMENT[e["replaced"]]["name"]
			return "%s equipou [color=#8be9fd]%s[/color]%s." % [nm(s, e["player"]), Texts.equip_name(e["id"]), extra]
		"kit_added":
			return "%s guardou um kit de armadilha." % nm(s, e["player"])
		"trap_set":
			return "%s armou uma armadilha." % nm(s, e["player"])
		"trap_triggered":
			return "[color=#ff9f43]%s caiu na armadilha de %s![/color]" % [nm(s, e["player"]), nm(s, e["owner"])]
		"trap_disarmed":
			return "%s desarmou a armadilha de %s e recuperou o kit." % [nm(s, e["player"]), nm(s, e["owner"])]
		"loot_dropped":
			return "[color=#8a90a0]O monstro largou algo.[/color]"
		"potion_added":
			return "%s guardou uma poção de %s." % [nm(s, e["player"]), "vida" if e["potion"] == "vida" else "força"]
		"potion_used":
			if e["potion"] == "vida":
				return "%s bebeu poção de vida (+%d)." % [nm(s, e["player"]), e.get("healed", 0)]
			return "%s bebeu poção de força." % nm(s, e["player"])
		"inventory_full":
			return "%s está com o inventário cheio." % nm(s, e["player"])
		"card_drawn":
			var col := "5fd38d" if e["kind"] == "SORTE" else "ff6b6b"
			return "[color=#%s]Carta de %s: %s[/color]" % [col, e["kind"].to_lower(), e["text"]]
		"teleported":
			return "%s foi teleportado." % nm(s, e["player"])
		"ability":
			return "%s usou %s." % [nm(s, e["player"]), ABILITY_NAMES.get(e["ability"], e["ability"])]
		"game_over":
			if e["winner"] < 0:
				return "[color=#ffd23f][b]Empate![/b][/color]"
			return "[color=#ffd23f][b]%s venceu a partida![/b][/color]" % nm(s, e["winner"])
	return ""


## Resumo curto de uma rodada de batalha para a janela de batalha.
static func round_summary(e: Dictionary, s: GameState, attacker_id: int, defender_id: int, monster_name: String) -> String:
	var out := ""
	var names: Array[String] = [nm(s, attacker_id), monster_name if defender_id < 0 else nm(s, defender_id)]
	for h in e["hits"]:
		var who: String = names[h["src"]]
		var tgt: String = names[h["dst"]]
		var how: String = { "duel": "venceu o duelo", "attack": "acertou", "magic": "lançou magia em", "counter": "contra-atacou", "riposte": "deu contra-golpe em" }.get(h["kind"], "acertou")
		if h["damage"] > 0:
			out += "%s %s %s: [color=#ff6b6b]-%d[/color]\n" % [who, how, tgt, h["damage"]]
		else:
			out += "%s %s %s, mas não causou dano.\n" % [who, how, tgt]
	if e["hits"].is_empty():
		out = "Ninguém acertou."
	return out
