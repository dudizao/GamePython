from abc import ABC, abstractmethod
from typing import Tuple, List
from core.enums import ClassePersonagem
class Entidade(ABC):
    def __init__(self, nome: str, posicao: Tuple[int,int], vida: int = 100):
        self.nome = nome
        self.posicao = posicao
        self.vida_maxima = vida
        self.vida_atual = vida
        self.status = []
        self.sprite = None
        self.animations = {}
        
    def receber_dano(self, dano: int) -> bool:
        self.vida_atual = max(0, self.vida_atual - dano)

        self.dano_flutuante = {
            "valor": dano,
            "tempo": 1000,  # tempo em milissegundos para exibir
            "alpha": 255
        }

        if hasattr(self, "controller") and hasattr(self.controller, "msg"):
            cor = (255, 80, 80) if dano > 0 else (150, 255, 150)
            self.controller.msg.add(f"-{dano} HP ({self.nome})", cor)

        return self.vida_atual <= 0    
        
    def curar(self, qtd: int): self.vida_atual = min(self.vida_maxima, self.vida_atual + qtd)
    @abstractmethod
    def mover(self, nova_posicao: Tuple[int,int]) -> bool: ...
    @abstractmethod
    def interagir(self, alvo) -> bool: ...
    def esta_vivo(self) -> bool: return self.vida_atual > 0
class Combatente(ABC):
    @abstractmethod
    def atacar(self, alvo) -> int: ...
    @abstractmethod
    def defender(self) -> int: ...
    @abstractmethod
    def usar_habilidade(self, alvo) -> bool: ...
class Personagem(Entidade, Combatente):
    def __init__(self, nome: str, posicao: Tuple[int,int], classe: ClassePersonagem):
        super().__init__(nome, posicao)
        self.classe = classe
        self.vida_maxima = 100; self.vida_atual = 100
        self.ataque = 10; self.defesa = 5; self.velocidade = 3
        self.mana = 0; self.mana_maxima = 0
        self.habilidades = []; self.inventario = []
        self.equipamento = {'arma': None, 'armadura': None}
        self.ja_moveu_turno = False; self.pontos_movimento_atual = 0; self.rolou_dados = False
    def mover(self, nova_posicao: Tuple[int,int]) -> bool: self.posicao = nova_posicao; return True
    def interagir(self, alvo) -> bool:
        if hasattr(alvo,'coletar'): return alvo.coletar(self); return False
    def atacar(self, alvo) -> int:
        dano_base = self.ataque
        if self.equipamento['arma']: dano_base += self.equipamento['arma'].bonus_ataque
        dano_final = max(1, dano_base - alvo.defender()); alvo.receber_dano(dano_final); return dano_final
    def defender(self) -> int:
        defesa_base = self.defesa
        if self.equipamento['armadura']: defesa_base += self.equipamento['armadura'].bonus_defesa
        return defesa_base
    def usar_habilidade(self, alvo) -> bool: return False
    def resetar_turno(self):
        self.ja_moveu_turno = False; self.pontos_movimento_atual = 0; self.rolou_dados = False
class Jogador:
    def __init__(self, nome: str):
        self.nome = nome; self.personagens: List[Personagem] = []
        self.ouro = 100; self.pontuacao = 0; self.inventario_global = []
    def adicionar_personagem(self, p: Personagem): self.personagens.append(p)
    def remover_personagem(self, p: Personagem):
        if p in self.personagens: self.personagens.remove(p)
    def get_personagens_vivos(self) -> List[Personagem]:
        return [p for p in self.personagens if p.esta_vivo()]
