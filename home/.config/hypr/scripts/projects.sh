#!/usr/bin/env bash
# Abre um projeto (repositório git em ~/work) num terminal já na pasta
pkill -x rofi && exit 0
base="$HOME/work"
choice="$(find "$base" -maxdepth 4 -type d -name .git -not -path '*/node_modules/*' -printf '%h\n' 2>/dev/null \
  | sed "s|^$base/||" | sort | rofi -dmenu -i -p 'projetos')" || exit 0
[ -n "$choice" ] && exec kitty --directory "$base/$choice"
