#!/usr/bin/env bash
# Busca na web pelo rofi (Super+S)
pkill rofi && exit 0
q="$(rofi -dmenu -p 'Pesquisar' -lines 0)" || exit 0
[ -z "$q" ] && exit 0
xdg-open "https://www.google.com/search?q=$(jq -rn --arg q "$q" '$q|@uri')"
