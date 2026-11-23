#!/usr/bin/env python3
"""Janus pelo rofi.

Fala com o Janus pelo próprio MCP (stdio, mesmo `mcp.sh` que o Claude usa).

  janus.py [tudo|wikis|decisoes]   consulta (Super+J). Dentro do menu:
      Alt+T tudo · Alt+W só wikis · Alt+D só decisões
      digitar filtra a lista; Enter num texto sem resultado = busca no Janus
      escolher um item abre o conteúdo completo num kitty flutuante (markdown)
  janus.py registrar               registra uma decisão (Super+Shift+J):
      texto → grupo (lista os existentes ou digite um novo) → record_decision

Caminho do Janus: $JANUS_MCP (padrão ~/work/janus/scripts/mcp.sh).
"""
import json, os, subprocess, sys, tempfile, time

MCP = os.environ.get("JANUS_MCP", os.path.expanduser("~/work/janus/scripts/mcp.sh"))

# Rodapé de ajuda no mesmo estilo do bitwarden.sh
def k(key, label): return f"<span foreground='#C8F031'>{key}</span> {label}"
SEP = "<span foreground='#2A2A27'>  ·  </span>"
THEME = ("mainbox { children: [ inputbar, listview, message ]; } "
         "message { padding: 10px 0 0 0; border: 1px 0 0 0; border-color: #2A2A27; } "
         "textbox { horizontal-align: 0.5; } window { width: 760px; }")


def notify(msg):
    subprocess.run(["notify-send", "-a", "janus", "Janus", msg], check=False)


