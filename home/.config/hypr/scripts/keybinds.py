#!/usr/bin/env python3
"""Cola de atalhos (Super+H): lista todos os keybinds e o que cada um faz.

Lê direto do Hyprland (`hyprctl binds -j`), então está sempre atualizada:
qualquer atalho novo com descrição no keybinds.lua aparece aqui sozinho.
Atalhos numerados (workspace 1..10) viram uma linha só ("Super + 1…0").
"""
import json, re, subprocess

MODS = [(64, "Super"), (4, "Ctrl"), (8, "Alt"), (1, "Shift")]
KEYS = {
    "Return": "Enter", "SPACE": "Espaço", "space": "Espaço", "period": ".", "comma": ",",
    "bracketleft": "[", "bracketright": "]", "Tab": "Tab", "Print": "PrtSc", "Delete": "Del",
    "mouse:272": "clique esq.", "mouse:273": "clique dir.", "mouse_down": "roda ↓", "mouse_up": "roda ↑",
    "XF86AudioRaiseVolume": "Vol+", "XF86AudioLowerVolume": "Vol−", "XF86AudioMute": "Mudo",
    "XF86AudioMicMute": "Mic mudo", "XF86AudioPlay": "Play", "XF86AudioPause": "Pause",
    "XF86AudioNext": "Próxima", "XF86AudioPrev": "Anterior", "XF86AudioStop": "Stop",
    "XF86MonBrightnessUp": "Brilho+", "XF86MonBrightnessDown": "Brilho−", "XF86Sleep": "Sleep",
    "left": "←", "right": "→", "up": "↑", "down": "↓",
}
THEME = ("window { width: 980px; } listview { lines: 14; } "
         "mainbox { children: [ inputbar, listview, message ]; } "
         "message { padding: 10px 0 0 0; border: 1px 0 0 0; border-color: #2A2A27; } "
         "textbox { horizontal-align: 0.5; }")


def esc(s): return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def keyname(b):
    k = b["key"]
    if not k and 10 <= b.get("keycode", 0) <= 19:   # teclas 1..0 presas por keycode
        return str((b["keycode"] - 9) % 10)
    return KEYS.get(k, k.upper() if len(k) == 1 else k)


def combo(b):
    mods = [n for m, n in MODS if b["modmask"] & m]
    key = keyname(b)
    return " + ".join(mods + [key])


def main():
    if subprocess.run(["pkill", "-x", "rofi"]).returncode == 0: return
    binds = json.loads(subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True).stdout)

    rows, index = [], {}   # mantém a ordem do keybinds.lua (seções ficam juntas)
    for b in binds:
        desc = b.get("description") or ""
        if not desc: continue
        c = combo(b)
        num = re.search(r"\b(10|[1-9])\b", desc)
        if num and re.fullmatch(r"[0-9]", keyname(b)):   # workspace N -> uma linha só
            desc = desc.replace(num.group(0), "N", 1)
            c = c.rsplit(" + ", 1)[0] + " + 1…0" if " + " in c else "1…0"
        if desc in index:
            if c not in rows[index[desc]][0]: rows[index[desc]][0].append(c)
        else:
            index[desc] = len(rows); rows.append([[c], desc])

    keys = [" / ".join(c) for c, _ in rows]
    w = min(max(len(k) for k in keys), 46)
    lines = [f"<b>{esc(k.ljust(w))}</b>  {esc(d)}" for k, (_, d) in zip(keys, rows)]
    mesg = (f"<span font_size='small' foreground='#8A8A84'>{len(rows)} atalhos"
            f"<span foreground='#2A2A27'>  ·  </span>digite para filtrar por tecla ou ação"
            f"<span foreground='#2A2A27'>  ·  </span><span foreground='#C8F031'>esc</span> fechar</span>")
    subprocess.run(["rofi", "-dmenu", "-i", "-markup-rows", "-no-custom", "-p", "atalhos",
                    "-mesg", mesg, "-theme-str", THEME], input="\n".join(lines), text=True)


if __name__ == "__main__":
    main()
