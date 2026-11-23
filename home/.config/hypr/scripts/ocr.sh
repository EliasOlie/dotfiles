#!/usr/bin/env bash
# Copiar texto de uma área da tela (Super+Shift+T): selecione a área e o texto
# reconhecido (português + inglês, tudo local, sem internet) vai pra área de
# transferência. Serve para print de erro, PDF travado, imagem de cliente…
set -u
command -v tesseract >/dev/null || { notify-send -a texto "Texto da tela" "Instale o tesseract (pacman -S tesseract tesseract-data-por tesseract-data-eng)"; exit 1; }
area=$(slurp 2>/dev/null) || exit 0
langs=$(tesseract --list-langs 2>/dev/null | grep -xE 'por|eng' | paste -sd+)
txt=$(grim -g "$area" - | tesseract stdin stdout -l "${langs:-eng}" --psm 6 2>/dev/null | sed -e 's/[[:space:]]*$//' -e '/./,$!d')
if [[ -z ${txt//[[:space:]]/} ]]; then
  notify-send -a texto "Texto da tela" "Não achei texto nessa área."
  exit 0
fi
printf '%s' "$txt" | wl-copy
n=$(printf '%s' "$txt" | wc -l); prev=$(printf '%s' "$txt" | head -c 160)
notify-send -a texto "Texto copiado ($((n + 1)) linhas)" "$prev"
