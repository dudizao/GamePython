class_name Sfx
extends Node
## Efeitos sonoros e música. Os arquivos ficam em assets/audio (gerados por tools/gen_sfx.py).
## Uso: Sfx.play("hit"). Não faz nada se o áudio estiver desligado ou o arquivo não existir.

const SETTINGS_PATH := "user://settings.cfg"
const POOL_SIZE := 10

static var instance: Sfx

var sfx_on := true
var music_on := true
var haptics_on := true
var sfx_volume := 1.0
var music_volume := 0.8
var bot_speed := 1
## Animação dos dados: 0 = completa, 1 = rápida/curta, 2 = desligada.
var dice_human := 0
var dice_bots := 1
var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer


func _ready() -> void:
	instance = self
	_load_settings()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_apply_music_volume()
	_apply_music()


static func play(sound: String, vol_db := 0.0, pitch := 1.0) -> void:
	if instance != null:
		instance._play(sound, vol_db, pitch)


func set_sfx(on: bool) -> void:
	sfx_on = on
	_save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_save_settings()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_music_volume()
	_save_settings()


func set_dice_human(n: int) -> void:
	dice_human = n
	_save_settings()


func set_dice_bots(n: int) -> void:
	dice_bots = n
	_save_settings()


func set_bot_speed(n: int) -> void:
	bot_speed = n
	_save_settings()


static func _db(v: float) -> float:
	return linear_to_db(maxf(v, 0.0001))


func _apply_music_volume() -> void:
	if _music != null:
		_music.volume_db = -13.0 + _db(music_volume)


func set_haptics(on: bool) -> void:
	haptics_on = on
	_save_settings()


func set_music(on: bool) -> void:
	music_on = on
	_save_settings()
	_apply_music()


func _stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var path := "res://assets/audio/%s.wav" % sound
		_cache[sound] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sound]


func _play(sound: String, vol_db: float, pitch: float) -> void:
	if not sfx_on:
		return
	var s := _stream(sound)
	if s == null:
		return
	var player: AudioStreamPlayer = _pool[0]
	for p in _pool:
		if not p.playing:
			player = p
			break
	player.stream = s
	player.volume_db = vol_db + _db(sfx_volume)
	player.pitch_scale = pitch
	player.play()


func _apply_music() -> void:
	if _music == null:
		return
	if not music_on:
		_music.stop()
		return
	if _music.stream == null:
		var m = _stream("music")
		if m is AudioStreamWAV:
			var loop: AudioStreamWAV = m.duplicate()
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_begin = 0
			loop.loop_end = loop.data.size() / 2  # 16 bits, mono
			_music.stream = loop
	if _music.stream != null and not _music.playing:
		_music.play()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		sfx_on = cfg.get_value("audio", "sfx", true)
		music_on = cfg.get_value("audio", "music", true)
		haptics_on = cfg.get_value("audio", "haptics", true)
		sfx_volume = cfg.get_value("audio", "sfx_volume", 1.0)
		music_volume = cfg.get_value("audio", "music_volume", 0.8)
		bot_speed = cfg.get_value("game", "bot_speed", 1)
		dice_human = cfg.get_value("game", "dice_human", 0)
		dice_bots = cfg.get_value("game", "dice_bots", 1)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx", sfx_on)
	cfg.set_value("audio", "music", music_on)
	cfg.set_value("audio", "haptics", haptics_on)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("game", "bot_speed", bot_speed)
	cfg.set_value("game", "dice_human", dice_human)
	cfg.set_value("game", "dice_bots", dice_bots)
	cfg.save(SETTINGS_PATH)
