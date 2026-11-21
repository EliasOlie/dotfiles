#!/usr/bin/env python3
"""Busca no Janus pelo rofi.

Fala com o Janus pelo próprio MCP (stdio, mesmo `mcp.sh` que o Claude usa):
  1. abre o rofi com todos os artigos/itens de conhecimento ("domínio · título");
     o rofi filtra enquanto você digita;
  2. digitou algo que não bate com nenhum título + Enter → busca no Janus
     (search_knowledge, inclui decisões) e mostra os resultados;
  3. escolheu um item → abre o conteúdo completo num kitty flutuante (bat, markdown).

Caminho do Janus: $JANUS_MCP (padrão ~/work/janus/scripts/mcp.sh).
"""
import json, os, subprocess, sys, tempfile

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


def rofi(prompt, lines, mesg):
    r = subprocess.run(["rofi", "-dmenu", "-i", "-p", prompt, "-format", "i:s", "-mesg", mesg,
                        "-theme-str", THEME, "-markup-rows"],
                       input="\n".join(lines), capture_output=True, text=True)
    if r.returncode != 0: return None, None
    idx, _, text = r.stdout.rstrip("\n").partition(":")
    return int(idx), text


def esc(s): return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def row(dom, title): return f"<span foreground='#8A8A84'>{esc(dom)}</span>  {esc(title)}"


def show(title, body):
    f = tempfile.NamedTemporaryFile("w", suffix=".md", prefix="janus-", delete=False)
    f.write(f"# {title}\n\n{body}\n"); f.close()
    subprocess.Popen(["kitty", "--class", "janus-view", "--title", "Janus",
                      "sh", "-c", f'bat -l md --style=plain --paging=always "{f.name}"; rm -f "{f.name}"'])


def main():
    if subprocess.run(["pkill", "-x", "rofi"]).returncode == 0: return
    if not os.path.exists(MCP):
        notify(f"Janus não encontrado em {MCP} (defina JANUS_MCP)"); return
    try:
        j = Janus()
        items = j.call("list_knowledge", limit=500)
        if not isinstance(items, list): items = []
    except Exception as e:
        notify(f"Não consegui falar com o Janus: {e}"); return

    help1 = f"<span font_size='small' foreground='#8A8A84'>{k('digite', 'filtra títulos')}{SEP}{k('↵ sem resultado', 'busca no janus')}{SEP}{k('esc', 'sair')}</span>"
    idx, text = rofi("janus", [row(i["sistema"], i["titulo"]) for i in items], help1)
    if idx is None: j.close(); return

    try:
        if 0 <= idx < len(items):                       # escolheu um título da lista
            it = j.call("get_knowledge", id=items[idx]["id"])
            if isinstance(it, list): it = it[0] if it else {}
            it = it.get("item", it) if isinstance(it, dict) else {}
            show(it.get("titulo", ""), f"_{it.get('sistema','')} · {it.get('tipo','')}_\n\n{it.get('descricao','')}\n\n---\n\n{it.get('conteudo','')}")
            return
        query = text.strip()
        if not query: return
        res = j.call("search_knowledge", query=query)    # texto livre → busca
        if not isinstance(res, list) or not res:
            notify(f"Nada encontrado para “{query}”"); return
        lines, bodies = [], []
        for r in res:
            it = r.get("item", {})
            if r.get("source") == "decision":
                dom = it.get("grupo_origem") or "decisão"
                title = it.get("texto", "").replace("\n", " ")[:110]
                body = f"_decisão · {it.get('autor','')} · {it.get('created_at','')[:10]}_\n\n{it.get('texto','')}"
            else:
                dom = it.get("sistema", "")
                title = it.get("titulo", "")
                body = f"_{dom} · {it.get('tipo','')}_\n\n{it.get('descricao','')}\n\n---\n\n{it.get('conteudo','')}"
            lines.append(row(dom, title)); bodies.append((title, body))
        help2 = f"<span font_size='small' foreground='#8A8A84'>{k('↵', 'abrir')}{SEP}resultados para “{esc(query)}”</span>"
        idx2, _ = rofi("janus", lines, help2)
        if idx2 is not None and 0 <= idx2 < len(bodies):
            show(*bodies[idx2])
    except Exception as e:
        notify(f"Erro no Janus: {e}")
    finally:
        j.close()


if __name__ == "__main__":
    main()
