import os
import sys
import pygame

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from telainicial import menu, mostrar_como_jogar, abrir_configuracoes
from controller.game_controller import GameController
from core.constants import LARGURA_TELA, ALTURA_TELA

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


def fade_in(tela, cor=(0, 0, 0), velocidade=8):
    fade_surface = pygame.Surface((LARGURA_TELA, ALTURA_TELA))
    fade_surface.fill(cor)
    for alpha in range(255, -1, -velocidade):
        fade_surface.set_alpha(alpha)
        tela.blit(fade_surface, (0, 0))
        pygame.display.update()
        pygame.time.delay(10)


def intro(tela):
    tela.fill((0, 0, 0))
    fonte_intro = pygame.font.SysFont("arial", 52, bold=True)
    texto = fonte_intro.render("ANTI-GORDAS S2", True, (255, 215, 0))

    tela.blit(
        texto,
        (LARGURA_TELA // 2 - texto.get_width() // 2,
         ALTURA_TELA // 2 - texto.get_height() // 2)
    )
    pygame.display.update()

    for alpha in range(0, 255, 8):
        texto_surf = fonte_intro.render("ANTI-GORDAS S2", True, (255, 215, 0))
        texto_surf.set_alpha(alpha)
        tela.fill((0, 0, 0))
        tela.blit(
            texto_surf,
            (LARGURA_TELA // 2 - texto_surf.get_width() // 2,
             ALTURA_TELA // 2 - texto_surf.get_height() // 2)
        )
        pygame.display.update()
        pygame.time.delay(30)

    pygame.time.delay(1300)
    fade_in(tela)


def main():
    print("Iniciando O Último Roubo")

    os.makedirs(os.path.join(BASE_DIR, "sprites/personagens"), exist_ok=True)
    os.makedirs(os.path.join(BASE_DIR, "sprites/itens"), exist_ok=True)
    os.makedirs(os.path.join(BASE_DIR, "sprites/terreno"), exist_ok=True)

    pygame.init()
    tela = pygame.display.set_mode((LARGURA_TELA, ALTURA_TELA))
    pygame.display.set_caption("O Último Roubo")

    intro(tela)

    # LOOP DO MENU PRINCIPAL
    while True:
        resultado = menu()

        if resultado == "jogar":
            while True:
                game = GameController()
                retorno = game.executar()

                if hasattr(game, "sair_para_menu") and game.sair_para_menu:
                    pygame.init()
                    tela = pygame.display.set_mode((LARGURA_TELA, ALTURA_TELA))
                    break
            
                break

        elif resultado == "como_jogar":
            mostrar_como_jogar(tela)

        elif resultado == "configuracao":
            abrir_configuracoes(tela)

        elif resultado is None:
            pass

        elif resultado == "sair":
            pygame.quit()
            sys.exit()


if __name__ == "__main__":
    main()
