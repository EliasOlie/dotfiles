#!/usr/bin/env python3
"""Bitwarden/Vaultwarden pelo rofi (rbw), com credenciais E notas.

  bitwarden.py          lista tudo (Super+Shift+P)
      Enter   credencial: digita usuário ⇥ senha na janela ativa
              nota:       copia a nota inteira (para colar/compartilhar)
      Alt+U   copia o usuário      Alt+P  copia a senha      Alt+T  copia o TOTP
      Alt+V   ver: abre um 2º modal com todos os campos (usuário, senha, TOTP,
              URLs, campos personalizados, nota) — setas navegam, Enter copia o
              selecionado e fecha tudo, Esc volta para a lista
  bitwarden.py totp     escolhe um item e copia o TOTP (sem atalho; no menu use Alt+T)

Segurança: cópias com wl-copy --sensitive (o cliphist não guarda) e apagadas em
20 s se ainda estiverem na área de transferência; segredos nunca vão para a
linha de comando de processos (vão por stdin).
"""
import json, os, subprocess, sys, time

CLEAR_AFTER = 20
SEP = "<span foreground='#2A2A27'>  ·  </span>"
THEME = ("mainbox { children: [ inputbar, listview, message ]; } "
         "message { padding: 10px 0 0 0; border: 1px 0 0 0; border-color: #2A2A27; } "
         "textbox { horizontal-align: 0.5; } window { width: 760px; }")
ICON = {"Login": "\U000f030b", "Note": "\U000f039e", "SecureNote": "\U000f039e",
        "Card": "\U000f019b", "Identity": "\U000f0004"}


