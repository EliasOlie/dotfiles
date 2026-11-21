#!/usr/bin/env bash
# Contas de WhatsApp Web como "apps" separados (cliente oficial, sem perfis visíveis).
# Contas em ~/.config/eliasolie/whatsapp.json (id, name, short).
#
# Cada conta = Brave em modo app com pasta própria (~/.local/share/whatsapp/<id>)
# e perfil interno "wa-<id>". O Brave ignora --class em modo app; quem diferencia
# as janelas é o nome do perfil: a classe vira "brave-web.whatsapp.com__-wa-<id>".
# Ficam abertas escondidas num workspace especial (special:wa-<id>), recebendo
# notificações e mantendo o contador de não lidas.
#
#   whatsapp.sh start          abre as que não estão rodando, escondidas (autostart)
#   whatsapp.sh toggle <id>    mostra/esconde a conta por cima do que você está fazendo
#   whatsapp.sh stop <id>      fecha a conta
#   whatsapp.sh menu           menu rofi (estilo bitwarden) com não lidas por conta
#   whatsapp.sh status         JSON [{id,name,short,n}] (n = -1 fechada)
#   whatsapp.sh waybar         JSON do módulo custom/whatsapp
#
# Não lidas: se o WhatsApp Web puser "(3) WhatsApp" no título, lemos pelo Hyprland.
# Obs.: a versão atual do WhatsApp Web (nov/2026) deixa o título como o domínio,
# então hoje o contador fica em 0 ("aberto"); nada aqui lê o conteúdo das mensagens.
set -uo pipefail
CONF="$HOME/.config/eliasolie/whatsapp.json"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/whatsapp"
URL="https://web.whatsapp.com"

mapfile -t IDS < <(jq -r '.accounts[].id' "$CONF" 2>/dev/null)
name()  { jq -r --arg i "$1" '.accounts[] | select(.id == $i) | .name'  "$CONF"; }
cls()   { echo "brave-web.whatsapp.com__-wa-$1"; }
clients() { hyprctl clients -j 2>/dev/null || echo '[]'; }

# não lidas: N, 0 (aberta sem não lidas) ou -1 (fechada)
count() {
    jq -r --arg c "$(cls "$1")" '[.[] | select(.class == $c)][0] // empty
        | (.title | capture("^\\((?<n>[0-9]+)\\)").n // "0")' <<<"$2" | head -1 | grep . || echo -1
}
# processo principal do Brave daquela conta (pela pasta de dados)
pid_of() {
    local p
    for p in $(pgrep -x brave); do
        tr '\0' '\n' < "/proc/$p/cmdline" 2>/dev/null | grep -qx -- "--user-data-dir=$DATA/$1" || continue
        tr '\0' '\n' < "/proc/$p/cmdline" | grep -q -- '^--type=' && continue
        echo "$p"; return
    done
}
launch() {
    local id=$1 dir="$DATA/$1"
    mkdir -p "$dir"
    # migração: login antigo ficou no perfil "Default" -> renomeia para wa-<id>
    if [[ -d $dir/Default && ! -e $dir/wa-$id && -z $(pid_of "$id") ]]; then mv "$dir/Default" "$dir/wa-$id"; fi
    hyprctl dispatch "hl.dsp.exec_cmd(\"brave --user-data-dir=$dir --profile-directory=wa-$id --app=$URL --no-first-run --no-default-browser-check\")" >/dev/null
}

case "${1:-}" in
start)
    c=$(clients)
    for id in "${IDS[@]}"; do [[ $(count "$id" "$c") == -1 && -z $(pid_of "$id") ]] && launch "$id"; done ;;
toggle)
    id=${2:?conta}
    if [[ $(count "$id" "$(clients)") == -1 ]]; then
        # só abre se o processo da conta não existir (senão o Brave abriria outra janela)
        [[ -z $(pid_of "$id") ]] && launch "$id"
        for _ in $(seq 80); do sleep 0.25; [[ $(count "$id" "$(clients)") != -1 ]] && break; done
    fi
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"wa-$id\")" >/dev/null
    # Mostrou? Foco na janela e centraliza no monitor atual (ela pode ter nascido
    # no outro monitor; sem o foco, atalhos como maximizar agiriam em outra janela)
    if hyprctl monitors -j | jq -e --arg s "special:wa-$id" '.[] | select(.focused) | .specialWorkspace.name == $s' >/dev/null; then
        addr=$(jq -r --arg c "$(cls "$id")" '[.[] | select(.class == $c)][0].address' <<<"$(clients)")
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null
        hyprctl dispatch "hl.dsp.window.center()" >/dev/null
    fi ;;
stop)
    p=$(pid_of "${2:?conta}"); [[ -n $p ]] && kill "$p" ;;
status)
    c=$(clients); out="["
    for id in "${IDS[@]}"; do
        out+=$(jq -c --arg i "$id" --argjson n "$(count "$id" "$c")" '.accounts[] | select(.id == $i) | . + {n: $n}' "$CONF"),
    done
    echo "${out%,}]" ;;
waybar)
    c=$(clients); total=0; tip=""; any=0
    for id in "${IDS[@]}"; do
        n=$(count "$id" "$c")
        (( n >= 0 )) && any=1
        (( n > 0 )) && total=$((total + n))
        tip+="${tip:+ · }$(name "$id") $([[ $n == -1 ]] && echo fechado || { (( n > 0 )) && echo "$n" || echo aberto; })"
    done
    if (( ! any )); then echo '{"text":""}'
    elif (( total > 0 )); then printf '{"text":"󰖣 %d","class":"unread","tooltip":"%s"}\n' "$total" "$tip"
    else printf '{"text":"󰖣","class":"zero","tooltip":"%s"}\n' "$tip"; fi ;;
menu)
    pkill -x rofi && exit 0
    k() { printf "<span foreground='#C8F031'>%s</span> %s" "$1" "$2"; }
    SEP="<span foreground='#2A2A27'>  ·  </span>"
    HELP="<span font_size='small' foreground='#8A8A84'>$(k '↵' abrir/esconder)${SEP}$(k '↑↓' escolher)${SEP}$(k esc sair)</span>"
    THEME="mainbox { children: [ inputbar, listview, message ]; } message { padding: 10px 0 0 0; border: 1px 0 0 0; border-color: #2A2A27; } textbox { horizontal-align: 0.5; } listview { lines: ${#IDS[@]}; } window { width: 520px; }"
    c=$(clients); rows=""
    for id in "${IDS[@]}"; do
        n=$(count "$id" "$c"); nm=$(name "$id")
        if   (( n > 0 ));  then badge="<span foreground='#C8F031'><b>$n</b></span>"; dot="#C8F031"
        elif (( n == 0 )); then badge="<span foreground='#8A8A84'>aberto</span>";  dot="#8A8A84"
        else                    badge="<span foreground='#8A8A84'>fechado</span>"; dot="#2A2A27"; fi
        rows+="<span foreground='$dot'>■</span>  $(printf '%-14s' "${nm^^}")  $badge"$'\n'
    done
    i=$(printf '%s' "$rows" | rofi -dmenu -i -markup-rows -no-custom -format i -p "whatsapp" \
          -mesg "$HELP" -theme-str "$THEME") || exit 0
    [[ -n $i ]] && exec "$0" toggle "${IDS[$i]}" ;;
*) echo "uso: $0 start|toggle <id>|stop <id>|menu|status|waybar" >&2; exit 1 ;;
esac
