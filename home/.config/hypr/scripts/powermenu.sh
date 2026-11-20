#!/usr/bin/env bash
# Menu de energia no rofi (Ctrl+Alt+P)
pkill rofi && exit 0
opts="  Bloquear\n󰍃  Sair do Hyprland\n󰤄  Suspender\n  Reiniciar\n⏻  Desligar"
choice="$(printf "$opts" | rofi -dmenu -i -p 'Energia')" || exit 0
case "$choice" in
  *Bloquear*)  pidof hyprlock || hyprlock ;;
  *Sair*)      hyprctl dispatch 'hl.dsp.exit()' ;;
  *Suspender*) systemctl suspend ;;
  *Reiniciar*) systemctl reboot ;;
  *Desligar*)  systemctl poweroff ;;
esac
