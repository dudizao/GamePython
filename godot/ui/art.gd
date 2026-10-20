class_name Art
extends RefCounted
## Carrega texturas e define cores/nomes usados pela interface.

const PLAYER_COLORS := [Color("4ea1ff"), Color("ff6b6b"), Color("5fd38d"), Color("ffd23f")]

const TERRAIN := {
	Defs.Terrain.PLANICIE: "terreno/planicie.png",
	Defs.Terrain.FLORESTA: "terreno/floresta.png",
	Defs.Terrain.MONTANHA: "terreno/montanha.png",
	Defs.Terrain.AGUA: "terreno/agua.png",
	Defs.Terrain.MASMORRA: "terreno/masmorra.png",
	Defs.Terrain.LAVA: "terreno/lava.png",
	Defs.Terrain.GELO: "terreno/gelo.png",
}
const HERO := {
	Defs.HeroClass.GUERREIRO: "personagens/guerreiro.png",
	Defs.HeroClass.MAGO: "personagens/mago.png",
	Defs.HeroClass.LADINO: "personagens/ladino.png",
	Defs.HeroClass.CLERIGO: "personagens/clerigo.png",
}
## Vida, força e armadilha são desenhados por código (os PNGs originais eram JPEG).
const ITEM := {
	Defs.ItemType.TESOURO: "ui/trofeu.png",
	Defs.ItemType.CARTA: "itens/carta.png",
}
const MONSTER_COLORS := {
	"slime": Color("5fd38d"), "lobo": Color("b0b7c3"), "ogro": Color("c0392b"),
	"yeti": Color("8ecdf0"), "salamandra": Color("ff7a3d"), "esqueleto": Color("e8dfc0"), "polvo": Color("b070e0"),
}
const MONSTER_LETTER := { "slime": "S", "lobo": "L", "ogro": "O", "yeti": "Y", "salamandra": "M", "esqueleto": "E", "polvo": "P" }

static var _cache := {}


## Imagem 2D do herói: quadro do modelo 3D no instante `t` ou, se ainda não houver, o PNG antigo.
static func monster_tex(kind: String, anim := "idle", t := 0.0) -> Texture2D:
	return HeroSprites.frame_key(Models3D.key_for_monster(kind), anim, t)


static func hero_tex(cls: int, anim := "idle", t := 0.0) -> Texture2D:
	var f := HeroSprites.frame(cls, anim, t)
	if f != null:
		return f
	return tex(HERO.get(cls, ""))


static func tex(path: String) -> Texture2D:
	if not _cache.has(path):
		var full := "res://assets/" + path
		_cache[path] = load(full) if ResourceLoader.exists(full) else null
	return _cache[path]


static func player_color(pid: int) -> Color:
	return PLAYER_COLORS[pid % PLAYER_COLORS.size()]
