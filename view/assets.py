import os, pygame
from core.constants import SPRITE_CONFIG, TAMANHO_CELULA
from .animation import SimpleAnimation


# --------------------------
# Mapa
# --------------------------
class MapaUnico:
    def __init__(self):
        self.mapa_original = None
        self.mapa_escalado = None
        self.tamanho_atual = TAMANHO_CELULA
        self.largura_mapa = 0
        self.altura_mapa = 0
        self.ativo = False
        self._carregar_mapa()

    def _carregar_mapa(self):
        caminho_mapa = "sprites/mapa.png"
        caminho_sprites = "sprites/terreno"
        if os.path.exists(caminho_mapa):
            try:
                self.mapa_original = pygame.image.load(caminho_mapa)
                self.largura_mapa = self.mapa_original.get_width()
                self.altura_mapa = self.mapa_original.get_height()
                self.ativo = True
                SPRITE_CONFIG['mapa_unico'] = True
                print(f"✅ Mapa único carregado: {caminho_mapa}")
            except Exception as e:
                print(f"❌ Erro ao carregar mapa {caminho_mapa}: {e}")
                self.ativo = False
                SPRITE_CONFIG['mapa_unico'] = False
        else:
            print(f"⚠️ Mapa único não encontrado: {caminho_mapa}")
            self.ativo = False
            SPRITE_CONFIG['mapa_unico'] = False

        if not self.ativo and os.path.exists(caminho_sprites):
            print(f"📁 Usando sprites individuais: {caminho_sprites}")
            self._carregar_sprites_individuais()

    def _carregar_sprites_individuais(self):
        from core.enums import TipoTerreno
        self.sprites_terreno = {}
        m = {
            TipoTerreno.PLANICIE: 'planicie.png',
            TipoTerreno.FLORESTA: 'floresta.png',
            TipoTerreno.MONTANHA: 'montanha.png',
            TipoTerreno.AGUA: 'agua.png',
            TipoTerreno.MASMORRA: 'masmorra.png',
            TipoTerreno.GELO: 'gelo.png',
            TipoTerreno.LAVA: 'lava.png'
        }
        for tipo, nome in m.items():
            caminho = f"sprites/terreno/{nome}"
            try:
                if os.path.exists(caminho):
                    surf = pygame.image.load(caminho)
                    if pygame.display.get_init() and pygame.display.get_surface():
                        try:
                            surf = surf.convert_alpha()
                        except:
                            pass
                    self.sprites_terreno[tipo] = surf
                    print(f"✅ Sprite terreno: {caminho}")
                else:
                    print(f"⚠️ Sprite terreno não encontrado: {caminho}")
            except Exception as e:
                print(f"❌ Erro sprite terreno {caminho}: {e}")

    def obter_celula_mapa(self, x, y, tamanho_celula):
        return None

    def obter_sprite_terreno(self, tipo_terreno, tamanho_celula: int = None):
        if self.ativo:
            return None
        if not hasattr(self, 'sprites_terreno') or tipo_terreno not in self.sprites_terreno:
            return None
        if tamanho_celula is None:
            tamanho_celula = self.tamanho_atual
        sprite_original = self.sprites_terreno[tipo_terreno]
        if SPRITE_CONFIG['qualidade_escala']:
            return pygame.transform.smoothscale(sprite_original, (tamanho_celula, tamanho_celula))
        return pygame.transform.scale(sprite_original, (tamanho_celula, tamanho_celula))


