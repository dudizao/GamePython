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


def mostrar_como_jogar(tela):
    fade(tela)
    tela.fill((10, 10, 20))
    fonte_titulo = pygame.font.SysFont("arial", 42, bold=True)
    fonte_texto = pygame.font.SysFont("arial", 28)

    titulo = fonte_titulo.render("COMO JOGAR", True, (255, 215, 0))
    tela.blit(titulo, (LARGURA_TELA // 2 - titulo.get_width() // 2, 40))

    # === Carregar GIFs ===
    gifs = {
        "dado": carregar_gif(resource_path("gifs/rolar_dado.gif")),
        "mover": carregar_gif(resource_path("gifs/movimento.gif")),
        "bau": carregar_gif(resource_path("gifs/abrir_bau.gif")),
        "batalha": carregar_gif(resource_path("gifs/batalha.gif")),
    }

    instrucoes = [
        ("🎯 Objetivo", "Colete 5 troféus e torne-se o maior ladrão do reino!"),
        ("🎲 Rolar Dado", "Pressione R para rolar o dado e liberar o movimento.", "dado"),
        ("🧭 Movimentação", "Use as setas para mover seu personagem.", "mover"),
        ("🗝️ Itens", "Abra baús com a barra de espaço (pode ser tesouro ou armadilha).", "bau"),
        ("⚔️ Batalha", "Se encontrar outro herói, uma luta por dados decidirá o vencedor!", "batalha"),
    ]

    y = 120
    frame_index = 0
    clock = pygame.time.Clock()
    rodando = True

    while rodando:
        tela.fill((10, 10, 20))
        tela.blit(titulo, (LARGURA_TELA // 2 - titulo.get_width() // 2, 40))

        for e in pygame.event.get():
            if e.type == QUIT:
                pygame.quit(); sys.exit()
            elif e.type == MOUSEBUTTONDOWN:
                if voltar_rect.collidepoint(e.pos):
                    fade(tela); rodando = False
            elif e.type == pygame.KEYDOWN and e.key == pygame.K_ESCAPE:
                fade(tela); rodando = False

        y = 120
        for bloco in instrucoes:
            nome, texto = bloco[0], bloco[1]
            gif_key = bloco[2] if len(bloco) > 2 else None

            nome_r = fonte_titulo.render(nome, True, (255, 215, 0))
            texto_r = fonte_texto.render(texto, True, (255, 255, 255))
            tela.blit(nome_r, (80, y))
            tela.blit(texto_r, (100, y + 40))

            if gif_key and gifs.get(gif_key):
                frames = gifs[gif_key]
                frame = frames[frame_index % len(frames)]
                frame = pygame.transform.scale(frame, (180, 120))
                tela.blit(frame, (LARGURA_TELA - 280, y))
            y += 170

        frame_index += 1
        if frame_index > 60: frame_index = 0

        voltar_rect = pygame.Rect(0, 0, 300, 60)
        voltar_rect.center = (LARGURA_TELA // 2, ALTURA_TELA - 80)
        pygame.draw.rect(tela, (255, 215, 0), voltar_rect, border_radius=10)
        txt_voltar = FONTE_BOTAO.render("VOLTAR AO MENU", True, (0, 0, 0))
        tela.blit(txt_voltar, (voltar_rect.centerx - txt_voltar.get_width() // 2, voltar_rect.centery - txt_voltar.get_height() // 2))

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
