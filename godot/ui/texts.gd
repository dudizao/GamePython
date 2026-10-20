class_name Texts
extends RefCounted
## Textos de regras e descrições. Os números vêm de Defs, então a ajuda nunca fica desatualizada.

const CLASS_BLURB := {
	Defs.HeroClass.GUERREIRO: "Muita vida e golpe poderoso.",
	Defs.HeroClass.MAGO: "Magia que ignora defesa.",
	Defs.HeroClass.LADINO: "Rápido, esquiva e contra-golpe.",
	Defs.HeroClass.CLERIGO: "Resistente, com cura.",
}


static func ability_name(c: int) -> String:
	return { Defs.HeroClass.GUERREIRO: "Golpe Poderoso", Defs.HeroClass.MAGO: "Ataque Mágico", Defs.HeroClass.LADINO: "Esquiva", Defs.HeroClass.CLERIGO: "Cura" }[c]


static func ability_desc(c: int) -> String:
	match c:
		Defs.HeroClass.GUERREIRO:
			return "Próximo golpe causa +%d de dano (+%d por nível). Em batalha, ataca já com o bônus." % [Defs.POWER_STRIKE_BONUS, Defs.POWER_STRIKE_PER_LEVEL]
		Defs.HeroClass.MAGO:
			return "%d de dano (+%d por nível) que ignora defesa. Fora de batalha, acerta quem estiver na mesma linha ou coluna a até %d casas." % [Defs.MAGIC_DAMAGE, Defs.MAGIC_DAMAGE_PER_LEVEL, Defs.MAGIC_RANGE]
		Defs.HeroClass.LADINO:
			return "Em batalha: anula o dano da rodada e devolve um contra-golpe a quem tentar acertar. Fora dela: ignora todo dano até o seu próximo turno."
		Defs.HeroClass.CLERIGO:
			return "Recupera %d de vida (+%d por nível)." % [Defs.CLERIC_HEAL, Defs.CLERIC_HEAL_PER_LEVEL]
	return ""


static func item_name(item: Dictionary) -> String:
	match item["type"]:
		Defs.ItemType.TESOURO: return "Troféu"
		Defs.ItemType.VIDA: return "Poção de vida"
		Defs.ItemType.POCAO_FORCA: return "Poção de força"
		Defs.ItemType.CARTA: return "Carta misteriosa"
		Defs.ItemType.ARMADILHA: return "Armadilha"
		Defs.ItemType.KIT_ARMADILHA: return "Kit de armadilha"
		Defs.ItemType.EQUIPAMENTO: return equip_name(item.get("id", ""))
	return "Item"


static func class_stats(c: int) -> String:
	var h := Hero.create(0, "", c, Vector2i.ZERO)
	return "Vida %d · Ataque %d · Defesa %d · Velocidade %d · Recarga %d turnos" % [h.max_hp, h.attack, h.defense, h.speed, Defs.ABILITY_COOLDOWN[c]]


static func equip_name(id: String) -> String:
	if not Defs.EQUIPMENT.has(id):
		return "—"
	var e: Dictionary = Defs.EQUIPMENT[id]
	var bits: Array[String] = []
	if e["atk"] != 0: bits.append("%+d ataque" % e["atk"])
	if e["def"] != 0: bits.append("%+d defesa" % e["def"])
	if e["spd"] != 0: bits.append("%+d velocidade" % e["spd"])
	return "%s (%s)" % [e["name"], ", ".join(bits)]


static func hero_tooltip(h: Hero) -> String:
	return "%s nv%d\nAtaque %d · Defesa %d · Velocidade %d\nArma: %s\nArmadura: %s\nKits de armadilha: %d\n%s: %s" % [
		Defs.CLASS_NAMES[h.hero_class], h.level, h.atk_total(), h.def_total(), h.speed_total(),
		equip_name(h.weapon), equip_name(h.armor), h.traps,
		ability_name(h.hero_class), ability_desc(h.hero_class)]


