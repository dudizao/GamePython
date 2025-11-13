import pygame
from core.constants import (
    CORES, TAMANHO_CELULA, LARGURA_TELA, ALTURA_TELA, UI_PANEL_ALTURA,
    HUD_W, HUD_H, HUD_RADIUS
)
from core.enums import TipoItem, ClassePersonagem
from view.assets import sprite_manager

# ========= Helpers de ícones com fallback =========

def _get_icon_png(nome_arquivo: str, size: int):
    """Tenta carregar o PNG via sprite_manager; se faltar, retorna None."""
    try:
        return sprite_manager.obter_sprite_item(nome_arquivo, size)
    except Exception:
        return None

def _draw_clock_fallback(size: int) -> pygame.Surface:
    surf = pygame.Surface((size, size), pygame.SRCALPHA)
    cx = cy = size // 2
    r  = size // 2 - 2
    pygame.draw.circle(surf, CORES['branco'], (cx, cy), r, 2)
    pygame.draw.line(surf, CORES['branco'], (cx, cy), (cx, cy - int(r*0.6)), 2)
    pygame.draw.line(surf, CORES['branco'], (cx, cy), (cx + int(r*0.5), cy), 2)
    return surf

def _draw_trophy_fallback(size: int) -> pygame.Surface:
    surf = pygame.Surface((size, size), pygame.SRCALPHA)
    # taça simples
    cup_rect = pygame.Rect(0, 0, size, size)
    pygame.draw.ellipse(surf, (255, 215, 0), cup_rect.inflate(-size*0.25, -size*0.55))
    pygame.draw.rect(surf, (255, 215, 0), (size*0.43, size*0.45, size*0.14, size*0.35))
    pygame.draw.rect(surf, (180, 140, 0), (size*0.35, size*0.80, size*0.30, size*0.12))
    return surf

def _draw_heart_fallback(size: int) -> pygame.Surface:
    surf = pygame.Surface((size, size), pygame.SRCALPHA)
    # coração estilizado
    r = size // 4
    x1 = size * 0.35
    y1 = size * 0.35
    x2 = size * 0.65
    y2 = size * 0.35
    pygame.draw.circle(surf, (220, 0, 0), (int(x1), int(y1)), r)
    pygame.draw.circle(surf, (220, 0, 0), (int(x2), int(y2)), r)
    points = [(size*0.18, size*0.45), (size*0.82, size*0.45), (size*0.50, size*0.88)]
    pygame.draw.polygon(surf, (220, 0, 0), points)
    return surf

# Ícones PNG (não prefixe com "sprites/", o manager já procura lá)
_ICON_TROFEU  = _get_icon_png("trofeu.png", 28)
_ICON_RELOGIO = _get_icon_png("relogio.png", 28)
_ICON_CORACAO = _get_icon_png("coracao.png", 22)

