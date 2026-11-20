#!/usr/bin/env bash
# Screenshots: now | area | in5 | in10 | active | swappy
# Salva em ~/Imagens/Screenshots e copia para o clipboard.
set -u
dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Imagens")/Screenshots"
mkdir -p "$dir"
file="$dir/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

notify() { notify-send -a screenshot -i "$file" "Screenshot salvo" "$(basename "$file")" 2>/dev/null || true; }
finish() { [ -s "$file" ] && { wl-copy < "$file"; notify; }; }
countdown() { for s in $(seq "$1" -1 1); do notify-send -a screenshot -t 1000 -h string:x-canonical-private-synchronous:shot "Screenshot em $s s" 2>/dev/null; sleep 1; done; }

case "${1:-now}" in
  now)    grim "$file"; finish ;;
  area)   g="$(slurp)" || exit 0; grim -g "$g" "$file"; finish ;;
  in5)    countdown 5;  grim "$file"; finish ;;
  in10)   countdown 10; grim "$file"; finish ;;
  active) g="$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
          grim -g "$g" "$file"; finish ;;
  swappy) g="$(slurp)" || exit 0; grim -g "$g" - | swappy -f - ;;
  *) echo "uso: $0 now|area|in5|in10|active|swappy" >&2; exit 1 ;;
esac
