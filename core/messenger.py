import pygame
class Mensageiro:
    def __init__(self, fonte_padrao=None):
        self.mensagens = []
        self.fonte = fonte_padrao or pygame.font.Font(None, 32)
        self.margem = 16
        self.altura_caixa = 42
        self.fade_ms = 300
    def add(self, texto, cor=(255,255,255), duracao_ms=1800):
        agora = pygame.time.get_ticks()
        self.mensagens.append({'texto': str(texto),'cor': cor,'ini': agora,'dur': duracao_ms})
    def _calc_alpha(self, restante):
        if restante <= self.fade_ms:
            return int(255 * (max(0, restante) / self.fade_ms))
        return 255
    def draw(self, surface, largura_tela, altura_tela):
        agora = pygame.time.get_ticks()
        self.mensagens[:] = [m for m in self.mensagens if agora - m['ini'] <= m['dur']]
        if not self.mensagens: return
        y = altura_tela - self.margem
        for m in reversed(self.mensagens[-5:]):
            restante = m['dur'] - (agora - m['ini'])
            if restante <= 0: continue
            alpha = self._calc_alpha(restante)
            texto = self.fonte.render(m['texto'], True, m['cor'])
            padding_x = 18
            w = texto.get_width() + padding_x * 2
            h = self.altura_caixa
            x = (largura_tela - w) // 2
            caixa = pygame.Surface((w, h), pygame.SRCALPHA)
            caixa.fill((0,0,0,int(alpha*0.7)))
            import pygame as pg
            pg.draw.rect(caixa, (255,255,255,int(alpha*0.8)), caixa.get_rect(), 2, border_radius=10)
            surface.blit(caixa, (x, y - h))
            texto.set_alpha(alpha)
            surface.blit(texto, (x + padding_x, y - h + (h - texto.get_height()) // 2))
            y -= (h + 8)
