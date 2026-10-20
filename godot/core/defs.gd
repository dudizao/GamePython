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
	# Monstros de bioma: só surgem no terreno indicado (polvo: casa ao lado da água) e têm efeito especial.
	"yeti": { "name": "Yeti", "hp": 40, "attack": 11, "defense": 6, "xp": 35, "weight": 0, "biome": Terrain.GELO, "special": "gelo" },
	"salamandra": { "name": "Salamandra", "hp": 32, "attack": 11, "defense": 3, "xp": 32, "weight": 0, "biome": Terrain.LAVA, "special": "queimadura" },
	"esqueleto": { "name": "Esqueleto", "hp": 28, "attack": 10, "defense": 4, "xp": 28, "weight": 0, "biome": Terrain.MASMORRA, "special": "ressurge" },
	"polvo": { "name": "Polvo", "hp": 35, "attack": 9, "defense": 4, "xp": 30, "weight": 0, "biome": Terrain.AGUA, "special": "prende" },
}
## Peso de um monstro de bioma quando a casa sorteada é do bioma dele.
const BIOME_SPAWN_WEIGHT := 60
## Efeitos (aplicados se o monstro causou dano e o herói sobreviveu à batalha).
const FREEZE_MOVE_PENALTY := 3   # Yeti: -3 pontos na próxima rolagem de movimento
const SNARE_MOVE_CAP := 2        # Polvo: no próximo turno anda no máximo 2 pontos
const BURN_DAMAGE := 5           # Salamandra: dano no início dos próximos turnos (nunca mata)
const BURN_TURNS := 2
const SKELETON_REVIVE_ROUNDS := 2
const SKELETON_REVIVE_HP_PCT := 50

# --- Terreno vivo ------------------------------------------------------------------
## Gelo: terminar o movimento em casa de gelo faz deslizar mais uma casa na mesma direção (até o limite).
const ICE_SLIDE_MAX := 3
## Lava se espalha para casas vizinhas a cada rodada, até este percentual das casas.
const LAVA_SPREAD_PER_ROUND := 1
const LAVA_MAX_PCT := 10
## Tempestade: a região (5x3) é avisada uma rodada antes; ao cair, fere quem está dentro e,
## durante aquela rodada, as casas dela custam +1 de movimento.
const STORM_START_ROUND := 3
const STORM_DAMAGE := 10
const STORM_HALF_W := 2
const STORM_HALF_H := 1
const STORM_EXTRA_COST := 1

# --- Eventos de rodada -----------------------------------------------------------------
## A cada ROUND_EVENT_EVERY rodadas acontece um evento, avisado na rodada anterior.
const ROUND_EVENT_EVERY := 3
const ROUND_EVENTS := ["chuva_itens", "caravana", "tregua", "erupcao", "nevasca"]
const EVENT_RAIN_ITEMS := 5
const EVENT_CARAVAN_MONSTERS := 2
const EVENT_SNOW_CELLS := 7

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
