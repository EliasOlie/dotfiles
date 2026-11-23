#!/usr/bin/env bash
# Abre um projeto (repositório git em ~/work) já na pasta:
#   Enter  → terminal          Alt+C → terminal com o Claude rodando
#   Alt+N  → Neovim (árvore de arquivos aberta)
pkill -x rofi && exit 0
base="$HOME/work"

k() { printf "<span foreground='#C8F031'>%s</span> %s" "$1" "$2"; }
SEP="<span foreground='#2A2A27'>  ·  </span>"
HELP="<span font_size='small' foreground='#8A8A84'>$(k '↵' terminal)$SEP$(k 'alt c' claude)$SEP$(k 'alt n' neovim)$SEP$(k esc sair)</span>"
THEME='mainbox { children: [ inputbar, listview, message ]; } message { padding: 10px 0 0 0; border: 1px 0 0 0; border-color: #2A2A27; } textbox { horizontal-align: 0.5; }'

choice="$(find "$base" -maxdepth 4 -type d -name .git -not -path '*/node_modules/*' -printf '%h\n' 2>/dev/null \
  | sed "s|^$base/||" | sort \
  | rofi -dmenu -i -p 'projetos' -mesg "$HELP" -theme-str "$THEME" \
         -kb-custom-1 "Alt+c" -kb-custom-2 "Alt+n")"
rc=$?
[ -n "$choice" ] || exit 0
dir="$base/$choice"
case $rc in
  0)  exec kitty --directory "$dir" ;;
  10) exec kitty --directory "$dir" --title "claude · $choice" zsh -ic 'claude; exec zsh' ;;
  11) exec kitty --directory "$dir" --title "nvim · $choice" zsh -ic 'nvim +NvimTreeOpen; exec zsh' ;;
esac
