#!/usr/bin/env python3
"""Wallpaper minimalista na paleta eliasolie: fundo void, grade de pontos sutil e um ponto 'signal'."""
import struct, zlib, sys
W, H = (int(x) for x in (sys.argv[2:4] if len(sys.argv) > 3 else (1920, 1080)))
out = sys.argv[1] if len(sys.argv) > 1 else "wallpaper.png"
VOID, DOT, SIGNAL = (5, 5, 5), (34, 34, 31), (200, 240, 49)
STEP = 40
sx, sy = W - 6 * STEP, H - 4 * STEP  # ponto de destaque perto do canto inferior direito
rows = []
for y in range(H):
    row = bytearray(b"\x00")
    for x in range(W):
        c = VOID
        if x % STEP == 0 and y % STEP == 0:
            c = DOT
        if abs(x - sx) <= 3 and abs(y - sy) <= 3:
            c = SIGNAL
        row += bytes(c)
    rows.append(bytes(row))
raw = b"".join(rows)
def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
open(out, "wb").write(png)
