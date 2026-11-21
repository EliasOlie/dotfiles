#!/usr/bin/env bash
# Utilitários do rofi com o mesmo rodapé de ajuda do bitwarden.sh
#   rofi-tools.sh clip   -> histórico da área de transferência (com prévia de imagens)
#   rofi-tools.sh emoji  -> emojis e símbolos
#   rofi-tools.sh calc   -> calculadora (qalc)
set -u
pkill -x rofi && exit 0

k() { printf "<span foreground='#C8F031'>%s</span> %s" "$1" "$2"; }
SEP="<span foreground='#2A2A27'>  ·  </span>"
help() { local out="" i; for i in "$@"; do out+="${out:+$SEP}$i"; done; printf "<span font_size='small' foreground='#8A8A84'>%s</span>" "$out"; }
THEME='mainbox { children: [ inputbar, listview, message ]; } message { padding: 10px 0 0 0; border: 1px 0 0 0; border-color: #2A2A27; } textbox { horizontal-align: 0.5; }'

case "${1:-}" in
clip)
    THUMBS="${XDG_CACHE_HOME:-$HOME/.cache}/cliphist-thumbs"
    mkdir -p "$THUMBS"
    while :; do
        # Imagens ganham miniatura (ícone da linha); texto aparece normal
        # (direto no pipe: guardar numa variável perderia os \0 dos ícones)
        sel=$(cliphist list | while IFS= read -r line; do
            id=${line%%$'\t'*}
            if [[ $line =~ \[\[\ binary\ data.*(png|jpe?g|webp|bmp) ]]; then
                t="$THUMBS/$id.png"
                [[ -s $t ]] || cliphist decode <<<"$line" > "$t" 2>/dev/null
                printf '%s\0icon\x1f%s\n' "$line" "$t"
            else
                printf '%s\n' "$line"
            fi
        done | rofi -dmenu -i -p "clipboard" -show-icons -display-columns 2 -display-column-separator '\t' \
                -kb-custom-1 "Alt+d" -kb-custom-2 "Alt+Shift+d" \
                -mesg "$(help "$(k '↵' copiar)" "$(k 'alt d' apagar)" "$(k 'alt shift d' limpar\ tudo)")" \
                -theme-str "$THEME element-icon { size: 36px; }")
        rc=$?
        case $rc in
            0)  cliphist decode <<<"$sel" | wl-copy; exit 0 ;;
            10) cliphist delete <<<"$sel"; rm -f "$THUMBS/${sel%%$'\t'*}.png" ;;   # apaga e reabre
            11) cliphist wipe; rm -f "$THUMBS"/*.png; notify-send -a clipboard "Clipboard" "Histórico limpo"; exit 0 ;;
            *)  exit 0 ;;
        esac
    done
    ;;
emoji)
    # rofi-emoji: Enter digita na janela ativa; Shift+Enter abre o menu (copiar etc.)
    exec rofi -modi emoji -show emoji -p "emoji" \
        -mesg "$(help "$(k '↵' inserir)" "$(k 'shift ↵' copiar\ /\ mais)" "digite em inglês: heart, fire, check")" \
        -theme-str "$THEME"
    ;;
calc)
    # Enter copia o resultado (o rofi-calc usa a área de mensagem para o resultado,
    # então aqui não tem rodapé de ajuda). Ex.: 15% de 380 · 3h20 to min · 100 usd to brl
    exec rofi -show calc -modi calc -no-show-match -no-sort -p "calc" \
        -calc-command "echo -n '{result}' | wl-copy" \
        -theme-str "$THEME"
    ;;
*) echo "uso: $0 clip|emoji|calc" >&2; exit 1 ;;
esac