class Janus:
    def __init__(self):
        self.p = subprocess.Popen(["bash", MCP], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL, text=True)
        self.n = 0
        self.rpc("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                                "clientInfo": {"name": "rofi-janus", "version": "1"}})
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def _send(self, m):
        self.p.stdin.write(json.dumps(m) + "\n"); self.p.stdin.flush()

    def rpc(self, method, params):
        self.n += 1
        self._send({"jsonrpc": "2.0", "id": self.n, "method": method, "params": params})
        while True:
            line = self.p.stdout.readline()
            if not line: raise RuntimeError("Janus não respondeu")
            try: m = json.loads(line)
            except ValueError: continue
            if m.get("id") == self.n:
                if "error" in m: raise RuntimeError(m["error"].get("message", "erro"))
                return m["result"]

    def call(self, tool, **args):
        r = self.rpc("tools/call", {"name": tool, "arguments": args})
        txt = r["content"][0]["text"]
        try: return json.loads(txt)
        except ValueError: return txt

    def close(self): self.p.terminate()


def rofi(prompt, lines, mesg, keys=True):
    """Devolve (código, índice, texto). Código 0 = Enter; 10/11/12 = Alt+T/W/D."""
    cmd = ["rofi", "-dmenu", "-i", "-p", prompt, "-format", "i:s", "-mesg", mesg,
           "-theme-str", THEME, "-markup-rows"]
    if keys:
        cmd += ["-kb-remove-word-forward", "Control+Alt+d",     # libera o Alt+D
                "-kb-custom-1", "Alt+t", "-kb-custom-2", "Alt+w", "-kb-custom-3", "Alt+d"]
    r = subprocess.run(cmd, input="\n".join(lines), capture_output=True, text=True)
    if r.returncode not in (0, 10, 11, 12): return None, None, None
    idx, _, text = r.stdout.rstrip("\n").partition(":")
    return r.returncode, int(idx) if idx.lstrip("-").isdigit() else -1, text


def esc(s): return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def row(dom, title, tag=""):
    t = f"<span foreground='#C8F031'>{esc(tag)}</span>  " if tag else ""
    return f"{t}<span foreground='#8A8A84'>{esc(dom)}</span>  {esc(title)}"


def show(title, body):
    f = tempfile.NamedTemporaryFile("w", suffix=".md", prefix="janus-", delete=False)
    f.write(f"# {title}\n\n{body}\n"); f.close()
    subprocess.Popen(["kitty", "--class", "janus-view", "--title", "Janus",
                      "sh", "-c", f'bat -l md --style=plain --paging=always "{f.name}"; rm -f "{f.name}"'])


def one_line(t, n=120): return " ".join((t or "").split())[:n]


def decision_view(d):
    meta = [f"decisão #{d.get('id','')}", d.get("autor") or "", (d.get("created_at") or "")[:10],
            d.get("grupo_origem") or "", d.get("status") or ""]
    extra = ""
    if d.get("tema"): extra += f"\n\n**Temas:** {', '.join(d['tema'])}"
    if d.get("wpp_message_url"): extra += f"\n\n**Mensagem:** {d['wpp_message_url']}"
    if d.get("substituida_por_id"): extra += f"\n\n**Substituída pela decisão #{d['substituida_por_id']}**"
    return one_line(d.get("texto"), 80), "_" + " · ".join(m for m in meta if m) + "_\n\n" + (d.get("texto") or "") + extra


def item_view(j, item_id):
    it = j.call("get_knowledge", id=item_id)
    if isinstance(it, list): it = it[0] if it else {}
    it = it.get("item", it) if isinstance(it, dict) else {}
    return it.get("titulo", ""), f"_{it.get('sistema','')} · {it.get('tipo','')}_\n\n{it.get('descricao','')}\n\n---\n\n{it.get('conteudo','')}"


MODES = ["tudo", "wikis", "decisoes"]
LABEL = {"tudo": "TUDO", "wikis": "WIKIS", "decisoes": "DECISÕES"}


def tabs(mode):
    parts = [(f"<span foreground='#C8F031'><b>{LABEL[m]}</b></span>" if m == mode else LABEL[m].lower())
             for m in MODES]
    return f"<span font_size='small' foreground='#8A8A84'>{SEP.join(parts)}{SEP}{k('alt t/w/d', 'trocar')}{SEP}{k('↵ sem resultado', 'busca')}{SEP}{k('esc', 'sair')}</span>"


def consult(j, mode):
    cache = {}
    while True:
        if mode not in cache:
            entries = []   # (linha, ("item", id) | ("dec", dict))
            if mode in ("tudo", "wikis"):
                items = j.call("list_knowledge", limit=500, **({"tipo": "artigo"} if mode == "wikis" else {}))
                for i in items if isinstance(items, list) else []:
                    tag = "WIKI" if i.get("tipo") == "artigo" else i.get("tipo", "").upper()
                    entries.append((row(i["sistema"], i["titulo"], tag if mode == "tudo" else ""), ("item", i["id"])))
            if mode in ("tudo", "decisoes"):
                decs = j.call("list_decisions", limit=500)
                for d in decs if isinstance(decs, list) else []:
                    dom = f"{(d.get('created_at') or '')[8:10]}/{(d.get('created_at') or '')[5:7]} · {d.get('grupo_origem') or 'sem grupo'}"
                    entries.append((row(dom, one_line(d.get("texto"), 110), "DECISÃO" if mode == "tudo" else ""), ("dec", d)))
            cache[mode] = entries
        entries = cache[mode]
        code, idx, text = rofi("janus", [e[0] for e in entries], tabs(mode))
        if code is None: return
        if code in (10, 11, 12): mode = MODES[code - 10]; continue
        if 0 <= idx < len(entries):
            kind, ref = entries[idx][1]
            show(*(item_view(j, ref) if kind == "item" else decision_view(ref)))
            return
        query = (text or "").strip()
        if not query: return
        res = j.call("search_knowledge", query=query)    # texto livre → busca
        if not isinstance(res, list) or not res:
            notify(f"Nada encontrado para “{query}”"); return
        lines, views = [], []
        for r in res:
            it = r.get("item", {})
            if r.get("source") == "decision":
                lines.append(row(it.get("grupo_origem") or "decisão", one_line(it.get("texto"), 110), "DECISÃO"))
                views.append(("dec", it))
            else:
                lines.append(row(it.get("sistema", ""), it.get("titulo", ""), "WIKI" if it.get("tipo") == "artigo" else ""))
                views.append(("item", it.get("id")))
        help2 = f"<span font_size='small' foreground='#8A8A84'>{k('↵', 'abrir')}{SEP}resultados para “{esc(query)}”</span>"
        _, idx2, _ = rofi("janus", lines, help2, keys=False)
        if idx2 is not None and 0 <= idx2 < len(views):
            kind, ref = views[idx2]
            show(*(item_view(j, ref) if kind == "item" else decision_view(ref)))
        return


def register(j):
    h = f"<span font_size='small' foreground='#8A8A84'>escreva a decisão ou nota{SEP}{k('↵', 'continuar')}{SEP}{k('esc', 'cancelar')}</span>"
    _, _, texto = rofi("decisão ▸", [], h, keys=False)
    texto = (texto or "").strip()
    if not texto: return
    decs = j.call("list_decisions", limit=500, status="todos")
    grupos = sorted({d.get("grupo_origem") for d in (decs if isinstance(decs, list) else []) if d.get("grupo_origem")})
    h2 = f"<span font_size='small' foreground='#8A8A84'>grupo / projeto{SEP}escolha ou digite um novo{SEP}{k('↵', 'registrar')}</span>"
    code, idx, g = rofi("grupo ▸", [esc(x) for x in grupos], h2, keys=False)
    if code is None: return
    grupo = grupos[idx] if 0 <= idx < len(grupos) else (g or "").strip() or "Geral"
    dec = j.call("record_decision", texto=texto, autor="Elias", grupo=grupo,
                 wpp_message_id=f"desktop-{int(time.time())}", tema=[])
    did = dec.get("id") if isinstance(dec, dict) else None
    notify(f"Decisão registrada{f' #{did}' if did else ''} · {grupo}")


def main():
    if subprocess.run(["pkill", "-x", "rofi"]).returncode == 0: return
    if not os.path.exists(MCP):
        notify(f"Janus não encontrado em {MCP} (defina JANUS_MCP)"); return
    arg = sys.argv[1] if len(sys.argv) > 1 else "tudo"
    try:
        j = Janus()
    except Exception as e:
        notify(f"Não consegui falar com o Janus: {e}"); return
    try:
        if arg == "registrar": register(j)
        else: consult(j, arg if arg in MODES else "tudo")
    except Exception as e:
        notify(f"Erro no Janus: {e}")
    finally:
        j.close()


if __name__ == "__main__":
    main()
