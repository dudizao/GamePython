# O Último Roubo — versão Godot

Núcleo de regras (`core/`) separado da interface (`ui/`). O mesmo núcleo vai rodar no cliente (contra bots) e,
depois, no servidor online. Regras completas: [`../docs/especificacao-regras.md`](../docs/especificacao-regras.md).

## Rodar
1. Instale o [Godot 4.7](https://godotengine.org) e abra a pasta `godot/` (ou `godot --path godot`).
2. Na primeira vez: `godot --headless --path godot --import`.
3. F5 no editor abre a abertura e o menu. Em **Jogar**, escolha jogadores, classe e mapa.

Controles: clique numa casa azul para andar · `R` rolar · `E` parar de andar · `C` coletar · `Q` habilidade ·
`1`/`2` poções · `Espaço` passar turno · `Esc` cancela a mira da magia · `F1` regras. No celular, tudo é por toque (veja [`../docs/mobile-build.md`](../docs/mobile-build.md)). Em batalha, use os botões da janela.

## Testes
```
godot --headless --path godot -s tests/run_tests.gd   # regras (núcleo)
godot --headless --path godot -s tests/ui_smoke.gd    # partidas completas pela interface
```

## Estrutura
- `core/` regras: `game_state.gd` (partida), `battle.gd` (batalha), `board.gd`, `hero.gd`, `monster.gd`, `bot.gd`.
- `ui/` interface: `app.gd` (navegação), `splash_screen.gd`, `main_menu.gd`, `setup_screen.gd`, `options_screen.gd`,
  `class_card.gd`, `map_tile.gd`, `menu_background.gd`, `game_screen.gd`, `board_view.gd`, `event_text.gd`, `sfx.gd`.
- `assets/` sprites reaproveitados do jogo em Python.

## Sons
Os arquivos de `assets/audio/*.wav` são gerados por `python3 tools/gen_sfx.py` (rode de dentro de `godot/`).
Para trocar por sons profissionais, substitua os arquivos mantendo os nomes (e `music.wav` para a trilha).

## Animações
Todas são só apresentação (o estado do jogo já está pronto quando elas começam). Ficam em `ui/board_view.gd` (efeitos no
tabuleiro: golpes, mortes, morto-vivo surgindo, mapa fechando em onda, tremor), `ui/dice_overlay.gd` (dado), `ui/game_screen.gd`
(janela de batalha, carta, flash de tela, ritmo dos bots) e `ui/confetti.gd`. O ritmo dos bots é ajustado por `HOLD_SCALE`
(pausas das animações) e `bot_delay` (intervalo entre ações) em `game_screen.gd`; o jogador ainda pode acelerar em
Opções/botão de velocidade.

## Dados 3D
`ui/dice_stage.gd` monta uma cena 3D dentro de um `SubViewport` transparente. Não usa arquivos de modelo: dados e mão são malhas
criadas por código (`dice3d.gd`, `hand3d.gd`). Ajustes de aparência (cores, tamanho, tempos) estão no topo de `dice_stage.gd`.

### Visual da mão e dos dados
`ui/toon.gd` define o material de desenho animado (sombreamento em faixas, luz de contorno e uma linha escura feita com um segundo
passe de malha inflada). Cores da pele e da manga: `SKIN`/`SKIN_SHADE` em `ui/hand3d.gd`; espessura do contorno: parâmetro `line`.

## Personagens 3D

- Modelos `.glb` em `assets/models3d/` (4 classes atuais: guerreiro, mago, ladino, clerigo; extras: arqueiro, paladino, barbaro, bardo, necromante, valquiria). Prévias e lore em `docs/personagens3d/` e `docs/personagens_lore.md`.
- Carregador: `ui/models3d.gd` (`Models3D.make(chave, anim)`, `key_for(classe)`, `play`, `bounds`). Animações após a importação: `idle` e `walk` (em loop). Os modelos usam cor de vértice, então o loader liga `vertex_color_use_as_albedo`.
- Pré-visualização: `godot --path . -s tools/preview_models.gd` (espaço alterna idle/walk, setas giram).
- Monstros: `assets/models3d/monstros/` (slime, lobo, golem em uso — o ogro usa o golem; yeti, esqueleto, polvo e salamandra prontos para novas regras). `Models3D.key_for_monster(tipo)`, `Art.monster_tex(tipo, anim, t)`.
- Uso no jogo: `ui/hero_sprites.gd` renderiza cada modelo uma vez na abertura em 8 quadros (idle/walk) e `Art.hero_tex(classe, anim, t)` entrega o quadro; `ui/hero_portrait.gd` é o retrato animado (cartões, HUD, batalha). O tabuleiro e o fundo do menu desenham os quadros direto. Sem renderizador (headless) ou antes de ficarem prontos, cai nos PNGs antigos.
-  as 6 classes extras não têm regras.

## Tabuleiro vivo

Terreno que muda (gelo que escorrega, lava que se espalha, tempestade avisada), monstros de bioma (yeti, salamandra, polvo, esqueleto) e evento de rodada a cada 3 rodadas. Regras em `docs/especificacao-regras.md`, seção 21; código em `GameState._world_tick` e `Defs`. A interface só reage aos eventos (`storm_warning`, `storm_struck`, `round_event`, `terrain_changed`, `slid`, `status_applied`, `monster_revived`).
