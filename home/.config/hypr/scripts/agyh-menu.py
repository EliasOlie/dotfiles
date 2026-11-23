#!/usr/bin/env python3
"""agyh pelo rofi (mesmo visual do Janus/Bitwarden).

  agyh-menu.py               busca: sessões recentes de todos os agentes; o rofi
                             filtra enquanto você digita; Enter num texto sem
                             resultado = busca completa no histórico (agyh search)
  agyh-menu.py project DIR   sessões daquele workspace + "nova sessão" (Claude/agy)

Dentro da lista:  Enter retoma a sessão no agente e workspace dela (agyh resume)
                  Alt+V mostra a conversa no leitor (Neovim só leitura)
"""
import json, os, subprocess, sys, tempfile

AGYH = os.path.expanduser("~/.local/bin/agyh")
THEME = ("mainbox { children: [ inputbar, listview, message ]; } "
         "message { padding: 10px 0 0 0; border: 1px 0 0 0; border-color: #2A2A27; } "
         "textbox { horizontal-align: 0.5; } window { width: 900px; }")
SEP = "<span foreground='#2A2A27'>  ·  </span>"
COLOR = {"claude": "#C8F031", "agy": "#7AA7FF", "codex": "#F2C94C"}


def k(key, label): return f"<span foreground='#C8F031'>{key}</span> {label}"
def esc(s): return (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
def notify(msg): subprocess.run(["notify-send", "-a", "agyh", "agyh", msg], check=False)


def agyh_json(*args):
    r = subprocess.run([AGYH, *args, "--json"], capture_output=True, text=True, timeout=30)
    try: return json.loads(r.stdout or "[]") or []
    except ValueError: return []


def rofi(prompt, lines, mesg):
    """(código, índice, texto). 0 = Enter · 10 = Alt+V"""
    r = subprocess.run(["rofi", "-dmenu", "-i", "-markup-rows", "-p", prompt, "-format", "i:s",
                        "-mesg", mesg, "-theme-str", THEME, "-kb-custom-1", "Alt+v"],
                       input="\n".join(lines), capture_output=True, text=True)
    if r.returncode not in (0, 10): return None, None, None
    idx, _, text = r.stdout.rstrip("\n").partition(":")
    return r.returncode, int(idx) if idx.lstrip("-").isdigit() else -1, text


def row(s):
    a = s.get("agent", "")
    when = (s.get("updated_at") or s.get("started_at") or "")[:16].replace("T", " ")
    ws = os.path.basename((s.get("workspace") or "").rstrip("/")) or "~"
    title = " ".join((s.get("title") or s.get("preview") or "").split())[:80]
    snip = " ".join((s.get("snippet") or "").split())[:70]
    tail = f"  <span foreground='#4A4A45'>{esc(snip)}</span>" if snip and snip != title else ""
    return (f"<span foreground='{COLOR.get(a, '#8A8A84')}'>{a:<6}</span> "
            f"<span foreground='#8A8A84'>{when[5:]}  {esc(ws)}</span>  {esc(title)}{tail}")


def resume(s):
    ws = s.get("workspace") or os.path.expanduser("~")
    subprocess.Popen(["kitty", "--directory", ws, "--title", f"{s.get('agent')} · {os.path.basename(ws)}",
                      AGYH, "resume", s["id"]])


def view(s):
    out = subprocess.run([AGYH, "show", s["id"]], capture_output=True, text=True).stdout
    f = tempfile.NamedTemporaryFile("w", suffix=".md", prefix="agyh-", delete=False)
    f.write(out); f.close()
    subprocess.Popen(["kitty", "--class", "janus-view", "--title", "agyh", "nvim", "-R",
                      "-c", "setlocal nomodifiable nonumber norelativenumber wrap linebreak signcolumn=no",
                      "-c", "nnoremap <buffer> q <Cmd>qa!<CR>", "-c", "nnoremap <buffer> <Esc> <Cmd>qa!<CR>",
                      "-c", f"autocmd VimLeave * call delete('{f.name}')", f.name])


def act(code, s):
    (view if code == 10 else resume)(s)


def search():
    recent = agyh_json("ls", "-n", "60")
    h = (f"<span font_size='small' foreground='#8A8A84'>{k('digite', 'filtra')}{SEP}"
         f"{k('↵ sem resultado', 'busca no histórico')}{SEP}{k('↵', 'retomar')}{SEP}{k('alt v', 'ver conversa')}</span>")
    code, idx, text = rofi("agyh", [row(s) for s in recent], h)
    if code is None: return
    if 0 <= idx < len(recent): return act(code, recent[idx])
    q = (text or "").strip()
    if not q: return
    found = agyh_json("search", *q.split(), "-n", "40")
    if not found: return notify(f"Nada encontrado para “{q}”")
    h2 = f"<span font_size='small' foreground='#8A8A84'>“{esc(q)}”{SEP}{k('↵', 'retomar')}{SEP}{k('alt v', 'ver conversa')}</span>"
    code, idx, _ = rofi("agyh", [row(s) for s in found], h2)
    if code is not None and 0 <= idx < len(found): act(code, found[idx])


def project(d):
    d = os.path.abspath(os.path.expanduser(d))
    sessions = [s for s in agyh_json("ls", "-w", d, "-n", "40") if (s.get("workspace") or "").rstrip("/") == d.rstrip("/")]
    news = [("claude", "<b>+ nova sessão</b>  claude"),
            ("agy", "<b>+ nova sessão</b>  agy")]
    h = (f"<span font_size='small' foreground='#8A8A84'>{esc(os.path.basename(d))}{SEP}{k('↵', 'retomar / criar')}"
         f"{SEP}{k('alt v', 'ver conversa')}{SEP}{len(sessions)} sessões</span>")
    code, idx, _ = rofi("agyh", [n[1] for n in news] + [row(s) for s in sessions], h)
    if code is None or idx < 0: return
    if idx < len(news):
        agent = news[idx][0]
        subprocess.Popen(["kitty", "--directory", d, "--title", f"{agent} · {os.path.basename(d)}",
                          AGYH, "new", agent, "-w", d])
    elif idx - len(news) < len(sessions):
        act(code, sessions[idx - len(news)])


def main():
    if subprocess.run(["pkill", "-x", "rofi"]).returncode == 0: return
    if len(sys.argv) > 2 and sys.argv[1] == "project": project(sys.argv[2])
    else: search()


if __name__ == "__main__":
    main()
