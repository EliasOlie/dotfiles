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
agenda)
    # Próximos eventos de ~/.local/share/eliasolie/agenda.json (mesmo arquivo do desktop)
    python3 - <<'PY'
import json, os, datetime as dt
try: ev = json.load(open(os.path.expanduser("~/.local/share/eliasolie/agenda.json")))
except Exception: raise SystemExit
now = dt.datetime.now().astimezone()
def parse(s):
    d = dt.datetime.fromisoformat(s)
    return d if d.tzinfo else d.astimezone()      # dia inteiro vem sem fuso: hora local
COR = {"eliasolie": "#C8F031", "conectame": "#6EEB62", "pessoal": "#7AA7FF"}
DIAS = ["SEG", "TER", "QUA", "QUI", "SEX", "SÁB", "DOM"]
esc = lambda t: t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
items = sorted(((parse(e["start"]), parse(e.get("end") or e["start"]), e) for e in ev), key=lambda x: x[0])
items = [x for x in items if x[1] >= now][:4]
if not items: raise SystemExit
out = ["<span foreground='#8A8A84' letter_spacing='3000'>PRÓXIMOS</span>", ""]
for s, e, it in items:
    d = s.date() - now.date()
    day = "HOJE" if d.days == 0 else "AMANHÃ" if d.days == 1 else f"{DIAS[s.weekday()]} {s:%d/%m}"
    when = f"{day} · DIA TODO" if it.get("allDay") else f"{day} · {s:%H:%M}"
    c = COR.get(it.get("brand") or "", "#8A8A84")
    out.append(f"<span foreground='{c}'>■</span>  <span foreground='#8A8A84'>{when}</span>")
    out.append(f"   <span foreground='#EDEDE8'>{esc(it['title'][:42])}</span>")
    out.append("")
print("\n".join(out).rstrip())
PY
    ;;
esac
