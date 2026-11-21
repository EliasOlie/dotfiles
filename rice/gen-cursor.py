#!/usr/bin/env python3
"""Gera o cursor "Eliasolie-Cursor": Bibata Modern com miolo void e borda lima.

Uso: gen-cursor.py <pasta do Bibata_Cursor clonado> [destino]
  git clone --depth 1 https://github.com/ful1e5/Bibata_Cursor.git /tmp/bibata
  python3 rice/gen-cursor.py /tmp/bibata          # -> ~/.local/share/icons/Eliasolie-Cursor

Não precisa de clickgen/xcursorgen: renderiza os SVGs com GdkPixbuf e escreve
os arquivos XCursor direto (formato simples: cabeçalho + TOC + imagens ARGB).
"""
import glob, os, struct, sys, tomllib

import gi
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf

NAME = "Eliasolie-Cursor"
COLORS = {"#00FF00": "#050505",   # miolo
          "#0000FF": "#C8F031",   # borda (lima)
          "#FF0000": "#050505"}   # detalhe do relógio de espera
SIZES = [24, 32, 48, 64, 96]


def recolor(svg: str) -> bytes:
    s = open(svg, encoding="utf-8").read()
    for a, b in COLORS.items():
        s = s.replace(a, b).replace(a.lower(), b)
    return s.encode()


def render(data: bytes, size: int):
    loader = GdkPixbuf.PixbufLoader.new_with_type("svg")
    loader.set_size(size, size)
    loader.write(data)
    loader.close()
    pb = loader.get_pixbuf()
    w, h, rs, n = pb.get_width(), pb.get_height(), pb.get_rowstride(), pb.get_n_channels()
    px = pb.get_pixels()
    out = bytearray()
    for y in range(h):
        for x in range(w):
            i = y * rs + x * n
            r, g, b = px[i], px[i + 1], px[i + 2]
            a = px[i + 3] if n == 4 else 255
            # XCursor usa ARGB pré-multiplicado, little-endian
            r, g, b = r * a // 255, g * a // 255, b * a // 255
            out += struct.pack("<I", (a << 24) | (r << 16) | (g << 8) | b)
    return w, h, bytes(out)


def write_xcursor(path, frames):
    """frames: lista de (size, w, h, xhot, yhot, delay, pixels)"""
    ntoc = len(frames)
    pos = 16 + ntoc * 12
    toc, chunks = b"", b""
    for size, w, h, xh, yh, delay, pix in frames:
        toc += struct.pack("<III", 0xFFFD0002, size, pos)
        chunk = struct.pack("<IIIIIIIII", 36, 0xFFFD0002, size, 1, w, h, xh, yh, delay) + pix
        chunks += chunk
        pos += len(chunk)
    with open(path, "wb") as f:
        f.write(b"Xcur" + struct.pack("<III", 16, 0x10000, ntoc) + toc + chunks)


def main():
    src = sys.argv[1]
    dest = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser(f"~/.local/share/icons/{NAME}")
    cfg = tomllib.load(open(os.path.join(src, "configs/normal/x.build.toml"), "rb"))["cursors"]
    fb = cfg.pop("fallback_settings")
    svgdir = os.path.join(src, "svg/modern")
    cdir = os.path.join(dest, "cursors")
    os.makedirs(cdir, exist_ok=True)

    for key, c in cfg.items():
        stem = c["png"].replace(".png", "")
        if "*" in stem:   # animado: pasta com quadros nome-01.svg, nome-02.svg...
            files = sorted(glob.glob(os.path.join(svgdir, stem.split("-*")[0], "*.svg")))
        else:
            files = [os.path.join(svgdir, stem + ".svg")]
        files = [f for f in files if os.path.exists(f)]
        if not files:
            print("pulei", key); continue
        xh, yh = c.get("x_hotspot", fb["x_hotspot"]), c.get("y_hotspot", fb["y_hotspot"])
        delay = c.get("x11_delay", fb["x11_delay"]) if len(files) > 1 else 0
        datas = [recolor(f) for f in files]
        frames = []
        for size in SIZES:
            for d in datas:
                w, h, pix = render(d, size)
                frames.append((size, w, h, xh * size // 256, yh * size // 256, delay, pix))
        name = c.get("x11_name", key)
        write_xcursor(os.path.join(cdir, name), frames)
        for link in c.get("x11_symlinks", []):
            lp = os.path.join(cdir, link)
            if os.path.lexists(lp): os.remove(lp)
            os.symlink(name, lp)
        print("ok", name)

    with open(os.path.join(dest, "index.theme"), "w") as f:
        f.write(f"[Icon Theme]\nName={NAME}\nComment=Bibata Modern na paleta eliasolie (borda lima)\nInherits=Bibata-Modern-Classic\n")
    print("pronto:", dest)


if __name__ == "__main__":
    main()
