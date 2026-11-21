# dotfiles — eliasolie

Ricing **sólido e minimalista** para Arch Linux + Hyprland (config em **Lua**, 0.57+), na identidade visual do eliasolie-site.

## Paleta

| Nome | HEX | Uso |
|---|---|---|
| void | `#050505` | fundo |
| graphite | `#161614` | superfícies (cards, tooltips) |
| line | `#2A2A27` | bordas inativas, separadores |
| static | `#8A8A84` | texto secundário |
| bone | `#EDEDE8` | texto |
| **signal** | **`#C8F031`** | destaque / ativo |
| alert | `#FF5A4E` | alertas, erros |

Tipografia: **Archivo** (títulos condensados com largura 62% e peso 800, texto da interface) e **JetBrains Mono Nerd Font** (terminal, barra, menus). Cantos retos em tudo.

## Instalar

```bash
git clone <este repo> ~/work/dotfiles
cd ~/work/dotfiles
./install.sh --all        # pacotes + links no $HOME + SDDM e fonte no sistema
hyprctl reload
```

- `./install.sh` sozinho só cria os links (faz backup `*.bak-DATA` do que já existir).
- Os arquivos em `home/` viram links no `$HOME`: editar `~/.config/hypr/look.lua` já edita o repositório.
- O `.zshrc` está aqui **sem segredos**: senhas e configs da máquina ficam em `~/.zshrc.local` (fora do git, `chmod 600`), que o `.zshrc` carrega no fim. O instalador cria esse arquivo vazio se não existir.
- O instalador também baixa o oh-my-zsh e os plugins (`zsh-autosuggestions`, `zsh-completions`, `zsh-syntax-highlighting`) se faltarem.
- Bitwarden: depois de instalar, configure o seu servidor:
  `rbw config set base_url https://SEU-VAULTWARDEN && rbw config set email SEU@EMAIL && rbw login`

## Estrutura

| Caminho | O que é |
|---|---|
| `home/.config/hypr/hyprland.lua` | config principal (monitores, input, regras); carrega `keybinds` e `look` |
| `home/.config/hypr/keybinds.lua` | todos os atalhos |
| `home/.config/hypr/look.lua` | visual: bordas, gaps, animações, autostart do visual |
| `home/.config/hypr/hypr{paper,idle,lock}.conf` | wallpaper, inatividade, tela de bloqueio |
| `home/.config/hypr/hyprsunset.conf` | luz noturna automática: 06:30 normal · 18:00 4800K · 21:30 4000K |
| `home/.config/hypr/scripts/` | screenshot, volume/brilho (OSD), menu de energia, busca, Bitwarden |
| `home/.config/waybar/` | barra do topo |
| `home/.config/rofi/` | launcher e menus (tema `eliasolie.rasi`) |
| `home/.config/swaync/` | notificações e central de controle |
| `home/.config/kitty/` | terminal (tema `eliasolie.conf`) |
| `home/.config/gtk-*`, `qt6ct/`, `kdeglobals`, `color-schemes/` | apps GTK, Qt e KDE na paleta |
| `home/.zshrc` | zsh (oh-my-zsh, aliases com eza/bat, zoxide, fzf, ssh-agent) |
| `home/.oh-my-zsh/custom/themes/eliasolie.zsh-theme` | prompt do zsh |
| `home/.config/rofi-rbw.rc` | Bitwarden no rofi |
| `home/.config/quickshell/` | widgets do desktop: relógio, apps, agenda, mídia e sistema (Quickshell) |
| `system/sddm/eliasolie/` | tema da tela de login (SDDM, Qt6) |
| `brave-theme/` | tema do Brave na paleta: `brave://extensions` → modo desenvolvedor → **Carregar sem compactação** → esta pasta |
| `packages-aur.txt` | pacotes do AUR (cursor Eliasolie (Bibata com borda lima)) |
| `rice/gen-wallpaper.py` | gera o PNG do wallpaper (usado no bloqueio e no SDDM) em qualquer resolução: `python3 rice/gen-wallpaper.py saida.png 2560 1440` (`--dot` inclui o ponto lima) |

## Atalhos

