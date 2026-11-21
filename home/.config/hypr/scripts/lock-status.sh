#!/usr/bin/env bash
# Linhas extras da tela de bloqueio (hyprlock), em pango:
#   lock-status.sh music  -> "♪ música — artista" (vazio se nada tocando)
#   lock-status.sh status -> "■ DOKPLOY | ■ BACKUP 22H" (mesma linha do rodapé do desktop)
set -uo pipefail
LIME='#C8F031'; CORAL='#FF5A4E'; STATIC='#8A8A84'; LINE='#2A2A27'
esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

case "${1:-}" in
music)
    st=$(playerctl status 2>/dev/null) || exit 0
    [[ $st == Playing || $st == Paused ]] || exit 0
    t=$(playerctl metadata --format '{{title}}' 2>/dev/null | esc)
    a=$(playerctl metadata --format '{{artist}}' 2>/dev/null | esc)
    icon=$([[ $st == Playing ]] && echo "󰎈" || echo "󰏤")
    echo "<span foreground='$LIME'>$icon</span>  $t<span foreground='$STATIC'>${a:+  —  $a}</span>"
    ;;
status)
    cfg="$HOME/.config/eliasolie/vps.json"
    [[ -f $cfg ]] || cfg="$HOME/.config/quickshell/vps.json"
    out=""
    while IFS=$'\t' read -r name url; do
        code=$(curl -s -o /dev/null -m 6 -w '%{http_code}' "$url")
        c=$([[ $code -gt 0 && $code -lt 500 ]] && echo "$LIME" || echo "$CORAL")
        out+="${out:+<span foreground='$LINE'>   |   </span>}<span foreground='$c'>■</span>  ${name^^}"
    done < <(jq -r '.services[] | "\(.name)\t\(.url)"' "$cfg" 2>/dev/null)
    read -r ok last < <("$HOME/.config/hypr/scripts/backup-status.sh")
    if [[ $ok == ok ]]; then
        h=$(( ($(date +%s) - last) / 3600 ))
        c=$( (( h < 26 )) && echo "$LIME" || echo "$CORAL")
        age=$( (( h < 48 )) && echo "${h}H" || echo "$(( h / 24 ))D")
    else c=$CORAL; age="?"; fi
    out+="<span foreground='$LINE'>   |   </span><span foreground='$c'>■</span>  BACKUP $age"
    echo "<span foreground='$STATIC'>$out</span>"
    ;;
esac
