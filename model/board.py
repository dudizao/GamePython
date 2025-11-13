from typing import Tuple, Dict
import random
from core.enums import TipoTerreno
from core.constants import CORES, TAMANHO_CELULA
from view.assets import mapa_unico


class Celula:
    def __init__(self, posicao: Tuple[int, int], tipo_terreno: TipoTerreno = TipoTerreno.PLANICIE):
        self.posicao = posicao
        self.tipo_terreno = tipo_terreno
        self.ocupantes = []
        self.itens = []
        self.visitado = False
        self.sprite_celula = None

        self.modificador_movimento = self._get_modificador_movimento()
        self.modificador_combate = self._get_modificador_combate()
        self._carregar_sprite_celula()

    def _carregar_sprite_celula(self):
        x, y = self.posicao
        if mapa_unico.ativo:
            self.sprite_celula = mapa_unico.obter_celula_mapa(x, y, TAMANHO_CELULA)
        else:
            self.sprite_celula = mapa_unico.obter_sprite_terreno(self.tipo_terreno, TAMANHO_CELULA)

    def _get_modificador_movimento(self) -> float:
        if self.tipo_terreno == TipoTerreno.PLANICIE:
            return 1.0
        if self.tipo_terreno == TipoTerreno.FLORESTA:
            return 1.5
        if self.tipo_terreno == TipoTerreno.MONTANHA:
            return 2.0
        if self.tipo_terreno == TipoTerreno.AGUA:
            return float('inf')
        if self.tipo_terreno == TipoTerreno.MASMORRA:
            return 1.0
        return 1.0

    def _get_modificador_combate(self) -> float:
        if self.tipo_terreno == TipoTerreno.FLORESTA:
            return 0.8
        if self.tipo_terreno == TipoTerreno.MONTANHA:
            return 1.2
        return 1.0

    def adicionar_ocupante(self, entidade):
        self.ocupantes.append(entidade)

    def remover_ocupante(self, entidade):
        if entidade in self.ocupantes:
            self.ocupantes.remove(entidade)

    def adicionar_item(self, item):
        self.itens.append(item)

    def remover_item(self, item):
        if item in self.itens:
            self.itens.remove(item)

    def esta_ocupado(self) -> bool:
        return len(self.ocupantes) > 0

    def get_cores_terreno(self):
        cores = {
            TipoTerreno.PLANICIE: (CORES['verde'], CORES['verde_escuro']),
            TipoTerreno.FLORESTA: (CORES['verde_escuro'], CORES['preto']),
            TipoTerreno.MONTANHA: (CORES['marrom'], CORES['cinza']),
            TipoTerreno.AGUA: (CORES['azul'], CORES['azul_claro']),
            TipoTerreno.MASMORRA: (CORES['preto'], CORES['cinza']),
            TipoTerreno.LAVA: ((255, 80, 0), (180, 30, 0)),
            TipoTerreno.GELO: ((180, 240, 255), (130, 200, 255))     
            
        }
        return cores.get(self.tipo_terreno, (CORES['cinza'], CORES['preto']))

    def obter_sprite_celula(self):
        return self.sprite_celula


