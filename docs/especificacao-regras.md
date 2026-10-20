# O Último Roubo — Especificação das regras (extraída do código Python)

Fonte: `main.py`, `core/`, `model/`, `controller/`. Descreve o comportamento **atual**, incluindo
bugs, para servir de base ao port para Godot. Itens marcados **[BUG]** devem ser decididos antes
de portar (corrigir ou preservar).

## 1. Visão geral
- Tabuleiro 2D em grade, por turnos. Hoje: **1 jogador humano controla 4 heróis** (hot-seat),
  um por classe. Não há bots nem rede.
- Condição de vitória: um herói acumular **5 tesouros** (troféus) no inventário.
- Cada turno é de **um herói**, ordem sorteada no início, ciclando e pulando os mortos.
- Tempo máximo por turno: **35 s** (`TURNO_DUR_MS`); estourou → turno encerra.

## 2. Tabuleiro
- Tamanho atual: **43 × 25 células** (derivado da resolução 1400×800; deve virar parâmetro).
- Vizinhança de 4 direções (sem diagonal).
- Terrenos: `PLANICIE, FLORESTA, MONTANHA, AGUA, MASMORRA, LAVA, GELO`.

| Terreno | Custo de movimento | Efeito |
|---|---|---|
| Planície | 1 | — |
| Floresta | 2 | — |
| Montanha | 3 | — |
| Masmorra | 1 | — |
| Gelo | 1 | −5 HP ao entrar |
| Lava | 2 | −5 HP ao entrar |
| Água | intransponível | — |

- `modificador_movimento` e `modificador_combate` existem na célula mas **não são usados** [BUG/código morto].
- 15 mapas selecionáveis (nomes em `game_controller.selecionar_mapa_visual`). Vários são gerados
  com `random` a cada partida (misto, caos, deserto, caverna, ruínas, vulcão, pântano, gelado,
  planície real, cidade antiga, lava, nevado); 1–4 têm padrão fixo (ilhas, montanhoso, forestado)
  exceto o 4 que é aleatório. Mapa 5 usa qualquer terreno aleatório (pode gerar mapa intransitável).
- Posições iniciais: meio de cada uma das 4 bordas, deslocadas para dentro até achar célula
  não-água e livre.

## 3. Personagens
- Atributos base: vida 100, ataque 10, defesa 5, velocidade 3 (ataque/defesa não entram em nada
  do combate atual).
- Classes e bônus iniciais (`ClasseController.aplicar_bonus_iniciais`):
  - Guerreiro: +30 vida máx, +1 velocidade
  - Mago: +1 velocidade
  - Ladino: +2 velocidade
  - Clérigo: +10 vida máx
- **[BUG]** `aplicar_bonus_iniciais` é chamado **fora** do loop de criação, então só o **último
  herói (Clérigo)** recebe bônus. Decidir: aplicar a todos (intenção provável).
- Morte: vida ≤ 0. Remoção do herói só ocorre dentro da coleta de item (ver §6) — **[BUG]**
  um herói que morre em batalha ou por lava/gelo continua no tabuleiro até coletar algo.

## 4. Fluxo de turno
Fases: `selecao → movimento → acao → (fim do turno)`.
1. **Seleção:** o herói da vez rola o dado (botão ou tecla R).
2. **Movimento:** gasta os pontos para andar célula a célula (setas) até zerar ou até Enter.
3. **Ação:** coletar item na própria célula (Espaço / clique), usar habilidade (X), ou Enter para passar.
4. **Fim:** reseta movimento/flags, passa ao próximo herói vivo. Se não restar nenhum, o jogo fica sem herói selecionado.

Dado de movimento: `max(1, d6 + (velocidade − 3) + bônus)`, com bônus +1 para Ladino e
−1 para Guerreiro com armadilha equipada (equipamento hoje nunca é preenchido).

