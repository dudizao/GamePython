import random
from typing import List, Tuple
from model.dice import Dado
from core.enums import TipoTerreno, ClassePersonagem

class SistemaMovimento:
    def __init__(self):
        self.movimentos_disponiveis = {}
        self.posicoes_alcancaveis = {}
        self.caminho_atual = []
        self.personagem_movendo = None
    
    def rolar_movimento(self, personagem) -> int:
        pontos_base = Dado.rolar_d6()
        modificador_velocidade = personagem.velocidade - 3
        if personagem.classe == ClassePersonagem.LADINO: 
            modificador_velocidade += 1
        elif personagem.classe == ClassePersonagem.GUERREIRO:
            if personagem.equipamento.get('armadura'): 
                modificador_velocidade -= 1
        pontos_total = max(1, pontos_base + modificador_velocidade)
        self.movimentos_disponiveis[personagem] = pontos_total
        return pontos_total
    
    def calcular_alcance(self, tabuleiro, personagem) -> List[Tuple[int,int]]:
        if personagem not in self.movimentos_disponiveis: 
            return []
        pontos_mov = self.movimentos_disponiveis[personagem]
        posicoes = []
        origem = personagem.posicao
        visitados = set([origem])
        fila = [(origem, 0)]
        
        while fila:
            pos_atual, custo = fila.pop(0)
            if custo <= pontos_mov and pos_atual != origem: 
                posicoes.append(pos_atual)
            if custo < pontos_mov:
                for viz in tabuleiro.get_vizinhos(pos_atual):
                    if viz not in visitados:
                        cel = tabuleiro.get_celula(viz)
                        if cel and self.pode_passar(cel):
                            novo = custo + self.calcular_custo_movimento(cel)
                            if novo <= pontos_mov:
                                visitados.add(viz)
                                fila.append((viz, novo))
        
        self.posicoes_alcancaveis[personagem] = posicoes
        return posicoes
    
    def iniciar_batalha(self, atacante, defensor):
        print(f"⚔️ BATALHA iniciada entre {atacante.nome} e {defensor.nome}!")

        rodadas = 3
        rodadas_info = []
        vitorias_atacante = 0
        vitorias_defensor = 0

        proximo_bonus = getattr(atacante, "proximo_ataque_bonus", 0)
        esquiva_defensor = getattr(defensor, "esquiva_ativa", False)

        for i in range(rodadas):
            dado1 = random.randint(1, 20)
            dado2 = random.randint(1, 20)

            # Cálculo de vencedor da rodada
            if dado1 > dado2:
                vencedor_rodada = atacante
                vitorias_atacante += 1
            elif dado2 > dado1:
                vencedor_rodada = defensor
                vitorias_defensor += 1
            else:
                vencedor_rodada = None

            dano_causado = 0
            texto_resultado = ""
            
            if vencedor_rodada is None:
                texto_resultado = f"Empate na rodada {i+1}!"
            else:
                if vencedor_rodada == atacante:
                    # Atacante venceu a rodada -> defensor recebe dano
                    dano = 10
                    
                    if proximo_bonus:
                        dano += proximo_bonus
                        proximo_bonus = 0
                        if hasattr(atacante, "proximo_ataque_bonus"):
                            atacante.proximo_ataque_bonus = 0
                    
                    if atacante.classe == ClassePersonagem.MAGO:
                        dano += 5

                    if getattr(defensor, "esquiva_ativa", False):
                        texto_resultado = f"{defensor.nome} esquivou da rodada {i+1}!"
                        defensor.esquiva_ativa = False
                        dano = 0
                    else:
                        defensor.receber_dano(dano)
                        texto_resultado = f"⚔ {atacante.nome} venceu a rodada {i+1}! -{dano} HP"
                        dano_causado = dano

                else:
                    # Defensor venceu a rodada -> atacante recebe dano
                    dano = 10
                    
                    if getattr(defensor, "proximo_ataque_bonus", 0):
                        dano += defensor.proximo_ataque_bonus
                        defensor.proximo_ataque_bonus = 0
                    
                    if defensor.classe == ClassePersonagem.MAGO:
                        dano += 5
                    
                    if getattr(atacante, "esquiva_ativa", False):
                        texto_resultado = f"🛡 {atacante.nome} esquivou da rodada {i+1}!"
                        atacante.esquiva_ativa = False
                        dano = 0
                    else:
                        atacante.receber_dano(dano)
                        texto_resultado = f"⚔ {defensor.nome} venceu a rodada {i+1}! -{dano} HP"
                        dano_causado = dano

            rodadas_info.append({
                "rodada": i+1,
                "dado_atacante": dado1,
                "dado_defensor": dado2,
                "vencedor_rodada": vencedor_rodada.nome if vencedor_rodada else None,
                "dano": dano_causado,
                "texto": texto_resultado,
                "atingido": defensor if vencedor_rodada == atacante else atacante if vencedor_rodada == defensor else None
            })

        # Determina vencedor final
        if vitorias_atacante > vitorias_defensor:
            vencedor = atacante
            perdedor = defensor
            msg_final = f"🏆 {atacante.nome} venceu a batalha!"
        elif vitorias_defensor > vitorias_atacante:
            vencedor = defensor
            perdedor = atacante
            msg_final = f"💀 {defensor.nome} venceu a batalha!"
        else:
            vencedor = None
            perdedor = None
            msg_final = "⚔️ A batalha terminou empatada!"

        print(msg_final)

        # Registra para a camada visual/processamento
        self.batalha_em_andamento = {
            "atacante": atacante,
            "defensor": defensor,
            "rodadas": rodadas_info,
            "vitorias_atacante": vitorias_atacante,
            "vitorias_defensor": vitorias_defensor,
            "vencedor": vencedor,
            "perdedor": perdedor
        }
    
    def pode_passar(self, celula) -> bool:
        # REMOVIDO: Bloqueio de ÁGUA - agora é atravessável mas custa mais movimento
        # Permitir passar mesmo com 1 ocupante, se for um personagem (para batalha)
        if len(celula.ocupantes) > 1:
            return False
        return True
    
    def calcular_custo_movimento(self, celula) -> int:
        custos = {
            TipoTerreno.PLANICIE: 1, 
            TipoTerreno.FLORESTA: 2, 
            TipoTerreno.MONTANHA: 3, 
            TipoTerreno.MASMORRA: 1, 
            TipoTerreno.AGUA: 3,  # ALTERADO: Água custa 3 pontos (nadar é difícil)
            TipoTerreno.LAVA: 2, 
            TipoTerreno.GELO: 2  # ALTERADO: Gelo custa 2 pontos
        }
        return custos.get(celula.tipo_terreno, 1)
    
    def calcular_caminho(self, tabuleiro, origem, destino):
        if origem == destino: 
            return [destino]
        
        visitados = set()
        fila = [(origem, [origem], 0)]
        
        while fila:
            fila.sort(key=lambda x: x[2] + self.distancia_manhattan(x[0], destino))
            pos, cam, custo = fila.pop(0)
            
            if pos == destino: 
                return cam
            if pos in visitados: 
                continue
            
            visitados.add(pos)
            
            for viz in tabuleiro.get_vizinhos(pos):
                if viz not in visitados:
                    cel = tabuleiro.get_celula(viz)
                    if cel and self.pode_passar(cel):
                        novo = custo + self.calcular_custo_movimento(cel)
                        fila.append((viz, cam + [viz], novo))
        
        return []
    
    def distancia_manhattan(self, a, b) -> int: 
        return abs(a[0] - b[0]) + abs(a[1] - b[1])
    
    def mover_personagem(self, tabuleiro, personagem, destino) -> bool:
        if personagem not in self.movimentos_disponiveis: 
            return False
        if destino not in self.posicoes_alcancaveis.get(personagem, []): 
            return False
        
        caminho = self.calcular_caminho(tabuleiro, personagem.posicao, destino)
        if not caminho: 
            return False
        
        custo = 0
        for i in range(1, len(caminho)):
            cel = tabuleiro.get_celula(caminho[i])
            custo += self.calcular_custo_movimento(cel)
        
        if custo > self.movimentos_disponiveis[personagem]: 
            return False
        
        # Remove da célula atual
        atual = tabuleiro.get_celula(personagem.posicao)
        if atual: 
            atual.remover_ocupante(personagem)
        
        # Atualiza posição
        personagem.posicao = destino
        dest = tabuleiro.get_celula(destino)
        
        # Inicializa flag de batalha
        houve_batalha = False
        
        if dest:
            # Verifica se há outro personagem na célula de destino (batalha)
            for oc in dest.ocupantes:
                if hasattr(oc, 'classe') and oc != personagem:
                    houve_batalha = True
                    self.iniciar_batalha(personagem, oc)
                    
                    # Posta evento de batalha
                    if hasattr(self, "batalha_em_andamento"):
                        from pygame import event, USEREVENT
                        event.post(event.Event(USEREVENT, {"tipo": "batalha"}))
                    break
            
            # SEMPRE adiciona o atacante à célula
            # (Ele só será removido depois se morrer na batalha)
            dest.adicionar_ocupante(personagem)
            
            # Dano por terreno perigoso (só se não houve batalha)
            if not houve_batalha and dest.tipo_terreno.name in ("LAVA", "GELO", "AGUA"):
                # Dano por terreno
                if dest.tipo_terreno.name == "LAVA":
                    dano = 5
                    msg = "lava"
                elif dest.tipo_terreno.name == "GELO":
                    dano = 3
                    msg = "gelo"
                elif dest.tipo_terreno.name == "AGUA":
                    dano = 2
                    msg = "água"
                else:
                    dano = 0
                    msg = ""
                
                if dano > 0:
                    personagem.receber_dano(dano)
                    print(f"{personagem.nome} sofreu {dano} de dano por {msg}")
                    
                    try:
                        if hasattr(personagem, "controller") and hasattr(personagem.controller, "msg"):
                            personagem.controller.msg.add(
                                f"💧 {personagem.nome} sofreu {dano} de dano por {msg}!",
                                (100, 150, 255) if msg == "água" else (255, 100, 100)
                            )
                    except Exception:
                        pass
        
        # Reduz movimento disponível
        self.movimentos_disponiveis[personagem] -= custo
        self.calcular_alcance(tabuleiro, personagem)
        
        return True
    
    def resetar_movimento(self, personagem):
        self.movimentos_disponiveis.pop(personagem, None)
        self.posicoes_alcancaveis.pop(personagem, None)
    
    def resetar_todos_movimentos(self):
        self.movimentos_disponiveis.clear()
        self.posicoes_alcancaveis.clear()
        self.caminho_atual.clear()
        self.personagem_movendo = None