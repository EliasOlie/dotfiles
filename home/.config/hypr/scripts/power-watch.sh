#!/usr/bin/env bash
# Avisa quando o carregador é ligado/desligado (acessibilidade: não depender de
# olhar a waybar). Lê /sys/class/power_supply/*/online (tipo Mains) a cada 2 s
# (a waybar atualiza a bateria sozinha a cada 5 s).
set -u
AC=$(grep -l Mains /sys/class/power_supply/*/type 2>/dev/null | head -1); AC=${AC%/type}
[[ -n $AC ]] || exit 0
bat() { cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1; }
last=$(cat "$AC/online")
while sleep 2; do
    now=$(cat "$AC/online" 2>/dev/null) || continue
    [[ $now == "$last" ]] && continue
    last=$now
    if [[ $now == 1 ]]; then
        notify-send -a energia -i battery-full-charging "Carregador conectado" "Bateria em $(bat)%"
    else
        notify-send -a energia -u critical -i battery-low "Carregador DESCONECTADO" "Rodando na bateria ($(bat)%)"
    fi
done
