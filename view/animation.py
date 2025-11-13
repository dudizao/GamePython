import pygame

class SimpleAnimation:
    def __init__(self, frames, fps=8, loop=True):
        self.frames = frames[:] if frames else []
        self.fps = fps
        self.loop = loop
        self.frame_ms = 1000 // max(1, fps)
        self.length = len(self.frames)

    def get_frame(self, t_ms):
        if self.length == 0:
            return None
        idx = (t_ms // self.frame_ms)
        if not self.loop:
            idx = min(idx, self.length - 1)
        else:
            idx = idx % self.length
        return self.frames[idx]
