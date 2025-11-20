import pygame
import sys
from pygame.locals import QUIT, MOUSEBUTTONDOWN
from core.constants import LARGURA_TELA, ALTURA_TELA
import os

pygame.font.init()

def resource_path(relative_path):
    try:
        base_path = sys._MEIPASS
    except AttributeError:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)

try:
    FONTE_TITULO = pygame.font.Font(resource_path("joystix.otf"), 60)
    FONTE_BOTAO = pygame.font.Font(resource_path("joystix.otf"), 36)
except FileNotFoundError:
    FONTE_TITULO = pygame.font.SysFont("arial", 60, bold=True)
    FONTE_BOTAO = pygame.font.SysFont("arial", 36, bold=True)

def fade(tela, cor=(0, 0, 0), velocidade=8):
    fade_surface = pygame.Surface((LARGURA_TELA, ALTURA_TELA))
    fade_surface.fill(cor)
    for alpha in range(0, 255, velocidade):
        fade_surface.set_alpha(alpha)
        tela.blit(fade_surface, (0, 0))
        pygame.display.update()
        pygame.time.delay(10)

# ==== Tela principal ====
def desenhar_menu(tela, indice_selecionado):
    fundo = pygame.image.load(resource_path("a.png"))
    fundo = pygame.transform.scale(fundo, (LARGURA_TELA, ALTURA_TELA))
    tela.blit(fundo, (0, 0))

    # Título com brilho pulsante
    brilho = abs((pygame.time.get_ticks() // 10) % 510 - 255)
    titulo = FONTE_TITULO.render("O ÚLTIMO ROUBO", True, (255, 215, brilho))
    tela.blit(titulo, (LARGURA_TELA // 2 - titulo.get_width() // 2, 100))

    botoes = ["JOGAR", "COMO JOGAR", "SAIR"]
    y_bases = [250, 340, 430]

    for i, texto in enumerate(botoes):
        cor_hover = (255, 215, 0) if i == indice_selecionado else (255, 255, 255)
        rect = pygame.Rect(0, 0, 400, 60)
        rect.center = (LARGURA_TELA // 2, y_bases[i])

        pygame.draw.rect(tela, cor_hover, rect, border_radius=10)
        texto_render = FONTE_BOTAO.render(texto, True, (0, 0, 0))
        tela.blit(
            texto_render,
            (rect.centerx - texto_render.get_width() // 2, rect.centery - texto_render.get_height() // 2),
        )

    engrenagem = pygame.image.load(resource_path("engrenagem.png"))
    engrenagem = pygame.transform.scale(engrenagem, (50, 50))
    tela.blit(engrenagem, (20, ALTURA_TELA - 70))

    pygame.display.update()

# ==== Tela "Como Jogar" ====
def carregar_gif(caminho):
    """Carrega um GIF em uma lista de frames Surface."""
    frames = []
    try:
        from PIL import Image, ImageSequence
        img = Image.open(caminho)
        for frame in ImageSequence.Iterator(img):
            modo = frame.mode
            tamanho = frame.size
            data = frame.tobytes()
            py_image = pygame.image.fromstring(data, tamanho, modo)
            frames.append(py_image.convert_alpha())
    except Exception as e:
        print(f"Erro ao carregar gif {caminho}: {e}")
    return frames

def render_texto_justificado(tela, texto, fonte, cor, x, y, largura_max):
    palavras = texto.split()
    linha_atual = []
    linhas = []
    
    # monta linhas dentro da largura
    for palavra in palavras:
        teste_linha = " ".join(linha_atual + [palavra])
        if fonte.size(teste_linha)[0] <= largura_max:
            linha_atual.append(palavra)
        else:
            linhas.append(linha_atual)
            linha_atual = [palavra]
    linhas.append(linha_atual)

    # desenha cada linha já justificada
    for linha in linhas:
        if linha == linhas[-1]:
            # última linha NÃO é justificada (padrão)
            texto_render = fonte.render(" ".join(linha), True, cor)
            tela.blit(texto_render, (x, y))
            y += texto_render.get_height()
        else:
            # linhas justificadas
            texto_total = " ".join(linha)
            largura_texto = fonte.size(texto_total)[0]
            espaco_extra = (largura_max - largura_texto) // (len(linha) - 1) if len(linha) > 1 else 0

            pos_x = x
            for palavra in linha:
                palavra_render = fonte.render(palavra, True, cor)
                tela.blit(palavra_render, (pos_x, y))
                pos_x += palavra_render.get_width() + fonte.size(" ")[0] + espaco_extra
            y += palavra_render.get_height()

    return y



def mostrar_como_jogar(tela):
    fade(tela)
    clock = pygame.time.Clock()

    fonte_titulo = pygame.font.SysFont("arial", 42, bold=True)
    fonte_topico = pygame.font.SysFont("arial", 30, bold=True)
    fonte_texto = pygame.font.SysFont("arial", 26)

    titulo = fonte_titulo.render("COMO JOGAR", True, (255, 215, 0))

    # === Carregar GIFs ===
    gifs = {
        "dado": carregar_gif(resource_path("gifs/rolar_dado.gif")),
        "mover": carregar_gif(resource_path("gifs/movimento.gif")),
        "bau": carregar_gif(resource_path("gifs/abrir_bau.gif")),
        "batalha": carregar_gif(resource_path("gifs/batalha.gif")),
    }

    # Tópicos (chave interna, texto do botão, texto explicativo)
    topicos = [
        ("objetivo", "Objetivo",
         "Colete 5 troféus antes dos outros jogadores para vencer a partida."),
        ("dado", "Rolar Dado",
         "Aperte R para rolar o dado. O resultado define o alcance do seu movimento neste turno."),
        ("mover", " Movimentação",
         "Use as setas do teclado para mover seu herói pelas células iluminadas."),
        ("bau", " Itens e Baús",
         "Pise sobre um baú e aperte ESPAÇO para abrir. Pode ser tesouro, cura ou armadilha."),
        ("batalha", " Batalha",
         "Ao entrar na célula de outro herói, começa uma batalha por dados em 3 rodadas."),
    ]

    selected_topic = "objetivo"
    frame_index = 0
    rodando = True

    while rodando:
        tela.fill((10, 10, 20))

        # Título
        tela.blit(titulo, (LARGURA_TELA // 2 - titulo.get_width() // 2, 40))

        mouse_x, mouse_y = pygame.mouse.get_pos()

        # === Desenhar painel de tópicos à esquerda ===
        botoes_temas = []
        painel_rect = pygame.Rect(60, 120, 420, 5 * 60)  # área geral dos tópicos
        # pygame.draw.rect(tela, (25, 25, 40), painel_rect, border_radius=12)  # se quiser ver o painel

        base_y = 140
        for i, (key, label, desc) in enumerate(topicos):
            rect = pygame.Rect(painel_rect.x, base_y + i * 60, painel_rect.width, 45)
            hover = rect.collidepoint(mouse_x, mouse_y)
            ativo = (key == selected_topic)

            if ativo:
                cor_fundo = (255, 215, 0)
                cor_borda = (0, 0, 0)
                cor_texto = (0, 0, 0)
            elif hover:
                cor_fundo = (80, 80, 120)
                cor_borda = (255, 215, 0)
                cor_texto = (255, 255, 255)
            else:
                cor_fundo = (40, 40, 60)
                cor_borda = (0, 0, 0)
                cor_texto = (230, 230, 230)

            pygame.draw.rect(tela, cor_fundo, rect, border_radius=10)
            pygame.draw.rect(tela, cor_borda, rect, 2, border_radius=10)

            txt = fonte_topico.render(label, True, cor_texto)
            tela.blit(txt, (rect.x + 15, rect.y + 10))

            botoes_temas.append((rect, key))

        for rect, key in botoes_temas:
            if key == selected_topic:
                pulse= 5 * abs(int((pygame.time.get_ticks() // 10) % 10 - 5))
                
                seta = fonte_topico.render(" >", True, (255, 215, 0))
                tela.blit(seta, (rect.left - 40 - pulse, rect.centery - seta.get_height() // 2))
                break

        # === Painel de detalhe à direita (GIF + descrição) ===
        detalhe_rect = pygame.Rect(LARGURA_TELA // 2 - 20, 120, LARGURA_TELA // 2 - 80, ALTURA_TELA - 220)
        pygame.draw.rect(tela, (20, 20, 35), detalhe_rect, border_radius=16)
        pygame.draw.rect(tela, (255, 215, 0), detalhe_rect, 2, border_radius=16)

        # Busca dados do tópico selecionado
        topico_atual = next(t for t in topicos if t[0] == selected_topic)
        _, label_atual, desc_atual = topico_atual

        # Título do painel
        titulo_det = fonte_topico.render(label_atual, True, (255, 215, 0))
        tela.blit(titulo_det, (detalhe_rect.x + 20, detalhe_rect.y + 20))

        # GIF (se houver)
        gif_key = selected_topic if selected_topic in gifs else None
        gif_frames = gifs.get(gif_key)

        if gif_frames:
            frame = gif_frames[frame_index % len(gif_frames)]
            # GIF grande com borda
            gif_w = detalhe_rect.width - 40
            gif_h = int(gif_w * 0.55)
            gif_surface = pygame.transform.scale(frame, (gif_w, gif_h))

            gif_rect = gif_surface.get_rect()
            gif_rect.topleft = (detalhe_rect.x + 20, detalhe_rect.y + 70)

            borda_rect = pygame.Rect(
                gif_rect.x - 4, gif_rect.y - 4,
                gif_rect.width + 8, gif_rect.height + 8
            )
            pygame.draw.rect(tela, (255, 215, 0), borda_rect, border_radius=12)
            pygame.draw.rect(tela, (0, 0, 0), borda_rect, 3, border_radius=12)

            tela.blit(gif_surface, gif_rect)

            texto_y = gif_rect.bottom + 20
        else:
            texto_y = detalhe_rect.y + 80

        # Texto descritivo
        linhas = []
        max_chars = 60
        texto_temp = desc_atual.split(" ")
        linha = ""
        for palavra in texto_temp:
            if len(linha) + len(palavra) + 1 <= max_chars:
                linha += " " + palavra if linha else palavra
            else:
                linhas.append(linha)
                linha = palavra
        if linha:
            linhas.append(linha)

        for lin in linhas:
            txt_l = fonte_texto.render(lin, True, (230, 230, 230))
            tela.blit(txt_l, (detalhe_rect.x + 20, texto_y))
            texto_y += 30

        # ===== BOTÃO VOLTAR AO MENU =====
        voltar_rect = pygame.Rect(0, 0, 320, 70)
        voltar_rect.center = (LARGURA_TELA // 2, ALTURA_TELA - 60)

        hover_voltar = voltar_rect.collidepoint(mouse_x, mouse_y)
        cor_botao = (255, 190, 0) if hover_voltar else (255, 215, 0)

        pygame.draw.rect(tela, cor_botao, voltar_rect, border_radius=12)
        pygame.draw.rect(tela, (0, 0, 0), voltar_rect, 3, border_radius=12)

        txt_voltar = FONTE_BOTAO.render("VOLTAR", True, (0, 0, 0))
        tela.blit(
            txt_voltar,
            (
                voltar_rect.centerx - txt_voltar.get_width() // 2,
                voltar_rect.centery - txt_voltar.get_height() // 2
            )
        )

        # ==== EVENTOS ====
        for e in pygame.event.get():
            if e.type == QUIT:
                pygame.quit()
                sys.exit()
            elif e.type == pygame.KEYDOWN and e.key == pygame.K_ESCAPE:
                fade(tela)
                rodando = False
            elif e.type == MOUSEBUTTONDOWN and e.button == 1:
                # Clicou em voltar
                if voltar_rect.collidepoint(e.pos):
                    fade(tela)
                    rodando = False
                    break

                # Clicou em algum tópico
                for rect, key in botoes_temas:
                    if rect.collidepoint(e.pos):
                        selected_topic = key
                        break

        frame_index = (frame_index + 1) % 60
        pygame.display.update()
        clock.tick(12)




# ==== Mini menu de Configuração (abre pela engrenagem) ====
def abrir_configuracoes(tela):
    menu_rect = pygame.Rect(30, ALTURA_TELA - 250, 260, 200)
    pygame.draw.rect(tela, (30, 30, 40), menu_rect, border_radius=12)
    pygame.draw.rect(tela, (255, 215, 0), menu_rect, 3, border_radius=12)

    fonte = pygame.font.SysFont("arial", 24)
    opcoes = ["🎧 Som: Ativado", "🌈 Tema: Escuro", "🕹️ Controles", "❌ Fechar"]
    y = menu_rect.top + 20
    botoes = []

    for texto in opcoes:
        texto_render = fonte.render(texto, True, (255, 255, 255))
        rect = pygame.Rect(menu_rect.left + 20, y, menu_rect.width - 40, 35)
        pygame.draw.rect(tela, (50, 50, 70), rect, border_radius=8)
        tela.blit(texto_render, (rect.x + 10, rect.y + 5))
        botoes.append((rect, texto))
        y += 45

    pygame.display.update()

    aberto = True
    while aberto:
        for e in pygame.event.get():
            if e.type == QUIT:
                pygame.quit()
                sys.exit()
            elif e.type == MOUSEBUTTONDOWN:
                for rect, texto in botoes:
                    if rect.collidepoint(e.pos):
                        if "❌" in texto:
                            aberto = False
                            fade(tela)
                            return
                        print(f"{texto} clicado!")
                # Clique fora fecha o menu
                if not menu_rect.collidepoint(e.pos):
                    aberto = False
                    fade(tela)
                    return

# ==== Loop principal do menu ====
def menu():
    pygame.init()
    tela = pygame.display.set_mode((LARGURA_TELA, ALTURA_TELA))
    pygame.display.set_caption("Menu Principal")

    indice_selecionado = 0
    clock = pygame.time.Clock()

    while True:
        desenhar_menu(tela, indice_selecionado)

        for e in pygame.event.get():
            if e.type == QUIT:
                pygame.quit()
                sys.exit()

            elif e.type == pygame.KEYDOWN:
                if e.key == pygame.K_UP:
                    indice_selecionado = (indice_selecionado - 1) % 3
                elif e.key == pygame.K_DOWN:
                    indice_selecionado = (indice_selecionado + 1) % 3
                elif e.key == pygame.K_RETURN:
                    if indice_selecionado == 0:
                        fade(tela)
                        return "jogar"
                    elif indice_selecionado == 1:
                        mostrar_como_jogar(tela)
                    elif indice_selecionado == 2:
                        pygame.quit()
                        sys.exit()

            elif e.type == MOUSEBUTTONDOWN:
                # Botões principais
                if 250 <= e.pos[1] <= 310:
                    fade(tela)
                    return "jogar"
                elif 340 <= e.pos[1] <= 400:
                    mostrar_como_jogar(tela)
                elif 430 <= e.pos[1] <= 490:
                    pygame.quit()
                    sys.exit()

                # Ícone engrenagem
                if 20 <= e.pos[0] <= 70 and ALTURA_TELA - 70 <= e.pos[1] <= ALTURA_TELA - 20:
                    abrir_configuracoes(tela)

        clock.tick(60)
