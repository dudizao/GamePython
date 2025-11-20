import pygame
import random
from controller.cartaEfeitoController import CartaEfeitoController

class CartaController:
    def __init__(self, game):
        self.game = game
        self.carta_efeito = CartaEfeitoController(game)
        self.font_titulo = pygame.font.SysFont("arial", 40, bold=True)
        self.font_texto = pygame.font.SysFont("arial", 26)
        self.cartas = self._carregar_cartas()

    def _carregar_cartas(self):
        return [
            ("Sorte", "Ganhe 30 de vida!"),
            ("Sorte", "Ganhe 1 troféu extra!"),
            ("Sorte", "Teleporte para uma posição aleatória!"),
            ("Azar", "Perde 25 de vida!"),
            ("Azar", "Perde um turno!"),
            ("Sorte", "Ganhe 50 de vida!"),
            ("Azar", "Perde 15 de vida!"),
            ("Sorte", "Teleporte mágico para lugar seguro!"),
        ]

    def sortear_carta(self, personagem):
        """Sorteia e aplica uma carta ao personagem."""
        tipo, descricao = random.choice(self.cartas)
        self._mostrar_popup(tipo, descricao)
        carta = type("CartaTemp", (), {"descricao": descricao})  # carta temporária
        self.carta_efeito.aplicar_efeito(personagem, carta)

    def _mostrar_popup(self, tipo, descricao):
        """Exibe o popup visual da carta."""
        tela = self.game.tela
        clock = pygame.time.Clock()
        largura, altura = 500, 300
        popup = pygame.Surface((largura, altura), pygame.SRCALPHA)
        popup.fill((0, 0, 0, 200))

        # Borda
        cor_borda = (255, 215, 0) if tipo == "Sorte" else (255, 60, 60)
        pygame.draw.rect(popup, cor_borda, popup.get_rect(), 6, border_radius=20)

        titulo = self.font_titulo.render(f"Carta de {tipo}", True, cor_borda)
        texto = self.font_texto.render(descricao, True, (255, 255, 255))

        tempo_exibicao = 1800  # 1.8 segundos
        inicio = pygame.time.get_ticks()

        while pygame.time.get_ticks() - inicio < tempo_exibicao:
            self.game.renderer.desenhar_tabuleiro()
            self.game.renderer.desenhar_interface()

            tela.blit(popup, (
                (self.game.tela.get_width() - largura) // 2,
                (self.game.tela.get_height() - altura) // 2
            ))
            tela.blit(
                titulo,
                (self.game.tela.get_width() // 2 - titulo.get_width() // 2,
                 self.game.tela.get_height() // 2 - altura // 2 + 40)
            )
            tela.blit(
                texto,
                (self.game.tela.get_width() // 2 - texto.get_width() // 2,
                 self.game.tela.get_height() // 2 - texto.get_height() // 2 + 40)
            )

            pygame.display.flip()
            clock.tick(60)
