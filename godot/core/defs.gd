class_name Defs
extends RefCounted
## Enums e constantes de regras. Sem nenhuma dependência de interface.

## BLOCO: célula que já fechou (intransponível), só surge durante a partida.
enum Terrain { PLANICIE, FLORESTA, MONTANHA, AGUA, MASMORRA, LAVA, GELO, BLOCO }
enum HeroClass { GUERREIRO, MAGO, LADINO, CLERIGO }
enum ItemType { TESOURO, ARMADILHA, VIDA, CARTA, POCAO_FORCA, KIT_ARMADILHA, EQUIPAMENTO }
enum Phase { ROLL, MOVE, ACTION, FINISHED, BATTLE }

const MAX_PLAYERS := 4
## Tabuleiro pequeno: partidas rápidas (alvo ~10-15 min).
const BOARD_WIDTH := 21
const BOARD_HEIGHT := 13

## Troféus são um conjunto fixo (sem reposição). Vence quem juntar todos ou eliminar todos os outros.
const TROPHIES_TOTAL := 3
const ITEMS_ON_MAP := 6
const TURN_SECONDS := 35

## Dados de movimento: 1 = um d6; 2 = média dos dois d6, arredondada para cima (1 a 6, menos variação).
const MOVE_DICE := 2
## Par nos dados de movimento: bônus de pontos. Dois 6 valem mais; dois 1 ("olhos de cobra") não dão bônus.
const DOUBLES_BONUS := 1
const DOUBLE_SIX_BONUS := 2

const MOVE_COST := {
	Terrain.PLANICIE: 1,
	Terrain.FLORESTA: 2,
	Terrain.MONTANHA: 3,
	Terrain.MASMORRA: 1,
	Terrain.LAVA: 2,
	Terrain.GELO: 1,
}
## Dano ao terminar movimento na célula.
const TERRAIN_DAMAGE := { Terrain.LAVA: 5, Terrain.GELO: 5 }
## Bônus de defesa de quem defende (está) na célula, em batalha.
const DEFENSE_BONUS := { Terrain.FLORESTA: 2, Terrain.MONTANHA: 3 }

## Itens aleatórios (sem troféus: esses vêm do conjunto fixo).
const ITEM_WEIGHTS := {
	ItemType.VIDA: 16,
	ItemType.POCAO_FORCA: 6,
	ItemType.CARTA: 40,
	ItemType.ARMADILHA: 14,
	ItemType.EQUIPAMENTO: 16,
	ItemType.KIT_ARMADILHA: 8,
}
const ITEM_VALUE := {
	ItemType.VIDA: 20,
	ItemType.TESOURO: 50,
	ItemType.ARMADILHA: 20,
	ItemType.CARTA: 0,
	ItemType.POCAO_FORCA: 0,
	ItemType.KIT_ARMADILHA: 0,
	ItemType.EQUIPAMENTO: 0,
}

const BATTLE_MAX_ROUNDS := 4
## Fuga: d20 + velocidade >= FLEE_DC.
const FLEE_DC := 12
const BATTLE_ACTIONS := ["attack", "defend", "ability", "item", "flee"]

# --- Poções (inventário) -------------------------------------------------------
const MAX_POTIONS := 3
const POTIONS := ["vida", "forca"]
const POTION_HEAL := 30
const POTION_STRENGTH_BONUS := 5
const POTION_STRENGTH_ROUNDS := 3
const POWER_STRIKE_BONUS := 20
const MAGIC_RANGE := 3
const MAGIC_DAMAGE := 18
const CLERIC_HEAL := 20

## Turnos do próprio herói até poder usar a habilidade de novo.
const ABILITY_COOLDOWN := {
	HeroClass.GUERREIRO: 2,
	HeroClass.MAGO: 3,
	HeroClass.LADINO: 3,
	HeroClass.CLERIGO: 3,
}

const CLASS_NAMES := {
	HeroClass.GUERREIRO: "Guerreiro",
	HeroClass.MAGO: "Mago",
	HeroClass.LADINO: "Ladino",
	HeroClass.CLERIGO: "Clérigo",
}

