import random

class Dado:
    @staticmethod
    def rolar_d6() -> int:
        return random.randint(1, 20)

    @staticmethod
    def rolar_d20() -> int:
        return random.randint(1, 20)