Alcance: BFS por custo acumulado, descartando água e células com **mais de 1 ocupante**. Como usa
`visitados` na primeira visita, não é um Dijkstra exato — pode subestimar alcance por rota de menor custo.

## 5. Combate (PvP por dado)
Disparado quando um herói **entra numa célula ocupada** por outro herói.
- 3 rodadas; em cada uma, cada lado rola d20. Maior vence a rodada; o perdedor leva **10 de dano**;
  empate não causa dano.
- Vence a batalha quem ganhar mais rodadas; empate geral = sem vencedor. Não há morte forçada nem
  roubo de itens.
- Após a batalha, os dois ficam na mesma célula.
- **[BUG]** a animação sorteia seus próprios d20 e não mostra os valores reais da batalha, e a
  checagem de quem foi atingido (`"" in resultado`) é sempre verdadeira.
- Atributos de ataque/defesa, terreno e classes não influenciam o combate.

## 6. Itens e coleta
Tipos: Tesouro (valor 50), Armadilha (20 de dano), Vida (+20 HP), Carta misteriosa.
- Coleta é manual, na célula do herói, na fase de ação (tecla Espaço / botão).
- Tesouro/Vida/Armadilha: aplicam efeito, vão para o inventário, o mapa **repõe itens até 10**.
- Carta: sorteia efeito (§7), é removida do mapa; **não** dispara reposição.
- Vitória: checada após coletar — ≥ 5 tesouros no inventário.
- Morte por armadilha: remove o herói e passa o turno.
- **[BUG] Geração inicial** (`_gerar_itens`): os limiares são inconsistentes, o resultado é
  ~50% cartas e ~50% armadilhas, **sem tesouros nem vidas** na geração inicial.
- Reposição (`repor_itens`): 10% vida, 30% tesouro, 50% carta, 10% armadilha.
  Logo, tesouros só aparecem após alguém coletar um item, ou via carta "troféu extra".

## 7. Cartas
Há duas listas; **só a de `CartaController` é usada**:

| Tipo | Efeito |
|---|---|
| Sorte | +30 vida |
| Sorte | +1 troféu extra |
| Sorte | teleporte para célula livre e não-água aleatória |
| Azar | −25 vida |
| Azar | perde o turno |
| Sorte | +50 vida |
| Azar | −15 vida |
| Sorte | teleporte "para lugar seguro" (mesmo efeito do teleporte aleatório) |

- O efeito é aplicado **interpretando o texto da descrição** com palavras-chave e regex
  (`CartaEfeitoController`). Frágil; no port deve virar dados estruturados (`tipo`, `valor`).
