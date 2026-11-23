#!/usr/bin/env bash
# Gravar a tela (Super+Shift+R liga/desliga):
#   ao ligar, selecione uma área com o mouse — ou aperte Esc para gravar o
#   monitor inteiro em que você está. Vídeo em ~/Vídeos/gravacoes/ (H.264 pela
#   GPU Intel quando dá, senão pelo processador). Bolinha coral na waybar.
#   rec.sh waybar → módulo custom/rec (fica ouvindo; sem processo por segundo)
set -u
STATE="${XDG_RUNTIME_DIR:-/tmp}/rec"          # "<pid> <início> <arquivo>"
OUT="${XDG_VIDEOS_DIR:-$HOME/Vídeos}/gravacoes"

refresh() { :; }   # a waybar percebe sozinha em até 2 s (ver "waybar" abaixo)

case "${1:-toggle}" in
toggle)
    if [[ -f $STATE ]]; then
        read -r pid _ file < "$STATE"
        kill -INT "$pid" 2>/dev/null
        for _ in $(seq 50); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
        rm -f "$STATE"; refresh
        notify-send -a gravar -i media-record "Gravação salva" "$(basename "$file")  ·  clique para abrir a pasta" \
            -A "abrir=Abrir pasta" | grep -q abrir && xdg-open "$OUT" &
        exit 0
    fi
    command -v wf-recorder >/dev/null || { notify-send -a gravar "Gravar tela" "Instale o wf-recorder (pacman -S wf-recorder)"; exit 1; }
    mkdir -p "$OUT"
    file="$OUT/$(date +%Y-%m-%d_%H-%M-%S).mp4"
    if area=$(slurp 2>/dev/null); then geo=(-g "$area")
    else geo=(-o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')"); fi
    # H.264 pela GPU Intel (VA-API); se falhar em 1 s, cai pro libx264
    wf-recorder "${geo[@]}" -c h264_vaapi -d /dev/dri/renderD128 -f "$file" >/dev/null 2>&1 &
    pid=$!; sleep 1
    if ! kill -0 "$pid" 2>/dev/null; then
        wf-recorder "${geo[@]}" -c libx264 -p preset=veryfast -f "$file" >/dev/null 2>&1 &
        pid=$!
    fi
    echo "$pid $(date +%s) $file" > "$STATE"; refresh
    notify-send -a gravar -i media-record "Gravando" "Super+Shift+R de novo para parar" ;;
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