static func help() -> String:
	var xp := Defs.XP_THRESHOLDS
	return """[font_size=26][color=#ffd23f][b]Como jogar[/b][/color][/font_size]

[color=#ffd23f][b]Objetivo[/b][/color]
Vença juntando [b]todos os %d troféus[/b] do mapa, ou sendo o [b]último herói vivo[/b]. Os troféus são fixos: ninguém repõe. Quem morre solta os troféus no chão.

[color=#ffd23f][b]Seu turno[/b][/color]
1. [b]Role os dados[/b]: vale a média dos dois (arredondada para cima, de 1 a 6), mais o bônus de velocidade. [b]Par[/b] dá +%d de movimento, [b]dois 6[/b] dão +%d; dois 1 (olhos de cobra) não dão nada. São seus pontos de movimento.
2. [b]Mova-se[/b] clicando nas casas azuis. O número é o custo: planície 1, floresta 2, montanha 3. Água não se atravessa.
3. [b]Aja[/b]: colete o item da casa, use a habilidade, beba poções ou passe o turno. Você tem %ds por turno.

[color=#ffd23f][b]Batalha[/b][/color]
Andar até um monstro ou herói inicia uma batalha de até %d rodadas. Em cada rodada [b]todos escolhem ao mesmo tempo[/b]:
• [b]Atacar[/b]: duelo de d20 + ataque/2. Contra quem não ataca, vence se passar de 10 + defesa.
• [b]Defender[/b]: dano pela metade. Se o inimigo errar, você contra-ataca.
• [b]Habilidade[/b]: a da sua classe (veja abaixo). Tem recarga em turnos.
• [b]Poção[/b]: vida (+%d) ou força (+%d de ataque por %d rodadas).
• [b]Fugir[/b]: d20 + velocidade precisa chegar a %d. Se falhar, você perde a ação.
Floresta (+2) e montanha (+3) dão bônus de defesa a quem está na casa. Sem mortes, quem atacou recua.

[color=#ffd23f][b]Monstros e níveis[/b][/color]
Monstros dão XP e às vezes largam poções. Quem sobe de nível ganha vida, ataque e defesa e recupera %d%% da vida. Nível máximo %d (XP: %d, %d, %d, %d).

[color=#ffd23f][b]Itens[/b][/color]
Troféu · Poção de vida · Poção de força · Carta (sorte ou azar) · Armadilha no chão (%d de dano a quem coletar). Você carrega até %d poções.

[color=#ffd23f][b]Equipamentos[/b][/color]
Cada herói tem um slot de [b]arma[/b] (ataque) e um de [b]armadura[/b] (defesa). Coletar equipa o item e deixa o antigo no chão. Os mais fortes são pesados e reduzem a velocidade. Quem morre solta o equipamento. Monstros também largam.

[color=#ffd23f][b]Armadilhas armadas[/b][/color]
Pegue um [b]kit de armadilha[/b] (até %d na mochila) e use [b]Armar[/b] na fase de ação: a armadilha fica escondida na sua casa (no máximo %d ativas). Quem pisar nela (menos você) leva [b]%d de dano[/b] e perde o resto do movimento. O [b]Ladino[/b] enxerga todas as armadilhas e as desarma sem dano, ganhando o kit.

[color=#ffd23f][b]Morto-vivo[/b][/color]
Se você morrer e ainda houver 2 ou mais heróis vivos, volta como [b]morto-vivo[/b] com metade da vida: não coleta itens, ignora lava e só ataca heróis vivos. Se for derrotado de novo, sai de vez. Mortos-vivos nunca vencem.

[color=#ffd23f][b]O mapa fecha[/b][/color]
A partir da rodada %d, a cada %d rodadas, o anel mais externo vira bloco (aviso uma rodada antes). Quem estiver nele é empurrado e leva %d de dano. Depois do último anel começa a [b]morte súbita[/b]: todos perdem vida a cada rodada.

[color=#ffd23f][b]Classes[/b][/color]
%s

[color=#ffd23f][b]Atalhos[/b][/color]
R rolar · E parar de andar · C coletar · Q habilidade · 1/2 poções · T armar armadilha · Espaço passar turno · Esc cancela a mira · F1 ajuda""" % [
		Defs.TROPHIES_TOTAL, Defs.DOUBLES_BONUS, Defs.DOUBLE_SIX_BONUS, Defs.TURN_SECONDS, Defs.BATTLE_MAX_ROUNDS,
		Defs.POTION_HEAL, Defs.POTION_STRENGTH_BONUS, Defs.POTION_STRENGTH_ROUNDS, Defs.FLEE_DC,
		Defs.LEVEL_UP_HEAL_PCT, Defs.MAX_LEVEL, xp[2], xp[3], xp[4], xp[5],
		Defs.ITEM_VALUE[Defs.ItemType.ARMADILHA], Defs.MAX_POTIONS,
		Defs.MAX_TRAP_KITS, Defs.MAX_ACTIVE_TRAPS, Defs.TRAP_DAMAGE,
		Defs.CLOSE_START_ROUND, Defs.CLOSE_EVERY_ROUNDS, Defs.CLOSE_DAMAGE,
		_classes_help()]


static func _classes_help() -> String:
	var out := ""
	for c in Defs.CLASS_NAMES:
		out += "[b]%s[/b] (%s)\n%s: %s\n\n" % [Defs.CLASS_NAMES[c], class_stats(c), ability_name(c), ability_desc(c)]
	return out.strip_edges()
