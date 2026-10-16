"""Builds the combat VFX textures.

Outputs (godot/assets/vfx/):
  vfx-atlas.png  2048x2048, 8x8 cells of 256 px. Cells 0-39 come from the CC0
                 Kenney Particle Pack (tools/_sources/kenney-particle-pack),
                 converted to white + alpha and rotated so streaks point +x.
                 Cells 40+ are drawn here: talismans, petals, ice, chains, ink.
  vfx-seals.png  2048x2048, 2x2 cells of 1024 px: 镇魂印 bagua, 缚地咒 seal,
                 燃灯 sun seal, 霜环 frost mandala (white, tinted in engine).
  vfx-noise.png  256x256 tileable fbm noise (erosion / streaks).
Cell indices are mirrored in godot/presentation/vfx_layer.gd (CELL).

Sources (tools/_sources is git-ignored; the built PNGs are committed):
  kenney-particle-pack/  unzip https://kenney.nl/assets/particle-pack (CC0),
                         copy the used PNGs from "PNG (Transparent)" here.
  MaShanZheng-source.ttf https://github.com/googlefonts/mashanzheng (OFL 1.1).
Run: .venv/bin/python tools/make_vfx_textures.py
"""
import math, random
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tools" / "_sources"
KENNEY = SRC / "kenney-particle-pack"
OUT = ROOT / "godot" / "assets" / "vfx"
BRUSH_FONT = SRC / "MaShanZheng-source.ttf"
CELL = 256
rng = random.Random(7)
np_rng = np.random.default_rng(7)

# name, kenney file, rotate degrees (so length lies along +x)
KENNEY_CELLS = [
    ("glow", "circle_05", 0), ("flare", "star_04", 0), ("burst", "star_08", 0), ("star", "star_06", 0),
    ("soft_star", "magic_05", 0), ("streak", "trace_06", 90), ("thin_streak", "trace_01", 90), ("bolt_a", "spark_05", 90),
    ("bolt_b", "spark_06", 90), ("bolt_c", "spark_07", 0), ("crackle_a", "spark_01", 0), ("crackle_b", "spark_02", 0),
    ("crackle_c", "spark_03", 0), ("smoke_a", "smoke_01", 0), ("smoke_b", "smoke_02", 0), ("smoke_c", "smoke_04", 0),
    ("smoke_d", "smoke_05", 0), ("smoke_e", "smoke_07", 0), ("smoke_f", "smoke_08", 0), ("smoke_ring", "smoke_10", 0),
    ("fire_a", "fire_01", 0), ("fire_b", "fire_02", 0), ("flame_wisp", "flame_02", 0), ("flame_tongue", "flame_05", 0),
    ("flame_lick", "flame_06", 0), ("muzzle_a", "muzzle_02", 0), ("muzzle_b", "muzzle_04", 0), ("scorch_a", "scorch_01", 0),
    ("scorch_b", "scorch_03", 0), ("dirt_a", "dirt_01", 0), ("dirt_b", "dirt_03", 0), ("twirl_a", "twirl_01", 0),
    ("twirl_b", "twirl_03", 0), ("ring", "circle_02", 0), ("rays", "light_02", 0), ("claw", "scratch_01", 0),
    ("crescent", "slash_03", 0), ("cross_star", "magic_03", 0),
]


def kenney(name: str, rotate: int) -> Image.Image:
    im = Image.open(KENNEY / f"{name}.png").convert("RGBA")
    r, g, b, a = im.split()
    lum = Image.merge("RGB", (r, g, b)).convert("L")
    alpha = ImageChops.multiply(lum, a)
    white = Image.new("L", im.size, 255)
    im = Image.merge("RGBA", (white, white, white, alpha))
    if rotate:
        im = im.rotate(rotate, resample=Image.BICUBIC)
    im = im.resize((CELL - 8, CELL - 8), Image.LANCZOS)
    cell = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 0))
    cell.paste(im, (4, 4))
    return cell


def canvas(size=CELL, scale=4):
    big = Image.new("RGBA", (size * scale, size * scale), (0, 0, 0, 0))
    return big, ImageDraw.Draw(big), scale


def finish(big: Image.Image, size=CELL) -> Image.Image:
    return big.resize((size, size), Image.LANCZOS)


