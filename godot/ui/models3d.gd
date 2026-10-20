class_name Models3D
extends RefCounted
## Carregador dos personagens 3D (voxel, formato .glb em assets/models3d).
## Cada modelo tem as animações "idle" (parado) e "walk" (andando), em loop, e usa cor por vértice.
##
## Uso:
##   var n := Models3D.make(Models3D.key_for(Defs.HeroClass.MAGO), "walk-loop")
##   parent.add_child(n)

const DIR := "res://assets/models3d/"
## Ao importar, o Godot tira o sufixo "-loop" do arquivo (idle-loop, walk-loop) e já marca como repetição.
const IDLE := "idle"
const WALK := "walk"

## Classes que já existem no jogo.
const BY_CLASS := {
	Defs.HeroClass.GUERREIRO: "guerreiro",
	Defs.HeroClass.MAGO: "mago",
	Defs.HeroClass.LADINO: "ladino",
	Defs.HeroClass.CLERIGO: "clerigo",
}
## Monstros do jogo -> modelo (o ogro usa o golem de pedra).
const MONSTER_BY_KIND := {
	"slime": "slime", "lobo": "lobo", "ogro": "golem",
	"yeti": "yeti", "salamandra": "salamandra", "esqueleto": "esqueleto", "polvo": "polvo",
}
## Monstros de bioma (ver Defs.MONSTER_KINDS).
const MONSTER_EXTRA := ["yeti", "esqueleto", "polvo", "salamandra"]
const MONSTER_DIR := "res://assets/models3d/monstros/"

## Modelos prontos para as próximas classes (ainda sem regras no jogo).
const EXTRA := ["arqueiro", "paladino", "barbaro", "bardo", "necromante", "valquiria"]


static func all_keys() -> Array:
	var out: Array = BY_CLASS.values()
	out.append_array(EXTRA)
	return out


static func key_for(hero_class: int) -> String:
	return BY_CLASS.get(hero_class, "")


static func monster_keys() -> Array:
	var out: Array = ["slime", "lobo", "golem"]
	out.append_array(MONSTER_EXTRA)
	return out


static func key_for_monster(kind: String) -> String:
	return MONSTER_BY_KIND.get(kind, "")


static func path_for(key: String) -> String:
	return (MONSTER_DIR if monster_keys().has(key) else DIR) + key + ".glb"


static func exists(key: String) -> bool:
	return ResourceLoader.exists(path_for(key))


## Instancia o modelo `key` (ex.: "mago") já com as cores ativas e a animação `anim` tocando.
## Retorna null se o modelo não existir. A escala é 1 unidade ≈ 1 célula do tabuleiro (altura 1.3–1.7).
static func make(key: String, anim := IDLE) -> Node3D:
	if not exists(key):
		return null
	var scene: PackedScene = load(path_for(key))
	var node := scene.instantiate() as Node3D
	use_vertex_colors(node)
	play(node, anim)
	return node


## O importador do glTF não liga a cor por vértice sozinho; sem isso os modelos aparecem brancos.
static func use_vertex_colors(node: Node) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s)
			if m is BaseMaterial3D:
				m.vertex_color_use_as_albedo = true


static func play(node: Node, anim: String) -> void:
	var ap := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null and ap.has_animation(anim):
		ap.play(anim)


## Caixa que envolve todas as malhas (no referencial do nó).
static func bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		b = (mi as MeshInstance3D).transform * b
		box = b if first else box.merge(b)
		first = false
	return box