def k(key, label): return f"<span foreground='#C8F031'>{key}</span> {label}"
def esc(s): return (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
def notify(title, body=""): subprocess.run(["notify-send", "-a", "bitwarden", title, body], check=False)


def rbw(*args, check=True):
    r = subprocess.run(["rbw", *args], capture_output=True, text=True)
    if check and r.returncode != 0: raise RuntimeError(r.stderr.strip() or "rbw falhou")
    return r.stdout


def rofi(prompt, lines, mesg, keys=()):
    """(código, índice). 0 = Enter · 10+ = Alt+… na ordem de `keys`."""
    cmd = ["rofi", "-dmenu", "-i", "-markup-rows", "-no-custom", "-format", "i", "-p", prompt,
           "-mesg", mesg, "-theme-str", THEME]
    for n, key in enumerate(keys, 1): cmd += [f"-kb-custom-{n}", key]
    r = subprocess.run(cmd, input="\n".join(lines), capture_output=True, text=True)
    if r.returncode not in [0] + [9 + n for n in range(1, len(keys) + 1)]: return None, None
    out = r.stdout.strip()
    return r.returncode, int(out) if out.lstrip("-").isdigit() else -1


# ---------------------------------------------------------------- área de transferência / digitar
def copy(value, what):
    subprocess.run(["wl-copy", "--sensitive"], input=value, text=True)
    # apaga depois de CLEAR_AFTER s se ainda for o mesmo conteúdo (processo à parte, valor por stdin)
    p = subprocess.Popen([sys.executable, os.path.abspath(__file__), "--clear-later"],
                         stdin=subprocess.PIPE, text=True, start_new_session=True)
    p.stdin.write(value); p.stdin.close()
    notify(f"{what} copiado", f"some da área de transferência em {CLEAR_AFTER} s")


def clear_later():
    value = sys.stdin.read()
    time.sleep(CLEAR_AFTER)
    cur = subprocess.run(["wl-paste", "-n"], capture_output=True, text=True).stdout
    if cur == value or cur == value.rstrip("\n"):
        subprocess.run(["wl-copy", "--clear"])


def type_text(text):
    subprocess.run(["wtype", "-"], input=text, text=True)


def type_login(user, password):
    time.sleep(0.15)                      # deixa o foco voltar para a janela de destino
    if user: type_text(user); subprocess.run(["wtype", "-k", "Tab"])
    if password: type_text(password)


# ---------------------------------------------------------------- dados
def entries():
    rows = []
    for line in rbw("list", "--fields", "id,name,user,folder,type").splitlines():
        parts = (line.split("\t") + [""] * 5)[:5]
        rows.append(dict(zip(["id", "name", "user", "folder", "type"], parts)))
    rows.sort(key=lambda e: (e["folder"] or "~", e["name"].lower()))
    return rows


def details(e):
    try: return json.loads(rbw("get", "--raw", e["id"]))
    except Exception: return {}


def totp(e):
    return rbw("code", e["id"], check=False).strip()


def is_note(e): return e["type"] in ("Note", "SecureNote")


def row(e):
    ic = ICON.get(e["type"], "\U000f030b")
    sub = e["user"] or ("nota" if is_note(e) else e["type"].lower())
    folder = f"  <span foreground='#4A4A45'>{esc(e['folder'])}</span>" if e["folder"] else ""
    return f"<span foreground='#C8F031'>{ic}</span>  {esc(e['name'])}  <span foreground='#8A8A84'>{esc(sub)}</span>{folder}"


# ---------------------------------------------------------------- 2º modal: ver campos
def view(e):
    """Mostra os campos; Enter copia o selecionado e fecha tudo. Devolve False se voltou (Esc)."""
    d = details(e)
    data = d.get("data") or {}
    fields = []   # (rótulo, valor exibido, valor real, segredo?)
    def add(label, value, secret=False, shown=None):
        if value: fields.append((label, shown or (("•" * 10) if secret else value), value, secret))

    if is_note(e):
        note = d.get("notes") or ""
        add("nota inteira", note, True, shown=f"{len(note.splitlines())} linhas · Enter copia tudo")
        for ln in note.splitlines():
            if ln.strip(): add("linha", ln.strip(), True, shown=ln.strip())
    else:
        add("usuário", data.get("username") or e["user"])
        add("senha", data.get("password"), True)
        if data.get("totp"): add("totp", totp(e), True, shown=totp(e))
        for u in data.get("uris") or []:
            add("url", u.get("uri") if isinstance(u, dict) else u)
        # cartão / identidade: o que vier em data, menos o que já foi mostrado
        for key, val in data.items():
            if key in ("username", "password", "totp", "uris") or not isinstance(val, str): continue
            add(key.replace("_", " "), val, key in ("number", "code", "ssn", "passport_number"))
        for f in d.get("fields") or []:
            add(f.get("name") or "campo", f.get("value"), (f.get("type") in (1, "hidden")))
        if d.get("notes"):
            add("nota", d["notes"], True, shown=" ".join(d["notes"].split())[:80])

    if not fields:
        notify("Bitwarden", "Esse item não tem campos para copiar."); return True
    w = max(len(f[0]) for f in fields)
    lines = [f"<span foreground='#8A8A84'>{esc(lbl.ljust(w))}</span>   {esc(shown)}" for lbl, shown, _, _ in fields]
    mesg = (f"<span font_size='small' foreground='#8A8A84'><b>{esc(e['name'])}</b>{SEP}"
            f"{k('↑↓', 'navegar')}{SEP}{k('↵', 'copiar e fechar')}{SEP}{k('esc', 'voltar')}</span>")
    code, idx = rofi("campos", lines, mesg)
    if code is None: return False
    if 0 <= idx < len(fields):
        lbl, _, value, _ = fields[idx]
        copy(value, "Nota" if lbl in ("nota inteira", "nota") else lbl.capitalize())
    return True


# ---------------------------------------------------------------- lista principal
def main_menu(mode):
    items = entries()
    if mode == "totp": items = [e for e in items if not is_note(e)]
    if mode == "totp":
        mesg = f"<span font_size='small' foreground='#8A8A84'>{k('↵', 'copiar TOTP')}{SEP}{k('esc', 'sair')}</span>"
        code, idx = rofi("totp", [row(e) for e in items], mesg)
        if code is None or not 0 <= idx < len(items): return
        c = totp(items[idx])
        return copy(c, "TOTP") if c else notify("Bitwarden", "Esse item não tem TOTP.")

    mesg = (f"<span font_size='small' foreground='#8A8A84'>{k('↵', 'digitar / copiar nota')}{SEP}"
            f"{k('alt u', 'usuário')}{SEP}{k('alt p', 'senha')}{SEP}{k('alt t', 'totp')}{SEP}{k('alt v', 'ver campos')}</span>")
    while True:
        code, idx = rofi("bitwarden", [row(e) for e in items], mesg, keys=("Alt+u", "Alt+p", "Alt+t", "Alt+v"))
        if code is None or not 0 <= idx < len(items): return
        e = items[idx]
        if code == 13:                                     # Alt+V: 2º modal
            if view(e): return
            continue                                       # Esc no 2º modal: volta para a lista
        d = details(e); data = d.get("data") or {}
        if code == 0:
            if is_note(e):
                note = d.get("notes") or ""
                return copy(note, "Nota") if note else notify("Bitwarden", "Nota vazia.")
            return type_login(data.get("username") or e["user"], data.get("password") or "")
        if code == 10: v = data.get("username") or e["user"]; what = "Usuário"
        elif code == 11: v = data.get("password"); what = "Senha"
        else: v = totp(e) if data.get("totp") else ""; what = "TOTP"
        return copy(v, what) if v else notify("Bitwarden", f"Esse item não tem {what.lower()}.")


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--clear-later": return clear_later()
    if subprocess.run(["pkill", "-x", "rofi"]).returncode == 0: return
    try: base = json.loads(rbw("config", "show")).get("base_url") or ""
    except Exception: base = ""
    if not base.startswith("http"):
        return notify("Bitwarden", "rbw ainda não configurado. No terminal: rbw config set base_url https://SEU-VAULTWARDEN && rbw config set email SEU@EMAIL && rbw login")
    if subprocess.run(["rbw", "unlocked"], capture_output=True).returncode != 0:
        if subprocess.run(["rbw", "unlock"]).returncode != 0: return notify("Bitwarden", "Cofre continua trancado")
    try:
        main_menu(sys.argv[1] if len(sys.argv) > 1 else "")
    except Exception as ex:
        notify("Bitwarden", f"Erro: {ex}")


if __name__ == "__main__":
    main()