def font(px: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(BRUSH_FONT), px)


def fbm(n=256, octaves=5, seed=1):
    gen = np.random.default_rng(seed)
    out = np.zeros((n, n))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        f = 4 * 2 ** o
        grid = gen.random((f, f))
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)
        # make tileable by wrapping the small grid
        g2 = np.tile(grid, (3, 3))
        img = Image.fromarray((g2 * 255).astype(np.uint8)).resize((n * 3, n * 3), Image.BICUBIC).crop((n, n, 2 * n, 2 * n))
        out += np.asarray(img, float) / 255 * amp
        total += amp
        amp *= 0.5
    out /= total
    out = (out - out.min()) / (out.max() - out.min())
    return out


# ---------------- procedural cells ----------------

def talisman(glyphs: str, paper=(232, 196, 92), ink=(176, 32, 24)) -> Image.Image:
    big, d, s = canvas()
    w, h = 108 * s, 238 * s
    x0, y0 = (CELL * s - w) // 2, (CELL * s - h) // 2
    # paper with torn-ish edge and fibre noise
    pts = []
    for i in range(24):
        pts.append((x0 + rng.uniform(-2, 2) * s, y0 + h * i / 23))
    for i in range(24):
        pts.append((x0 + w + rng.uniform(-2, 2) * s, y0 + h * (23 - i) / 23))
    d.polygon(pts, fill=paper + (255,))
    noise = fbm(CELL * s // 2, 4, 3)
    tex = Image.fromarray((noise * 70).astype(np.uint8)).resize(big.size)
    shade = Image.new("RGBA", big.size, (120, 70, 10, 0))
    shade.putalpha(ImageChops.multiply(tex, big.split()[3]))
    big = Image.alpha_composite(big, shade)
    d = ImageDraw.Draw(big)
    d.rectangle((x0 + 7 * s, y0 + 7 * s, x0 + w - 7 * s, y0 + h - 7 * s), outline=ink + (255,), width=3 * s)
    d.rectangle((x0 + 12 * s, y0 + 12 * s, x0 + w - 12 * s, y0 + h - 12 * s), outline=ink + (200,), width=1 * s)
    f = font(66 * s)
    y = y0 + 18 * s
    for ch in glyphs:
        bb = d.textbbox((0, 0), ch, font=f)
        d.text((x0 + (w - (bb[2] - bb[0])) / 2 - bb[0], y - bb[1]), ch, font=f, fill=ink + (255,))
        y += (bb[3] - bb[1]) + 8 * s
    # swirl "符" squiggle down the remaining length
    cx = x0 + w / 2
    pts = []
    for i in range(60):
        t = i / 59
        yy = y + t * (y0 + h - 26 * s - y)
        pts.append((cx + math.sin(t * 9.0) * 18 * s * (1 - t * 0.5), yy))
    d.line(pts, fill=ink + (255,), width=5 * s, joint="curve")
    d.ellipse((cx - 10 * s, y0 + h - 30 * s, cx + 10 * s, y0 + h - 10 * s), outline=ink + (255,), width=4 * s)
    return finish(big)


def petal(blossom=False) -> Image.Image:
    big, d, s = canvas()
    c = CELL * s / 2
    def one(angle, length, width):
        pts = []
        for i in range(41):
            t = i / 40
            r = length * t
            wv = width * math.sin(math.pi * t) ** 0.8 * (1 - 0.25 * t)
            pts.append((t, r, wv))
        poly = [(c + math.cos(angle) * r - math.sin(angle) * wv, c + math.sin(angle) * r + math.cos(angle) * wv) for t, r, wv in pts]
        poly += [(c + math.cos(angle) * r + math.sin(angle) * wv, c + math.sin(angle) * r - math.cos(angle) * wv) for t, r, wv in reversed(pts)]
        return poly
    layer = Image.new("RGBA", big.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    if blossom:
        for k in range(5):
            ld.polygon(one(k * 2 * math.pi / 5 - math.pi / 2, 112 * s, 46 * s), fill=(246, 178, 192, 255))
    else:
        ld.polygon(one(-math.pi / 2 + 0.2, 220 * s, 80 * s), fill=(246, 178, 192, 255))
    # gradient: deeper rose toward centre
    yy, xx = np.mgrid[0:big.size[1], 0:big.size[0]]
    dist = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / (CELL * s / 2)
    k = np.clip(1 - dist * 1.6, 0, 1)
    arr = np.asarray(layer).astype(float)
    deep = np.array([206, 74, 104])
    for ch in range(3):
        arr[..., ch] = arr[..., ch] * (1 - k * 0.8) + deep[ch] * k * 0.8
    layer = Image.fromarray(arr.astype(np.uint8))
    ld = ImageDraw.Draw(layer)
    if blossom:
        for k2 in range(5):
            a = k2 * 2 * math.pi / 5 - math.pi / 2
            ld.line((c, c, c + math.cos(a) * 40 * s, c + math.sin(a) * 40 * s), fill=(150, 30, 50, 255), width=3 * s)
        ld.ellipse((c - 14 * s, c - 14 * s, c + 14 * s, c + 14 * s), fill=(240, 196, 90, 255))
    else:
        ld.line((c, c, c + 40 * s, c - 150 * s), fill=(230, 140, 160, 200), width=2 * s)
    return finish(layer)


def paper_scrap(seed, mark=True) -> Image.Image:
    r = random.Random(seed)
    big, d, s = canvas()
    c = CELL * s / 2
    pts = []
    n = 9
    for i in range(n):
        a = i * 2 * math.pi / n + r.uniform(-0.2, 0.2)
        rad = r.uniform(70, 110) * s
        pts.append((c + math.cos(a) * rad * 1.15, c + math.sin(a) * rad * 0.8))
    d.polygon(pts, fill=(240, 228, 198, 255), outline=(150, 120, 80, 255))
    if mark:
        d.line([(c - 50 * s, c - 10 * s), (c + 10 * s, c + 20 * s), (c + 50 * s, c - 25 * s)], fill=(176, 40, 30, 255), width=12 * s)
    return finish(big)


def ice_shard(tall=False) -> Image.Image:
    big, d, s = canvas()
    c = CELL * s / 2
    if tall:
        top, bot, wd = 10 * s, CELL * s - 20 * s, 44 * s
        pts = [(c, top), (c + wd, bot - 70 * s), (c + wd * 0.6, bot), (c - wd * 0.7, bot), (c - wd, bot - 60 * s)]
        d.polygon(pts, fill=(214, 240, 255, 235))
        d.polygon([(c, top), (c + wd, bot - 70 * s), (c + wd * 0.6, bot), (c + 6 * s, bot)], fill=(150, 206, 240, 235))
        d.line([(c, top), (c + 6 * s, bot)], fill=(255, 255, 255, 255), width=3 * s)
    else:
        pts = [(16 * s, c), (c, c - 34 * s), (CELL * s - 10 * s, c - 4 * s), (c + 10 * s, c + 36 * s)]
        d.polygon(pts, fill=(214, 240, 255, 235))
        d.polygon([(16 * s, c), (CELL * s - 10 * s, c - 4 * s), (c + 10 * s, c + 36 * s)], fill=(140, 200, 236, 235))
        d.line([(16 * s, c), (CELL * s - 10 * s, c - 4 * s)], fill=(255, 255, 255, 255), width=3 * s)
    big = Image.alpha_composite(big.filter(ImageFilter.GaussianBlur(10 * s)).point(lambda v: v) if False else big, big)
    return finish(big)


def snowflake() -> Image.Image:
    big, d, s = canvas()
    c = CELL * s / 2
    for k in range(6):
        a = k * math.pi / 3
        ex, ey = c + math.cos(a) * 110 * s, c + math.sin(a) * 110 * s
        d.line((c, c, ex, ey), fill=(255, 255, 255, 255), width=10 * s)
        for t in (0.45, 0.72):
            bx, by = c + math.cos(a) * 110 * s * t, c + math.sin(a) * 110 * s * t
            for side in (-1, 1):
                aa = a + side * 0.75
                d.line((bx, by, bx + math.cos(aa) * 34 * s, by + math.sin(aa) * 34 * s), fill=(255, 255, 255, 255), width=7 * s)
    return finish(big)


def chain_link() -> Image.Image:
    big, d, s = canvas()
    c = CELL * s / 2
    d.rounded_rectangle((20 * s, c - 46 * s, CELL * s - 20 * s, c + 46 * s), radius=46 * s, outline=(255, 255, 255, 255), width=20 * s)
    d.rounded_rectangle((34 * s, c - 34 * s, CELL * s - 34 * s, c - 22 * s), radius=6 * s, fill=(255, 255, 255, 120))
    return finish(big)


def ink_splat(seed, spray=False) -> Image.Image:
    gen = np.random.default_rng(seed)
    n = CELL * 2
    yy, xx = np.mgrid[0:n, 0:n] / n - 0.5
    field = np.zeros((n, n))
    blobs = 3 if spray else 14
    for i in range(blobs):
        cx, cy = gen.normal(0, 0.08, 2)
        r = gen.uniform(0.05, 0.16) if not spray else 0.05
        field += np.exp(-((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * r * r))
    for i in range(40 if spray else 26):
        a = gen.uniform(0, 2 * math.pi)
        dist = gen.uniform(0.12, 0.45)
        r = gen.uniform(0.006, 0.022)
        cx, cy = math.cos(a) * dist, math.sin(a) * dist
        field += 1.4 * np.exp(-((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * r * r))
    noise = fbm(n, 5, seed)
    v = field + (noise - 0.5) * 0.55
    alpha = np.clip((v - 0.55) * 8, 0, 1)
    img = np.zeros((n, n, 4), np.uint8)
    img[..., :3] = 255
    img[..., 3] = (alpha * 255).astype(np.uint8)
    return Image.fromarray(img).resize((CELL, CELL), Image.LANCZOS)


def crack() -> Image.Image:
    big, d, s = canvas()
    c = CELL * s / 2
    r = random.Random(11)
    def branch(x, y, a, length, width, depth):
        steps = int(length / (8 * s))
        for i in range(steps):
            a += r.uniform(-0.35, 0.35)
            nx, ny = x + math.cos(a) * 8 * s, y + math.sin(a) * 8 * s
            w = max(1, int(width * (1 - i / steps)))
            d.line((x, y, nx, ny), fill=(255, 255, 255, 255), width=w)
            x, y = nx, ny
            if depth < 2 and r.random() < 0.08:
                branch(x, y, a + r.choice([-1, 1]) * r.uniform(0.5, 1.0), length * 0.45, width * 0.6, depth + 1)
    for k in range(7):
        branch(c, c, k * 2 * math.pi / 7 + r.uniform(-0.2, 0.2), r.uniform(80, 120) * s, 9 * s, 0)
    d.ellipse((c - 16 * s, c - 12 * s, c + 16 * s, c + 12 * s), fill=(255, 255, 255, 255))
    return finish(big)


def bubble() -> Image.Image:
    big, d, s = canvas()
    c = CELL * s / 2
    d.ellipse((c - 100 * s, c - 100 * s, c + 100 * s, c + 100 * s), outline=(255, 255, 255, 230), width=10 * s)
    d.ellipse((c - 90 * s, c - 90 * s, c + 90 * s, c + 90 * s), fill=(255, 255, 255, 50))
    d.ellipse((c - 60 * s, c - 70 * s, c - 20 * s, c - 40 * s), fill=(255, 255, 255, 220))
    return finish(big)


def brush_stroke() -> Image.Image:
    n = CELL * 2
    gen = np.random.default_rng(5)
    yy, xx = np.mgrid[0:n, 0:n] / n
    # bristle streaks: noise stretched along x
    streak = np.asarray(Image.fromarray((gen.random((n, 24)) * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC), float).T / 255
    streak = np.asarray(Image.fromarray((gen.random((40, n)) * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC), float) / 255
    width = 0.32 * np.sin(np.clip(xx, 0, 1) * math.pi) ** 0.5 * (0.7 + 0.3 * (1 - xx))
    band = np.clip(1 - np.abs(yy - 0.5) / np.maximum(width, 1e-3), 0, 1)
    dry = np.clip((streak - 0.25 - xx * 0.45) * 4, 0, 1)
    alpha = np.clip(band * 3, 0, 1) * dry
    img = np.zeros((n, n, 4), np.uint8)
    img[..., :3] = 255
    img[..., 3] = (alpha * 255).astype(np.uint8)
    return Image.fromarray(img).resize((CELL, CELL), Image.LANCZOS)


def pill() -> Image.Image:
    big, d, s = canvas()
    c = CELL * s / 2
    r = 84 * s
    d.ellipse((c - r, c - r, c + r, c + r), fill=(186, 36, 28, 255))
    d.ellipse((c - r * 0.8, c - r * 0.85, c + r * 0.5, c + r * 0.3), fill=(222, 74, 46, 255))
    d.arc((c - r, c - r * 0.35, c + r, c + r * 0.35), 0, 180, fill=(236, 186, 84, 255), width=12 * s)
    d.ellipse((c - r * 0.55, c - r * 0.6, c - r * 0.15, c - r * 0.3), fill=(255, 236, 200, 230))
    return finish(big)


# ---------------- seals (1024 cells) ----------------
SEAL = 1024


def seal_canvas():
    s = 2
    big = Image.new("RGBA", (SEAL * s, SEAL * s), (255, 255, 255, 0))
    return big, ImageDraw.Draw(big), s, SEAL * s / 2


def ring(d, c, r, w, alpha=255):
    d.ellipse((c - r, c - r, c + r, c + r), outline=(255, 255, 255, alpha), width=int(w))


def glyph_ring(d, c, r, chars, px, alpha=255, offset=0.0):
    f = font(px)
    for i, ch in enumerate(chars):
        a = offset + i * 2 * math.pi / len(chars) - math.pi / 2
        tile = Image.new("RGBA", (px * 2, px * 2), (0, 0, 0, 0))
        td = ImageDraw.Draw(tile)
        bb = td.textbbox((0, 0), ch, font=f)
        td.text((px - (bb[2] + bb[0]) / 2, px - (bb[3] + bb[1]) / 2), ch, font=f, fill=(255, 255, 255, alpha))
        tile = tile.rotate(-math.degrees(a + math.pi / 2), resample=Image.BICUBIC)
        yield tile, (int(c + math.cos(a) * r - px), int(c + math.sin(a) * r - px))


def seal_finish(big):
    a = big.split()[3]
    halo = a.filter(ImageFilter.GaussianBlur(10))
    a2 = ImageChops.lighter(a, halo.point(lambda v: int(v * 0.45)))
    white = Image.new("L", big.size, 255)
    return Image.merge("RGBA", (white, white, white, a2)).resize((SEAL, SEAL), Image.LANCZOS)


def seal_bagua():
    big, d, s, c = seal_canvas()
    R = SEAL * s * 0.47
    ring(d, c, R, 14 * s)
    ring(d, c, R * 0.93, 4 * s)
    for i in range(72):
        a = i * 2 * math.pi / 72
        r0, r1 = R * 0.93, R * (0.885 if i % 3 else 0.86)
        d.line((c + math.cos(a) * r0, c + math.sin(a) * r0, c + math.cos(a) * r1, c + math.sin(a) * r1), fill=(255, 255, 255, 255), width=3 * s)
    # eight trigrams (先天八卦 order, 乾 at top)
    trig = ["111", "011", "101", "001", "110", "010", "100", "000"]
    for i, t in enumerate(trig):
        a = i * 2 * math.pi / 8 - math.pi / 2
        tile = Image.new("RGBA", (260 * s, 160 * s), (0, 0, 0, 0))
        td = ImageDraw.Draw(tile)
        for row, bit in enumerate(t):
            y = 22 * s + row * 44 * s
            if bit == "1":
                td.rectangle((30 * s, y, 230 * s, y + 26 * s), fill=(255, 255, 255, 255))
            else:
                td.rectangle((30 * s, y, 116 * s, y + 26 * s), fill=(255, 255, 255, 255))
                td.rectangle((144 * s, y, 230 * s, y + 26 * s), fill=(255, 255, 255, 255))
        tile = tile.rotate(-math.degrees(a + math.pi / 2), resample=Image.BICUBIC, expand=True)
        r = R * 0.72
        big.alpha_composite(tile, (int(c + math.cos(a) * r - tile.size[0] / 2), int(c + math.sin(a) * r - tile.size[1] / 2)))
    d = ImageDraw.Draw(big)
    ring(d, c, R * 0.56, 6 * s)
    for tile, at in glyph_ring(d, c, R * 0.47, "乾兑离震巽坎艮坤", 64 * s, offset=math.pi / 8):
        big.alpha_composite(tile, at)
    d = ImageDraw.Draw(big)
    ring(d, c, R * 0.37, 8 * s)
    # taiji
    r = R * 0.28
    d.ellipse((c - r, c - r, c + r, c + r), outline=(255, 255, 255, 255), width=6 * s)
    d.pieslice((c - r, c - r, c + r, c + r), 90, 270, fill=(255, 255, 255, 255))
    d.ellipse((c - r / 2, c - r, c + r / 2, c), fill=(255, 255, 255, 255))
    d.ellipse((c - r / 2, c, c + r / 2, c + r), fill=(255, 255, 255, 0))
    big2 = big.copy()
    ImageDraw.Draw(big2).ellipse((c - r / 2, c, c + r / 2, c + r), fill=(255, 255, 255, 0))
    d = ImageDraw.Draw(big2)
    d.pieslice((c - r / 2, c, c + r / 2, c + r), 270, 90, fill=(255, 255, 255, 0))
    d.ellipse((c - r * 0.1, c - r * 0.6, c + r * 0.1, c - r * 0.4), fill=(255, 255, 255, 0))
    d.ellipse((c - r * 0.1, c + r * 0.4, c + r * 0.1, c + r * 0.6), fill=(255, 255, 255, 255))
    return seal_finish(big2)


def seal_bind():
    big, d, s, c = seal_canvas()
    R = SEAL * s * 0.47
    ring(d, c, R, 10 * s)
    # chain ring
    n = 36
    for i in range(n):
        a = i * 2 * math.pi / n
        r = R * 0.9
        x, y = c + math.cos(a) * r, c + math.sin(a) * r
        tile = Image.new("RGBA", (90 * s, 50 * s), (0, 0, 0, 0))
        ImageDraw.Draw(tile).rounded_rectangle((4 * s, 4 * s, 86 * s, 46 * s), radius=22 * s, outline=(255, 255, 255, 255), width=9 * s if i % 2 == 0 else 6 * s)
        tile = tile.rotate(-math.degrees(a + math.pi / 2) + (90 if i % 2 else 0), resample=Image.BICUBIC, expand=True)
        big.alpha_composite(tile, (int(x - tile.size[0] / 2), int(y - tile.size[1] / 2)))
    d = ImageDraw.Draw(big)
    ring(d, c, R * 0.8, 5 * s)
    for k in range(2):
        pts = []
        for i in range(4):
            a = i * math.pi / 2 + k * math.pi / 4 - math.pi / 2
            pts.append((c + math.cos(a) * R * 0.78, c + math.sin(a) * R * 0.78))
        d.polygon(pts, outline=(255, 255, 255, 255), width=7 * s)
    for tile, at in glyph_ring(d, c, R * 0.6, "天地玄黄封镇锁缚", 70 * s):
        big.alpha_composite(tile, at)
    d = ImageDraw.Draw(big)
    ring(d, c, R * 0.44, 6 * s)
    f = font(int(R * 0.62))
    bb = d.textbbox((0, 0), "缚", font=f)
    d.text((c - (bb[2] + bb[0]) / 2, c - (bb[3] + bb[1]) / 2), "缚", font=f, fill=(255, 255, 255, 255))
    return seal_finish(big)


def seal_sun():
    big, d, s, c = seal_canvas()
    R = SEAL * s * 0.47
    for i in range(16):
        a = i * 2 * math.pi / 16
        pts = []
        for j in range(21):
            t = j / 20
            w = 0.16 * math.sin(math.pi * t)
            rr = R * (0.62 + 0.38 * t)
            pts.append((c + math.cos(a + w) * rr, c + math.sin(a + w) * rr))
        for j in range(20, -1, -1):
            t = j / 20
            w = 0.16 * math.sin(math.pi * t)
            rr = R * (0.62 + 0.38 * t ** 1.3)
            pts.append((c + math.cos(a - w * 0.4) * rr, c + math.sin(a - w * 0.4) * rr))
        d.polygon(pts, fill=(255, 255, 255, 80), outline=(255, 255, 255, 255), width=5 * s)
    ring(d, c, R * 0.62, 10 * s)
    ring(d, c, R * 0.55, 3 * s)
    for tile, at in glyph_ring(d, c, R * 0.45, "照夜长明不灭", 66 * s):
        big.alpha_composite(tile, at)
    d = ImageDraw.Draw(big)
    ring(d, c, R * 0.33, 6 * s)
    f = font(int(R * 0.45))
    bb = d.textbbox((0, 0), "燃", font=f)
    d.text((c - (bb[2] + bb[0]) / 2, c - (bb[3] + bb[1]) / 2), "燃", font=f, fill=(255, 255, 255, 255))
    return seal_finish(big)


def seal_frost():
    big, d, s, c = seal_canvas()
    R = SEAL * s * 0.47
    ring(d, c, R, 6 * s)
    ring(d, c, R * 0.95, 2 * s)
    for k in range(12):
        a = k * math.pi / 6
        L = R * (0.92 if k % 2 == 0 else 0.6)
        d.line((c, c, c + math.cos(a) * L, c + math.sin(a) * L), fill=(255, 255, 255, 255), width=(9 if k % 2 == 0 else 5) * s)
        if k % 2 == 0:
            for t in (0.35, 0.55, 0.75):
                bx, by = c + math.cos(a) * L * t, c + math.sin(a) * L * t
                for side in (-1, 1):
                    aa = a + side * 0.7
                    ln = R * 0.16 * (1.1 - t * 0.6)
                    d.line((bx, by, bx + math.cos(aa) * ln, by + math.sin(aa) * ln), fill=(255, 255, 255, 255), width=5 * s)
    for rr, w in ((0.3, 6), (0.62, 4)):
        pts = [(c + math.cos(k * math.pi / 3 + math.pi / 6) * R * rr, c + math.sin(k * math.pi / 3 + math.pi / 6) * R * rr) for k in range(6)]
        d.polygon(pts, outline=(255, 255, 255, 255), width=w * s)
    for i in range(48):
        a = i * 2 * math.pi / 48
        x, y = c + math.cos(a) * R * 0.86, c + math.sin(a) * R * 0.86
        d.ellipse((x - 5 * s, y - 5 * s, x + 5 * s, y + 5 * s), fill=(255, 255, 255, 255))
    return seal_finish(big)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (CELL * 8, CELL * 8), (255, 255, 255, 0))
    names = []
    def put(index, cell, name):
        atlas.alpha_composite(cell, ((index % 8) * CELL, (index // 8) * CELL))
        names.append((index, name))
    for i, (name, src, rot) in enumerate(KENNEY_CELLS):
        put(i, kenney(src, rot), name)
    put(40, talisman("敕令"), "talisman")
    put(41, talisman("镇煞", paper=(214, 188, 120)), "talisman_b")
    put(42, petal(False), "petal")
    put(43, petal(True), "blossom")
    put(44, paper_scrap(1), "paper_a")
    put(45, paper_scrap(2, False), "paper_b")
    put(46, ice_shard(False), "ice_shard")
    put(47, ice_shard(True), "ice_spike")
    put(48, snowflake(), "snowflake")
    put(49, chain_link(), "chain")
    put(50, ink_splat(3), "ink_a")
    put(51, ink_splat(9), "ink_b")
    put(52, ink_splat(21, True), "ink_spray")
    put(53, crack(), "crack")
    put(54, bubble(), "bubble")
    put(55, brush_stroke(), "brush")
    put(56, pill(), "pill")
    atlas.save(OUT / "vfx-atlas.png", optimize=True)
    seals = Image.new("RGBA", (SEAL * 2, SEAL * 2), (255, 255, 255, 0))
    for i, fn in enumerate([seal_bagua, seal_bind, seal_sun, seal_frost]):
        seals.alpha_composite(fn(), ((i % 2) * SEAL, (i // 2) * SEAL))
    seals.save(OUT / "vfx-seals.png", optimize=True)
    noise = fbm(256, 5, 42)
    Image.fromarray((noise * 255).astype(np.uint8)).save(OUT / "vfx-noise.png")
    for index, name in names:
        print(index, name)


if __name__ == "__main__":
    main()
