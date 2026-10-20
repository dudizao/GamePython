# Build para Android e iOS

O projeto Godot está em `godot/` e já vem com `export_presets.cfg` (Android e iOS). **Eu não consegui gerar nem testar um
build em aparelho aqui**: faltam o Android SDK, o Xcode e os export templates nesta máquina. O que foi verificado é o
comportamento da interface em tela de celular (retrato e paisagem), simulado no desktop.

## Antes de tudo
1. Instale o **Godot 4.7** e baixe os **export templates** (Editor → Gerenciar templates de exportação).
2. `godot --headless --path godot --import` (gera os `.import`).

## Android
1. Instale o **JDK 17** e o **Android SDK** (Android Studio resolve). Em Editor Settings → Export → Android, aponte o
   SDK e o keystore de debug.
2. Para publicar na Play Store, crie um keystore de **release** e preencha em Projeto → Exportar → Android (usuário e senha
   do keystore). Troque `package/unique_name` (`com.ultimoroubo.jogo`) pelo seu identificador definitivo.
3. Projeto → Exportar → Android → Exportar (APK para testes, **AAB** para a Play Store: ative *Use Gradle Build* e
   instale o *Android Build Template*).
4. Conta Google Play: US$ 25 (uma vez).

## iOS
1. Precisa de um Mac com **Xcode** (aceite a licença: `sudo xcodebuild -license accept`).
2. Preencha `application/app_store_team_id` e o `bundle_identifier` no preset iOS (conta **Apple Developer**, US$ 99/ano).
3. Projeto → Exportar → iOS gera um projeto Xcode; abra, assine e rode no aparelho ou envie pelo TestFlight.

## O que já está preparado para celular
- **Orientação:** travada em **paisagem** (sensor: aceita os dois lados da paisagem). O layout de retrato continua no código e é
  usado em janelas estreitas no desktop, mas os celulares não o mostram.
- **Escala:** no celular o lado curto da tela vale 540 unidades (≈ 2 px por unidade em telas Full HD), então os botões ficam com
  tamanho de toque (≥ 52 unidades). Em desktop são 720 unidades.
- **Tabuleiro:** toque numa casa = ação/informação; arrastar move a câmera; pinça e os botões **+ − ◎** dão zoom; a câmera segue o seu herói.
- **Áreas seguras:** margens automáticas para entalhe e barras do sistema (só em aparelho real).
- **Botão Voltar do Android:** fecha janelas ou pergunta se quer sair da partida.
- **Vibração** em dano, morte, nível e armadilha (liga/desliga no menu).
- **Economia de bateria:** o tabuleiro redesenha a ~30 quadros/s e só as casas visíveis; renderizador *GL Compatibility*.

## Testar o modo toque no desktop
`godot --path godot -- --touch` (ou redimensione a janela para retrato) ativa botões grandes, zoom inicial e dicas sem teclado.

## Ainda não verificado em aparelho real
Pinça (gesto de zoom), vibração, áreas seguras em aparelhos com entalhe, desempenho em celulares antigos e o tamanho real dos
botões em polegadas. Vale um teste em pelo menos um Android e um iPhone antes de publicar.