# --- Progressão -------------------------------------------------------------
const MAX_LEVEL := 5
## XP acumulado necessário para alcançar cada nível (índice = nível).
const XP_THRESHOLDS := [0, 0, 25, 65, 120, 190]
const LEVEL_UP_HEAL_PCT := 30
const XP_PER_PVP_ROUND_WIN := 4
const XP_KILL_HERO_BASE := 30
const XP_KILL_HERO_PER_LEVEL := 10
const XP_KILL_UNDEAD_BASE := 20
const XP_KILL_UNDEAD_PER_LEVEL := 5
## Morto-vivo: volta com esta fração da vida máxima.
const UNDEAD_HP_PCT := 50
## Ganhos por nível (a partir do nível 2).
const LEVEL_GROWTH := {
	HeroClass.GUERREIRO: { "hp": 15, "attack": 2, "defense": 1, "speed": 0 },
	HeroClass.MAGO: { "hp": 8, "attack": 3, "defense": 1, "speed": 0 },
	HeroClass.LADINO: { "hp": 10, "attack": 3, "defense": 1, "speed": 0 },
	HeroClass.CLERIGO: { "hp": 10, "attack": 1, "defense": 1, "speed": 0 },
}
## Habilidades escalam por nível acima do 1.
const POWER_STRIKE_PER_LEVEL := 5
const MAGIC_DAMAGE_PER_LEVEL := 4
const CLERIC_HEAL_PER_LEVEL := 5
## Ladino: a partir deste nível a recarga da Esquiva cai em 1 turno.
const DODGE_COOLDOWN_LEVEL := 3

# --- Monstros ----------------------------------------------------------------
const MONSTERS_ON_MAP := 4
const MONSTER_SCALE_PER_LEVEL := 0.25
const MONSTER_MIN_DISTANCE_FROM_HEROES := 3
const MONSTER_KINDS := {
	"slime": { "name": "Slime", "hp": 20, "attack": 6, "defense": 2, "xp": 15, "weight": 50 },
	"lobo": { "name": "Lobo", "hp": 30, "attack": 9, "defense": 3, "xp": 25, "weight": 35 },
	"ogro": { "name": "Ogro", "hp": 45, "attack": 12, "defense": 5, "xp": 40, "weight": 15 },
}

# --- Mapa que fecha (estilo Bomberman) ---------------------------------------
## A cada CLOSE_EVERY_ROUNDS rodadas, a partir da CLOSE_START_ROUND, o anel mais externo
## vira bloco. Aviso uma rodada antes. Quem está no anel é empurrado e leva CLOSE_DAMAGE.
const CLOSE_START_ROUND := 5
const CLOSE_EVERY_ROUNDS := 2
const CLOSE_DAMAGE := 30
## Depois do último anel, todos levam dano inevitável por rodada: BASE, BASE+STEP, ...
const SUDDEN_DEATH_BASE := 10
const SUDDEN_DEATH_STEP := 5

# --- Equipamentos ----------------------------------------------------------------
## Um slot de arma e um de armadura. Coletar equipa e deixa o item antigo no chão.
const EQUIPMENT := {
	"adaga": { "name": "Adaga", "slot": "weapon", "atk": 2, "def": 0, "spd": 1, "weight": 30 },
	"espada": { "name": "Espada", "slot": "weapon", "atk": 4, "def": 0, "spd": 0, "weight": 20 },
	"machado": { "name": "Machado", "slot": "weapon", "atk": 6, "def": 0, "spd": -1, "weight": 8 },
	"gibao": { "name": "Gibão", "slot": "armor", "atk": 0, "def": 2, "spd": 0, "weight": 30 },
	"cota": { "name": "Cota de malha", "slot": "armor", "atk": 0, "def": 4, "spd": 0, "weight": 20 },
	"placas": { "name": "Armadura de placas", "slot": "armor", "atk": 0, "def": 6, "spd": -1, "weight": 8 },
}
## Chance de um monstro derrotado largar algo, e o que larga (pesos).
const MONSTER_DROP_PCT := 45
const MONSTER_DROPS := {
	ItemType.VIDA: 32,
	ItemType.POCAO_FORCA: 18,
	ItemType.EQUIPAMENTO: 35,
	ItemType.KIT_ARMADILHA: 15,
}

# --- Armadilhas armadas pelos jogadores ----------------------------------------------
## Kit na mochila (máx. MAX_TRAP_KITS). Armar custa um kit e a armadilha fica escondida na casa.
## Quem pisa (menos o dono) leva TRAP_DAMAGE e perde o resto do movimento. O Ladino as desarma e recupera o kit.
const TRAP_DAMAGE := 25
const MAX_TRAP_KITS := 2
const MAX_ACTIVE_TRAPS := 3
