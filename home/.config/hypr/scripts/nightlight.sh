#!/usr/bin/env bash
# Luz noturna: automática por horário (hyprsunset.conf) + liga/desliga manual
#   nightlight.sh toggle   alterna (desligar vale até o próximo horário do perfil)
#   nightlight.sh status   imprime 1 (ligada) ou 0 (desligada)
set -u
OFF="${XDG_RUNTIME_DIR:-/tmp}/nightlight-off"   # guarda a temperatura de quando foi desligada

pgrep -x hyprsunset >/dev/null || { hyprsunset >/dev/null 2>&1 & disown; sleep 0.5; }
temp() { hyprctl hyprsunset temperature 2>/dev/null | grep -oE '^[0-9]+' || echo 6000; }

# Se o perfil mudou de horário depois do "desligar", o desligar perdeu a validade
if [ -f "$OFF" ] && [ "$(cat "$OFF")" != "$(temp)" ]; then rm -f "$OFF"; fi

is_on() { [ ! -f "$OFF" ] && [ "$(temp)" -lt 6000 ]; }

case "${1:-status}" in
  status) is_on && echo 1 || echo 0 ;;
  waybar)
    if is_on; then t=$(temp); printf '{"text":"LUZ %sK","class":"on","tooltip":"Luz noturna ligada (%sK) · clique para desligar"}\n' "$t" "$t"
    else printf '{"text":"LUZ","class":"off","tooltip":"Luz noturna desligada · clique para ligar"}\n'; fi ;;
  toggle)
    if is_on; then
      temp > "$OFF"; hyprctl hyprsunset identity >/dev/null
      notify-send -a nightlight -t 1500 -h string:x-canonical-private-synchronous:night "Luz noturna desligada" "volta no próximo horário" 2>/dev/null
    else
      rm -f "$OFF"; hyprctl hyprsunset temperature 4500 >/dev/null
      notify-send -a nightlight -t 1500 -h string:x-canonical-private-synchronous:night "Luz noturna ligada" 2>/dev/null
    fi ;;
  *) echo "uso: $0 toggle|status|waybar" >&2; exit 1 ;;
esac
# Atualiza o módulo da waybar na hora (signal 8)
[ "${1:-}" = toggle ] && pkill -RTMIN+8 -x waybar 2>/dev/null
exit 0
