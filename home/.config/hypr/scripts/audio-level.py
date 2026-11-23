#!/usr/bin/env python3
"""Nível de "batida" do que está tocando, para o wallpaper pulsar com a música.

Lê o monitor da saída de áudio padrão com `parec` (sem cava), filtra os graves
e imprime ~30 valores por segundo entre 0 e 1 (com ganho automático).
O Quickshell só roda isto quando há música tocando e o desktop está à mostra.
"""
import array, math, os, signal, subprocess, sys

RATE, CHUNK = 11025, 459              # ~42 ms por leitura (24 por segundo: suficiente pro olho)
sink = subprocess.run(["pactl", "get-default-sink"], capture_output=True, text=True).stdout.strip()
p = subprocess.Popen(["parec", "-d", sink + ".monitor", "--format=s16le", f"--rate={RATE}",
                      "--channels=1", "--latency-msec=30"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)


def bye(*_):
    p.terminate(); sys.exit(0)
signal.signal(signal.SIGTERM, bye)
signal.signal(signal.SIGINT, bye)

alpha = 1 - math.exp(-2 * math.pi * 160 / RATE)   # passa-baixa ~160 Hz (bumbo/baixo)
lp, peak, out = 0.0, 0.02, 0.0
try:
    while True:
        raw = p.stdout.read(CHUNK * 2)
        if not raw: break
        s = array.array("h", raw)
        acc = 0.0
        for v in s:
            lp += alpha * (v / 32768.0 - lp)
            acc += lp * lp
        rms = math.sqrt(acc / len(s))
        peak = max(rms, peak * 0.995, 0.02)            # ganho automático (decai devagar)
        level = min(1.0, rms / peak)
        out = level if level > out else out * 0.82 + level * 0.18   # ataque rápido, queda suave
        sys.stdout.write(f"{out:.3f}\n"); sys.stdout.flush()
except BrokenPipeError:
    pass
finally:
    p.terminate()