| Atalho | Ação |
|---|---|
| `Super+Space` | launcher |
| `Super+Enter` | terminal |
| `Super+W` / `Super+Q` | fechar janela |
| `Super+Shift+Q` | matar o processo da janela (kill -9) |
| `Super+E` / `Super+B` | arquivos / navegador |
| `Super+D` | mostrar o desktop (vai para um workspace vazio do monitor; de novo, volta) |
| `Super+V` / `Super+Alt+Space` | flutuar janela / flutuar todas do workspace |
| `Super+Shift+F` / `Super+Ctrl+F` | tela cheia / maximizar |
| `Super+setas` | foco · `+Ctrl` mover · `+Alt` trocar · `+Shift` redimensionar |
| `Super+1..0` | workspace N **só no monitor atual** |
| `Super+Ctrl+1..0` | workspace N em **todos os monitores** |
| `Super+Shift+1..0` / `Super+Alt+1..0` | mover janela para o workspace N (indo junto / sem ir) |
| `Super+Tab`, `Super+,` `Super+.`, scroll | navegar entre workspaces |
| `Super+U` / `Super+Shift+U` | workspace especial / mandar janela para ele |
| `Super+Shift+Enter` | terminal dropdown |
| `Super+Ctrl+F9..F12` | mover workspace para o monitor da esquerda/direita/cima/baixo |
| `Super+Alt+V` / `E` / `C` | clipboard / emoji / calculadora |
| `Super+S` / `Super+Ctrl+S` | busca na web / alternar janelas |
| `Super+Shift+O` | abrir projeto (repositórios git em `~/work`) num terminal |
| `Super+Alt+D` | desktop compacto no monitor atual: esconde atalhos e painéis (etiquetas `+ ⌄` abrem ao passar o mouse); fica salvo |
| `Super+A` | agenda grande no centro do desktop (monitor atual; fica salvo). Com janelas na frente, vai pro desktop |
| `Super+H` | cola de atalhos: lista todos os keybinds e o que fazem (lê do Hyprland, sempre atualizada) |
| `Super+J` | buscar no Janus (rofi) |
| `Super+Alt+F` | modo foco: 25 min com "não perturbe" (de novo encerra) |
| `Super+Shift+P` | Bitwarden: digita login (no menu: `alt u` copia usuário, `alt p` senha, `alt t` TOTP) |
| `Super+Alt+P` | Bitwarden: copia TOTP |
| `Super+Shift+G` | game mode (sem animações, blur, sombras e gaps) |
| `Super+N` | luz noturna: liga/desliga (ela já é automática por horário) |
| `Super+Shift+N` | notificações |
| `Ctrl+Alt+L` / `Ctrl+Alt+P` / `Ctrl+Alt+Del` | bloquear / menu de energia / sair do Hyprland |
| `Super+Print` (+`Shift` área, +`Ctrl` 5 s), `Alt+Print`, `Super+Shift+S` | screenshots (salvos em `~/Imagens/Screenshots`) |

Workspaces por monitor: o monitor 1 (`eDP-1`) usa os IDs 1–10 e o monitor 2 (`HDMI-A-1`) usa 11–20; a barra mostra sempre 1–10. A ordem fica em `MONITORS` no `keybinds.lua`.

## Widgets do desktop (Quickshell)

O **wallpaper também é do Quickshell** (substitui o hyprpaper, ~200 MB a menos): fundo void com grade de pontos que **acendem em lima perto do mouse**.

Os widgets ficam sobre o wallpaper (abaixo das janelas) e **só aparecem quando o workspace do monitor está vazio** — abriu uma janela, eles somem com um fade.

- **Topo-centro:** frase que troca a cada 10 min em ordem embaralhada (clique troca na hora). As frases ficam em `quickshell/phrases.txt`, uma por linha, e o widget recarrega ao salvar. Easter eggs por data/hora (madrugada, sexta à tarde, 13:37, Natal, dia do π…) ficam em `egg()` no `CenterPiece.qml` — e tem um escondido para quem clicar demais e, abaixo, um badge `+ ⌄` que abre os quick actions ao passar o mouse (fecha ao sair): projetos, senhas, print, luz noturna, não perturbe, game mode, bloquear. Badges no estilo do site; os toggles ligados ficam lima cheio.
- **Atalhos (topo-esquerdo):** card no estilo dos cards do site, 3 quadrados por linha. Clique abre no Brave (`url`) ou roda um comando (`cmd`). Lista em `quickshell/shortcuts.json` (recarrega ao salvar); imagens em `quickshell/icons/`, ou um `glyph` da Nerd Font, e um `badge` opcional no canto.
- **Relógio:** Archivo 62% / 800 e a data, no canto inferior esquerdo.
- **Mídia:** o player ativo (MPRIS: navegador, Spotify, mpv…); some quando nada está aberto.
- **Sistema:** CPU, RAM, temperatura, GPU NVIDIA e disco. Clique abre o `htop`.
- **VPS (rodapé-centro, discreto: ● nome | ● nome):** checa por HTTP os serviços de `quickshell/vps.json` a cada 60 s (só com o desktop à mostra). Responde abaixo de 500 = no ar (ponto lima + latência); fora = ponto e borda coral. Clique abre o Dokploy. Serviços privados vão em `~/.config/eliasolie/vps.json` (mesmo formato, fora do repo), que substitui o do repo.
- **Agenda:** lê `~/.local/share/eliasolie/agenda.json` e atualiza sozinho quando o arquivo muda (até 4 eventos). Formato:

  ```json
  [{ "title": "Reunião", "start": "2026-11-21T14:00:00-03:00", "end": "2026-11-21T15:00:00-03:00", "where": "Meet" }]
  ```

## Modo compacto e frase

