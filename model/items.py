import os, pygame
from abc import ABC, abstractmethod
from typing import Tuple
from core.enums import TipoItem
from controller.cartaController import CartaController

class Item(ABC):
    def __init__(self, nome: str, tipo: TipoItem, posicao: Tuple[int,int]):
        self.nome = nome; self.tipo = tipo; self.posicao = posicao; self.sprite = None
    @abstractmethod
    def usar(self, personagem) -> bool: ...
class Tesouro(Item):
    def __init__(self, nome: str, posicao: Tuple[int,int], valor: int):
        super().__init__(nome, TipoItem.TESOURO, posicao); self.valor = valor
    def usar(self, personagem) -> bool: return True
class Armadilha(Item):
    def __init__(self, nome: str, posicao: Tuple[int,int], dano: int):
        super().__init__(nome, TipoItem.ARMADILHA, posicao); self.dano = dano
    def usar(self, personagem) -> bool: personagem.receber_dano(self.dano); return True

class Vida(Item):
    def __init__(self, nome: str, posicao: Tuple[int,int], vida: int):
        super().__init__(nome, TipoItem.VIDA, posicao); self.vida = vida
    def usar(self, personagem) -> bool:
        personagem.curar(self.vida)  
        return True
    
class Carta(Item):
    def __init__(self, nome, posicao, game, descricao="Uma carta misteriosa."):
        super().__init__(nome, TipoItem.CARTA, posicao)
        self.descricao = descricao
        self.game = game
        
        caminho = os.path.join("sprites", "itens", "carta.png")
        try:
            self.sprite = pygame.image.load(caminho).convert_alpha()
            self.sprite = pygame.transform.scale(self.sprite, (32, 32))
        except Exception as e:
            print(f"[AVISO] Erro ao carregar sprite da carta: {e}")
            self.sprite = None

    def usar(self, personagem) -> bool:
        from controller.cartaController import CartaController
        controller = CartaController(self.game)
        controller.sortear_carta(personagem)
        return True
    
class CartaSorteAzar:
    def __init__(self, nome, posicao):
        self.nome = nome
        self.posicao = posicao
        self.tipo = "CARTA"
        self.sprite = None
        self.controller = None

    def usar(self, jogador):
        if not self.controller:
            return False
        self.controller.carta_controller.sortear_carta(jogador)
        return True
