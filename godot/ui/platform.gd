class_name Platform
extends RefCounted
## Diferenças entre desktop e celular: modo toque, áreas seguras e vibração.


## Modo toque: celular/tablet, ou `--touch` na linha de comando (para testar no desktop:
## godot --path godot -- --touch).
static func is_touch() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or "--touch" in OS.get_cmdline_user_args()


## Alturas mínimas de botão em unidades da interface (a escala já foi ajustada pelo App).
static func button_height() -> int:
	return 52 if is_touch() else 42


## Margens (esquerda, topo, direita, base) para entalhes e barras do sistema, em unidades da interface.
static func safe_insets(win: Window) -> Vector4:
	if not OS.has_feature("mobile") or win == null or win.size.x <= 0:  # só em aparelhos reais (entalhe, barras)
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.x <= 0 or safe.size.x <= 0:
		return Vector4.ZERO
	var units_per_px := win.get_viewport().get_visible_rect().size.x / float(win.size.x)
	return Vector4(
		maxf(0.0, safe.position.x), maxf(0.0, safe.position.y),
		maxf(0.0, screen.x - safe.end.x), maxf(0.0, screen.y - safe.end.y)) * units_per_px


static func vibrate(ms: int) -> void:
	if is_touch() and (Sfx.instance == null or Sfx.instance.haptics_on):
		Input.vibrate_handheld(ms)