- **Compacto (`Super+Alt+D`, por monitor):** some o painel de atalhos e a coluna da direita; no lugar ficam as etiquetas `+ ATALHOS ⌄` e `+ AGENDA · MÍDIA · RECURSOS ⌃`, que abrem o bloco ao passar o mouse e fecham ao sair (igual aos quick actions). Estado salvo em `~/.local/state/eliasolie/desktop.json`; via terminal: `qs ipc call desktop toggleCompact`.
- **Alfinete:** com um bloco aberto (atalhos, painéis da direita ou quick actions) aparece um alfinete no canto; clicou, o bloco fica fixo aberto (lima). Salvo por monitor junto do modo compacto.
- **Modo foco compacta o desktop** em todos os monitores enquanto conta (`qs ipc call desktop setFocus true|false`).
- **Relógio que voa:** o relógio da waybar (`custom/clock`, `hypr/scripts/bar-clock.py`) some quando o desktop do monitor está à mostra; o relógio grande sai do centro da barra crescendo até o canto e, ao abrir uma janela, encolhe de volta para a barra.
- **Entrada em cascata:** na primeira vez que o desktop aparece (login ou reinício do Quickshell), o relógio voa da barra e os blocos entram um a um.
- **Wallpaper que reage:** clique no fundo do desktop solta uma onda pelos pontos; com música tocando (MPRIS) e o desktop à mostra, os pontos pulsam em lima no ritmo dos graves (`hypr/scripts/audio-level.py`, via `parec`, sem cava).
- **Indicador de volume/brilho/microfone:** card no estilo do site que sobe do rodapé, só no monitor com foco (`quickshell/Osd.qml`; `qs ipc call osd popup volume 45 false`). O `osd.sh` cai numa notificação se o Quickshell não estiver rodando.
- **Agenda** (`quickshell/AgendaCard.qml`, dados em `~/.local/share/eliasolie/agenda.json` pelo timer `agenda-sync` do projeto agenda): calendário do mês com marcação por marca e próximos eventos. `Super+A` abre a agenda "do wallpaper" (`quickshell/AgendaWall.qml`, por monitor): sem card, o mês escrito em tamanho grande sobre a grade de pontos, cada dia num quadrado da própria grade e os próximos eventos à direita; a coluna da direita recolhe numa etiqueta. Dados compartilhados em `quickshell/AgendaData.qml`. Também aparece na tela de bloqueio (`lock-status.sh agenda`).
- **Lembretes da agenda** (`quickshell/AgendaNotify.qml`): notificação 1 h e 10 min antes; dia inteiro às 8h. Cada aviso sai uma vez (`~/.local/state/eliasolie/agenda-notified.json`).
- **Workspaces vai-e-volta:** `Super+N` no workspace em que você já está volta para o anterior daquele monitor.
- **Frase do dia:** discreta no canto superior direito (`quickshell/Phrase.qml`); clique troca, 6 cliques rápidos = easter egg.

## Integrações

- **Clima (Serra Talhada):** na linha da data, via Open-Meteo (sem chave), a cada 30 min. Outra cidade: `lat`/`lon` em `quickshell/Weather.qml`.
- **Backup:** `■ BACKUP 22H` no rodapé e na tela de bloqueio (`hypr/scripts/backup-status.sh`, lê `RESTIC_*` do `~/.zshrc.local`, cache de 30 min). Coral se passar de 26 h.
- **Modo foco (`Super+Alt+F`):** módulo `FOCO` na waybar. Clique = 25 min com "não perturbe"; rolar = ±5 min; no fim, notificação e DND volta como estava (`hypr/scripts/focus.sh`, timer do systemd).
- **Janus no rofi (`Super+J`):** `hypr/scripts/janus.py` fala com o Janus pelo MCP (stdio). Lista os artigos (o rofi filtra), Enter em texto livre busca no Janus (inclui decisões), e o item abre num kitty flutuante. Caminho: `$JANUS_MCP` (padrão `~/work/janus/scripts/mcp.sh`).
- **Utilitários rofi** (`hypr/scripts/rofi-tools.sh`): clipboard com miniatura de imagens (`alt d` apaga, `alt shift d` limpa), emoji (precisa `noto-fonts-emoji`) e calculadora (Enter copia).
- **Tela de bloqueio:** música tocando + linha de status (VPS e backup) via `hypr/scripts/lock-status.sh`.
- **Boot:** tema Plymouth em `system/plymouth/eliasolie` (logo EO_ + barra lima). Instala com `bash system/install-boot.sh` (pacotes, hook, `quiet splash` no systemd-boot, initramfs e cursor lima no SDDM, tudo com backup).

## Notas

- O Hyprland em Lua não aceita mais `hyprctl dispatch <nome> <args>` nem `hyprctl keyword`. Scripts usam `hyprctl dispatch 'hl.dsp....'` ou `hyprctl repl`.
- Cópias do Bitwarden saem com `wl-copy --sensitive`: o cliphist não guarda.
