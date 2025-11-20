import pygame

class SimpleAnimation:
    def __init__(self, frames, fps=8, loop=False):
        self.frames = frames[:] if frames else []
        self.fps = fps
        self.loop = loop
        self.frame_ms = 1000 // max(1, fps)
        self.length = len(self.frames)

        self.start_time = pygame.time.get_ticks()
        self.finished = False

    def reset(self):
        self.start_time = pygame.time.get_ticks()
        self.finished = False

    def is_finished(self):
        if self.loop:
            return False
        elapsed = pygame.time.get_ticks() - self.start_time
        return elapsed >= (self.length * self.frame_ms)

    def get_current_frame(self):
        if self.length == 0:
            return None

        elapsed = pygame.time.get_ticks() - self.start_time
        idx = elapsed // self.frame_ms

        if self.loop:
            idx = idx % self.length
        else:
            if idx >= self.length:
                idx = self.length - 1
                self.finished = True

        return self.frames[idx]

    # 🔥 MÉTODO DE COMPATIBILIDADE COM O SEU RENDERER
    def get_frame(self, t_ms):
        if self.length == 0:
            return None

        idx = (t_ms // self.frame_ms)

        if not self.loop:
            if idx >= self.length:
                idx = self.length - 1
                self.finished = True
        else:
            idx = idx % self.length
        
        return self.frames[idx]