- `model/cartas.py` define 20 cartas (10 sorte / 10 azar, ex.: "Avance 5 Casas", "Maldição
  Ancestral") **nunca usadas** — candidatas a conteúdo futuro.
- Tipo de item `"CARTA"` é comparado como string em um lugar e como enum `TipoItem.CARTA` em
  outro. Inconsistência a unificar.

## 8. Habilidades de classe (tecla X)
Cooldown em **segundos reais**: Guerreiro 60, Mago 90, Ladino 110, Clérigo 98.
- Guerreiro "Força Extra", Mago "Ataque Mágico", Ladino "Esquiva": **só exibem mensagem, sem efeito**.
- Clérigo "Cura Pessoal": +25 vida. É a única habilidade com efeito real.
- Cooldown por tempo real não faz sentido num jogo por turnos/online → trocar por cooldown em turnos.

## 9. Interface e fluxo de telas (para o port)
Intro → Menu (jogar / como jogar / configurações) → Seleção de mapa → Partida → Tela de vitória.
Pausa (Esc): continuar / menu principal / sair. HUD com 4 retratos (clicáveis para selecionar herói).
Todas as animações (dado, carta, baú, batalha, transição de turno) são **loops bloqueantes** com
`time.delay`/`while` — no port viram máquina de estados / tweens.

## 10. Decisões tomadas para o port (Godot, em `godot/core/`)
- **1 herói por jogador**, 2 a 4 jogadores; classes podem se repetir na sala. Todos contra todos.
- **Bugs corrigidos:** bônus de classe para todos; itens iniciais com a distribuição certa
  (10% vida, 30% tesouro, 50% carta, 10% armadilha); morte remove o herói na hora e solta os
  troféus no chão; cartas viram dados estruturados; animação de batalha deve usar os dados
  reais (eventos `battle_round`); cooldown em turnos; mapa 13 ganhou pontes; regiões
  inalcançáveis viram água; Dijkstra de verdade no alcance.
- **Combate mais complexo:** pontuação da rodada = d20 + bônus. Atacante: ataque/2. Defensor:
  defesa + terreno (floresta +2, montanha +3). Perdedor sofre `ataque do vencedor − defesa/2 +
  margem/4` (mín. 1). Empate de pontuação não causa dano.
- **Habilidades:** Força Extra = +20 de dano no próximo golpe vencido numa batalha. Ataque Mágico =
  15 de dano fixo em herói na mesma linha ou coluna a até 3 células (interpretação de "3 células
  à frente", já que não há direção). Esquiva = ignora todo dano até o início do próximo turno do
  dono. Cura Pessoal = +25 de vida. Recarga em turnos do próprio herói: 2 / 3 / 3 / 3.
- **Fim de jogo:** 5 troféus, ou último herói vivo. Limite de turnos opcional (`max_turns`).
- **Reprodutibilidade:** toda aleatoriedade passa por um RNG com seed (necessário para o servidor).
- Carta de perder turno e reposição de itens agora valem para qualquer item coletado, inclusive carta.

## 11. Em aberto
- Duração: bots levam em média ~450 turnos totais por partida (tabuleiro 43×25 e bot simples).
  Ajustar tamanho do mapa, número de troféus ou itens no balanceamento.
- Interpretação do Ataque Mágico e valores de dano/recarga são propostas, passíveis de ajuste.

## 12. Atualização: progressão, monstros e vitória (partidas rápidas)
- **Vitória:** juntar **todos** os troféus (conjunto fixo de 3, sem reposição) ou **eliminar todos** os outros
  jogadores. Troféu de herói morto cai no chão. O limite de turnos (`max_turns`) é opcional.
- **Tabuleiro** 21×13, 6 itens aleatórios (vida 25 / carta 55 / armadilha 20), 4 monstros.
- **Níveis 1–5** (XP acumulado 25 / 65 / 120 / 190). Ganhos por classe; level up cura 30% da vida máxima.
  Habilidades escalam com o nível; a Esquiva do Ladino recarrega 1 turno mais rápido no nível 3.
- **XP:** monstro (15 / 25 / 40, escalado pelo nível médio dos heróis), +4 por rodada de PvP vencida,
  +30 +10×nível por matar um herói. Carta de "troféu extra" virou "ganhe 25 de XP".
- **Monstros:** slime, lobo, ogro. Andar até a casa deles inicia a luta (até 3 rodadas). Se sobrar monstro,
  o herói recua para a casa de origem e o monstro continua ferido. Não dá para atravessar monstros.
  Derrotado: 40% de chance de largar poção de vida; reaparece longe dos heróis.
- **Ainda não feito:** batalha com ações (defender, item, fugir), inventário/poções de força, equipamentos,
  reaparecimento após a morte. **Decidido: não haverá chefe final.**

## 13. Mapa que fecha (estilo Bomberman)
- Cada **rodada** é uma volta completa da ordem de turnos. A partir da rodada 5, e a cada 2 rodadas, o anel mais
  externo do tabuleiro vira **bloco** (intransponível). Fecham 5 anéis (21×13), sobrando uma arena central de 9 células.
- **Aviso uma rodada antes** (`ring_warning`), para o jogador sair do anel a tempo.
- Quem estiver no anel é **empurrado** para a célula aberta mais próxima e leva **30 de dano inevitável** (Esquiva não
  protege). Troféus no anel são realocados (o conjunto é fixo); outros itens e monstros somem e são repostos.
- **Morte súbita:** depois do último anel, todos levam dano inevitável por rodada (10, 15, 20, ...). Se todos caírem na
  mesma rodada, vence quem tinha mais vida; empate real = sem vencedor.
- Resultado nas simulações com bots: mediana de 31 / 47 / 61 turnos totais para 2 / 3 / 4 jogadores
  (≈15 por jogador), p90 de 39 / 55 / 69, nenhuma partida estourou o limite.

## 14. Batalha com ações e poções
Implementada em `godot/core/battle.gd`. Vale contra monstro (andar até a casa dele) e no PvP (entrar na casa de outro
herói). A batalha é uma fase (`BATTLE`): em cada rodada, **todos os envolvidos escolhem uma ação ao mesmo tempo**
(`battle_action`) e a rodada só resolve quando todos escolheram. O monstro escolhe sozinho (75% ataca, 25% defende;
40% de defender com menos de 30% de vida). No servidor, o tempo da rodada acaba com `timeout()` e quem não escolheu ataca.

| Ação | Efeito |
|---|---|
| Atacar | Contra outro ataque: duelo, d20 + ataque/2 (o ocupante da casa soma o bônus de terreno); o vencedor causa `ataque − defesa/2 + margem/4`. Contra quem não ataca: teste contra 10 + defesa. |
| Defender | Dano recebido pela metade e +3 no teste. Se o golpe falha, **contra-ataque** de ataque/3. |
| Habilidade | Guerreiro: Golpe Poderoso (+20, escala com nível). Mago: Ataque Mágico (15 fixo, ignora defesa e rolagens). Ladino: Esquiva (anula todo dano **só nessa rodada**). Clérigo: Cura (+25). Gasta a recarga em turnos. |
| Item | Bebe uma poção do inventário. |
| Fugir | d20 + velocidade ≥ 12. Falhando, perde a ação. |

- Todo o dano da rodada é aplicado **junto**; XP e cura de level up só valem depois. Duas mortes na mesma rodada são possíveis.
- Máximo de 4 rodadas. Sem mortes, o atacante **recua** para a casa de origem e perde o resto do movimento.
  Se o defensor foge, ele sai para uma casa vizinha e o atacante fica e pode continuar andando.
- Monstro derrotado: XP, 40% de largar poção (vida ou força); monstro sobrevivente continua ferido.
- **Poções:** inventário de até 3. Vida (+30) e Força (+5 de ataque por 3 rodadas). Também dá para beber fora de batalha
  (`use_item`). Inventário cheio: a poção de vida é bebida na hora; a de força se perde. A poção de força agora é
  um item sorteado no mapa (8%).
- Resultado nas simulações com bots: duração praticamente igual (mediana 32 / 50 / 65 turnos totais para 2 / 3 / 4
  jogadores). Equilíbrio entre classes ainda irregular (Clérigo forte, Ladino fraco), ajustar depois.

## 15. Morto-vivo
Quando um herói vivo morre e a partida continua, ele **volta como morto-vivo da própria classe**, controlado pelo
mesmo jogador.
- **Condição:** só levanta se ainda restarem **2 ou mais heróis vivos**. A partida acaba quando sobra 1 vivo (ou nenhum),
  então em duelo de 2 jogadores a primeira morte já encerra tudo.
- **Volta com** 50% da vida máxima (e esse novo máximo), o nível e o XP que tinha, sem poções, sem troféus (caem no chão)
  e com a recarga zerada. Aparece na casa livre mais próxima de onde morreu.
- **Joga normalmente os turnos** (dado, movimento, batalha, habilidades), com estas diferenças:
  não coleta itens nem troféus, é imune ao dano de lava/gelo, não entra em casa de monstro (monstros o ignoram) e só
  inicia batalha contra heróis vivos. Mortos-vivos não brigam entre si.
- **Heróis vivos podem atacá-lo.** Derrotado, sai de jogo de vez e quem o derrotou ganha 20 + 5×nível de XP.
- Quem morre para um morto-vivo também vira morto-vivo (cadeia). O fechamento do mapa fere mortos-vivos; a morte
  súbita só atinge vivos. Mortos-vivos nunca vencem: quem vence é sempre um herói vivo.
- Simulações: em partidas de 3 e 4 jogadores surgem em média 0,8 e 1,6 mortos-vivos por partida; a duração subiu
  cerca de 4 turnos (mediana 52 e 69 turnos totais).

## 16. Ajustes de equilíbrio (substituem os números das seções anteriores)
Medidos com 360 partidas de bots por configuração (a taxa ideal de vitória por classe é 33% com 3 jogadores e 25% com 4).
Antes: Clérigo 46% e Ladino 10% com 4 jogadores. Depois: Guerreiro 23%, Mago 19%, Ladino 26%, Clérigo 31%.
- **Ladino:** +2 de ataque inicial (12) e +3 de ataque por nível. A **Esquiva em batalha agora dá contra-golpe**: quem
  teria acertado o ladino leva um golpe de volta de ataque/2.
- **Clérigo:** cura 20 (era 25), +10 de vida e +1 de defesa por nível (eram +12 e +2).
- **Mago:** Ataque Mágico causa 18 (era 15), +4 por nível (era +3).
Os valores estão em `core/defs.gd`; as classes ainda não são perfeitamente iguais para bots, mas ficam dentro de uma
faixa aceitável. Reavaliar com partidas reais.

## 17. Equipamentos, armadilhas armadas e sons
### Equipamentos
- Dois slots por herói: **arma** (ataque) e **armadura** (defesa). Coletar equipa o item e **deixa o antigo no chão**.
  Os atributos de batalha usam o total (base + equipamento + poção de força); a velocidade também (dado de movimento e fuga).
- Itens (ataque / defesa / velocidade): Adaga +2 / 0 / +1 · Espada +4 · Machado +6 / −1 velocidade ·
  Gibão +2 defesa · Cota de malha +4 · Armadura de placas +6 / −1 velocidade.
- Surgem no mapa (16% dos itens aleatórios) e em butins de monstros (45% de chance de largar algo; 35% disso é equipamento).
  Quem morre **solta o equipamento** no chão. O morto-vivo volta sem equipamento.
### Armadilhas armadas
- **Kit de armadilha** (item do mapa ou butim; até 2 na mochila). Ação **Armar** na fase de ação: a armadilha fica escondida
  na casa do herói (uma por casa, até 3 ativas por jogador).
- Quem **para** numa armadilha alheia leva **25 de dano** e perde o resto do movimento (vale também para mortos-vivos). O dono é imune.
  O **Ladino** enxerga todas as armadilhas e as desarma sem dano, recuperando o kit.
- O anel que fecha leva as armadilhas dele. A armadilha "no chão" antiga (coletar = dano) continua existindo.
- **Informação escondida:** a interface só mostra armadilhas ao dono e ao Ladino. Num servidor online, o núcleo deve
  filtrar os eventos `trap_set` (posição) e o estado `traps` por jogador; hoje isso é feito só na interface.
### Sons
- Efeitos e uma música em loop em `assets/audio`, gerados por `tools/gen_sfx.py` (síntese simples). Podem ser trocados por
  arquivos profissionais com o mesmo nome. Liga/desliga no menu e no botão **Som** da partida (salvo em `user://settings.cfg`).
- Equilíbrio após as mudanças (4 jogadores, 360 partidas de bots): Guerreiro 23%, Mago 23%, Ladino 28%, Clérigo 27%.

## 18. Dados 3D e dois dados de movimento
- **Movimento:** agora rola **dois d6** e vale a **média, arredondada para cima** (1 a 6), mais o bônus de velocidade. A média
  dos pontos sobe de 3,5 para 3,75 e a variação cai. Para voltar a um dado só, mude `Defs.MOVE_DICE` para 1 em `core/defs.gd`.
  Efeito medido (360 partidas de bots por configuração): duração igual (≈46 e 61 turnos totais) e classes ainda equilibradas
  (4 jogadores: Guerreiro 24%, Mago 19%, Ladino 29%, Clérigo 28%).
- **Animação 3D** (`ui/dice_stage.gd`, `ui/dice3d.gd`, `ui/hand3d.gd`): uma cena 3D transparente sobre o tabuleiro. Uma mão de
  manga preta (punho com faixa na cor do jogador) entra, balança fechada, abre os dedos e solta dois d6 vermelhos de pontos brancos
  que quicam, giram e assentam. Os dados são feitos por código (cubo arredondado com pontos; d20 em icosaedro com números).
  O movimento é roteirizado, e a face sorteada sempre termina para cima (provado em teste para as 6 faces do d6 e as 20 do d20).
- **Batalha:** cada rodada com rolagem mostra d20 3D no centro da janela (dois no duelo, um num ataque sem oposição); o golpe
  só acontece quando eles assentam. Magia não tem rolagem, então não mostra dados.
- Agir durante a animação do dado a encerra na hora. O 3D só renderiza enquanto anima (economiza bateria).

## 19. Pares nos dados, sons sincronizados e estilos de animação
- **Pares no movimento:** par dá **+1** ponto de movimento; **dois 6** dão **+2**; **dois 1** ("olhos de cobra") não dão bônus.
  Constantes `DOUBLES_BONUS` e `DOUBLE_SIX_BONUS` em `core/defs.gd`. Efeito medido (360 partidas de bots por configuração): duração
  igual (≈46 e 61 turnos totais) e classes ainda equilibradas (4 jogadores: 20% a 31% cada). O evento `dice_rolled` traz `dice`, `pair` e `bonus`.
- **Comemoração:** dois 6 e pares comuns fazem os dados brilharem, soltam estrelas e mostram "DOIS 6! +2" / "PAR DE n! +1" com um chime;
  olhos de cobra tremem a câmera, soltam brasas vermelhas e tocam um som de azar.
- **Sons sincronizados:** vento na entrada e no arremesso, chocalho durante a sacudida (acompanha a intensidade) e uma batida por
  quique (3 variações, mais fraca a cada quique, tom levemente variado) e um tique ao assentar. A velocidade acelera o tom.
- **Estilos de animação** (Opções): para as suas jogadas **Completa** (padrão) / **Rápida** (só os dados caem, sem a mão) / **Desligada**;
  para as dos bots **Completa** / **Curta** (padrão) / **Desligada**. Agir durante a animação ainda a encerra.

## 20. Física dos dados, câmera, poeira e mãos por classe
- **Física** (`ui/dice_physics.gd`, só apresentação): gravidade, quique, atrito no chão, paredes invisíveis e **colisão entre os dois
  dados**. Roda uma vez antes da animação; os sons (batida de cada quique, "clique" mais agudo no choque), a poeira e o brilho ao parar
  saem dos eventos da simulação. A face que fica para cima é **sempre a sorteada** (a física só decide por onde o dado anda, nunca o resultado).
  Os dados terminam no meio do tabuleiro, qualquer que seja a diagonal da mão.
- **Câmera** (jogada completa): zoom suave sobre os dados e câmera lenta curta no último quique.
- **Poeira e brilho:** nuvem de poeira nos quiques fortes; brilho e uma faísca quando cada dado para.
- **Mãos por classe:** Guerreiro (braçadeira de couro com rebites, bate os dados com força e levanta poeira), Mago (túnica larga com
  estrelas e barra dourada, lança com faíscas roxas e halo nos dados), Ladino (luva sem dedos, sacudida rápida e giro de pulso em truque),
  Clérigo (punho e anéis dourados, gesto suave e faíscas douradas de bênção durante a sacudida).
