jogo/
├── main.py                  ← ponto de entrada
├── telaInicial.py           ← tela de início/menu
│
├── core/
│   ├── constants.py         ← define LARGURA_TELA, FPS, cores, tamanhos
│   ├── enums.py             ← enums: classes, tipos de item, etc.
│   └── messenger.py         ← sistema de mensagens entre camadas
│
├── controller/
│   └── game_controller.py   ← lógica principal: turnos, eventos, mapa
│   └── cartaController.py 
    └── cartaEfeitoController.py 
    └── classeController.py 

├── model/
│   ├── board.py             ← tabuleiro (mapa), células, obstáculos, etc.
│   ├── characters.py        ← classes de personagem e jogador
│   ├── items.py             ← tesouros, armadilhas, poções etc.
│   ├── dice.py              ← lógica do dado
│   └── movement.py
    └── cartas.py           ← movimentação no tabuleiro
│
├── view/
│   ├── renderer.py          ← renderiza tela e HUD
│   ├── assets.py            ← sprites e animações
│   └── animation.py         ← efeitos visuais
│
└── sprites/
    ├── mapas/               ← imagens de mapas (mapa1.png, mapa4.png)
    ├── personagens/
    ├── itens/
    └── terreno/

    a.png
    engrenagem.png
