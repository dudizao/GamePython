from enum import Enum
class TipoTerreno(Enum):
    PLANICIE = "planicie"
    FLORESTA = "floresta"
    MONTANHA = "montanha"
    AGUA = "agua"
    MASMORRA = "masmorra"
    LAVA = "lava"
    GELO = "gelo"
class TipoItem(Enum):
    TESOURO = "tesouro"
    ARMADILHA = "armadilha"
    VIDA = "vida"
    CARTA = "carta"
class ClassePersonagem(Enum):
    GUERREIRO = "guerreiro"
    MAGO = "mago"
    LADINO = "ladino"
    CLERIGO = "clerigo"
