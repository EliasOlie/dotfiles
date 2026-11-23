#!/usr/bin/env bash
# Conta-gotas (Super+Shift+C): clique em qualquer pixel da tela e a cor vai pra
# área de transferência em #hex (e aparece numa notificação com a amostra).
set -u
command -v hyprpicker >/dev/null || { notify-send -a cor "Conta-gotas" "Instale o hyprpicker (pacman -S hyprpicker)"; exit 1; }
hex=$(hyprpicker -f hex -n 2>/dev/null | tr -d '\n' | tr '[:lower:]' '[:upper:]') || exit 0
[[ -n $hex ]] || exit 0
printf '%s' "$hex" | wl-copy
# amostra da cor como ícone da notificação
icon="${XDG_RUNTIME_DIR:-/tmp}/cor-amostra.svg"
printf '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="%s"/></svg>' "$hex" > "$icon"
notify-send -a cor -i "$icon" "Cor copiada" "$hex"
