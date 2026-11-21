#!/usr/bin/env bash
# Três contas de WhatsApp Web como "apps" separados (cliente oficial, sem perfis):
# cada conta é uma janela do Brave em modo app, com dados numa pasta própria
# (~/.local/share/whatsapp/<conta>) e classe wa-<conta>. Ficam abertas escondidas
# num workspace especial (recebem notificações e mantêm o contador de não lidas).
#
#   whatsapp.sh start          abre as que não estão rodando, escondidas (autostart)
#   whatsapp.sh toggle <conta> mostra/esconde a conta por cima do que você está fazendo
#   whatsapp.sh menu           menu rofi (estilo bitwarden) com não lidas por conta
#   whatsapp.sh status         JSON {"pessoal":3,...,"total":N} (-1 = fechada)
#   whatsapp.sh waybar         JSON do módulo custom/whatsapp
#
# Não lidas: o WhatsApp Web põe "(3) WhatsApp" no título da janela; lemos o
# título pelo Hyprland, sem API e sem tocar no conteúdo das mensagens.
set -uo pipefail
IDS=(pessoal profissional jac)
declare -A NAME=([pessoal]="Pessoal" [profissional]="Profissional" [jac]="Grupo JAC")
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/whatsapp"
URL="https://web.whatsapp.com"

clients() { hyprctl clients -j 2>/dev/null || echo '[]'; }
# não lidas da conta: N, 0 (aberta sem não lidas) ou -1 (fechada)
count() {
    jq -r --arg c "wa-$1" '[.[] | select(.class == $c)][0] // empty
        | if . == null then empty else (.title | capture("^\\((?<n>[0-9]+)\\)").n // "0") end' <<<"$2" | head -1 | grep . || echo -1
}
launch() {
    mkdir -p "$DATA/$1"
    hyprctl dispatch "hl.dsp.exec_cmd(\"brave --user-data-dir=$DATA/$1 --class=wa-$1 --app=$URL --no-first-run --no-default-browser-check\")" >/dev/null
}

case "${1:-}" in
start)
    c=$(clients)
    for id in "${IDS[@]}"; do [[ $(count "$id" "$c") == -1 ]] && launch "$id"; done ;;
toggle)
    id=${2:?conta}; c=$(clients)
    if [[ $(count "$id" "$c") == -1 ]]; then
        launch "$id"
        # espera a janela nascer (vai pro workspace especial pela regra) e mostra
        for _ in $(seq 60); do sleep 0.25; [[ $(count "$id" "$(clients)") != -1 ]] && break; done
    fi
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"wa-$id\")" >/dev/null ;;
status)
    c=$(clients); out="{"; total=0
    for id in "${IDS[@]}"; do n=$(count "$id" "$c"); out+="\"$id\":$n,"; (( n > 0 )) && total=$((total + n)); done
    echo "${out}\"total\":$total}" ;;
waybar)
    c=$(clients); total=0; tip=""; any=0
    for id in "${IDS[@]}"; do
        n=$(count "$id" "$c")
        (( n >= 0 )) && any=1
        (( n > 0 )) && total=$((total + n))
        tip+="${tip:+ · }${NAME[$id]} $([[ $n == -1 ]] && echo fechado || echo "$n")"
    done
    if (( ! any )); then echo '{"text":""}'
    elif (( total > 0 )); then printf '{"text":"󰖣 %d","class":"unread","tooltip":"%s"}\n' "$total" "$tip"
    else printf '{"text":"󰖣","class":"zero","tooltip":"%s"}\n' "$tip"; fi ;;
menu)
    pkill -x rofi && exit 0
    k() { printf "<span foreground='#C8F031'>%s</span> %s" "$1" "$2"; }
    SEP="<span foreground='#2A2A27'>  ·  </span>"
    HELP="<span font_size='small' foreground='#8A8A84'>$(k '↵' abrir/esconder)${SEP}$(k '↑↓' escolher)${SEP}$(k esc sair)</span>"
    THEME='mainbox { children: [ inputbar, listview, message ]; } message { padding: 10px 0 0 0; border: 1px 0 0 0; border-color: #2A2A27; } textbox { horizontal-align: 0.5; } listview { lines: 3; } window { width: 520px; }'
    c=$(clients); rows=""
    for id in "${IDS[@]}"; do
        n=$(count "$id" "$c")
        if   (( n > 0 ));  then badge="<span foreground='#C8F031'><b>$n</b></span>"; dot="#C8F031"
        elif (( n == 0 )); then badge="<span foreground='#8A8A84'>em dia</span>";  dot="#8A8A84"
        else                    badge="<span foreground='#8A8A84'>fechado</span>"; dot="#2A2A27"; fi
        rows+="<span foreground='$dot'>■</span>  $(printf '%-14s' "${NAME[$id]^^}")  $badge"$'\n'
    done
    i=$(printf '%s' "$rows" | rofi -dmenu -i -markup-rows -no-custom -format i -p "whatsapp" \
          -mesg "$HELP" -theme-str "$THEME") || exit 0
    [[ -n $i ]] && exec "$0" toggle "${IDS[$i]}" ;;
*) echo "uso: $0 start|toggle <conta>|menu|status|waybar" >&2; exit 1 ;;
esac
