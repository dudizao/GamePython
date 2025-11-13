import random

class Carta:
    def __init__(self, nome, tipo, descricao, efeito=None):
        self.nome = nome
        self.tipo = tipo 
        self.descricao = descricao
        self.efeito = efeito 


# === LISTA DE CARTAS DISPONÍVEIS ===
CARTAS_DISPONIVEIS = [
    # ===== SORTE =====
    Carta("Avance 5 Casas", "SORTE", "Você encontrou um atalho seguro e avança 5 casas!"),
    Carta("Cura Mágica", "SORTE", "Uma poção misteriosa cura 20 pontos de vida."),
    Carta("Tesouro Perdido", "SORTE", "Você encontrou um tesouro esquecido e ganha um item extra!"),
    Carta("Movimento Extra", "SORTE", "O vento sopra a seu favor — jogue o dado novamente!"),
    Carta("Bênção dos Deuses", "SORTE", "Os deuses sorriem para você — recupere toda a vida!"),
    Carta("Troca da Fortuna", "SORTE", "Troque de posição com outro jogador aleatoriamente."),
    Carta("Proteção Divina", "SORTE", "Você será imune ao próximo efeito de azar."),
    Carta("Explorador", "SORTE", "Você pode se mover livremente por 2 turnos sem restrições."),
    Carta("Sorte em Dobro", "SORTE", "Na próxima rodada, seus ganhos serão dobrados."),
    Carta("Aliado Invisível", "SORTE", "Um aliado oculto o ajuda: +10 HP e +1 movimento."),

    # ===== AZAR =====
    Carta("Volte 4 Casas", "AZAR", "Você tropeçou em uma armadilha e recua 4 casas!"),
    Carta("Perdeu um Turno", "AZAR", "Você caiu em um buraco e ficará preso por um turno."),
    Carta("Tempestade", "AZAR", "Uma tempestade reduz sua visibilidade — perca o próximo movimento."),
    Carta("Roubo Misterioso", "AZAR", "Um ladrão rouba um de seus tesouros."),
    Carta("Doença Repentina", "AZAR", "Você perde 15 pontos de vida!"),
    Carta("Explosão", "AZAR", "Uma erupção inesperada faz você perder 20 HP."),
    Carta("Confusão Mental", "AZAR", "Seu próximo movimento será aleatório."),
    Carta("Caminho Quebrado", "AZAR", "O caminho à frente desabou. Você ficará parado por 1 turno."),
    Carta("Maldição Ancestral", "AZAR", "Os espíritos te amaldiçoam: reduza seu HP pela metade."),
    Carta("Invasão de Monstros", "AZAR", "Monstros atacam! Perde 10 HP e 1 item do inventário.")
]