class Tabuleiro:
    def __init__(self, largura: int, altura: int, mapa_id: int = None):
        self.largura = largura
        self.altura = altura
        self.celulas: Dict[Tuple[int, int], Celula] = {}

        self.mapa_id = mapa_id or random.randint(1, 13)
        self._criar_tabuleiro()

    def _criar_tabuleiro(self):
        mapa_predefinido = self._obter_mapa_por_id(self.mapa_id)
        for x in range(self.largura):
            for y in range(self.altura):
                tipo = mapa_predefinido.get((x, y), TipoTerreno.PLANICIE)
                self.celulas[(x, y)] = Celula((x, y), tipo)

    # === SELETOR DE MAPAS ===
    def _obter_mapa_por_id(self, mapa_id: int) -> Dict[Tuple[int, int], TipoTerreno]:
        mapas = {
            1: self._mapa_ilhas(),
            2: self._mapa_montanhoso(),
            3: self._mapa_forestado(),
            4: self._mapa_misto(),
            5: self._mapa_caos_total(),
            6: self._mapa_deserto(),
            7: self._mapa_caverna(),
            8: self._mapa_ruinas(),
            9: self._mapa_vulcao(),
            10: self._mapa_pantano(),
            11: self._mapa_gelado(),
            12: self._mapa_planicie_real(),
            13: self._mapa_cidade_antiga(),
            14: self._mapa_lava(),
            15: self._mapa_nevado()
        }
        return mapas.get(mapa_id, self._mapa_misto())

    # === MAPAS PADRÕES ===
    def _mapa_ilhas(self):
        mapa = {}
        for x in range(self.largura):
            for y in range(self.altura):
                if x in [0, self.largura - 1] or y in [0, self.altura - 1]:
                    mapa[(x, y)] = TipoTerreno.AGUA
                elif (x + y) % 5 == 0:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                elif (x * y) % 7 == 0:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        return mapa

    def _mapa_montanhoso(self):
        mapa = {}
        for x in range(self.largura):
            for y in range(self.altura):
                if y % 4 == 0:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                elif x % 6 == 0:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                elif x < 2 or y < 2 or x > self.largura - 3 or y > self.altura - 3:
                    mapa[(x, y)] = TipoTerreno.AGUA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        return mapa

    def _mapa_forestado(self):
        mapa = {}
        for x in range(self.largura):
            for y in range(self.altura):
                if (x % 3 == 0 and y % 2 == 0) or (x + y) % 4 == 0:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                elif (x + y) % 10 == 0:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        return mapa

    def _mapa_misto(self):
        mapa = {}
        for x in range(self.largura):
            for y in range(self.altura):
                r = random.random()
                if x == 0 or y == 0 or x == self.largura - 1 or y == self.altura - 1:
                    mapa[(x, y)] = TipoTerreno.AGUA
                elif r < 0.10:
                    mapa[(x, y)] = TipoTerreno.AGUA
                elif r < 0.25:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                elif r < 0.45:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        return mapa

    # === MAPAS EXTRAS (5–13) ===
    def _mapa_caos_total(self):
        mapa = {}
        for x in range(self.largura):
            for y in range(self.altura):
                tipo = random.choice(list(TipoTerreno))
                mapa[(x, y)] = tipo
        return mapa

    def _mapa_deserto(self):
        mapa = {}
        for x in range(self.largura):
            for y in range(self.altura):
                r = random.random()
                if x == 0 or y == 0 or x == self.largura - 1 or y == self.altura - 1:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                elif r < 0.05:
                    mapa[(x, y)] = TipoTerreno.AGUA
                elif r < 0.15:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        return mapa

    def _mapa_caverna(self):
        mapa = {}
        for x in range(self.largura):
            for y in range(self.altura):
                if x % 7 == 0 or y % 5 == 0:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                elif random.random() < 0.1:
                    mapa[(x, y)] = TipoTerreno.AGUA
                else:
                    mapa[(x, y)] = TipoTerreno.MASMORRA
        return mapa

    def _mapa_ruinas(self):
        mapa = {}
        for x in range(self.largura):
            for y in range(self.altura):
                if (x + y) % 6 == 0:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                elif random.random() < 0.1:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        return mapa

    def _mapa_vulcao(self):
        mapa = {}
        centro_x = self.largura // 2
        centro_y = self.altura // 2
        for x in range(self.largura):
            for y in range(self.altura):
                dist = abs(x - centro_x) + abs(y - centro_y)
                if dist < 3:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                elif 3 <= dist < 6:
                    mapa[(x, y)] = TipoTerreno.AGUA
                elif random.random() < 0.1:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        return mapa

    def _mapa_pantano(self):
        mapa = {}
        for x in range(self.largura):
            for y in range(self.altura):
                r = random.random()
                if r < 0.15:
                    mapa[(x, y)] = TipoTerreno.AGUA
                elif r < 0.35:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        return mapa

    def _mapa_gelado(self):
        mapa = {}
        for x in range(self.largura):
            for y in range(self.altura):
                if x % 5 == 0 or y % 7 == 0:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                elif random.random() < 0.1:
                    mapa[(x, y)] = TipoTerreno.AGUA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        return mapa

    def _mapa_planicie_real(self):
        mapa = {}
        for x in range(self.largura):
            for y in range(self.altura):
                if random.random() < 0.05:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                elif random.random() < 0.15:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        return mapa

    def _mapa_cidade_antiga(self):
        mapa = {}
        for x in range(self.largura):
            for y in range(self.altura):
                if (x % 6 == 0 or y % 6 == 0):
                    mapa[(x, y)] = TipoTerreno.AGUA
                elif (x + y) % 9 == 0:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                elif random.random() < 0.1:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        return mapa
    
    def _mapa_lava(self):
        mapa = {}
        for x in range(self.largura):
            for y in range(self.altura):
                if x == 0 or y == 0 or x == self.largura - 1 or y == self.altura - 1:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                elif random.random() < 0.15:
                    mapa[(x, y)] = TipoTerreno.LAVA
                elif random.random() < 0.25:
                    mapa[(x, y)] = TipoTerreno.MASMORRA
                elif random.random() < 0.3:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        return mapa


    def _mapa_nevado(self):
        mapa = {}
        for x in range(self.largura):
            for y in range(self.altura):
                if x == 0 or y == 0 or x == self.largura - 1 or y == self.altura - 1:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                elif random.random() < 0.20:
                    mapa[(x, y)] = TipoTerreno.GELO
                elif random.random() < 0.30:
                    mapa[(x, y)] = TipoTerreno.AGUA
                elif random.random() < 0.35:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        return mapa

    # === FUNÇÕES PADRÃO ===
    def get_celula(self, posicao):
        return self.celulas.get(posicao)

    def get_vizinhos(self, posicao):
        x, y = posicao
        vizinhos = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
        return [pos for pos in vizinhos if pos in self.celulas]
