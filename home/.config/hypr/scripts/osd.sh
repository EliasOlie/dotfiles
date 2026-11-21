#!/usr/bin/env bash
# Volume (PulseAudio/pactl), microfone e brilho com indicador na tela
# (Quickshell, Osd.qml; se o qs não estiver rodando, cai numa notificação).
# uso: osd.sh vol-up N | vol-down N | mute | mic | br-up | br-down
set -u
# osd <volume|brilho|mic> <0-100> [mudo:true|false]
osd() {
  qs ipc call osd popup "$1" "$2" "${3:-false}" >/dev/null 2>&1 && return
  notify-send -a osd -t 1200 -h string:x-canonical-private-synchronous:osd -h "int:value:$2" "${1^} $2%" 2>/dev/null || true
}
vol() { pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+(?=%)' | head -1; }
muted() { pactl get-sink-mute @DEFAULT_SINK@ | grep -q yes; }

case "${1:-}" in
  vol-up)   pactl set-sink-mute @DEFAULT_SINK@ 0
            v=$(vol); step=${2:-5}; [ $((v + step)) -gt 100 ] && pactl set-sink-volume @DEFAULT_SINK@ 100% || pactl set-sink-volume @DEFAULT_SINK@ "+${step}%"
            osd volume "$(vol)" ;;
  vol-down) pactl set-sink-volume @DEFAULT_SINK@ "-${2:-5}%"; osd volume "$(vol)" "$(muted && echo true || echo false)" ;;
  mute)     pactl set-sink-mute @DEFAULT_SINK@ toggle
            if muted; then osd volume "$(vol)" true; else osd volume "$(vol)"; fi ;;
  mic)      pactl set-source-mute @DEFAULT_SOURCE@ toggle
            if pactl get-source-mute @DEFAULT_SOURCE@ | grep -q yes; then osd mic 0 true; else osd mic 100; fi ;;
  br-up)    brightnessctl -q -e4 -n2 set 5%+; b=$(( $(brightnessctl g) * 100 / $(brightnessctl m) )); osd brilho "$b" ;;
  br-down)  brightnessctl -q -e4 -n2 set 5%-; b=$(( $(brightnessctl g) * 100 / $(brightnessctl m) )); osd brilho "$b" ;;
  *) echo "uso: $0 vol-up N|vol-down N|mute|mic|br-up|br-down" >&2; exit 1 ;;
esac
