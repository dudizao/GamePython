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
            return 2.5  # Nadar é difícil mas possível
        if self.tipo_terreno == TipoTerreno.MASMORRA:
            return 1.0
        if self.tipo_terreno == TipoTerreno.LAVA:
            return 1.8  # Perigoso mas atravessável (causa dano)
        if self.tipo_terreno == TipoTerreno.GELO:
            return 1.3  # Escorregadio mas atravessável (causa dano leve)
        return 1.0

    def _get_modificador_combate(self) -> float:
        if self.tipo_terreno == TipoTerreno.FLORESTA:
            return 0.8  # Mais fácil se esconder
        if self.tipo_terreno == TipoTerreno.MONTANHA:
            return 1.2  # Vantagem de altura
        if self.tipo_terreno == TipoTerreno.LAVA:
            return 1.3  # Perigoso para ambos
        if self.tipo_terreno == TipoTerreno.GELO:
            return 0.9  # Difícil manter equilíbrio
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

        self.mapa_id = mapa_id or random.randint(1, 15)
        self._criar_tabuleiro()

    def _criar_tabuleiro(self):
        mapa_predefinido = self._obter_mapa_por_id(self.mapa_id)
        for x in range(self.largura):
            for y in range(self.altura):
                tipo = mapa_predefinido.get((x, y), TipoTerreno.PLANICIE)
                self.celulas[(x, y)] = Celula((x, y), tipo)

    def _obter_mapa_por_id(self, mapa_id: int) -> Dict[Tuple[int, int], TipoTerreno]:
        mapas = {
            1: self._mapa_arquipelago(),
            2: self._mapa_cordilheiras(),
            3: self._mapa_floresta_densa(),
            4: self._mapa_reino_central(),
            5: self._mapa_caos_total(),
            6: self._mapa_deserto_oasis(),
            7: self._mapa_caverna_profunda(),
            8: self._mapa_ruinas_antigas(),
            9: self._mapa_vulcao(),
            10: self._mapa_pantano_mistico(),
            11: self._mapa_terras_geladas(),
            12: self._mapa_planicie_real(),
            13: self._mapa_cidade_antiga(),
            14: self._mapa_campos_lava(),
            15: self._mapa_fortaleza_gelo()
        }
        return mapas.get(mapa_id, self._mapa_reino_central())

    # === MAPAS MELHORADOS ===
    
    def _mapa_arquipelago(self):
        """Ilhas cercadas por água com pontes de planície"""
        mapa = {}
        centro_x = self.largura // 2
        centro_y = self.altura // 2
        
        # Preenche com água
        for x in range(self.largura):
            for y in range(self.altura):
                mapa[(x, y)] = TipoTerreno.AGUA
        
        # Cria 4 ilhas principais nos cantos
        ilhas = [
            (3, 3, 4),  # canto superior esquerdo
            (self.largura - 4, 3, 4),  # canto superior direito
            (3, self.altura - 4, 4),  # canto inferior esquerdo
            (self.largura - 4, self.altura - 4, 4)  # canto inferior direito
        ]
        
        for ilha_x, ilha_y, raio in ilhas:
            for x in range(self.largura):
                for y in range(self.altura):
                    dist = ((x - ilha_x)**2 + (y - ilha_y)**2)**0.5
                    if dist <= raio:
                        if dist < 1.5:
                            mapa[(x, y)] = TipoTerreno.MONTANHA
                        elif dist < 3:
                            mapa[(x, y)] = TipoTerreno.FLORESTA
                        else:
                            mapa[(x, y)] = TipoTerreno.PLANICIE
        
        # Pontes conectando as ilhas (horizontal e vertical)
        for x in range(self.largura):
            if centro_y - 1 <= self.altura and centro_y + 1 < self.altura:
                mapa[(x, centro_y)] = TipoTerreno.PLANICIE
                
        for y in range(self.altura):
            if centro_x - 1 <= self.largura and centro_x + 1 < self.largura:
                mapa[(centro_x, y)] = TipoTerreno.PLANICIE
        
        return mapa

    def _mapa_cordilheiras(self):
        """Cadeias de montanhas com vales verdes"""
        mapa = {}
        
        for x in range(self.largura):
            for y in range(self.altura):
                # Cria ondas de montanhas
                onda1 = abs((x + y) % 8 - 4)
                onda2 = abs((x - y) % 6 - 3)
                
                if onda1 <= 1 or onda2 <= 1:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                elif (x + y) % 11 < 2:
                    mapa[(x, y)] = TipoTerreno.AGUA  # Rios nos vales
                elif (x * y) % 13 < 4:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        
        return mapa

    def _mapa_floresta_densa(self):
        """Floresta espessa com clareiras"""
        mapa = {}
        centro_x = self.largura // 2
        centro_y = self.altura // 2
        
        for x in range(self.largura):
            for y in range(self.altura):
                dist_centro = ((x - centro_x)**2 + (y - centro_y)**2)**0.5
                
                # Clareira central
                if dist_centro < 3:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
                # Padrão de floresta densa
                elif (x % 3 != 0 or y % 3 != 0) and random.random() < 0.7:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                # Montanhas esparsas
                elif (x + y) % 9 == 0:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                # Pequenos lagos
                elif random.random() < 0.05:
                    mapa[(x, y)] = TipoTerreno.AGUA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        
        return mapa

    def _mapa_reino_central(self):
        """Reino com castelo central e muralhas"""
        mapa = {}
        centro_x = self.largura // 2
        centro_y = self.altura // 2
        
        for x in range(self.largura):
            for y in range(self.altura):
                dist = max(abs(x - centro_x), abs(y - centro_y))
                
                # Castelo central (masmorra)
                if dist <= 2:
                    mapa[(x, y)] = TipoTerreno.MASMORRA
                # Primeira muralha (montanhas)
                elif dist == 5 or dist == 6:
                    if (x + y) % 3 != 0:  # Deixa algumas aberturas
                        mapa[(x, y)] = TipoTerreno.MONTANHA
                    else:
                        mapa[(x, y)] = TipoTerreno.PLANICIE
                # Fosso
                elif dist == 7:
                    mapa[(x, y)] = TipoTerreno.AGUA
                # Florestas ao redor
                elif dist > 7 and random.random() < 0.3:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        
        return mapa

    def _mapa_caos_total(self):
        """Caos verdadeiro - totalmente aleatório"""
        mapa = {}
        terrenos = [TipoTerreno.PLANICIE, TipoTerreno.FLORESTA, 
                   TipoTerreno.MONTANHA, TipoTerreno.AGUA, TipoTerreno.MASMORRA]
        
        for x in range(self.largura):
            for y in range(self.altura):
                mapa[(x, y)] = random.choice(terrenos)
        
        return mapa

    def _mapa_deserto_oasis(self):
        """Deserto com oásis esparsos"""
        mapa = {}
        
        # Primeiro preenche com planície (deserto)
        for x in range(self.largura):
            for y in range(self.altura):
                mapa[(x, y)] = TipoTerreno.PLANICIE
        
        # Cria 3-4 oásis (água com floresta ao redor)
        num_oasis = random.randint(3, 4)
        for _ in range(num_oasis):
            ox = random.randint(4, self.largura - 5)
            oy = random.randint(4, self.altura - 5)
            
            for x in range(self.largura):
                for y in range(self.altura):
                    dist = ((x - ox)**2 + (y - oy)**2)**0.5
                    if dist < 1.5:
                        mapa[(x, y)] = TipoTerreno.AGUA
                    elif dist < 3:
                        mapa[(x, y)] = TipoTerreno.FLORESTA
        
        # Dunas (montanhas) esparsas
        for x in range(self.largura):
            for y in range(self.altura):
                if (x % 7 == 0 and y % 5 == 0) and mapa[(x, y)] == TipoTerreno.PLANICIE:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
        
        return mapa

    def _mapa_caverna_profunda(self):
        """Sistema de cavernas com túneis"""
        mapa = {}
        
        # Preenche com masmorra (pedra)
        for x in range(self.largura):
            for y in range(self.altura):
                mapa[(x, y)] = TipoTerreno.MASMORRA
        
        # Cria túneis horizontais e verticais
        for i in range(0, self.altura, 3):
            for x in range(self.largura):
                if random.random() < 0.8:
                    mapa[(x, i)] = TipoTerreno.PLANICIE
                    if i + 1 < self.altura:
                        mapa[(x, i + 1)] = TipoTerreno.PLANICIE
        
        for i in range(0, self.largura, 4):
            for y in range(self.altura):
                if random.random() < 0.7:
                    mapa[(i, y)] = TipoTerreno.PLANICIE
        
        # Lagos subterrâneos
        for _ in range(3):
            lx = random.randint(2, self.largura - 3)
            ly = random.randint(2, self.altura - 3)
            for dx in [-1, 0, 1]:
                for dy in [-1, 0, 1]:
                    if 0 <= lx + dx < self.largura and 0 <= ly + dy < self.altura:
                        mapa[(lx + dx, ly + dy)] = TipoTerreno.AGUA
        
        # Cristais (montanhas) brilhantes
        for x in range(self.largura):
            for y in range(self.altura):
                if mapa[(x, y)] == TipoTerreno.MASMORRA and random.random() < 0.08:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
        
        return mapa

    def _mapa_ruinas_antigas(self):
        """Ruínas com estruturas geométricas"""
        mapa = {}
        
        for x in range(self.largura):
            for y in range(self.altura):
                mapa[(x, y)] = TipoTerreno.PLANICIE
        
        # Cria estruturas em forma de quadrados (ruínas)
        for i in range(3, self.largura - 3, 6):
            for j in range(3, self.altura - 3, 6):
                # Paredes das ruínas
                for dx in range(-2, 3):
                    for dy in range(-2, 3):
                        x_pos = i + dx
                        y_pos = j + dy
                        if 0 <= x_pos < self.largura and 0 <= y_pos < self.altura:
                            # Paredes externas
                            if abs(dx) == 2 or abs(dy) == 2:
                                if random.random() < 0.7:  # Algumas paredes quebradas
                                    mapa[(x_pos, y_pos)] = TipoTerreno.MONTANHA
                            # Centro da ruína
                            elif abs(dx) <= 1 and abs(dy) <= 1:
                                if random.random() < 0.3:
                                    mapa[(x_pos, y_pos)] = TipoTerreno.MASMORRA
        
        # Vegetação invadindo
        for x in range(self.largura):
            for y in range(self.altura):
                if mapa[(x, y)] == TipoTerreno.PLANICIE and random.random() < 0.2:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
        
        return mapa

    def _mapa_vulcao(self):
        """Vulcão central com anéis concêntricos"""
        mapa = {}
        centro_x = self.largura // 2
        centro_y = self.altura // 2
        
        for x in range(self.largura):
            for y in range(self.altura):
                dist = ((x - centro_x)**2 + (y - centro_y)**2)**0.5
                
                if dist < 2:
                    mapa[(x, y)] = TipoTerreno.LAVA
                elif dist < 4:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                elif dist < 6:
                    mapa[(x, y)] = TipoTerreno.AGUA
                elif dist < 8 and random.random() < 0.4:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        
        return mapa

    def _mapa_pantano_mistico(self):
        """Pântano com água e florestas densas"""
        mapa = {}
        
        for x in range(self.largura):
            for y in range(self.altura):
                r = random.random()
                # Padrão de xadrez para água
                if (x + y) % 5 < 2:
                    mapa[(x, y)] = TipoTerreno.AGUA
                elif r < 0.4:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                elif r < 0.5:
                    mapa[(x, y)] = TipoTerreno.MASMORRA  # Árvores mortas
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        
        return mapa

    def _mapa_terras_geladas(self):
        """Tundra gelada com montanhas nevadas"""
        mapa = {}
        
        for x in range(self.largura):
            for y in range(self.altura):
                # Cria cordilheiras diagonais
                if (x + y) % 6 < 2:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                elif (x - y) % 8 < 2:
                    mapa[(x, y)] = TipoTerreno.GELO
                elif random.random() < 0.15:
                    mapa[(x, y)] = TipoTerreno.AGUA  # Lagos congelados
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        
        return mapa

    def _mapa_planicie_real(self):
        """Planície aberta com características suaves"""
        mapa = {}
        
        for x in range(self.largura):
            for y in range(self.altura):
                r = random.random()
                if r < 0.75:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
                elif r < 0.85:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                elif r < 0.90:
                    mapa[(x, y)] = TipoTerreno.AGUA
                else:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
        
        return mapa

    def _mapa_cidade_antiga(self):
        """Cidade em grid com ruas e praças"""
        mapa = {}
        
        for x in range(self.largura):
            for y in range(self.altura):
                # Ruas (água representa canais)
                if x % 6 == 0 or y % 6 == 0:
                    mapa[(x, y)] = TipoTerreno.AGUA
                # Praças centrais
                elif (x % 6 == 3 and y % 6 == 3):
                    mapa[(x, y)] = TipoTerreno.PLANICIE
                # Edifícios (masmorra)
                elif random.random() < 0.3:
                    mapa[(x, y)] = TipoTerreno.MASMORRA
                # Parques (floresta)
                elif random.random() < 0.2:
                    mapa[(x, y)] = TipoTerreno.FLORESTA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        
        return mapa

    def _mapa_campos_lava(self):
        """Campos vulcânicos perigosos"""
        mapa = {}
        
        for x in range(self.largura):
            for y in range(self.altura):
                # Bordas seguras
                if x == 0 or y == 0 or x == self.largura - 1 or y == self.altura - 1:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                # Rios de lava
                elif (x % 5 == 2 or y % 7 == 3):
                    mapa[(x, y)] = TipoTerreno.LAVA
                # Rochas vulcânicas
                elif random.random() < 0.3:
                    mapa[(x, y)] = TipoTerreno.MONTANHA
                # Cavernas
                elif random.random() < 0.15:
                    mapa[(x, y)] = TipoTerreno.MASMORRA
                else:
                    mapa[(x, y)] = TipoTerreno.PLANICIE
        
        return mapa

    def _mapa_fortaleza_gelo(self):
        """Fortaleza congelada com muralhas de gelo"""
        mapa = {}
        centro_x = self.largura // 2
        centro_y = self.altura // 2
        
        for x in range(self.largura):
            for y in range(self.altura):
                dist = max(abs(x - centro_x), abs(y - centro_y))
                
                # Núcleo de gelo
                if dist <= 1:
                    mapa[(x, y)] = TipoTerreno.GELO
                # Muralhas congeladas
                elif dist == 4 or dist == 5:
                    if (x + y) % 2 == 0:
                        mapa[(x, y)] = TipoTerreno.MONTANHA
                    else:
                        mapa[(x, y)] = TipoTerreno.GELO
                # Fosso congelado
                elif dist == 6:
                    mapa[(x, y)] = TipoTerreno.AGUA
                # Tundra externa
                elif random.random() < 0.3:
                    mapa[(x, y)] = TipoTerreno.GELO
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