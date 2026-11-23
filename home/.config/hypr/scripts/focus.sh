#!/usr/bin/env bash
# Modo foco (pomodoro): liga o "não perturbe", conta o tempo na waybar e avisa no fim.
#   focus.sh start [min]  -> começa (padrão 25 min)
#   focus.sh stop         -> encerra antes da hora
#   focus.sh toggle       -> start/stop (clique na waybar)
#   focus.sh add <min>    -> soma/subtrai minutos com o foco rodando (rolar na waybar)
#   focus.sh waybar       -> JSON para o módulo custom/focus
#   focus.sh done         -> chamado pelo timer do systemd no fim
set -uo pipefail
STATE="${XDG_RUNTIME_DIR:-/tmp}/focus"          # "<fim_epoch> <dnd_antes>"
UNIT=eliasolie-focus
DEFAULT=25

refresh() { pkill -USR1 -f "focus.sh waybar" 2>/dev/null || true; }
desk() { qs ipc call desktop setFocus "$1" >/dev/null 2>&1 || true; }   # foco compacta o desktop
arm() {   # (re)agenda o fim para daqui a $1 segundos
    systemctl --user stop "$UNIT.timer" "$UNIT.service" 2>/dev/null
    systemd-run --user --quiet --unit="$UNIT" --on-active="${1}s" --timer-property=AccuracySec=1s \
        "$HOME/.config/hypr/scripts/focus.sh" done
}
finish() {   # $1 = mensagem
    read -r _ dnd < "$STATE" 2>/dev/null || dnd=false
    rm -f "$STATE"
    [[ $dnd == true ]] || swaync-client -df >/dev/null 2>&1
    desk false
    notify-send -a foco -i alarm-symbolic "Foco" "$1"
    refresh
}

case "${1:-}" in
start)
    min=${2:-$DEFAULT}
    end=$(( $(date +%s) + min * 60 ))
    echo "$end $(swaync-client -D 2>/dev/null || echo false)" > "$STATE"
    notify-send -a foco -i alarm-symbolic "Foco" "$min minutos. Notificações em silêncio até lá."
    sleep 0.3; swaync-client -dn >/dev/null 2>&1
    arm $(( min * 60 )); desk true; refresh ;;
stop)
    [[ -f $STATE ]] || exit 0
    systemctl --user stop "$UNIT.timer" "$UNIT.service" 2>/dev/null
    finish "Foco encerrado." ;;
done)
    [[ -f $STATE ]] || exit 0
    finish "Tempo! Levanta, bebe uma água e volta em 5 min." ;;
toggle)
    if [[ -f $STATE ]]; then "$0" stop; else "$0" start; fi ;;
add)
    [[ -f $STATE ]] || exit 0
    read -r end dnd < "$STATE"
    end=$(( end + ${2:-5} * 60 )); now=$(date +%s)
    (( end < now + 60 )) && end=$(( now + 60 ))
    echo "$end $dnd" > "$STATE"; arm $(( end - now )); refresh ;;
waybar)
    trap ':' USR1
    while true; do
        if [[ -f $STATE ]]; then
            read -r end _ < "$STATE" 2>/dev/null || true
            printf -v now '%(%s)T' -1
            left=$(( ${end:-0} - now )); (( left < 0 )) && left=0
            printf '{"text":"FOCO %02d:%02d","class":"on","tooltip":"clique: encerrar · rolar: ±5 min"}\n' $((left/60)) $((left%60))
            sleep 1 & wait $! || true
        else
            printf '{"text":"FOCO","class":"off","tooltip":"clique: %s min de foco (não perturbe ligado)"}\n' "$DEFAULT"
            sleep 300 & wait $! || true
        fi
    done ;;
*) echo "uso: $0 start [min]|stop|toggle|add <min>|waybar" >&2; exit 1 ;;
esac