# --------------------------
# Personagens/itens sprites
# --------------------------
class SpriteManager:
    def __init__(self):
        self.sprites_originais = {}
        self.cache_sprites = {}
        self._carregar_sprites()

    def _carregar_sprites(self):
        from core.enums import ClassePersonagem

        # personagens
        personagens = {
            ClassePersonagem.GUERREIRO: 'guerreiro.png',
            ClassePersonagem.MAGO:      'mago.png',
            ClassePersonagem.LADINO:    'ladino.png',
            ClassePersonagem.CLERIGO:   'clerigo.png'
        }
        for classe, nome in personagens.items():
            caminho = f"sprites/personagens/{nome}"
            try:
                if os.path.exists(caminho):
                    surf = pygame.image.load(caminho)
                    if pygame.display.get_init() and pygame.display.get_surface():
                        try:
                            surf = surf.convert_alpha()
                        except:
                            pass
                    self.sprites_originais[f'personagem_{classe.value}'] = surf
                    print(f"✅ Sprite personagem: {caminho}")
            except Exception as e:
                print(f"❌ Erro sprite personagem {caminho}: {e}")

        # itens (agora inclui vida.png)
        for nome in ['tesouro.png', 'armadilha.png', 'vida.png']:
            caminho = f"sprites/itens/{nome}"
            try:
                if os.path.exists(caminho):
                    surf = pygame.image.load(caminho)
                    if pygame.display.get_init() and pygame.display.get_surface():
                        try:
                            surf = surf.convert_alpha()
                        except:
                            pass
                    self.sprites_originais[f'item_{nome}'] = surf
                    print(f"✅ Sprite item: {caminho}")
                else:
                    print(f"⚠️ Sprite item não encontrado: {caminho}")
            except Exception as e:
                print(f"❌ Erro sprite item {caminho}: {e}")

    def _obter_sprite_escalado(self, chave, tamanho):
        if chave not in self.sprites_originais:
            return None
        ch = (chave, tamanho)
        if ch in self.cache_sprites:
            return self.cache_sprites[ch]
        sprite_original = self.sprites_originais[chave]
        sprite_escalado = pygame.transform.smoothscale(sprite_original, tamanho)
        self.cache_sprites[ch] = sprite_escalado
        return sprite_escalado

    def obter_sprite_personagem(self, classe, tamanho=None):
        if tamanho is None:
            tamanho = TAMANHO_CELULA
        chave = f'personagem_{classe.value}'
        return self._obter_sprite_escalado(chave, (tamanho, tamanho))

    def obter_sprite_item(self, nome_arquivo, tamanho=None):
        if tamanho is None:
            tamanho = TAMANHO_CELULA // 2
        chave = f'item_{nome_arquivo}'
        return self._obter_sprite_escalado(chave, (tamanho, tamanho))


# --------------------------
# Helpers de animação (NÍVEL DE MÓDULO)
# --------------------------
def _load_frame_sequence(pasta, tamanho):
    """Carrega frames *.png de uma pasta e redimensiona."""
    if not os.path.isdir(pasta):
        return []
    nomes = sorted([n for n in os.listdir(pasta) if n.lower().endswith(".png")])
    frames = []
    for n in nomes:
        p = os.path.join(pasta, n)
        try:
            img = pygame.image.load(p).convert_alpha()
            if tamanho:
                img = pygame.transform.smoothscale(img, (tamanho, tamanho))
            frames.append(img)
        except Exception:
            pass
    return frames


def obter_animacao_personagem(classe, tipo_anim, tamanho=64, fps=8):
    """
    Procura por frames em:
      sprites/personagens_anim/<classe>/<tipo_anim>/*.png
    Ex.: sprites/personagens_anim/guerreiro/walk/frame_01.png
    """
    classe_nome = getattr(classe, 'value', None)
    if isinstance(classe_nome, str):
        classe_nome = classe_nome.lower()
    else:
        classe_nome = str(classe).lower()

    base = os.path.join("sprites", "personagens_anim", classe_nome, tipo_anim)
    frames = _load_frame_sequence(base, tamanho)
    if not frames:
        return None
    return SimpleAnimation(frames, fps=fps, loop=True)



def obter_animacao_bau(classe, resultado, tamanho=180, fps=10):
    """
    Carrega a animação do personagem abrindo o baú.
    resultado: 'tesouro' ou 'armadilha'
    """
    classe_nome = getattr(classe, 'value', str(classe)).lower()
    base_path = os.path.join("sprites", "personagens_anim", classe_nome, f"open_{resultado}")

    if not os.path.exists(base_path):
        print(f"⚠️ Caminho não encontrado: {base_path}")
        return None

    frames = []
    for arquivo in sorted(os.listdir(base_path)):
        if arquivo.endswith(".png"):
            caminho = os.path.join(base_path, arquivo)
            img = pygame.image.load(caminho).convert_alpha()
            img = pygame.transform.smoothscale(img, (tamanho, tamanho))
            frames.append(img)

    if not frames:
        print(f"⚠️ Nenhum frame encontrado em {base_path}")
        return None

    return SimpleAnimation(frames, fps=fps, loop=False)


# --------------------------
# Instâncias globais
# --------------------------
mapa_unico = MapaUnico()
sprite_manager = SpriteManager()
