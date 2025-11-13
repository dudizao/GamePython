import os
import pygame

class GifPlayer:
    def __init__(self, gif_path, size=(200, 200)):
        try:
            from PIL import Image, ImageSequence
        except ImportError:
            print("Biblioteca Pillow não instalada. Rode: pip install pillow")
            self.frames = []
            return

        if not os.path.exists(gif_path):
            print(f"⚠️ GIF não encontrado: {gif_path}")
            self.frames = []
            return

        pil_img = Image.open(gif_path)
        self.frames = []
        for frame in ImageSequence.Iterator(pil_img):
            mode = frame.mode
            size_orig = frame.size
            data = frame.tobytes()
            frame_surface = pygame.image.fromstring(data, size_orig, mode).convert_alpha()
            frame_surface = pygame.transform.smoothscale(frame_surface, size)
            self.frames.append(frame_surface)

        self.index = 0
        self.playing = False
        self.fps = 24
        self.last_update = 0

    def play(self):
        """Inicia a reprodução do GIF"""
        self.playing = True
        self.index = 0
        self.last_update = pygame.time.get_ticks()

    def draw(self, surface, center):
        """Desenha o frame atual do GIF na tela"""
        if not self.playing or not self.frames:
            return False

        now = pygame.time.get_ticks()
        if now - self.last_update > 1000 / self.fps:
            self.index += 1
            self.last_update = now
            if self.index >= len(self.frames):
                self.playing = False
                return False

        frame = self.frames[self.index]
        rect = frame.get_rect(center=center)
        surface.blit(frame, rect)
        return True
