import pygame
from core.enums import ClassePersonagem

class ClasseController:
    def __init__(self, game):
        self.game = game
        self.cooldowns = {}

    def aplicar_bonus_iniciais(self, personagem):
        if personagem.classe.name == "GUERREIRO":
            personagem.vida_maxima += 30
            personagem.vida_atual += 30
            personagem.velocidade += 1
        elif personagem.classe.name == "MAGO":
            personagem.velocidade += 1
        elif personagem.classe.name == "LADINO":
            personagem.velocidade += 2
        elif personagem.classe.name == "CLERIGO":
            personagem.vida_maxima += 10
            personagem.vida_atual += 10

    def usar_habilidade(self, personagem):
        agora = pygame.time.get_ticks() / 1000

        tempos_recarga = {
            ClassePersonagem.GUERREIRO: 60,
            ClassePersonagem.MAGO: 90,
            ClassePersonagem.LADINO: 110,
            ClassePersonagem.CLERIGO: 98
        }

        tempo_recarga = tempos_recarga.get(personagem.classe, 10)

        if personagem not in self.cooldowns or agora - self.cooldowns[personagem] >= tempo_recarga:
            self.cooldowns[personagem] = agora
            self._executar_habilidade(personagem)
        else:
            restante = int(tempo_recarga - (agora - self.cooldowns[personagem]))
            self.game.msg.add(f"Habilidade em recarga ({restante}s restantes)", (200, 200, 200))

    def _executar_habilidade(self, personagem):
        if personagem.classe.name == "GUERREIRO":
            self._forca_extra(personagem)
        elif personagem.classe.name == "MAGO":
            self._ataque_magico(personagem)
        elif personagem.classe.name == "LADINO":
            self._esquiva(personagem)
        elif personagem.classe.name == "CLERIGO":
            self._cura_pessoal(personagem)

    def _forca_extra(self, personagem):
        personagem.proximo_ataque_bonus = getattr(personagem, "proximo_ataque_bonus", 0) + 20
        self.game.msg.add(f"{personagem.nome} usou Força Extra! (+20 dano no próximo ataque)", (255, 215, 0))

    def _ataque_magico(self, personagem):
        personagem.proximo_ataque_bonus = getattr(personagem, "proximo_ataque_bonus", 0) + 5
        self.game.msg.add(f"{personagem.nome} lançou Ataque Mágico! (+5 dano por rodada)", (180, 100, 255))

    def _esquiva(self, personagem):
        personagem.esquiva_ativa = True
        self.game.msg.add(f"{personagem.nome} ativou Esquiva! (ignora 1 rodada)", (150, 255, 150))

    def _cura_pessoal(self, personagem):
        cura = 25
        personagem.vida_atual = min(personagem.vida_maxima, personagem.vida_atual + cura)
        self.game.msg.add(f"{personagem.nome} usou Cura Pessoal! (+{cura} de vida)", (100, 255, 100))
