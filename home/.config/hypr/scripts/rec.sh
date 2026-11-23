#!/usr/bin/env bash
# Gravar a tela (Super+Shift+R liga/desliga):
#   1. menu do som: sem som · computador · microfone · computador + microfone
#      (já vem marcada a última escolha)
#   2. selecione uma área com o mouse — ou Esc para gravar o monitor inteiro
#   Vídeo em ~/Vídeos/gravacoes/ (H.264 pela GPU Intel quando dá, senão pelo
#   processador). Bolinha coral na waybar enquanto grava.
#
#   rec.sh                         liga (com os menus) / desliga
#   rec.sh start <som> [tela]      liga direto. som: nenhum|pc|mic|ambos · tela = monitor inteiro
#   rec.sh waybar                  módulo custom/rec (fica ouvindo; sem processo por segundo)
set -u
STATE="${XDG_RUNTIME_DIR:-/tmp}/rec"          # "<pid> <início> <arquivo> [módulos de áudio…]"
LAST="${XDG_CACHE_HOME:-$HOME/.cache}/rec-audio"
OUT="${XDG_VIDEOS_DIR:-$HOME/Vídeos}/gravacoes"

stop() {
    read -r pid _ file mods < "$STATE"
    kill -INT "$pid" 2>/dev/null
    for _ in $(seq 50); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    for m in $mods; do pactl unload-module "$m" 2>/dev/null; done     # desfaz a mistura de áudio
    rm -f "$STATE"
    notify-send -a gravar -i media-record "Gravação salva" "$(basename "$file")" -A "abrir=Abrir pasta" \
        | grep -q abrir && xdg-open "$OUT" &
}

start() {   # $1 = nenhum|pc|mic|ambos · $2 = "tela" para o monitor inteiro
    local som=$1 mods="" dev=""
    command -v wf-recorder >/dev/null || { notify-send -a gravar "Gravar tela" "Instale o wf-recorder (pacman -S wf-recorder)"; exit 1; }
    mkdir -p "$OUT"
    local file="$OUT/$(date +%Y-%m-%d_%H-%M-%S).mp4" geo
    if [[ ${2:-} != tela ]] && area=$(slurp 2>/dev/null); then geo=(-g "$area")
    else geo=(-o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')"); fi

    local sink mic
    sink=$(pactl get-default-sink); mic=$(pactl get-default-source)
    case $som in
        pc)    dev="$sink.monitor" ;;
        mic)   dev="$mic" ;;
        ambos) # saída virtual só durante a gravação: o som do PC e o microfone entram nela
               local m0 m1 m2
               m0=$(pactl load-module module-null-sink sink_name=rec_mix sink_properties=device.description=Gravacao)
               m1=$(pactl load-module module-loopback source="$sink.monitor" sink=rec_mix latency_msec=30)
               m2=$(pactl load-module module-loopback source="$mic" sink=rec_mix latency_msec=30)
               mods="$m2 $m1 $m0"; dev="rec_mix.monitor" ;;
    esac
    local audio=(); [[ -n $dev ]] && audio=(--audio="$dev")

    # H.264 pela GPU Intel (VA-API); se falhar em 1 s, cai pro libx264
    wf-recorder "${geo[@]}" "${audio[@]}" -c h264_vaapi -d /dev/dri/renderD128 -f "$file" >/dev/null 2>&1 &
    local pid=$!; sleep 1
    if ! kill -0 "$pid" 2>/dev/null; then
        wf-recorder "${geo[@]}" "${audio[@]}" -c libx264 -p preset=veryfast -f "$file" >/dev/null 2>&1 &
        pid=$!
    fi
    echo "$pid $(date +%s) $file $mods" > "$STATE"
    local nome; case $som in pc) nome="com o som do computador";; mic) nome="com o microfone";; ambos) nome="com computador + microfone";; *) nome="sem som";; esac
    notify-send -a gravar -i media-record "Gravando $nome" "Super+Shift+R de novo para parar"
}

case "${1:-toggle}" in
toggle)
    if [[ -f $STATE ]]; then stop; exit 0; fi
    pkill -x rofi && exit 0
    opts=("sem som" "som do computador" "microfone" "computador + microfone"); keys=(nenhum pc mic ambos)
    last=$(cat "$LAST" 2>/dev/null); sel=0
    for i in "${!keys[@]}"; do [[ ${keys[$i]} == "$last" ]] && sel=$i; done
    k() { printf "<span foreground='#C8F031'>%s</span> %s" "$1" "$2"; }
    SEP="<span foreground='#2A2A27'>  ·  </span>"
    HELP="<span font_size='small' foreground='#8A8A84'>$(k '↵' escolher)${SEP}depois selecione a área (ou $(k esc tela\ inteira))</span>"
    THEME='mainbox { children: [ inputbar, listview, message ]; } message { padding: 10px 0 0 0; border: 1px 0 0 0; border-color: #2A2A27; } textbox { horizontal-align: 0.5; } listview { lines: 4; } window { width: 460px; }'
    i=$(printf '%s\n' "${opts[@]}" | rofi -dmenu -i -no-custom -format i -p "gravar" -selected-row "$sel" \
          -mesg "$HELP" -theme-str "$THEME") || exit 0
    [[ -n $i ]] || exit 0
    mkdir -p "$(dirname "$LAST")"; echo "${keys[$i]}" > "$LAST"
    start "${keys[$i]}" ;;
start)
    [[ -f $STATE ]] && { echo "já está gravando" >&2; exit 1; }
    start "${2:-nenhum}" "${3:-}" ;;
waybar)
    # escuta sem criar processos: o "read -t" num fifo próprio serve de espera
    # (1 s gravando, 2 s parado); a waybar lê cada linha nova
    fifo="${XDG_RUNTIME_DIR:-/tmp}/rec-waybar.$$"; mkfifo "$fifo"; exec 3<>"$fifo"; rm -f "$fifo"
    last=""
    while :; do
        if [[ -f $STATE ]]; then
            read -r _ start _ < "$STATE"
            s=$(( EPOCHSECONDS - start ))
            printf '{"text":"● REC %02d:%02d","class":"on","tooltip":"gravando · Super+Shift+R para parar"}\n' $((s / 60)) $((s % 60))
            last=on; read -r -t 1 -u 3 _ || true
        else
            [[ $last != off ]] && echo '{"text":""}'
            last=off; read -r -t 2 -u 3 _ || true
        fi
    done ;;
esac
