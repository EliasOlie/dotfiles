#!/usr/bin/env python3
"""Envia um texto (lido do stdin) para o seu WhatsApp ou Telegram.

  echo "texto" | send-to.py whatsapp   → Evolution API (evo.eliasolie.com.br) para EVO_TO
  echo "texto" | send-to.py telegram   → bot do Telegram que o agyh já usa (ponte local)

WhatsApp: ~/.config/eliasolie/evolution.env (privado, fora do git):
    EVO_URL=https://evo.eliasolie.com.br
    EVO_INSTANCE=<nome da instância>
    EVO_APIKEY=<apikey da instância ou global>
    EVO_TO=55<DDD><número>
Telegram: ~/.config/agyh/config.json (bridge.addr e bridge.secret; o agyh bridge
precisa estar rodando). Nada disso é impresso nem vai para a linha de comando.
Saída: código 0 = enviado; o motivo da falha vai para o stderr.
"""
import json, os, sys, urllib.error, urllib.request

ENV = os.path.expanduser("~/.config/eliasolie/evolution.env")
AGYH = os.path.expanduser("~/.config/agyh/config.json")


def post(url, body, headers):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), method="POST",
                                 headers={"Content-Type": "application/json", **headers})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status, r.read().decode(errors="replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace")
    except Exception as e:  # rede fora, ponte parada…
        return 0, str(e)


def load_env():
    env = {}
    try:
        for line in open(ENV, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1); env[k.strip()] = v.strip().strip('"').strip("'")
    except FileNotFoundError:
        pass
    return env


def whatsapp(text):
    e = load_env()
    missing = [k for k in ("EVO_URL", "EVO_INSTANCE", "EVO_APIKEY", "EVO_TO") if not e.get(k)]
    if missing: sys.exit(f"Preencha {ENV}: falta {', '.join(missing)}")
    code, out = post(f"{e['EVO_URL'].rstrip('/')}/message/sendText/{e['EVO_INSTANCE']}",
                     {"number": e["EVO_TO"], "text": text}, {"apikey": e["EVO_APIKEY"]})
    if not 200 <= code < 300: sys.exit(f"Evolution respondeu {code or 'sem conexão'}: {out[:160]}")


def telegram(text):
    try: b = json.load(open(AGYH)).get("bridge", {})
    except Exception: sys.exit("Sem a configuração do agyh (~/.config/agyh/config.json)")
    if not b.get("secret"): sys.exit("A ponte do agyh ainda não tem segredo (rode agyh bridge uma vez)")
    code, out = post(f"http://{b.get('addr', '127.0.0.1:9123')}/v1/notify", {"text": text, "markdown": False},
                     {"Authorization": "Bearer " + b["secret"]})
    if code == 0: sys.exit("A ponte do agyh não está rodando (agyh bridge)")
    if not 200 <= code < 300: sys.exit(f"Ponte do agyh respondeu {code}: {out[:160]}")


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("whatsapp", "telegram"):
        sys.exit("uso: echo texto | send-to.py whatsapp|telegram")
    text = sys.stdin.read().strip()
    if not text: sys.exit("texto vazio")
    (whatsapp if sys.argv[1] == "whatsapp" else telegram)(text)


if __name__ == "__main__":
    main()
