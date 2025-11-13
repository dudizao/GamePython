LARGURA_TELA = 1400
ALTURA_TELA = 800
FPS = 60
UI_PANEL_ALTURA  = 160 
UI_MARGEM_LATERAL = 160 

HUD_W = 140
HUD_H = 90
HUD_PADDING = 8
HUD_RADIUS = 12

TURNO_DUR_MS = 35000
ACAO_DUR_MS = 5000


AREA_JOGO_ALTURA  = ALTURA_TELA - UI_PANEL_ALTURA
AREA_JOGO_LARGURA = LARGURA_TELA - 2*UI_MARGEM_LATERAL
TAMANHO_CELULA = min(AREA_JOGO_LARGURA // 25, AREA_JOGO_ALTURA // 25)
RENDER_SCALE = 2
CELL_PX = TAMANHO_CELULA * RENDER_SCALE
CORES = {
    'preto': (0, 0, 0),
    'branco': (255, 255, 255),
    'cinza': (128, 128, 128),
    'verde': (0, 255, 0),
    'azul': (0, 0, 255),
    'vermelho': (255, 0, 0),
    'amarelo': (255, 255, 50),
    'marrom': (139, 69, 19),
    'verde_escuro': (0, 100, 0),
    'azul_claro': (173, 216, 230),
    'laranja': (255, 165, 0),
    'roxo': (128, 0, 128)
,
    'painel_bg': (20,20,24),
    'hud_bg': (24,26,32),
    'hud_bg_inativo': (18,18,22),
    'hp_bar': (56,180,74),
    'hp_bg': (60,60,60)
}
SPRITE_CONFIG = {
    'auto_escala': True,
    'manter_proporcao': True,
    'qualidade_escala': True,
    'cache_sprites': True,
    'fallback_cores': True,
    'mapa_unico': True,
    'detectar_automaticamente': True
}
CORES.update({
    'hud_bg': (24, 26, 32),
    'hud_bg_inativo': (18, 18, 22),
    'hp_bar': (56, 180, 74),
    'hp_bg': (60, 60, 60),
})
