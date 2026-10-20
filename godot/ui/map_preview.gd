class_name MapPreview
extends RefCounted
## Miniaturas dos mapas (uma cor por terreno).

const COLORS := {
	Defs.Terrain.PLANICIE: Color("a9b24a"), Defs.Terrain.FLORESTA: Color("2f6a3a"),
	Defs.Terrain.MONTANHA: Color("8c6239"), Defs.Terrain.AGUA: Color("2f78c8"),
	Defs.Terrain.MASMORRA: Color("464652"), Defs.Terrain.LAVA: Color("e65a1e"),
	Defs.Terrain.GELO: Color("aae6fa"), Defs.Terrain.BLOCO: Color("2b2622"),
}
const PX := 6

static var _cache := {}


static func thumbnail(map_id: int) -> ImageTexture:
	if _cache.has(map_id):
		return _cache[map_id]
	var rng := RandomNumberGenerator.new()
	rng.seed = map_id * 97
	var b := Board.new()
	b.generate(map_id, rng)
	var img := Image.create(b.width * PX, b.height * PX, false, Image.FORMAT_RGBA8)
	for y in b.height:
		for x in b.width:
			img.fill_rect(Rect2i(x * PX, y * PX, PX, PX), COLORS.get(b.terrain_at(Vector2i(x, y)), Color.MAGENTA))
	var tex := ImageTexture.create_from_image(img)
	_cache[map_id] = tex
	return tex