class Renderer:
    def __init__(self, tela, jogo):
        self.tela = tela
        self.jogo = jogo

    # ================= Utilidades =================

    def coordenadas_celula_para_pixel(self, x, y):
        return int(x * TAMANHO_CELULA + self.jogo.offset_x), int(y * TAMANHO_CELULA + self.jogo.offset_y)

    def _cor_por_classe(self, classe):
        mapa = {
            ClassePersonagem.GUERREIRO: CORES['azul'],
            ClassePersonagem.MAGO:      CORES['vermelho'],
            ClassePersonagem.LADINO:    CORES['roxo'],
            ClassePersonagem.CLERIGO:   CORES['amarelo'],
        }
        return mapa.get(classe, CORES['cinza'])

    def _dim(self, c, fator=0.45):
        r, g, b = c
        return (int(r * fator), int(g * fator), int(b * fator))

    # ================= Células / Entidades / Itens =================

    def desenhar_celula(self, pos, cor):
        x, y = pos
        px, py = self.coordenadas_celula_para_pixel(x, y)
        rect = pygame.Rect(px, py, TAMANHO_CELULA, TAMANHO_CELULA)
        pygame.draw.rect(self.tela, cor, rect)
        pygame.draw.rect(self.tela, CORES['preto'], rect, 2)

    def desenhar_overlay_celula(self, pos, cor, alpha=128):
        x, y = pos
        px, py = self.coordenadas_celula_para_pixel(x, y)
        overlay = pygame.Surface((TAMANHO_CELULA, TAMANHO_CELULA), pygame.SRCALPHA)
        overlay.fill((*cor, alpha))
        self.tela.blit(overlay, (px, py))

    def desenhar_sprite_celula(self, pos, sprite):
        x, y = pos
        px, py = self.coordenadas_celula_para_pixel(x, y)
        self.tela.blit(sprite, (px, py))
        pygame.draw.rect(self.tela, CORES['preto'], pygame.Rect(px, py, TAMANHO_CELULA, TAMANHO_CELULA), 2)

    def desenhar_entidade(self, ent, pos_celula):
        px, py = self.coordenadas_celula_para_pixel(*pos_celula)

        caindo = getattr(self.jogo, "caindo", None)
        if caindo and ent is caindo.get('pers'):
            py += caindo.get('offset_px', 0)

        if getattr(ent, 'sprite', None):
            r = ent.sprite.get_rect()
            r.center = (px + TAMANHO_CELULA // 2, py + TAMANHO_CELULA // 2)
            self.tela.blit(ent.sprite, r)
        else:
            cor = CORES['vermelho']
            if hasattr(ent, 'classe'):
                cor = self._cor_por_classe(ent.classe)
            cx, cy = px + TAMANHO_CELULA // 2, py + TAMANHO_CELULA // 2
            pygame.draw.circle(self.tela, cor, (cx, cy), TAMANHO_CELULA // 3)

            # barra de vida fallback
            if hasattr(ent, 'vida_atual') and hasattr(ent, 'vida_maxima') and ent.vida_atual < ent.vida_maxima:
                largura_barra = TAMANHO_CELULA
                altura_barra = 4
                xb = px
                yb = py - 10
                pygame.draw.rect(self.tela, CORES['vermelho'], (xb, yb, largura_barra, altura_barra))
                vr = ent.vida_atual / ent.vida_maxima
                lv = int(largura_barra * vr)
                pygame.draw.rect(self.tela, CORES['verde'], (xb, yb, lv, altura_barra))

    def desenhar_item(self, it, pos_celula):
        px, py = self.coordenadas_celula_para_pixel(*pos_celula)
        if getattr(it, 'sprite', None):
            r = it.sprite.get_rect()
            r.center = (px + TAMANHO_CELULA // 2, py + TAMANHO_CELULA // 2)
            self.tela.blit(it.sprite, r)
        else:
            cores_item = {
                TipoItem.ARMADILHA: CORES['amarelo'],
                TipoItem.TESOURO:   CORES['amarelo'],
                TipoItem.VIDA:      CORES['vermelho']
            }
            cor = cores_item.get(it.tipo, CORES['cinza'])
            cx, cy = px + TAMANHO_CELULA // 2, py + TAMANHO_CELULA // 2
            pygame.draw.circle(self.tela, cor, (cx, cy), TAMANHO_CELULA // 6)

    # ================= Tabuleiro & Interface =================

    def desenhar_tabuleiro(self):
        self.tela.fill(CORES['branco'])

        for pos, cel in self.jogo.tabuleiro.celulas.items():
            sp = cel.obter_sprite_celula()
            if sp:
                self.desenhar_sprite_celula(pos, sp)
            else:
                self.desenhar_celula(pos, cel.get_cores_terreno()[0])

            # seleção do personagem
            if (self.jogo.personagem_selecionado
                and pos == self.jogo.personagem_selecionado.posicao):
                self.desenhar_overlay_celula(pos, CORES['azul'], 150)

            # ocupantes
            for oc in cel.ocupantes:
                self.desenhar_entidade(oc, pos)

            # itens
            for it in cel.itens:
                self.desenhar_item(it, pos)

        # alcance de movimento
        psel = self.jogo.personagem_selecionado
        if (psel and self.jogo.mostrar_alcance
            and psel in self.jogo.sistema_movimento.posicoes_alcancaveis):
            cor_borda = self._cor_por_classe(psel.classe)
            for pos in self.jogo.sistema_movimento.posicoes_alcancaveis[psel]:
                x, y = self.coordenadas_celula_para_pixel(*pos)
                rect = pygame.Rect(x, y, TAMANHO_CELULA, TAMANHO_CELULA)
                pygame.draw.rect(self.tela, cor_borda, rect, 3)

        # HUDs + painel
        self._desenhar_huds_cantos()
        self.desenhar_painel_inferior()

    def desenhar_interface(self):
        # Mantido para compatibilidade; a UI toda é feita em desenhar_tabuleiro()
        pass

    # ================= Painel inferior =================

    def desenhar_painel_inferior(self):
        panel = self.jogo.panel_rect

        pygame.draw.rect(self.tela, CORES['painel_bg'], panel)
        pygame.draw.line(self.tela, CORES['cinza'], (panel.left, panel.top), (panel.right, panel.top), 2)

        p = self.jogo.personagem_selecionado

        # --- Habilidade especial (botão X) ---
        if p:
            fonte = pygame.font.SysFont("arial", 18, bold=True)
            rect_hab = pygame.Rect(panel.left + 150, ALTURA_TELA - 90, 160, 50)

            # cooldown
            cd = 0
            if p in self.jogo.classe_controller.cooldowns:
                tempos_recarga = {
                    "GUERREIRO": 60,
                    "MAGO": 90,
                    "LADINO": 110,
                    "CLERIGO": 98
                }
                tempo_total = tempos_recarga.get(p.classe.name, 10)
                agora = pygame.time.get_ticks() / 1000
                decorrido = agora - self.jogo.classe_controller.cooldowns[p]
                restante = tempo_total - decorrido
                if restante > 0:
                    cd = int(restante)

            cor_btn = (255, 215, 0) if cd == 0 else (100, 100, 100)
            pygame.draw.rect(self.tela, cor_btn, rect_hab, border_radius=10)
            pygame.draw.rect(self.tela, (255, 255, 255), rect_hab, 2, border_radius=10)

            texto = "Habilidade (X)" if cd == 0 else f"Recarga {cd}s"
            label = fonte.render(texto, True, (0, 0, 0))
            self.tela.blit(label, (rect_hab.centerx - label.get_width()//2,
                                   rect_hab.centery - label.get_height()//2))
            self.jogo.botao_habilidade_rect = rect_hab

        # --- Animação/Sprite do personagem selecionado ---
        margem_l = 30
        size = 64
        if p:
            anim_key = "walk" if self.jogo.fase_atual in ("selecao", "movimento") else ("action" if self.jogo.fase_atual == "acao" else None)
            frame_surf = None
            if anim_key and hasattr(p, "animations") and anim_key in p.animations:
                frame_surf = p.animations[anim_key].get_frame(pygame.time.get_ticks())
            if frame_surf is None and getattr(p, "sprite", None):
                frame_surf = p.sprite
            if frame_surf is not None:
                frame_surf = pygame.transform.smoothscale(frame_surf, (size, size))
                ar = frame_surf.get_rect()
                ar.left = panel.left + margem_l
                ar.centery = panel.centery
                self.tela.blit(frame_surf, ar)

        # --- Informações de batalha (se houver) ---
        batalha = getattr(self.jogo.sistema_movimento, "batalha_em_andamento", None)
        if batalha and all(k in batalha for k in ("atacante", "defensor", "dado1", "dado2")):
            f_batalha = pygame.font.Font(None, 26)
            txt1 = f_batalha.render(
                f"Batalha: {batalha['atacante'].nome} [{batalha['dado1']}] vs {batalha['defensor'].nome} [{batalha['dado2']}]",
                True, CORES['branco']
            )
            if batalha.get("vencedor"):
                txt2 = f_batalha.render(
                    f"{batalha['vencedor'].nome} venceu e causou 10 de dano!",
                    True, CORES['vermelho']
                )
            else:
                txt2 = f_batalha.render("Empate! Nenhum dano foi causado.", True, CORES['amarelo'])

            self.tela.blit(txt1, (panel.left + 20, panel.top + 12))
            self.tela.blit(txt2, (panel.left + 20, panel.top + 40))

        # --- Cronômetro central (ícone + tempo) ---
        now = pygame.time.get_ticks()
        rest_ms = max(0, self.jogo.turno_deadline - now)
        rest_s = (rest_ms + 999) // 1000
        is_alert = rest_s <= 5
        blink_on = ((now // 280) % 2) == 0

        f_time  = pygame.font.Font(None, 48)

        # ícone: PNG se existir, fallback se não
        icon_surf = _ICON_RELOGIO if _ICON_RELOGIO else _draw_clock_fallback(28)

        time_surf = f_time.render(f"{rest_s:02d}s", True, CORES['branco'])

        pad_x, pad_y = 16, 10
        gap = 8
        content_w = icon_surf.get_width() + gap + time_surf.get_width()
        content_h = max(icon_surf.get_height(), time_surf.get_height())

        chip_w = content_w + pad_x * 2
        chip_h = content_h + pad_y * 2
        chip_rect = pygame.Rect(0, 0, chip_w, chip_h)
        chip_rect.center = panel.center

        content_x = chip_rect.centerx - content_w // 2
        content_y = chip_rect.centery - content_h // 2

        # Ícone piscando nos últimos 5s
        if not (is_alert and not blink_on):
            self.tela.blit(icon_surf, (content_x, content_y))

        # Número sempre visível
        tx = content_x + icon_surf.get_width() + gap
        ty = content_y + (content_h - time_surf.get_height()) // 2
        self.tela.blit(time_surf, (tx, ty))

        # --- Botões (direita): Rolar Dado / Baú ---
        def _dim_local(c, f=0.45):
            r, g, b = c
            return (int(r * f), int(g * f), int(b * f))

        margem_r = 30
        btn_w, btn_h = 180, 40
        espaco = 12
        base = self._cor_por_classe(getattr(p, 'classe', None)) if p else CORES['cinza']
        y_btns = panel.top + (panel.height - btn_h) // 2

        # Rolar Dado
        x_dado = panel.right - margem_r - btn_w
        self.jogo.botao_dado_rect = pygame.Rect(x_dado, y_btns, btn_w, btn_h)
        pode_rolar = (
            self.jogo.fase_atual == "selecao"
            and p
            and not getattr(p, "rolou_dados", False)
            and not getattr(self.jogo, "caindo", False)
        )
        cor_dado = base if pode_rolar else _dim_local(base, 0.45)
        pygame.draw.rect(self.tela, cor_dado, self.jogo.botao_dado_rect, border_radius=8)
        pygame.draw.rect(self.tela, CORES['branco'], self.jogo.botao_dado_rect, 2, border_radius=8)
        f_btn = pygame.font.Font(None, 28)
        txt_dado = f_btn.render("🎲 Rolar Dado (R)", True, CORES['branco'])
        self.tela.blit(
            txt_dado,
            (
                self.jogo.botao_dado_rect.centerx - txt_dado.get_width() // 2,
                self.jogo.botao_dado_rect.centery - txt_dado.get_height() // 2,
            ),
        )

        # Abrir Baú
        x_bau = x_dado - espaco - btn_w
        self.jogo.botao_bau_rect = pygame.Rect(x_bau, y_btns, btn_w, btn_h)
        pode_bau = (self.jogo.fase_atual == "acao" and p is not None and not getattr(self.jogo, "caindo", False))
        cor_bau = base if pode_bau else _dim_local(base, 0.45)
        pygame.draw.rect(self.tela, cor_bau, self.jogo.botao_bau_rect, border_radius=8)
        pygame.draw.rect(self.tela, CORES['branco'], self.jogo.botao_bau_rect, 2, border_radius=8)
        txt_bau = f_btn.render("Abrir Baú (Espaço)", True, CORES['branco'])
        self.tela.blit(
            txt_bau,
            (
                self.jogo.botao_bau_rect.centerx - txt_bau.get_width() // 2,
                self.jogo.botao_bau_rect.centery - txt_bau.get_height() // 2,
            ),
        )

    # ================= HUDs =================

    def _desenhar_huds_cantos(self):
        personagens = self.jogo.jogador.personagens[:4]
        ativo = self.jogo.personagem_selecionado

        # primeiro os inativos
        for i, p in enumerate(personagens):
            rect = self.jogo.huds_rects[i]
            if p is not ativo:
                self._desenhar_hud_personagem(p, rect, ativo=False)

        # por último o ativo (por cima, com glow)
        if ativo in personagens:
            i = personagens.index(ativo)
            self._desenhar_hud_personagem(ativo, self.jogo.huds_rects[i], ativo=True)

    def _desenhar_hud_personagem(self, p, rect, ativo=False):
        rect_draw = rect.inflate(18, 12) if ativo else rect
        base = self._cor_por_classe(getattr(p, 'classe', None))

        def blend(c, fator):
            r, g, b = c
            return (
                max(0, min(255, int(r * fator))),
                max(0, min(255, int(g * fator))),
                max(0, min(255, int(b * fator))),
            )

        bg = blend(base, 1.15) if ativo else blend(base, 0.60)

        if ativo:
            glow = pygame.Surface((rect_draw.width + 16, rect_draw.height + 16), pygame.SRCALPHA)
            pygame.draw.rect(glow, (*base, 60), glow.get_rect(), border_radius=HUD_RADIUS + 8)
            self.tela.blit(glow, (rect_draw.left - 8, rect_draw.top - 8))

        pygame.draw.rect(self.tela, bg, rect_draw, border_radius=HUD_RADIUS)
        pygame.draw.rect(self.tela, CORES['branco'], rect_draw, 2, border_radius=HUD_RADIUS)

        x_text = rect_draw.left + 10

        fonte = pygame.font.Font(None, 22 if ativo else 20)
        sub   = pygame.font.Font(None, 17 if ativo else 15)
        ESPACO_TXT = 7 if ativo else 6

        # nome + classe
        nome = f"{p.nome} [{getattr(getattr(p, 'classe', None), 'value', '?')}]"
        y = rect_draw.top + 10
        self.tela.blit(fonte.render(nome, True, CORES['branco']), (x_text, y))

        # linha de HP com ícone coração (PNG ou fallback), no "mesmo tamanho" visual do texto
        y += fonte.get_linesize() + ESPACO_TXT
        hp_text = sub.render(f"{p.vida_atual}/{p.vida_maxima} HP", True, CORES['branco'])

        icon_h = hp_text.get_height()  # altura do texto como referência
        heart_icon = _ICON_CORACAO
        if heart_icon is None:
            heart_icon = _draw_heart_fallback(icon_h)
        else:
            heart_icon = pygame.transform.smoothscale(heart_icon, (icon_h, icon_h))

        self.tela.blit(heart_icon, (x_text, y))
        self.tela.blit(hp_text, (x_text + icon_h + 6, y))

        # barra de HP
        y_bar = y + sub.get_linesize() + (ESPACO_TXT // 2)
        hp_x, hp_y = x_text, y_bar
        hp_w, hp_h = rect_draw.right - 16 - x_text, 10
        pygame.draw.rect(self.tela, CORES['hp_bg'], (hp_x, hp_y, hp_w, hp_h), border_radius=5)
        if getattr(p, 'vida_maxima', 0) > 0:
            frac = max(0.0, min(1.0, p.vida_atual / p.vida_maxima))
            pygame.draw.rect(self.tela, CORES['hp_bar'], (hp_x, hp_y, int(hp_w * frac), hp_h), border_radius=5)

        # troféus (ícone + contador)
        try:
            trofeus = sum(1 for it in getattr(p, "inventario", []) if getattr(it, "tipo", None) == TipoItem.TESOURO)
        except Exception:
            trofeus = 0

        y_trophy = hp_y + hp_h + ESPACO_TXT
        trophy_icon = _ICON_TROFEU if _ICON_TROFEU else _draw_trophy_fallback(22)
        count_font  = pygame.font.Font(None, 22 if ativo else 20)
        count_surf  = count_font.render(f"x{trofeus}", True, CORES['branco'])

        ix = x_text
        iy = y_trophy
        # alinhar ícone ao texto
        if trophy_icon.get_height() != count_surf.get_height():
            trophy_icon = pygame.transform.smoothscale(trophy_icon, (count_surf.get_height(), count_surf.get_height()))
        cx = ix + trophy_icon.get_width() + 6
        cy = iy + (trophy_icon.get_height() - count_surf.get_height()) // 2
        self.tela.blit(trophy_icon, (ix, iy))
        self.tela.blit(count_surf, (cx, cy))

    # ================= Fim de jogo =================

    def desenhar_tela_vitoria(self, vencedor):
        self.tela.fill(CORES['branco'])
        f1 = pygame.font.Font(None, 64)
        f2 = pygame.font.Font(None, 32)
        t1 = f1.render("FIM DE JOGO!", True, CORES['vermelho'])
        t2 = f2.render(f"{vencedor} venceu ao coletar 5 troféus!", True, CORES['azul'])
        self.tela.blit(t1, (LARGURA_TELA // 2 - t1.get_width() // 2, ALTURA_TELA // 2 - 80))
        self.tela.blit(t2, (LARGURA_TELA // 2 - t2.get_width() // 2, ALTURA_TELA // 2))
        t3 = f2.render("Pressione ESC para sair", True, CORES['preto'])
        self.tela.blit(t3, (LARGURA_TELA // 2 - t3.get_width() // 2, ALTURA_TELA // 2 + 60))
