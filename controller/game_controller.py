# controller/game_controller.py
import random
import pygame
import sys

from core.constants import (
    LARGURA_TELA, ALTURA_TELA, FPS, CORES, TAMANHO_CELULA,
    AREA_JOGO_ALTURA, AREA_JOGO_LARGURA, UI_MARGEM_LATERAL, UI_PANEL_ALTURA,
    HUD_W, HUD_H, HUD_PADDING, TURNO_DUR_MS
)
from core.enums import TipoItem, ClassePersonagem
from core.messenger import Mensageiro
from model.board import Tabuleiro
from model.items import Tesouro, Armadilha, Vida, Carta
from model.characters import Jogador, Personagem
from model.movement import SistemaMovimento
from view.assets import sprite_manager, obter_animacao_personagem
from view.renderer import Renderer
from controller.cartaController import CartaController
from controller.classeController import ClasseController
from view.gif_player import GifPlayer

PROB_VIDA = 0.10
PROB_TESOURO = 0.30
PROB_ARMADILHA = 0.30
PROB_CARTA = 0.50


class GameController:
    def __init__(self):
        pygame.init()
        self.tela = pygame.display.set_mode((LARGURA_TELA, ALTURA_TELA))
        pygame.display.set_caption("Jogo de Fantasia")
        self.clock = pygame.time.Clock()

        mapa_id = self.selecionar_mapa_visual()
        if mapa_id is None:
            pygame.quit()
            return

        self.tabuleiro = Tabuleiro(
            AREA_JOGO_LARGURA // TAMANHO_CELULA,
            AREA_JOGO_ALTURA // TAMANHO_CELULA,
            mapa_id=mapa_id
        )
        self.gameplay_rect = pygame.Rect(
            UI_MARGEM_LATERAL, 0, AREA_JOGO_LARGURA, AREA_JOGO_ALTURA
        )

        largura_px_tab = self.tabuleiro.largura * TAMANHO_CELULA
        altura_px_tab = self.tabuleiro.altura * TAMANHO_CELULA
        self.offset_x = self.gameplay_rect.left + (self.gameplay_rect.width - largura_px_tab) // 2
        self.offset_y = self.gameplay_rect.top + (self.gameplay_rect.height - altura_px_tab) // 2

        # UI/Estados base
        self.panel_rect = pygame.Rect(0, ALTURA_TELA - UI_PANEL_ALTURA, LARGURA_TELA, UI_PANEL_ALTURA)
        self.huds_rects = [
            pygame.Rect(HUD_PADDING, HUD_PADDING, HUD_W, HUD_H),
            pygame.Rect(LARGURA_TELA - HUD_W - HUD_PADDING, HUD_PADDING, HUD_W, HUD_H),
            pygame.Rect(HUD_PADDING, ALTURA_TELA - UI_PANEL_ALTURA - HUD_H - HUD_PADDING, HUD_W, HUD_H),
            pygame.Rect(LARGURA_TELA - HUD_W - HUD_PADDING, ALTURA_TELA - UI_PANEL_ALTURA - HUD_H - HUD_PADDING, HUD_W, HUD_H)
        ]

        self.botao_dado_rect = None
        self.botao_bau_rect = None
        self.turno_deadline = 0
        self.caindo = None

        # Estados principais
        self.jogador = Jogador("Jogador")
        self.turno_atual = 1
        self.fase_atual = "selecao"
        self.personagem_selecionado = None
        self.jogo_finalizado = False
        self.vencedor = None
        self.jogo_rodando = True

        # Subsistemas
        self.renderer = Renderer(self.tela, self)
        self.sistema_movimento = SistemaMovimento()
        self.ultimo_resultado_dado = 0
        self.mostrar_alcance = False
        self.tempo_ultima_acao = pygame.time.get_ticks()
        self.delay_transicao = 2500
        self.msg = Mensageiro()
        self.transicao_ativa = False
        self.transicao_alpha = 0
        self.transicao_inicio = 0
        self.transicao_duracao = 3500
        self.transicao_personagem = None

        self.carta_controller = CartaController(self)
        self.classe_controller = ClasseController(self)

        # Inicialização
        self._inicializar_jogo()
        self._resetar_cronometro_turno()

    # -----------------------------------------------------------
    # Seleção visual de mapa com mini-preview
    # -----------------------------------------------------------
    def selecionar_mapa_visual(self):
        pygame.display.set_caption("Seleção de Mapa")
        fonte_titulo = pygame.font.SysFont("arial", 38, bold=True)
        fonte_legenda = pygame.font.SysFont("arial", 22, bold=True)
        clock = pygame.time.Clock()

        mini_largura = 14
        mini_altura = 9
        cel_tam = 12

        nomes_mapas = {
            1: "Arquipélago",
            2: "Cordilheiras",
            3: "Floresta Densa",
            4: "Reino Central",
            5: "Caos Total",
            6: "Deserto",
            7: "Caverna",
            8: "Ruínas Antigas",
            9: "Vulcão",
            10: "Pântano",
            11: "Terras Geladas",
            12: "Planície Real",
            13: "Cidade Antiga",
            14: "Campos de Lava",
            15: "Fortaleza de Gelo"
        }

        total_mapas = len(nomes_mapas)

    # === Pré-renderiza miniaturas ===
        previews = {}
        for mapa_id in range(1, total_mapas + 1):
            tabuleiro_preview = Tabuleiro(mini_largura, mini_altura, mapa_id=mapa_id)
            surface = pygame.Surface((mini_largura * cel_tam, mini_altura * cel_tam))
            for (x, y), cel in tabuleiro_preview.celulas.items():
                cor1, _ = cel.get_cores_terreno()
                pygame.draw.rect(surface, cor1, (x * cel_tam, y * cel_tam, cel_tam - 1, cel_tam - 1))
            previews[mapa_id] = surface

        rodando = True
        fade_surface = pygame.Surface((LARGURA_TELA, ALTURA_TELA))
        fade_surface.fill((0, 0, 0))

        scroll_y = 0
        scroll_speed = 25
        mini_w = mini_largura * cel_tam
        mini_h = mini_altura * cel_tam
        espacamento_x = 200
        espacamento_y = 180
        mapas_por_linha = 5

        while rodando:
            self.tela.fill((15, 15, 25))
            titulo = fonte_titulo.render("Selecione o Mapa", True, CORES['branco'])
            self.tela.blit(titulo, (LARGURA_TELA // 2 - titulo.get_width() // 2, 40))

            mouse_x, mouse_y = pygame.mouse.get_pos()
            botoes = []

        # === Desenha em grade ===
            for i, mapa_id in enumerate(range(1, total_mapas + 1)):
                col = i % mapas_por_linha
                lin = i // mapas_por_linha
                pos_x = 120 + col * espacamento_x
                pos_y = 140 + lin * espacamento_y + scroll_y

                rect = pygame.Rect(pos_x, pos_y, mini_w, mini_h)
                botoes.append((rect, mapa_id))

            # evita desenhar fora da tela
                if pos_y + mini_h < 100 or pos_y > ALTURA_TELA - 80:
                    continue

                self.tela.blit(previews[mapa_id], (pos_x, pos_y))

            # Destaque hover
                if rect.collidepoint(mouse_x, mouse_y):
                    glow_color = (255, 215, 0)
                    glow_size = 6
                else:
                    glow_color = (180, 180, 180)
                    glow_size = 2

                pygame.draw.rect(
                    self.tela, glow_color,
                    (pos_x - 2, pos_y - 2, mini_w + 4, mini_h + 4),
                    glow_size, border_radius=8
                )

            # Legenda
                nome = nomes_mapas.get(mapa_id, f"Mapa {mapa_id}")
                label = fonte_legenda.render(nome, True, CORES['amarelo'])
                rect_label = label.get_rect(center=(pos_x + mini_w // 2, pos_y + mini_h + 25))
                self.tela.blit(label, rect_label)

            pygame.display.flip()
            clock.tick(60)

        # === Eventos ===
            for e in pygame.event.get():
                if e.type == pygame.QUIT:
                    return None
                elif e.type == pygame.MOUSEBUTTONDOWN:
                    if e.button == 4:  # scroll up
                        scroll_y += scroll_speed
                    elif e.button == 5:  # scroll down
                        scroll_y -= scroll_speed
                    elif e.button == 1:  # clique
                        for rect, id_mapa in botoes:
                            if rect.collidepoint(e.pos):
                                # Fade out curto
                                for alpha in range(0, 255, 15):
                                    fade_surface.set_alpha(alpha)
                                    self.tela.blit(fade_surface, (0, 0))
                                    pygame.display.update()
                                    pygame.time.delay(15)
                                return id_mapa

    # -----------------------------------------------------------
    # Setup inicial
    # -----------------------------------------------------------
    def _posicoes_iniciais_borda(self):
        midx = self.tabuleiro.largura // 2
        midy = self.tabuleiro.altura // 2
        return [
            (0, midy),
            (self.tabuleiro.largura - 1, midy),
            (midx, 0),
            (midx, self.tabuleiro.altura - 1)
        ]

    def _posicoes_iniciais_seguras(self):
        alvos = self._posicoes_iniciais_borda()
        seguras = []
        for (x, y) in alvos:
            dx, dy = 0, 0
            if x == 0: dx = 1
            elif x == self.tabuleiro.largura - 1: dx = -1
            elif y == 0: dy = 1
            elif y == self.tabuleiro.altura - 1: dy = -1
            cx, cy = x, y
            for _ in range(max(self.tabuleiro.largura, self.tabuleiro.altura)):
                cel = self.tabuleiro.get_celula((cx, cy))
                if cel and cel.tipo_terreno.name != 'AGUA' and not cel.esta_ocupado():
                    seguras.append((cx, cy))
                    break
                cx += dx
                cy += dy
                if cx < 0 or cy < 0 or cx >= self.tabuleiro.largura or cy >= self.tabuleiro.altura:
                    break
        while len(seguras) < 4:
            seguras.append((self.tabuleiro.largura // 2, self.tabuleiro.altura // 2))
        return seguras

    def _inicializar_jogo(self):
        posicoes_iniciais = self._posicoes_iniciais_seguras()
        classes = [
            ClassePersonagem.GUERREIRO,
            ClassePersonagem.MAGO,
            ClassePersonagem.LADINO,
            ClassePersonagem.CLERIGO
        ]

        for i, (pos, classe) in enumerate(zip(posicoes_iniciais, classes)):
            p = Personagem(f"Herói {i + 1}", pos, classe)
            p.vida_maxima = 100
            p.vida_atual = 100
            p.velocidade = 3

            sprite = sprite_manager.obter_sprite_personagem(classe, TAMANHO_CELULA)
            if sprite:
                p.sprite = sprite
                
            sprite_hd = sprite_manager.obter_sprite_personagem(classe, 180)
            if sprite_hd:
                p.sprite_hd = sprite_hd

            if not hasattr(p, "animations"):
                p.animations = {}
            walk = obter_animacao_personagem(classe, "walk", tamanho=64, fps=10)
            act = obter_animacao_personagem(classe, "action", tamanho=64, fps=10)
            if walk: p.animations['walk'] = walk
            if act: p.animations['action'] = act

            self.jogador.adicionar_personagem(p)
            cel = self.tabuleiro.get_celula(pos)
            if cel:
                cel.adicionar_ocupante(p)
                
                
        self.classe_controller.aplicar_bonus_iniciais(p)

        self.ordem_turnos = self.jogador.personagens[:]
        random.shuffle(self.ordem_turnos)
        self.indice_turno = 0
        self.personagem_selecionado = self.ordem_turnos[self.indice_turno]

        self._gerar_itens()
        self.msg.add("Mapa selecionado com sucesso! Boa sorte!", (255, 255, 255), 2500)
        self._mostrar_transicao_turno(self.personagem_selecionado)
        
     # -----------------------------------------------------------
    # Exibição de transição de turno
    # -----------------------------------------------------------
    def _transicao_turno(self):
        now = pygame.time.get_ticks()

        if now - self.tempo_transicao_turno < self.fade_duration:
            self.fade_alpha = int(255 * (now - self.tempo_transicao_turno) / self.fade_duration)
        else:
            self.fade_alpha = 255

        if self.fade_alpha == 255 and self.fade_in:
            self.fade_in = False
            self.tempo_transicao_turno = now

        if self.fade_alpha == 0 and not self.fade_in:
            self.fade_in = True
            self.turno_atual += 1
            self.indice_turno = (self.indice_turno + 1) % len(self.ordem_turnos)
            self.personagem_selecionado = self.ordem_turnos[self.indice_turno]
            self.tempo_transicao_turno = now

    def _mostrar_legenda_heroi(self):
        fonte = pygame.font.Font(None, 64)
        nome_heroi = self.personagem_selecionado.nome
        texto = fonte.render(nome_heroi, True, (255, 255, 0))
        self.tela.blit(texto, (LARGURA_TELA // 2 - texto.get_width() // 2, ALTURA_TELA // 2 - texto.get_height() // 2))

        if self.personagem_selecionado.sprite:
            heroi_sprite = self.personagem_selecionado.sprite.copy()
            heroi_sprite.set_alpha(self.fade_alpha)
            self.tela.blit(heroi_sprite, (LARGURA_TELA // 2 - heroi_sprite.get_width() // 2, ALTURA_TELA // 2 + 50))

    # -----------------------------------------------------------
    # Geração de itens (inclui carta misteriosa)
    # -----------------------------------------------------------
    def _gerar_itens(self):
        posicoes = [
            pos for pos, cel in self.tabuleiro.celulas.items()
            if (not cel.esta_ocupado())
            and cel.tipo_terreno.name != 'AGUA'
            and not self._eh_borda(pos)
        ]

        for _ in range(10):
            if not posicoes:
                break
            rnd = random.random()
            pos = random.choice(posicoes)
            posicoes.remove(pos)

            # --- 10% de chance de gerar carta ---
            if rnd < 0.50:
                item = Carta("📜 Carta Misteriosa", pos, self)
                sprite = sprite_manager.obter_sprite_item("carta.png", TAMANHO_CELULA // 2)
                item.controller = self
            elif rnd < 0.15 + PROB_VIDA:
                item = Vida("❤️ Poção de Vida", pos, vida=20)
                sprite = sprite_manager.obter_sprite_item("vida.png", TAMANHO_CELULA // 2)
            elif rnd < 0.10 + PROB_VIDA + PROB_TESOURO:
                item = Tesouro("🏆 Tesouro", pos, 50)
                sprite = sprite_manager.obter_sprite_item("tesouro.png", TAMANHO_CELULA // 2)
            else:
                item = Armadilha("💀 Armadilha", pos, 20)
                sprite = sprite_manager.obter_sprite_item("armadilha.png", TAMANHO_CELULA // 2)

            if sprite:
                item.sprite = sprite
            self.tabuleiro.celulas[pos].adicionar_item(item)

    def repor_itens(self):
        itens = sum(len(c.itens) for c in self.tabuleiro.celulas.values())
        while itens < 10:
            posicoes = [
                pos for pos, cel in self.tabuleiro.celulas.items()
                if (not cel.esta_ocupado())
                and (not cel.itens)
                and cel.tipo_terreno.name != 'AGUA'
                and not self._eh_borda(pos)
            ]
            if not posicoes:
                break
            pos = random.choice(posicoes)
            rnd = random.random()
            if rnd < PROB_VIDA:
                item = Vida("❤️ Poção de Vida", pos, vida=20)
                sprite = sprite_manager.obter_sprite_item("vida.png", TAMANHO_CELULA // 2)
            elif rnd < PROB_VIDA + PROB_TESOURO:
                item = Tesouro("🏆 Troféu", pos, 50)
                sprite = sprite_manager.obter_sprite_item("tesouro.png", TAMANHO_CELULA // 2)
            elif rnd < PROB_VIDA + PROB_TESOURO + PROB_CARTA:
                item = Carta("Carta Misteriosa", pos, self)
                sprite = sprite_manager.obter_sprite_item("carta.png", TAMANHO_CELULA // 2)
                item.controller = self
            else:
                item = Armadilha("💀 Armadilha", pos, 20)
                sprite = sprite_manager.obter_sprite_item("armadilha.png", TAMANHO_CELULA // 2)
            if sprite:
                item.sprite = sprite
            self.tabuleiro.celulas[pos].adicionar_item(item)
            itens += 1

    # -----------------------------------------------------------
    # Loop principal
    # -----------------------------------------------------------
    def executar(self):
        while self.jogo_rodando:
            self._processar_eventos()
            self._atualizar_cronometro_e_queda()

            if self.jogo_finalizado:
                self.renderer.desenhar_tela_vitoria(self.vencedor)
            else:
                self._verificar_transicoes_automaticas()
                
                batalha = getattr(self.sistema_movimento, "batalha_em_andamento", None)
                if batalha and all(k in batalha for k in ("atacante", "defensor", "dado1", "dado2", "vencedor")):
                    self._mostrar_animacao_batalha(
                        batalha["atacante"],
                        batalha["defensor"],
                        batalha["dado1"],
                        batalha["dado2"],
                        batalha["vencedor"]
                    )
                    self.sistema_movimento.batalha_em_andamento = None  # evita repetir animação
    
            
                self.renderer.desenhar_tabuleiro()
                self.renderer.desenhar_interface()
                self.msg.draw(self.tela, LARGURA_TELA, ALTURA_TELA)

            pygame.display.flip()
            self.clock.tick(FPS)
        
        pygame.quit()

    # -----------------------------------------------------------
    # Eventos / Entrada
    # -----------------------------------------------------------
    def _processar_eventos(self):
        for e in pygame.event.get():
            if e.type == pygame.QUIT:
                self.jogo_rodando = False

            elif e.type == pygame.KEYDOWN:
                # === ESC abre o menu de pausa ===
                if e.key == pygame.K_ESCAPE:
                    self._menu_pausa()
                    continue

                if self.caindo or self.jogo_finalizado:
                    continue

                if e.key == pygame.K_r and not self.jogo_finalizado:
                    if (self.fase_atual == "selecao"
                        and self.personagem_selecionado
                        and not getattr(self.personagem_selecionado, "rolou_dados", False)):
                        self._rolar_dados_movimento()

                elif self.fase_atual == "movimento" and self.personagem_selecionado and not self.jogo_finalizado:
                    self._teclas_movimento(e.key)
                    if e.key == pygame.K_RETURN:
                        self.fase_atual = "acao"
                        self.mostrar_alcance = False
                        self.tempo_ultima_acao = pygame.time.get_ticks()
                        self.msg.add("➡ Fase de AÇÃO", (255, 255, 255))
                        
                elif self.fase_atual == "acao" and e.key == pygame.K_RETURN:
                    # ENTER pula o turno manualmente
                    self.msg.add(f" {self.personagem_selecionado.nome} passou o turno.", (200, 200, 200))
                    self._finalizar_turno()
                    self._resetar_cronometro_turno()
                    return


                elif self.fase_atual == "acao" and self.personagem_selecionado and not self.jogo_finalizado:
                    if e.key == pygame.K_x:
                        self.classe_controller.usar_habilidade(self.personagem_selecionado)

                    if e.key == pygame.K_SPACE:
                        self._tentar_coletar_bau(self.personagem_selecionado.posicao)
                        
                        

            elif e.type == pygame.MOUSEBUTTONDOWN and not self.jogo_finalizado:
                if e.button == 1:
                    if self.caindo:
                        continue
                    self._clique_mouse(e.pos)

            # botões no painel
            if pygame.mouse.get_pressed()[0]:
                mx, my = pygame.mouse.get_pos()

                rect = getattr(self, "botao_dado_rect", None)
                if rect and rect.collidepoint(mx, my):
                    if (self.fase_atual == "selecao"
                        and self.personagem_selecionado
                        and not getattr(self.personagem_selecionado, "rolou_dados", False)
                        and not self.caindo):
                        self._rolar_dados_movimento()

                rect = getattr(self, "botao_bau_rect", None)
                if rect and rect.collidepoint(mx, my):
                    if self.fase_atual == "acao" and self.personagem_selecionado and not self.caindo:
                        self._tentar_coletar_bau(self.personagem_selecionado.posicao)
                        
                rect = getattr(self, "botao_habilidade_rect", None)
                if rect and rect.collidepoint(mx, my):
                    if self.fase_atual == "acao" and self.personagem_selecionado:
                        self.classe_controller.usar_habilidade(self.personagem_selecionado)
                        
            elif e.type == pygame.USEREVENT and e.dict.get("tipo") == "batalha":
                batalha = getattr(self.sistema_movimento, "batalha_em_andamento", None)
                if batalha and all(k in batalha for k in ("atacante", "defensor", "vencedor")):
                    self._mostrar_animacao_batalha(
                        batalha["atacante"],
                        batalha["defensor"],
                        batalha["rodadas"][0].split()[0],  # só pra mostrar o 1º resultado
                        "",  # sem necessidade dos dados
                        batalha["vencedor"] or batalha["defensor"]
                    )


    def _mostrar_animacao_batalha(self, atacante, defensor, *_):
        """Anima uma batalha em 3 rodadas com texto de dano flutuante."""
        batalha = getattr(self.sistema_movimento, "batalha_em_andamento", None)
        if not batalha:
            return

        clock = pygame.time.Clock()
        fonte_titulo = pygame.font.SysFont("arial", 46, bold=True)
        fonte_info = pygame.font.SysFont("arial", 32)
        fonte_dano = pygame.font.SysFont("arial", 50, bold=True)
        fonte_dados = pygame.font.SysFont("arial", 60, bold=True)

        sprite_a = getattr(atacante, "sprite_hd", atacante.sprite)
        sprite_d = getattr(defensor, "sprite_hd", defensor.sprite)

        rodadas = batalha.get("rodadas", [])
        vencedor_final = batalha.get("vencedor")
        perdedor_final = batalha.get("perdedor")

    # loop de cada rodada
        for i, resultado in enumerate(rodadas, start=1):
            start = pygame.time.get_ticks()
            duracao = 1800  # tempo da rodada
            
            dado1 = random.randint(1, 20)
            dado2 = random.randint(1, 20)

            dano_txt = None
            dano_y = 0
            dano_alpha = 255

        # define quem levou dano nesta rodada
            if "" in resultado:
                atingido = defensor
            elif "" in resultado:
                atingido = atacante
            else:
                atingido = None

            while pygame.time.get_ticks() - start < duracao:
                self.renderer.desenhar_tabuleiro()
                overlay = pygame.Surface((LARGURA_TELA, ALTURA_TELA), pygame.SRCALPHA)
                overlay.fill((0, 0, 0, 180))
                self.tela.blit(overlay, (0, 0))

            # posição dos personagens
                rect_a = sprite_a.get_rect(center=(LARGURA_TELA // 2 - 200, ALTURA_TELA // 2))
                rect_d = sprite_d.get_rect(center=(LARGURA_TELA // 2 + 200, ALTURA_TELA // 2))
                self.tela.blit(sprite_a, rect_a)
                self.tela.blit(sprite_d, rect_d)

            # texto de rodada
                titulo = fonte_titulo.render(f"Rodada {i}", True, (255, 215, 0))
                self.tela.blit(titulo, (LARGURA_TELA // 2 - titulo.get_width() // 2, 120))

            # valores dos dados
                txt_dados = fonte_dados.render(f"{dado1}  vs  {dado2}", True, (255, 255, 255))
                self.tela.blit(txt_dados, (LARGURA_TELA // 2 - txt_dados.get_width() // 2, ALTURA_TELA // 2 - 180))

            # resultado parcial
                txt_res = fonte_info.render(resultado, True, (255, 230, 100))
                self.tela.blit(txt_res, (LARGURA_TELA // 2 - txt_res.get_width() // 2, ALTURA_TELA // 2 + 150))

            # flash de golpe
                tempo_flash = (pygame.time.get_ticks() - start) % 400
                if tempo_flash < 200:
                    pygame.draw.circle(self.tela, (255, 255, 255, 60), (LARGURA_TELA // 2, ALTURA_TELA // 2), 70)

            # dano flutuante
                if atingido:
                    if dano_txt is None:
                        dano_txt = fonte_dano.render("-10", True, (255, 60, 60))
                        dano_y = -40
                        dano_alpha = 255

                    dano_surface = dano_txt.copy()
                    dano_surface.set_alpha(dano_alpha)
                    if atingido == defensor:
                        x = rect_d.centerx - dano_surface.get_width() // 2
                        y = rect_d.top + dano_y
                    else:
                        x = rect_a.centerx - dano_surface.get_width() // 2
                        y = rect_a.top + dano_y

                    self.tela.blit(dano_surface, (x, y))
                    dano_y -= 1.5
                    dano_alpha = max(0, dano_alpha - 5)

                pygame.display.flip()
                clock.tick(60)

    # -------------------------------
    # Tela final de resultado
    # -------------------------------
        start = pygame.time.get_ticks()
        duracao = 1500
        while pygame.time.get_ticks() - start < duracao:
            self.renderer.desenhar_tabuleiro()
            overlay = pygame.Surface((LARGURA_TELA, ALTURA_TELA), pygame.SRCALPHA)
            overlay.fill((0, 0, 0, 200))
            self.tela.blit(overlay, (0, 0))

            if vencedor_final:
                cor_texto = (0, 255, 0)
                texto_final = f"🏆 {vencedor_final.nome} venceu a batalha!"
            else:
                cor_texto = (255, 255, 255)
                texto_final = "A batalha terminou empatada!"

            texto = fonte_dano.render(texto_final, True, cor_texto)
            self.tela.blit(texto, (LARGURA_TELA // 2 - texto.get_width() // 2, ALTURA_TELA // 2))
            pygame.display.flip()
            clock.tick(60)

    # encerra a flag
        self.sistema_movimento.batalha_em_andamento = None

    
    # -----------------------------------------------------------
    # Menu de pausa
    # -----------------------------------------------------------
    def _menu_pausa(self):
        clock = pygame.time.Clock()
        pausado = True

        fonte_titulo = pygame.font.SysFont("arial", 60, bold=True)
        fonte_botao = pygame.font.SysFont("arial", 38, bold=True)

        botoes = [
            ("CONTINUAR", (255, 215, 0)),       # dourado
            ("MENU PRINCIPAL", (70, 130, 180)), # azul
            ("SAIR DO JOGO", (220, 20, 60))     # vermelho
        ]

        while pausado:
            # Desenha o tabuleiro atual antes do overlay
            self.renderer.desenhar_tabuleiro()

            # Fundo translúcido sobre o jogo
            overlay = pygame.Surface((LARGURA_TELA, ALTURA_TELA), pygame.SRCALPHA)
            overlay.fill((0, 0, 0, 180))  # preto semi-transparente
            self.tela.blit(overlay, (0, 0))

            # Título
            titulo = fonte_titulo.render("⏸️ PAUSADO", True, (255, 215, 0))
            self.tela.blit(titulo, (LARGURA_TELA // 2 - titulo.get_width() // 2, 140))

            # Botões
            botoes_rects = []
            for i, (texto, cor) in enumerate(botoes):
                rect = pygame.Rect(LARGURA_TELA // 2 - 200, 300 + i * 100, 400, 70)
                botoes_rects.append((rect, texto))
                pygame.draw.rect(self.tela, cor, rect, border_radius=14)
                pygame.draw.rect(self.tela, (255, 255, 255), rect, 3, border_radius=14)
                texto_render = fonte_botao.render(texto, True, (0, 0, 0))
                self.tela.blit(
                    texto_render,
                    (rect.centerx - texto_render.get_width() // 2,
                     rect.centery - texto_render.get_height() // 2)
                )

            pygame.display.flip()
            clock.tick(30)

            for e in pygame.event.get():
                if e.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                elif e.type == pygame.KEYDOWN:
                    if e.key == pygame.K_ESCAPE:
                        pausado = False  # volta ao jogo
                elif e.type == pygame.MOUSEBUTTONDOWN and e.button == 1:
                    mx, my = e.pos
                    for rect, texto in botoes_rects:
                        if rect.collidepoint((mx, my)):
                            if texto == "CONTINUAR":
                                pausado = False
                            elif texto == "MENU PRINCIPAL":
                                from main import main
                                pygame.display.quit()
                                main()
                                return
                            elif texto == "SAIR DO JOGO":
                                pygame.quit()
                                sys.exit()

    # -----------------------------------------------------------
    # Movimento / clique / ação
    # -----------------------------------------------------------
    def _teclas_movimento(self, key):
        dx, dy = 0, 0
        if key == pygame.K_UP: dy = -1
        elif key == pygame.K_DOWN: dy = 1
        elif key == pygame.K_LEFT: dx = -1
        elif key == pygame.K_RIGHT: dx = 1
        if dx == dy == 0:
            return
        x, y = self.personagem_selecionado.posicao
        destino = (x + dx, y + dy)
        alc = self.sistema_movimento.posicoes_alcancaveis.get(self.personagem_selecionado, [])
        if destino in alc:
            self.sistema_movimento.mover_personagem(self.tabuleiro, self.personagem_selecionado, destino)
            self.tempo_ultima_acao = pygame.time.get_ticks()
            pts = self.sistema_movimento.movimentos_disponiveis.get(self.personagem_selecionado, 0)
            self.msg.add(f"{self.personagem_selecionado.nome} foi para {destino} | Restante: {pts}", (173, 216, 230))
            if pts > 0:
                self.sistema_movimento.calcular_alcance(self.tabuleiro, self.personagem_selecionado)

    def _clique_mouse(self, pos_mouse):
        mx, my = pos_mouse

        if self.panel_rect.collidepoint(mx, my):
            return

        for p, rect in zip(self.jogador.personagens, self.huds_rects):
            if rect.collidepoint(mx, my) and p.esta_vivo():
                self.personagem_selecionado = p
                self.mostrar_alcance = False
                self._resetar_cronometro_turno()
                self.msg.add(f"{p.nome} selecionado", (255, 255, 255))
                return

        # clique no tabuleiro
        pos_celula = self._pixel_para_coordenadas_celula(mx, my)
        cel = self.tabuleiro.get_celula(pos_celula)
        if not cel:
            return

        if self.fase_atual == "selecao":
            for oc in cel.ocupantes:
                if isinstance(oc, Personagem) and oc in self.jogador.personagens and oc.esta_vivo():
                    self.personagem_selecionado = oc
                    self.mostrar_alcance = False
                    self.tempo_ultima_acao = pygame.time.get_ticks()
                    self._resetar_cronometro_turno()
                    self.msg.add(f"{oc.nome} selecionado", (255, 255, 255))
                    return

        elif self.fase_atual == "acao":
            if not self.personagem_selecionado or not self.personagem_selecionado.esta_vivo():
                return
            if self.personagem_selecionado.posicao == pos_celula:
                self._tentar_coletar_bau(pos_celula)

    # -----------------------------------------------------------
    # Ação de coletar item (baú/vida/armadilha/carta)
    # -----------------------------------------------------------
    def _tentar_coletar_bau(self, pos_celula):
        cel = self.tabuleiro.get_celula(pos_celula)
        if not cel:
            return

        for item in list(cel.itens):
            # Carta misteriosa (item de ação)
            if getattr(item, "tipo", None) == "CARTA":
                item.controller = self  # garante referência
                item.usar(self.personagem_selecionado)  # abre popup + aplica efeito
                cel.remover_item(item)
                return

            # Itens padrão
            if item.usar(self.personagem_selecionado):
                cel.remover_item(item)
                self.personagem_selecionado.inventario.append(item)

                if item.tipo == TipoItem.TESOURO:
                    self.msg.add("🏆 Tesouro coletado!", (255, 215, 0))
                    self._mostrar_animacao_bau(self.personagem_selecionado, "tesouro")
                elif item.tipo == TipoItem.VIDA:
                    self.msg.add(f"❤️ +{getattr(item,'vida',0)} de Vida!", (0, 200, 0))
                else:
                    self.msg.add(f"💥 Armadilha! -{getattr(item,'dano',0)} HP", (255, 100, 100))
                    self._mostrar_animacao_bau(self.personagem_selecionado, "armadilha")

                self.tempo_ultima_acao = pygame.time.get_ticks()
                self.repor_itens()

                # vitória
                trofeus = sum(1 for i in self.personagem_selecionado.inventario
                              if getattr(i, 'tipo', None) == TipoItem.TESOURO)
                if trofeus >= 5:
                    self.jogo_finalizado = True
                    self.vencedor = self.personagem_selecionado.nome
                    self.msg.add(f"🏆 Vitória de {self.vencedor}!", (0, 200, 0), duracao_ms=2800)

                # morte por dano
                if self.personagem_selecionado.vida_atual <= 0:
                    cel.remover_ocupante(self.personagem_selecionado)
                    self.jogador.remover_personagem(self.personagem_selecionado)
                    self.msg.add(f"{self.personagem_selecionado.nome} foi derrotado",
                                 (255, 120, 120), duracao_ms=2400)
                    self.personagem_selecionado = None
                return



    def _mostrar_animacao_bau(self, personagem, resultado):
   
        from view.assets import obter_animacao_bau

        anim = obter_animacao_bau(personagem.classe, resultado, tamanho=180, fps=10)
        if not anim:
            print(f"⚠️ Animação não encontrada para {personagem.classe} - {resultado}")
            return

        self.animacao_bau = anim
        self.animacao_ativa = True

        clock = pygame.time.Clock()
        start = pygame.time.get_ticks()
        dur_ms = 1200  # duração da animação

        while pygame.time.get_ticks() - start < dur_ms:
            self.renderer.desenhar_tabuleiro()
            self.renderer.desenhar_interface()

        # desenha personagem centralizado
            frame = anim.get_frame(pygame.time.get_ticks())
            if frame:
                rect = frame.get_rect(center=(LARGURA_TELA // 2, ALTURA_TELA // 2))
                self.tela.blit(frame, rect)

            pygame.display.flip()
            clock.tick(60)

        self.animacao_ativa = False





    # -----------------------------------------------------------
    # Turnos / Fases / Cronômetro / Queda
    # -----------------------------------------------------------
    def _animar_dado(self, dur_ms=700):
        start = pygame.time.get_ticks()
        fonte = pygame.font.Font(None, 120)
        rect_w, rect_h = 220, 220
        cx = LARGURA_TELA // 2 - rect_w // 2
        cy = ALTURA_TELA // 2 - rect_h // 2
        while pygame.time.get_ticks() - start < dur_ms:
            self.renderer.desenhar_tabuleiro()
            self.renderer.desenhar_interface()
            overlay = pygame.Surface((rect_w, rect_h), pygame.SRCALPHA)
            overlay.fill((0, 0, 0, 200))
            pygame.draw.rect(overlay, (255, 255, 255, 230), overlay.get_rect(), 4, border_radius=16)
            self.tela.blit(overlay, (cx, cy))
            val = random.randint(1, 6)
            txt = fonte.render(str(val), True, (255, 255, 0))
            self.tela.blit(txt, (LARGURA_TELA // 2 - txt.get_width() // 2,
                                 ALTURA_TELA // 2 - txt.get_height() // 2))
            pygame.display.flip()
            self.clock.tick(60)

    def _rolar_dados_movimento(self):
        if not self.personagem_selecionado or self.caindo:
            return
        self._animar_dado()
        resultado = self.sistema_movimento.rolar_movimento(self.personagem_selecionado)
        self.ultimo_resultado_dado = resultado
        self.personagem_selecionado.rolou_dados = True
        self.sistema_movimento.calcular_alcance(self.tabuleiro, self.personagem_selecionado)
        self.mostrar_alcance = True
        self.msg.add(f"🎲 Dado: {resultado} ponto(s) de movimento", (255, 255, 0))

    def _verificar_transicoes_automaticas(self):
        if self.caindo or self.jogo_finalizado:
            return
        t = pygame.time.get_ticks()

        if (self.fase_atual == 'selecao'
            and self.personagem_selecionado
            and getattr(self.personagem_selecionado, "rolou_dados", False)):
            self.fase_atual = 'movimento'
            self.tempo_ultima_acao = t
            self.msg.add(" Fase de MOVIMENTO", (255, 255, 255))

        elif (self.fase_atual == 'movimento'
              and self.personagem_selecionado
              and self.personagem_selecionado in self.sistema_movimento.movimentos_disponiveis):
            pts = self.sistema_movimento.movimentos_disponiveis[self.personagem_selecionado]
            if pts <= 0:
                self.fase_atual = 'acao'
                self.mostrar_alcance = False
                self.tempo_ultima_acao = t
                self.msg.add("⚔️ Fase de AÇÃO", (255, 255, 255))

    def _finalizar_turno(self):
        if self.personagem_selecionado:
            self.sistema_movimento.resetar_movimento(self.personagem_selecionado)
            self.personagem_selecionado.resetar_turno()
        self.mostrar_alcance = False
        self.ultimo_resultado_dado = 0
        self.turno_atual += 1
        self.fase_atual = 'selecao'
        self.tempo_ultima_acao = pygame.time.get_ticks()

        total = len(self.ordem_turnos)
        for _ in range(total):
            self.indice_turno = (self.indice_turno + 1) % total
            prox = self.ordem_turnos[self.indice_turno]
            if prox.esta_vivo():
                self.personagem_selecionado = prox
                break
        else:
            self.personagem_selecionado = None
            
        if self.personagem_selecionado:
            self._mostrar_transicao_turno(self.personagem_selecionado)
            
    def _eh_borda(self, pos):
        x, y = pos
        return (
            x == 0
            or y == 0
            or x == self.tabuleiro.largura - 1
            or y == self.tabuleiro.altura - 1
        )
    # Cronômetro
    def _resetar_cronometro_turno(self):
        self.turno_deadline = pygame.time.get_ticks() + int(TURNO_DUR_MS)

    def _mostrar_transicao_turno(self, personagem):
        if not personagem:
            return

        self.transicao_ativa = True
        self.transicao_inicio = pygame.time.get_ticks()
        self.transicao_personagem = personagem

        fonte = pygame.font.SysFont("arial", 52, bold=True)
        nome = personagem.nome
        texto = fonte.render(f"Turno de {nome}", True, (255, 215, 0))
        sombra = fonte.render(f"Turno de {nome}", True, (0, 0, 0))

        sprite = getattr(personagem, "sprite_hd", None) or getattr(personagem, "sprite", None)
        if sprite:
            sprite_grande = sprite.copy()
        else:
            sprite_grande = pygame.Surface((180, 180), pygame.SRCALPHA)
            pygame.draw.circle(sprite_grande, (255, 255, 0), (90, 90), 90)

        clock = pygame.time.Clock()
        while True:
            tempo = pygame.time.get_ticks() - self.transicao_inicio
            alpha = min(255, int(255 * (tempo / self.transicao_duracao)))
            if tempo >= self.transicao_duracao:
                break

            self.renderer.desenhar_tabuleiro()
            self.renderer.desenhar_interface()

            overlay = pygame.Surface((LARGURA_TELA, ALTURA_TELA), pygame.SRCALPHA)
            overlay.fill((0, 0, 0, int(alpha * 0.6)))
            self.tela.blit(overlay, (0, 0))

            sprite_grande.set_alpha(alpha)
            rect_sprite = sprite_grande.get_rect(center=(LARGURA_TELA // 2, ALTURA_TELA // 2 - 50))
            self.tela.blit(sprite_grande, rect_sprite)

            texto.set_alpha(alpha)
            sombra.set_alpha(alpha)
            rect_txt = texto.get_rect(center=(LARGURA_TELA // 2, ALTURA_TELA // 2 + 100))
            self.tela.blit(sombra, (rect_txt.x + 3, rect_txt.y + 3))
            self.tela.blit(texto, rect_txt)

            pygame.display.flip()
            clock.tick(60)

        # Fade out
        for alpha in range(255, 0, -10):
            self.renderer.desenhar_tabuleiro()
            self.renderer.desenhar_interface()
            overlay = pygame.Surface((LARGURA_TELA, ALTURA_TELA), pygame.SRCALPHA)
            overlay.fill((0, 0, 0, int(alpha * 0.6)))
            self.tela.blit(overlay, (0, 0))
            pygame.display.flip()
            clock.tick(60)

        self.transicao_ativa = False

    
    def _iniciar_queda_personagem(self, p):
        self.caindo = {'pers': p, 'offset_px': 0, 'vel': int(TAMANHO_CELULA * 0.9)}

    def _atualizar_cronometro_e_queda(self):
        if self.jogo_finalizado:
            return
        now = pygame.time.get_ticks()

        # estourou tempo
        if not self.caindo and now >= self.turno_deadline:
            if self.personagem_selecionado and self.personagem_selecionado.esta_vivo():
                self.msg.add(f"Tempo esgotado! Turno de {self.personagem_selecionado.nome} encerrado.", (255, 150, 150))
            self._finalizar_turno()
            self._resetar_cronometro_turno()
            return

        # animação de queda
        if self.caindo:
            self.caindo['offset_px'] += self.caindo['vel']
            if self.caindo['offset_px'] >= TAMANHO_CELULA * 2:
                self.caindo = None
                self._finalizar_turno()
                self._resetar_cronometro_turno()

    # -----------------------------------------------------------
    # Conversão de coordenadas
    # -----------------------------------------------------------
    def _pixel_para_coordenadas_celula(self, x, y):
        # fora da área jogável
        if not self.gameplay_rect.collidepoint(x, y):
            return None
        x -= self.offset_x
        y -= self.offset_y
        if x < 0 or y < 0:
            return None
        cx = x // TAMANHO_CELULA
        cy = y // TAMANHO_CELULA
        return (cx, cy) if (cx, cy) in self.tabuleiro.celulas else None
