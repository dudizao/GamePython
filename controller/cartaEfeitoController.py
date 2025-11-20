import random
import re

class CartaEfeitoController:
    def __init__(self, game_controller):
        self.game = game_controller

    def aplicar_efeito(self, personagem, carta):
        """Aplica o efeito da carta no personagem."""
        descricao = carta.descricao.lower()

        # ❤️ Ganhar vida
        if "ganhe" in descricao and "vida" in descricao:
            valor = self._extrair_numero(descricao, 20)
            personagem.vida_atual = min(personagem.vida_atual + valor, personagem.vida_maxima)
            self.game.msg.add(f"❤️ {personagem.nome} ganhou {valor} de vida!", (0, 255, 0))

        # 💀 Perder vida
        elif "perde" in descricao and "vida" in descricao:
            valor = self._extrair_numero(descricao, 20)
            personagem.vida_atual = max(personagem.vida_atual - valor, 0)
            self.game.msg.add(f"💀 {personagem.nome} perdeu {valor} de vida!", (255, 50, 50))

        # 🏆 Ganhar troféu
        elif "troféu" in descricao or "trofeu" in descricao:
            from model.items import Tesouro
            item = Tesouro("🏆 Tesouro Extra", personagem.posicao, 50)
            personagem.inventario.append(item)
            self.game.msg.add(f"🏆 {personagem.nome} recebeu um troféu extra!", (255, 215, 0))

        # ⏳ Perder turno
        elif "perde" in descricao and "turno" in descricao:
            self.game.msg.add(f"⏳ {personagem.nome} perdeu um turno!", (255, 255, 0))
            self.game._finalizar_turno()

        # 💫 Teleporte
        elif "teleporte" in descricao or "mova" in descricao:
            celulas = [pos for pos, cel in self.game.tabuleiro.celulas.items()
                       if not cel.esta_ocupado() and cel.tipo_terreno.name != 'AGUA']
            if celulas:
                nova_pos = random.choice(celulas)
                self.game.tabuleiro.get_celula(personagem.posicao).remover_ocupante(personagem)
                self.game.tabuleiro.get_celula(nova_pos).adicionar_ocupante(personagem)
                personagem.posicao = nova_pos
                self.game.msg.add(f"💫 {personagem.nome} foi teleportado!", (173, 216, 230))

    def _extrair_numero(self, texto, padrao=10):
        """Extrai o primeiro número encontrado na descrição."""
        numeros = re.findall(r'\d+', texto)
        return int(numeros[0]) if numeros else padrao
