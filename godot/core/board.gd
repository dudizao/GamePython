class_name Board
extends RefCounted
## Tabuleiro em grade. Toda aleatoriedade vem do RNG recebido (partidas reproduzíveis por seed).

const MAP_NAMES := {
	1: "Arquipélago", 2: "Cordilheiras", 3: "Floresta Densa", 4: "Reino Central",
	5: "Caos Total", 6: "Deserto", 7: "Caverna", 8: "Ruínas Antigas", 9: "Vulcão",
	10: "Pântano", 11: "Terras Geladas", 12: "Planície Real", 13: "Cidade Antiga",
	14: "Campos de Lava", 15: "Fortaleza de Gelo",
}

var width: int
var height: int
var map_id := 0
## Células transitáveis da maior região conectada (spawns, itens e teleporte usam só estas).
var main_cells: Array[Vector2i] = []
var _terrain := PackedInt32Array()


func _init(p_width: int = Defs.BOARD_WIDTH, p_height: int = Defs.BOARD_HEIGHT) -> void:
	width = p_width
	height = p_height


func generate(p_map_id: int, rng: RandomNumberGenerator) -> void:
	map_id = p_map_id
	_terrain.resize(width * height)
	for y in height:
		for x in width:
			_terrain[y * width + x] = _terrain_for(map_id, x, y, rng)
	_keep_main_component()


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func terrain_at(p: Vector2i) -> int:
	return _terrain[p.y * width + p.x]


func terrain_copy() -> PackedInt32Array:
	return _terrain.duplicate()


func set_terrain(p: Vector2i, t: int) -> void:
	_terrain[p.y * width + p.x] = t


func is_passable(p: Vector2i) -> bool:
	return in_bounds(p) and terrain_at(p) != Defs.Terrain.AGUA and terrain_at(p) != Defs.Terrain.BLOCO


## 0 = borda externa, 1 = anel seguinte, ...
func ring_of(p: Vector2i) -> int:
	return mini(mini(p.x, p.y), mini(width - 1 - p.x, height - 1 - p.y))


## Quantos anéis podem fechar (o centro nunca fecha, para sobrar uma arena final).
func max_rings() -> int:
	return mini(width, height) / 2 - 1


## Fecha o anel: vira BLOCO. Retorna as células que eram transitáveis.
func close_ring(ring: int) -> Array[Vector2i]:
	var closed: Array[Vector2i] = []
	for y in height:
		for x in width:
			var p := Vector2i(x, y)
			if ring_of(p) == ring and is_passable(p):
				set_terrain(p, Defs.Terrain.BLOCO)
				closed.append(p)
	var still: Array[Vector2i] = []
	for c in main_cells:
		if is_passable(c):
			still.append(c)
	main_cells = still
	return closed


func move_cost(p: Vector2i) -> int:
	return Defs.MOVE_COST.get(terrain_at(p), 1)


func is_border(p: Vector2i) -> bool:
	return p.x == 0 or p.y == 0 or p.x == width - 1 or p.y == height - 1


func neighbors(p: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = p + d
		if in_bounds(n):
			out.append(n)
	return out


func _terrain_for(id: int, x: int, y: int, rng: RandomNumberGenerator) -> int:
	var T := Defs.Terrain
	var edge := x == 0 or y == 0 or x == width - 1 or y == height - 1
	match id:
		1: # Arquipélago
			if edge: return T.AGUA
			if (x + y) % 5 == 0: return T.MONTANHA
			if (x * y) % 7 == 0: return T.FLORESTA
			return T.PLANICIE
		2: # Cordilheiras
			if y % 4 == 0: return T.MONTANHA
			if x % 6 == 0: return T.FLORESTA
			if x < 2 or y < 2 or x > width - 3 or y > height - 3: return T.AGUA
			return T.PLANICIE
		3: # Floresta Densa
			if (x % 3 == 0 and y % 2 == 0) or (x + y) % 4 == 0: return T.FLORESTA
			if (x + y) % 10 == 0: return T.MONTANHA
			return T.PLANICIE
		4: # Reino Central
			var r := rng.randf()
			if edge or r < 0.10: return T.AGUA
			if r < 0.25: return T.MONTANHA
			if r < 0.45: return T.FLORESTA
			return T.PLANICIE
		5: # Caos Total
			return rng.randi_range(0, 6)
		6: # Deserto
			var r := rng.randf()
			if edge: return T.MONTANHA
			if r < 0.05: return T.AGUA
			if r < 0.15: return T.FLORESTA
			return T.PLANICIE
		7: # Caverna
			if x % 7 == 0 or y % 5 == 0: return T.MONTANHA
			if rng.randf() < 0.1: return T.AGUA
			return T.MASMORRA
		8: # Ruínas Antigas
			if (x + y) % 6 == 0: return T.MONTANHA
			if rng.randf() < 0.1: return T.FLORESTA
			return T.PLANICIE
		9: # Vulcão
			var dist := absi(x - width / 2) + absi(y - height / 2)
			if dist < 3: return T.MONTANHA
			if dist < 6: return T.AGUA
			if rng.randf() < 0.1: return T.FLORESTA
			return T.PLANICIE
		10: # Pântano
			var r := rng.randf()
			if r < 0.15: return T.AGUA
			if r < 0.35: return T.FLORESTA
			return T.PLANICIE
		11: # Terras Geladas
			if x % 5 == 0 or y % 7 == 0: return T.MONTANHA
			if rng.randf() < 0.1: return T.AGUA
			return T.PLANICIE
		12: # Planície Real
			if rng.randf() < 0.05: return T.MONTANHA
			if rng.randf() < 0.15: return T.FLORESTA
			return T.PLANICIE
		13: # Cidade Antiga: canais em grade, com pontes (no original os quarteirões ficavam isolados)
			if (x % 6 == 0 and y % 4 != 2) or (y % 6 == 0 and x % 4 != 2): return T.AGUA
			if (x + y) % 9 == 0: return T.MONTANHA
			if rng.randf() < 0.1: return T.FLORESTA
			return T.PLANICIE
		14: # Campos de Lava
			if edge: return T.MONTANHA
			if rng.randf() < 0.15: return T.LAVA
			if rng.randf() < 0.25: return T.MASMORRA
			if rng.randf() < 0.3: return T.FLORESTA
			return T.PLANICIE
		15: # Fortaleza de Gelo
			if edge: return T.MONTANHA
			if rng.randf() < 0.20: return T.GELO
			if rng.randf() < 0.30: return T.AGUA
			if rng.randf() < 0.35: return T.FLORESTA
			return T.PLANICIE
	return T.PLANICIE


## Regiões isoladas (inalcançáveis) viram água; guarda a maior região em main_cells.
func _keep_main_component() -> void:
	var seen := {}
	var best: Array[Vector2i] = []
	for y in height:
		for x in width:
			var start := Vector2i(x, y)
			if seen.has(start) or not is_passable(start):
				continue
			var comp: Array[Vector2i] = []
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var cur: Vector2i = stack.pop_back()
				comp.append(cur)
				for n in neighbors(cur):
					if not seen.has(n) and is_passable(n):
						seen[n] = true
						stack.append(n)
			if comp.size() > best.size():
				for c in best:
					set_terrain(c, Defs.Terrain.AGUA)
				best = comp
			else:
				for c in comp:
					set_terrain(c, Defs.Terrain.AGUA)
	main_cells = best
