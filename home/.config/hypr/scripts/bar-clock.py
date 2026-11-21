#!/usr/bin/env python3
"""Relógio da waybar que some quando o desktop do monitor está à mostra.

Com o workspace vazio, o relógio grande do desktop (Quickshell) assume, com a
animação de "voo" entre a barra e o canto inferior esquerdo. Este script escuta
os eventos do Hyprland (socket2) e imprime JSON para o módulo custom/clock:
texto vazio = módulo escondido. Cada barra roda o seu (WAYBAR_OUTPUT_NAME).
"""
import json, os, select, socket, subprocess, sys, time
from datetime import datetime

OUT = os.environ.get("WAYBAR_OUTPUT_NAME", "")
SOCK = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/run/user/%d" % os.getuid()), "hypr",
                    os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", ""), ".socket2.sock")
LAND_DELAY = 0.34   # espera o relógio "voar" de volta para a barra antes de aparecer
MESES = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
DIAS = ["segunda", "terça", "quarta", "quinta", "sexta", "sábado", "domingo"]


def hypr(*args):
    try: return json.loads(subprocess.run(["hyprctl", *args, "-j"], capture_output=True, text=True, timeout=2).stdout)
    except Exception: return []


def desktop_showing():
    mons = hypr("monitors")
    mon = next((m for m in mons if m.get("name") == OUT), mons[0] if mons else None)
    if not mon: return False
    ws = mon["activeWorkspace"]["id"]
    return not any(w.get("id") == ws and w.get("windows", 0) > 0 for w in hypr("workspaces"))


def emit(hidden):
    now = datetime.now()
    tip = f"{DIAS[now.weekday()]}, {now.day} de {MESES[now.month - 1]}"
    print(json.dumps({"text": "" if hidden else now.strftime("%H:%M"), "tooltip": tip,
                      "class": "hidden" if hidden else "shown"}), flush=True)


def main():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCK)
    hidden = desktop_showing()
    emit(hidden)
    buf = b""
    while True:
        timeout = 60 - datetime.now().second + 0.05          # acorda na virada do minuto
        r, _, _ = select.select([s], [], [], timeout)
        if r:
            data = s.recv(65536)
            if not data: sys.exit(1)                           # Hyprland saiu: waybar reinicia o script
            buf += data
            if b"\n" not in buf: continue
            buf = buf.rsplit(b"\n", 1)[1]
            time.sleep(0.03)                                   # deixa o Hyprland assentar o estado
            h = desktop_showing()
            if h == hidden: continue
            if not h: time.sleep(LAND_DELAY)                   # saindo do desktop: espera o pouso
            hidden = h
        emit(hidden)


if __name__ == "__main__":
    main()
