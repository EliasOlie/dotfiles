#!/usr/bin/env bash
# Resgata janelas quando um monitor sai e devolve quando ele volta.
#   Cada monitor tem um bloco de workspaces (eDP-1: 1..10, HDMI-A-1: 11..20,
#   mesma ordem de MONITORS no keybinds.lua). Se o monitor de um bloco sumir,
#   as janelas dele ficam inalcançáveis pelos atalhos (Super+N só enxerga o
#   bloco do monitor atual). Então:
#     removed -> move cada janela órfã para o mesmo número no primeiro monitor
#                conectado (ex.: 13 -> 3) e anota de onde ela veio;
#     added   -> devolve as anotadas (se você não mexeu nelas nesse meio-tempo).
set -uo pipefail
MONITORS=(eDP-1 HDMI-A-1)
STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-ws-orphans"

move() { hyprctl dispatch "hl.dsp.window.move({ workspace = $2, follow = false, window = \"address:$1\" })" >/dev/null; }

connected=$(hyprctl monitors -j | jq -r '.[].name')
block_of() { local i; for i in "${!MONITORS[@]}"; do [[ ${MONITORS[$i]} == "$1" ]] && { echo "$i"; return; }; done; echo -1; }

case "${1:-}" in
removed)
    sleep 0.5
    first=$(echo "$connected" | head -1); fb=$(block_of "$first"); ((fb < 0)) && fb=0
    hyprctl clients -j | jq -r '.[] | select(.workspace.id > 0) | "\(.address) \(.workspace.id)"' |
    while read -r addr ws; do
        b=$(( (ws - 1) / 10 ))
        mon=${MONITORS[$b]:-}
        if [[ -n $mon ]] && ! grep -qx "$mon" <<<"$connected"; then
            dest=$(( fb * 10 + (ws - 1) % 10 + 1 ))
            move "$addr" "$dest"
            echo "$addr $ws $dest" >> "$STATE"
        fi
    done
    ;;
added)
    sleep 1   # dá tempo das regras de workspace prenderem o bloco ao monitor novo
    [[ -f $STATE ]] || exit 0
    cur=$(hyprctl clients -j | jq -r '.[] | "\(.address) \(.workspace.id)"')
    keep=$(mktemp)
    while read -r addr orig dest; do
        mon=${MONITORS[$(( (orig - 1) / 10 ))]:-}
        if grep -qx "$mon" <<<"$connected"; then
            grep -qx "$addr $dest" <<<"$cur" && move "$addr" "$orig"
        else
            echo "$addr $orig $dest" >> "$keep"
        fi
    done < "$STATE"
    mv "$keep" "$STATE"
    ;;
*) echo "uso: $0 removed|added" >&2; exit 1 ;;
esac
