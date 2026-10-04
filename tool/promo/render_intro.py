"""Video perkenalan MyQuran (YouTube + listing Play): ~56 detik, 1920x1080, 60 fps.

Semua layar aplikasi berasal dari golden test asli (test/golden/goldens/). Animasi:
HP berputar 3D (perspektif), zoom ke bagian penting dengan penanda, teks muncul per
kata, transisi sapuan dengan blur gerak, dan karosel 3D. Penanda (cincin emas + garis)
adalah anotasi, bukan UI aplikasi.

Suara: nasyid dari berkas yang diberikan pemilik (--nasyid) + efek suara buatan sendiri
(whoosh, swish, ketuk, pop). Tanpa --nasyid hanya efek suara.

Pakai (dari root repo):
    tool/promo/.venv/Scripts/python.exe tool/promo/render_intro.py --nasyid <berkas.m4a>
    tool/promo/.venv/Scripts/python.exe tool/promo/render_intro.py --preview 3,12.5,20
"""
import argparse
import json
import math
import os
import re
import subprocess
import sys
import wave
from functools import lru_cache

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render as base  # noqa: E402
from render import (  # noqa: E402
    BG, DEVICE, DEVICE_EDGE, FFMPEG, FONT_SANS, FONT_SERIF, GOLD, GOLD_BUTTON, GOLDEN, HERO_A,
    ON_GOLD_BUTTON, ON_HERO, OUT, PRIMARY, PRIMARY_TEXT, ROOT, SEC, clamp, ease_in_out, ease_out, font,
    lerp, paste, prog, rounded_mask, text_block, with_alpha, wrap,
)

W, H, FPS = 1920, 1080, 60
SR = 48000
GOLD_LINE = (0xE2, 0xC3, 0x6A)
TRANS = 0.22  # setengah durasi transisi antar adegan

GOLDENS = {
    "beranda": "19_beranda_baru_light.png",
    "beranda_gelap": "19_beranda_baru_dark.png",
    "murottal": "20_murottal_teks_light.png",
    "kartu": "05_kartu_light.png",
    "belajar": "08_belajar_light.png",
    "sesi": "19_sesi_tirukan_light.png",
    "hafalan": "10_hafalan_light.png",
    "salat": "22_waktu_salat_light.png",
    "qari": "23_qari_light.png",
}


def spring(x):
    """Ease-out dengan sedikit lewat (back), untuk kesan 'pop' yang lembut."""
    c1 = 1.70158
    return 1 + (c1 + 1) * (x - 1) ** 3 + c1 * (x - 1) ** 2


# ------------------------------------------------------------------ latar
def pattern_tile(color, alpha, size=160):
    """Bintang delapan sudut bergaris tipis (ornamen geometris), satu ubin."""
    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    c, r = size / 2, size * 0.34
    rr = r * math.sqrt(2)
    d.polygon([(c - r, c - r), (c + r, c - r), (c + r, c + r), (c - r, c + r)], outline=color + (alpha,), width=2)
    d.polygon([(c, c - rr), (c + rr, c), (c, c + rr), (c - rr, c)], outline=color + (alpha,), width=2)
    d.ellipse((c - 6, c - 6, c + 6, c + 6), outline=color + (alpha,), width=2)
    return tile


def tiled(tile):
    big = Image.new("RGBA", (W + tile.width * 2, H + tile.height * 2), (0, 0, 0, 0))
    for y in range(0, big.height, tile.height):
        for x in range(0, big.width, tile.width):
            big.alpha_composite(tile, (x, y))
    return big


class Backdrop:
    def __init__(self):
        self.light = base.radial_bg(BG, (0xFB, 0xF7, 0xEC), (W * 0.7, H * 0.4), W * 0.8)
        self.dark = base.hero_bg()
        self.pat_light = tiled(pattern_tile(PRIMARY, 13))
        self.pat_dark = tiled(pattern_tile(GOLD_LINE, 26))
        glow = Image.new("RGBA", (900, 900), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse((150, 150, 750, 750), fill=GOLD_LINE + (46,))
        self.glow = glow.filter(ImageFilter.GaussianBlur(120))

    def draw(self, t, dark):
        img = (self.dark if dark else self.light).copy()
        pat = self.pat_dark if dark else self.pat_light
        ox, oy = int(t * 14) % 160, int(t * 7) % 160
        img.alpha_composite(pat.crop((ox, oy, ox + W, oy + H)))
        if dark:
            gx = W * 0.5 + math.cos(t * 0.35) * 360 - 450
            gy = H * 0.42 + math.sin(t * 0.5) * 120 - 450
            paste(img, self.glow, gx, gy)
        return img


# ------------------------------------------------------------------ HP 3D
def persp_coeffs(dst, src):
    a, b = [], []
    for (x, y), (u, v) in zip(dst, src):
        a.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        b.append(u)
        a.append([0, 0, 0, x, y, 1, -v * x, -v * y])
        b.append(v)
    return np.linalg.solve(np.array(a, float), np.array(b, float)).tolist()


def rotate_y(img, deg, focal=2.4):
    """Putar gambar pada sumbu tegak dengan perspektif. deg > 0: tepi kanan menjauh."""
    w, h = img.size
    th = math.radians(deg)
    f = focal * h
    pts = []
    for x, y in ((0, 0), (w, 0), (w, h), (0, h)):
        dx, dy = x - w / 2, y - h / 2
        k = f / (f + dx * math.sin(th))
        pts.append((dx * math.cos(th) * k, dy * k))
    minx, miny = min(p[0] for p in pts), min(p[1] for p in pts)
    ow = max(2, math.ceil(max(p[0] for p in pts) - minx))
    oh = max(2, math.ceil(max(p[1] for p in pts) - miny))
    dst = [(px - minx, py - miny) for px, py in pts]
    return img.transform((ow, oh), Image.PERSPECTIVE, persp_coeffs(dst, [(0, 0), (w, 0), (w, h), (0, h)]),
                         Image.BICUBIC)


@lru_cache(maxsize=64)
def shadow_img(w, h):
    w, h = max(16, w // 8 * 8), max(16, h // 8 * 8)
    s = Image.new("RGBA", (w // 4 + 60, h // 4 + 60), (0, 0, 0, 0))
    ImageDraw.Draw(s).rounded_rectangle((30, 30, 30 + w // 4, 30 + h // 4), max(4, h // 60), fill=(6, 24, 18, 105))
    return s.filter(ImageFilter.GaussianBlur(9)).resize((w + 240, h + 240), Image.BICUBIC)


class Phone:
    """Frame HP polos tanpa merek, resolusi asli golden (1170x2532) supaya tajam saat zoom."""

    def __init__(self, name):
        self.name = name
        self.sw, self.sh = 1170, 2532
        self.bezel = 44
        self.bw, self.bh = self.sw + 2 * self.bezel, self.sh + 2 * self.bezel
        r_out = round(self.bh * 0.07)
        body = Image.new("RGBA", (self.bw, self.bh), (0, 0, 0, 0))
        d = ImageDraw.Draw(body)
        d.rounded_rectangle((0, 0, self.bw - 1, self.bh - 1), r_out, fill=DEVICE + (255,))
        d.rounded_rectangle((3, 3, self.bw - 4, self.bh - 4), r_out - 3, outline=DEVICE_EDGE + (255,), width=6)
        shot = Image.open(os.path.join(GOLDEN, GOLDENS[name])).convert("RGBA")
        body.paste(shot, (self.bezel, self.bezel), rounded_mask((self.sw, self.sh), r_out - self.bezel))
        self.full = body
        self.mid = body.resize((round(self.bw * 1200 / self.bh), 1200), Image.LANCZOS)

    def render(self, height, rot_y=0.0, rot_z=0.0):
        src = self.mid if height <= 1200 else self.full
        s = height / self.bh
        img = src.resize((max(2, round(self.bw * s)), max(2, round(height))), Image.BICUBIC, reducing_gap=2.0)
        if abs(rot_y) > 0.2:
            img = rotate_y(img, rot_y)
        if abs(rot_z) > 0.1:
            img = img.rotate(rot_z, resample=Image.BICUBIC, expand=True)
        return img

    def draw(self, canvas, cx, cy, height, rot_y=0.0, rot_z=0.0, a=1.0):
        if a <= 0.003:
            return
        img = self.render(height, rot_y, rot_z)
        sh = shadow_img(int(img.width * 0.94), int(img.height * 0.96))
        paste(canvas, sh, cx - sh.width / 2, cy - sh.height / 2 + height * 0.035, a * 0.85)
        paste(canvas, img, cx - img.width / 2, cy - img.height / 2, a)

    def rect(self, cx, cy, height, u0, v0, u1, v1):
        """Kotak area layar (koordinat 0..1) di kanvas, untuk HP tanpa rotasi."""
        s = height / self.bh
        left = cx - self.bw * s / 2 + self.bezel * s
        top = cy - self.bh * s / 2 + self.bezel * s
        return (left + u0 * self.sw * s, top + v0 * self.sh * s, left + u1 * self.sw * s, top + v1 * self.sh * s)

    def center_for(self, height, u, v, sx, sy):
        """Pusat HP supaya titik layar (u, v) jatuh di titik kanvas (sx, sy)."""
        s = height / self.bh
        return (sx - (self.bezel + u * self.sw - self.bw / 2) * s,
                sy - (self.bezel + v * self.sh - self.bh / 2) * s)


# ------------------------------------------------------------------ teks
class Kinetic:
    """Teks yang muncul per kata dengan pegas lembut."""

    def __init__(self, text, fnt, color, max_w, line_h, align="center"):
        lines = wrap(text, fnt, max_w)
        space = fnt.getlength(" ")
        self.words = []
        self.w = max_w
        self.h = line_h * len(lines)
        for li, ln in enumerate(lines):
            x = (max_w - fnt.getlength(ln)) / 2 if align == "center" else 0
            for word in ln.split():
                ww = fnt.getlength(word)
                img = Image.new("RGBA", (int(ww) + 8, int(line_h * 1.25)), (0, 0, 0, 0))
                ImageDraw.Draw(img).text((4, 0), word, font=fnt, fill=color)
                self.words.append((img, x - 4, li * line_h))
                x += ww + space

    def draw(self, canvas, x0, y0, t, start, stagger=0.08, dur=0.5, out=1.0):
        for i, (img, x, y) in enumerate(self.words):
            p = prog(t, start + i * stagger, start + i * stagger + dur)
            if p <= 0:
                continue
            sc = lerp(0.6, 1.0, spring(p))
            im = img if abs(sc - 1) <= 0.01 else img.resize(
                (max(1, round(img.width * sc)), max(1, round(img.height * sc))), Image.BICUBIC)
            cx, cy = x0 + x + img.width / 2, y0 + y + img.height / 2 + (1 - ease_out(p)) * 22
            paste(canvas, im, cx - im.width / 2, cy - im.height / 2, clamp(p * 2.2) * out)

    def times(self, start, stagger=0.08):
        return [start + i * stagger for i in range(len(self.words))]


def pill(text, size, ink, fill, height):
    label = text_block(text, font(FONT_SANS, size, 700), ink, 1400, round(size * 1.35), align="center")
    img = Image.new("RGBA", (label.width + 2 * round(height * 0.55), height), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle((0, 0, img.width - 1, height - 1), height // 2, fill=fill + (255,))
    img.alpha_composite(label, ((img.width - label.width) // 2, round((height - size * 1.35) / 2)))
    return img


class Panel:
    """Eyebrow + judul + anak judul di kolom kiri."""

    def __init__(self, eyebrow, title, sub, col=760):
        self.items = [
            (Image.new("RGBA", (72, 6), GOLD + (255,)), 0.0, 24),
            (text_block(eyebrow, font(FONT_SANS, 27, 800), PRIMARY_TEXT, col, 38, tracking=5), 0.0, 22),
            (text_block(title, font(FONT_SERIF, 80, 500), PRIMARY, col, 88), 0.1, 26),
            (text_block(sub, font(FONT_SANS, 36, 500), SEC, col - 40, 52), 0.22, 0),
        ]
        self.h = sum(img.height + gap for img, _, gap in self.items)

    def draw(self, canvas, t, start, end, x0=130, cy=540):
        y = cy - self.h / 2
        out = 1 - ease_in_out(prog(t, end - 0.35, end))
        for img, delay, gap in self.items:
            p = ease_out(prog(t, start + delay, start + delay + 0.7))
            paste(canvas, img, x0 - (1 - p) * 60, y + (1 - p) * 26, p * out)
            y += img.height + gap


class Callout:
    """Penanda: cincin emas di layar HP + garis penghubung + label di kolom kiri."""

    def __init__(self, label, sub, region):
        self.label = text_block(label, font(FONT_SERIF, 66, 500), PRIMARY, 640, 74)
        self.sub = text_block(sub, font(FONT_SANS, 34, 500), SEC, 600, 48)
        self.region = region

    def draw(self, canvas, t, start, end, rect, x0=130, cy=540):
        p = ease_out(prog(t, start, start + 0.55))
        out = 1 - ease_in_out(prog(t, end - 0.3, end))
        if p <= 0 or out <= 0:
            return
        y = cy - (self.label.height + 16 + self.sub.height) / 2
        paste(canvas, self.label, x0 - (1 - p) * 50, y, p * out)
        q = ease_out(prog(t, start + 0.12, start + 0.7))
        paste(canvas, self.sub, x0 - (1 - q) * 50, y + self.label.height + 16, q * out)

        pad = 16
        x1, y1, x2, y2 = rect[0] - pad, rect[1] - pad, rect[2] + pad, rect[3] + pad
        grow = lerp(1.06, 1.0, spring(p))
        cxr, cyr = (x1 + x2) / 2, (y1 + y2) / 2
        hw, hh = (x2 - x1) / 2 * grow, (y2 - y1) / 2 * grow
        ring = Image.new("RGBA", (int(hw * 2) + 40, int(hh * 2) + 40), (0, 0, 0, 0))
        ImageDraw.Draw(ring).rounded_rectangle((20, 20, 20 + hw * 2, 20 + hh * 2), 30, outline=GOLD + (90,), width=14)
        ring = ring.filter(ImageFilter.GaussianBlur(6))
        ImageDraw.Draw(ring).rounded_rectangle((20, 20, 20 + hw * 2, 20 + hh * 2), 30, outline=GOLD + (255,), width=6)
        paste(canvas, ring, cxr - hw - 20, cyr - hh - 20, p * out)

        r = ease_in_out(prog(t, start + 0.2, start + 0.75))
        if r > 0:
            lx = min(x0 + max(self.label.width, self.sub.width) + 30, cxr - hw - 60)
            ly, ex, ey = cy, cxr - hw - 6, cyr
            mx, my = lerp(lx, ex, r), lerp(ly, ey, r)
            box = (int(min(lx, ex)) - 12, int(min(ly, ey)) - 12, int(max(lx, ex)) + 12, int(max(ly, ey)) + 12)
            layer = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), (0, 0, 0, 0))
            ld = ImageDraw.Draw(layer)
            o = (box[0], box[1])
            ld.line((lx - o[0], ly - o[1], mx - o[0], my - o[1]), fill=GOLD + (255,), width=4)
            ld.ellipse((lx - o[0] - 8, ly - o[1] - 8, lx - o[0] + 8, ly - o[1] + 8), fill=GOLD + (255,))
            if r >= 1:
                ld.ellipse((ex - o[0] - 8, ey - o[1] - 8, ex - o[0] + 8, ey - o[1] + 8), fill=GOLD + (255,))
            paste(canvas, layer, o[0], o[1], out)


# ------------------------------------------------------------------ adegan
class Scene:
    dark = False

    def __init__(self, start, end):
        self.start, self.end = start, end
        self.sfx = []  # (detik, jenis)


class Intro(Scene):
    dark = True

    def __init__(self, start, end):
        super().__init__(start, end)
        logo = Image.open(os.path.join(ROOT, "assets", "brand", "logo_utama_gelap.png")).convert("RGBA")
        self.logo = logo.resize((round(logo.width * 380 / logo.height), 380), Image.LANCZOS)
        self.kin = Kinetic("Al-Qur'an, setiap hari.", font(FONT_SERIF, 96, 500), ON_HERO, 1400, 110)
        self.tag = text_block("BACA  ·  BELAJAR  ·  HAFAL", font(FONT_SANS, 30, 800), GOLD_LINE, 1000, 40,
                              tracking=7, align="center")
        band = Image.new("L", (240, 900), 0)
        ImageDraw.Draw(band).rectangle((80, 0, 160, 900), fill=150)
        self.band = band.filter(ImageFilter.GaussianBlur(40)).rotate(18, expand=True)
        self.sfx = [(start + 0.1, "swish")] + [(x, "pop") for x in self.kin.times(start + 1.25, 0.12)]

    def draw(self, canvas, t):
        lt = t - self.start
        p = prog(lt, 0.1, 1.0)
        sc = lerp(0.72, 1.0, spring(p))
        logo = self.logo.resize((round(self.logo.width * sc), round(self.logo.height * sc)), Image.BICUBIC)
        s = prog(lt, 1.0, 1.9)
        if 0 < s < 1:
            # Kilau yang menyapu, hanya di bagian logo yang tidak transparan. Warna logo tidak diubah.
            shine = Image.new("L", logo.size, 0)
            shine.paste(self.band, (int(lerp(-self.band.width, logo.width, s)), -100))
            a = np.asarray(shine, np.float32) * np.asarray(logo.getchannel("A"), np.float32) / 255 * 0.55
            glint = Image.new("RGBA", logo.size, (255, 248, 225, 0))
            glint.putalpha(Image.fromarray(a.astype(np.uint8)))
            logo = logo.copy()
            logo.alpha_composite(glint)
        paste(canvas, logo, (W - logo.width) / 2, 320 - logo.height / 2, clamp(p * 1.6))
        self.kin.draw(canvas, (W - self.kin.w) / 2, 560, lt, 1.25, stagger=0.12)
        q = ease_out(prog(lt, 2.3, 3.0))
        paste(canvas, self.tag, (W - self.tag.width) / 2, 720 + (1 - q) * 20, q)


class Hook(Scene):
    def __init__(self, start, end):
        super().__init__(start, end)
        f = font(FONT_SERIF, 84, 500)
        self.l1 = Kinetic("Mau rutin dekat dengan Al-Qur'an,", f, PRIMARY, 1600, 96)
        self.l2 = Kinetic("tapi bingung mulai dari mana?", f, HERO_A, 1600, 96)
        self.pill = pill("MyQuran menunjukkan langkah berikutnya.", 40, ON_HERO, HERO_A, 100)
        self.sfx = ([(x, "pop") for x in self.l1.times(start + 0.25)] +
                    [(x, "pop") for x in self.l2.times(start + 1.1)] + [(start + 2.7, "tick")])

    def draw(self, canvas, t):
        lt = t - self.start
        self.l1.draw(canvas, (W - self.l1.w) / 2, 300, lt, 0.25)
        self.l2.draw(canvas, (W - self.l2.w) / 2, 410, lt, 1.1)
        u = ease_in_out(prog(lt, 1.9, 2.5))
        if u > 0:
            paste(canvas, Image.new("RGBA", (max(1, int(760 * u)), 7), GOLD + (255,)), W / 2 - 380, 530)
        p = prog(lt, 2.7, 3.3)
        if p > 0:
            sc = lerp(0.7, 1.0, spring(p))
            im = self.pill.resize((round(self.pill.width * sc), round(self.pill.height * sc)), Image.BICUBIC)
            paste(canvas, im, (W - im.width) / 2, 660 + (self.pill.height - im.height) / 2, clamp(p * 2))


class Feature(Scene):
    """Satu HP + panel judul + penanda zoom berurutan.

    callouts: [(Callout, mulai, selesai, tinggi_zoom, x_fokus, y_fokus)] dalam detik lokal.
    """

    def __init__(self, start, end, phone, panel, callouts, enter="kanan", home=(1400, 540, 900, 12)):
        super().__init__(start, end)
        self.phone, self.panel, self.callouts, self.enter, self.home = phone, panel, callouts, enter, home
        self.sfx = [(start + 0.05, "swish")] + [(start + c[1], "tick") for c in callouts]

    def state(self, lt):
        hx, hy, hh, hr = self.home
        st = (hx, hy, hh, hr)
        for co, s, e, zh, sx, sy in self.callouts:
            u0, v0, u1, v1 = co.region
            tgt = self.phone.center_for(zh, (u0 + u1) / 2, (v0 + v1) / 2, sx, sy) + (zh, 0.0)
            z = ease_in_out(prog(lt, s - 0.55, s))
            st = tuple(lerp(a, b, z) for a, b in zip(st, tgt))
        return st

    def draw(self, canvas, t):
        lt = t - self.start
        first = self.callouts[0][1] if self.callouts else self.end - self.start
        self.panel.draw(canvas, lt, 0.25, first - 0.45)
        cx, cy, hh, ry = self.state(lt)
        p = prog(lt, 0.0, 1.0)
        rz = 0.0
        if self.enter == "kanan":
            cx += (1 - ease_out(p)) * 900
            ry = lerp(55, ry, spring(p))
        elif self.enter == "bawah":
            cy += (1 - ease_out(p)) * 900
            rz = lerp(-12, 0, spring(p))
        else:  # "putar": berputar masuk dari tepi
            ry = lerp(88, ry, ease_out(p))
        fy = math.sin(2 * math.pi * t / 4.0) * 6 * (1 - prog(lt, first - 0.6, first))
        self.phone.draw(canvas, cx, cy + fy, hh, ry, rz, clamp(p * 3))
        for co, s, e, zh, sx, sy in self.callouts:
            if s <= lt <= e:
                co.draw(canvas, lt, s, e, self.phone.rect(cx, cy + fy, hh, *co.region))


class Pair(Scene):
    """Dua HP berkipas (Belajar di belakang, Sesi di depan) + panel + satu penanda."""

    def __init__(self, start, end, back, front, panel, callout):
        super().__init__(start, end)
        self.back, self.front, self.panel, self.callout = back, front, panel, callout
        self.sfx = [(start + 0.05, "swish"), (start + 0.35, "swish"), (start + callout[1], "tick")]

    def draw(self, canvas, t):
        lt = t - self.start
        co, s, e = self.callout
        self.panel.draw(canvas, lt, 0.25, s - 0.45)
        pb = ease_out(prog(lt, 0.0, 1.0))
        pf = prog(lt, 0.3, 1.3)
        settle = ease_in_out(prog(lt, s - 0.6, s))
        bx = lerp(lerp(W + 500, 1230, pb), 1150, settle)
        self.back.draw(canvas, bx, 560, lerp(820, 780, settle), lerp(22, 16, settle), lerp(-6, -3, settle),
                       clamp(pb * 2) * lerp(1, 0.5, settle))
        fx = lerp(lerp(W + 400, 1560, ease_out(pf)), 1500, settle)
        fh = lerp(880, 960, settle)
        ry = lerp(-40, -10, spring(pf)) * (1 - settle)
        self.front.draw(canvas, fx, 545, fh, ry, 0.0, clamp(pf * 3))
        if s <= lt <= e:
            co.draw(canvas, lt, s, e, self.front.rect(fx, 545, fh, *co.region))


class Carousel(Scene):
    """Karosel 3D: Waktu salat, Pilih qari, Beranda gelap bergiliran ke depan."""

    def __init__(self, start, end, phones, panel, captions):
        super().__init__(start, end)
        self.phones, self.panel, self.captions = phones, panel, captions
        self.sfx = [(start + 0.05, "swish"), (start + 2.2, "whoosh_kecil"), (start + 4.2, "whoosh_kecil")]

    def draw(self, canvas, t):
        lt = t - self.start
        self.panel.draw(canvas, lt, 0.25, self.end - self.start + 1)
        enter = ease_out(prog(lt, 0.0, 1.1))
        step = ease_in_out(prog(lt, 2.0, 2.7)) + ease_in_out(prog(lt, 4.0, 4.7))
        rot = -step * 2 * math.pi / 3
        cx, cy, radius = 1400, 520, 320
        items = []
        for i, ph in enumerate(self.phones):
            ang = i * 2 * math.pi / 3 + rot
            z = math.cos(ang)
            items.append((z, ph, cx + math.sin(ang) * radius + (1 - enter) * 800, lerp(540, 860, (z + 1) / 2),
                          -math.degrees(math.sin(ang)) * 0.55, lerp(0.35, 1.0, (z + 1) / 2) * enter))
        for z, ph, x, hgt, ry, a in sorted(items, key=lambda it: it[0]):
            ph.draw(canvas, x, cy, hgt, ry, 0.0, a)
        idx = int(round(step)) % 3
        cap = self.captions[idx]
        q = ease_out(prog(lt, [0.6, 2.6, 4.6][idx], [1.1, 3.1, 5.1][idx]))
        paste(canvas, cap, cx - cap.width / 2, 985 + (1 - q) * 14, q)


class Outro(Scene):
    dark = True

    def __init__(self, start, end):
        super().__init__(start, end)
        logo = Image.open(os.path.join(ROOT, "assets", "brand", "logo_utama_gelap.png")).convert("RGBA")
        self.logo = logo.resize((round(logo.width * 300 / logo.height), 300), Image.LANCZOS)
        self.kin = Kinetic("Gratis. Tanpa iklan. Tanpa pelacakan.", font(FONT_SERIF, 84, 500), ON_HERO, 1700, 96)
        self.pill = pill("Cari MyQuran di Google Play", 40, ON_GOLD_BUTTON, GOLD_BUTTON, 104)
        self.small = text_block("Untuk Android 7.0 ke atas", font(FONT_SANS, 28, 500), (0xD9, 0xE2, 0xDA), 800, 38,
                                align="center")
        self.sfx = ([(start + 0.1, "swish")] + [(x, "pop") for x in self.kin.times(start + 0.8, 0.09)] +
                    [(start + 2.2, "tick")])

    def draw(self, canvas, t):
        lt = t - self.start
        p = prog(lt, 0.0, 0.9)
        sc = lerp(0.75, 1.0, spring(p))
        logo = self.logo.resize((round(self.logo.width * sc), round(self.logo.height * sc)), Image.BICUBIC)
        paste(canvas, logo, (W - logo.width) / 2, 250 - logo.height / 2, clamp(p * 1.6))
        self.kin.draw(canvas, (W - self.kin.w) / 2, 470, lt, 0.8, stagger=0.09)
        q = prog(lt, 2.2, 2.8)
        if q > 0:
            sc = lerp(0.7, 1.0, spring(q))
            im = self.pill.resize((round(self.pill.width * sc), round(self.pill.height * sc)), Image.BICUBIC)
            paste(canvas, im, (W - im.width) / 2, 640 + (self.pill.height - im.height) / 2, clamp(q * 2))
        paste(canvas, self.small, (W - self.small.width) / 2, 790, ease_out(prog(lt, 2.8, 3.4)))


def build():
    def caption(text):
        return text_block(text, font(FONT_SANS, 30, 700), PRIMARY_TEXT, 900, 40, align="center")

    ph = {n: Phone(n) for n in GOLDENS}
    return [
        Intro(0.0, 5.0),
        Hook(5.0, 9.5),
        Feature(9.5, 16.5, ph["beranda"],
                Panel("BERANDA", "Satu langkah untuk hari ini",
                      "Buka aplikasi, langsung tahu harus mulai dari mana."),
                [(Callout("Salat berikutnya", "Lengkap dengan hitung mundurnya.", (0.04, 0.215, 0.96, 0.355)),
                  2.6, 4.6, 1500, 1350, 520),
                 (Callout("Langkah berikutnya", "Sesi, murajaah, atau lanjut membaca. Dipilih otomatis.",
                          (0.04, 0.375, 0.96, 0.79)), 4.9, 7.0, 1400, 1350, 560)],
                enter="kanan"),
        Feature(16.5, 23.5, ph["murottal"],
                Panel("MUROTTAL", "Dengar sambil mengikuti ayatnya",
                      "Ayat yang dibaca qari tampil, tersorot, dan ikut bergulir."),
                [(Callout("Ayat yang sedang dibaca", "Arab dan terjemahannya langsung terlihat.",
                          (0.04, 0.355, 0.96, 0.595)), 2.6, 4.6, 1500, 1350, 540),
                 (Callout("Ulang ayat atau rentang", "1×, 3×, 5×, 7×, atau terus untuk murajaah.",
                          (0.04, 0.72, 0.96, 0.965)), 4.9, 7.0, 1350, 1350, 600)],
                enter="bawah"),
        Feature(23.5, 29.5, ph["kartu"],
                Panel("MEMBACA", "Tajwid berwarna di setiap huruf",
                      "Teks Uthmani dari Tanzil dan terjemahan Indonesia, tanpa internet."),
                [(Callout("Ketuk huruf berwarna", "Nama hukum tajwidnya langsung muncul.",
                          (0.04, 0.50, 0.96, 0.88)), 2.8, 6.0, 1350, 1350, 520)],
                enter="putar"),
        Pair(29.5, 36.0, ph["belajar"], ph["sesi"],
             Panel("SESI HARI INI", "Sepuluh menit, satu kebiasaan",
                   "Ulang, materi baru, temukan di ayat, lalu tirukan qari."),
             (Callout("Lima langkah singkat", "Rekaman suaramu hanya tersimpan di HP.",
                      (0.03, 0.13, 0.97, 0.20)), 3.0, 6.5)),
        Feature(36.0, 42.0, ph["hafalan"],
                Panel("HAFALAN", "Hafalan dan murajaah terjadwal",
                      "Ziyadah, murajaah, dan tasmi' dalam satu tempat."),
                [(Callout("Ziyadah · Murajaah · Tasmi'", "Ayat yang jatuh tempo muncul otomatis.",
                          (0.03, 0.16, 0.97, 0.29)), 2.8, 6.0, 1450, 1350, 470)],
                enter="kanan"),
        Carousel(42.0, 49.0, [ph["salat"], ph["qari"], ph["beranda_gelap"]],
                 Panel("SESUAI KEBUTUHANMU", "Salat, qari, dan tampilan pilihanmu",
                       "Lokasi otomatis atau kota pilihan. Qari dari sumber berizin. Mode gelap untuk malam."),
                 [caption("Waktu salat: otomatis atau pilih kota"), caption("Pilih qari dan dengar contohnya"),
                  caption("Mode gelap yang nyaman di malam hari")]),
        Outro(49.0, 56.0),
    ]


# ------------------------------------------------------------------ transisi
def motion_blur(img, k):
    if k < 2:
        return img
    arr = np.asarray(img.convert("RGB"), np.float32)
    c = np.cumsum(np.pad(arr, ((0, 0), (k, 0), (0, 0)), mode="edge"), axis=1)
    return Image.fromarray(np.clip((c[:, k:] - c[:, :-k]) / k, 0, 255).astype(np.uint8), "RGB")


def zoom_crop(img, s):
    w, h = round(W * s), round(H * s)
    big = img.resize((w, h), Image.BILINEAR)
    x, y = (w - W) // 2, (h - H) // 2
    return big.crop((x, y, x + W, y + H))


class Film:
    def __init__(self, scenes):
        self.scenes = scenes
        self.backdrop = Backdrop()
        self.dur = scenes[-1].end

    def scene_frame(self, sc, t):
        canvas = self.backdrop.draw(t, sc.dark)
        sc.draw(canvas, t)
        return canvas

    def frame(self, t):
        for i in range(1, len(self.scenes)):
            b = self.scenes[i].start
            if abs(t - b) < TRANS:
                fa, fb = self.scene_frame(self.scenes[i - 1], t), self.scene_frame(self.scenes[i], t)
                p = ease_in_out(prog(t, b - TRANS, b + TRANS))
                if i % 2 == 1:
                    # Sapuan horizontal dengan blur gerak.
                    out = Image.new("RGBA", (W, H))
                    out.paste(fa, (int(-p * W), 0))
                    out.paste(fb, (int((1 - p) * W), 0))
                    return motion_blur(out, int(math.sin(math.pi * p) * 70)).convert("RGB")
                # Zoom tembus: adegan lama membesar dan memudar, adegan baru mengecil ke ukuran.
                return Image.blend(zoom_crop(fa, 1 + 0.12 * p).convert("RGB"),
                                   zoom_crop(fb, 1.08 - 0.08 * p).convert("RGB"), p)
        cur = next(sc for sc in reversed(self.scenes) if t >= sc.start)
        return self.scene_frame(cur, t).convert("RGB")

    def sfx_events(self):
        ev = []
        for i, sc in enumerate(self.scenes):
            ev += sc.sfx
            if i > 0:
                ev.append((sc.start - TRANS, "whoosh"))
        return sorted(ev)


# ------------------------------------------------------------------ suara
def sfx(kind, rng):
    if kind in ("whoosh", "whoosh_kecil", "swish"):
        dur = {"whoosh": 0.55, "whoosh_kecil": 0.4, "swish": 0.35}[kind]
        n = int(dur * SR)
        t = np.arange(n) / SR
        noise = rng.standard_normal(n + 64)
        out = np.zeros(n)
        seg = n // 24
        for k in range(24):
            # Derau dihaluskan dengan jendela yang makin pendek: kesannya nada naik menyapu.
            win = int(lerp(60, 6, k / 23))
            sm = np.convolve(noise[k * seg:(k + 1) * seg + win], np.ones(win) / win, mode="same")[:seg]
            out[k * seg:k * seg + len(sm)] = sm
        env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.6
        return out * env * {"whoosh": 1.6, "whoosh_kecil": 1.2, "swish": 1.0}[kind]
    if kind == "tick":
        n = int(0.14 * SR)
        t = np.arange(n) / SR
        return (np.sin(2 * np.pi * 1500 * t) + 0.3 * np.sin(2 * np.pi * 2250 * t)) * np.exp(-t / 0.025) * 0.22
    if kind == "pop":
        n = int(0.08 * SR)
        t = np.arange(n) / SR
        return np.sin(2 * np.pi * np.cumsum(np.linspace(700, 420, n)) / SR) * np.exp(-t / 0.02) * 0.12
    raise ValueError(kind)


def decode(path, dur):
    raw = subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-i", path, "-t", f"{dur:.3f}",
                          "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).astype(np.float64)


def build_audio(film, path, nasyid):
    dur = film.dur
    n = int(dur * SR)
    t = np.arange(n) / SR
    mix = np.zeros((n, 2))
    if nasyid:
        bed = decode(nasyid, dur)
        m = min(n, len(bed))
        env = np.clip(t[:m] / 0.8, 0, 1) * np.clip((dur - t[:m]) / 2.5, 0, 1)
        mix[:m] += bed[:m] * env[:, None] * 0.55
    rng = np.random.default_rng(5)
    for when, kind in film.sfx_events():
        s = sfx(kind, rng)
        i = int(max(0.0, when) * SR)
        e = min(n, i + len(s))
        pan = 0.45 + 0.1 * rng.random() if kind == "pop" else 0.5
        mix[i:e, 0] += s[: e - i] * (1 - pan) * 2
        mix[i:e, 1] += s[: e - i] * pan * 2
    mix *= (np.clip(t / 0.4, 0, 1) * np.clip((dur - t) / 0.6, 0, 1))[:, None]
    mix *= 0.6 / max(1e-9, np.abs(mix).max())
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((mix * 32767).astype("<i2").tobytes())


def loudnorm(src, dst, target="I=-14:TP=-1.5:LRA=11"):
    p1 = subprocess.run([FFMPEG, "-hide_banner", "-i", src, "-af", f"loudnorm={target}:print_format=json",
                         "-f", "null", "-"], capture_output=True, text=True)
    m = json.loads(re.search(r"\{[^{}]*\"input_i\"[^{}]*\}", p1.stderr, re.S).group(0))
    af = (f"loudnorm={target}:measured_I={m['input_i']}:measured_TP={m['input_tp']}:"
          f"measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:"
          f"offset={m['target_offset']}:linear=true")
    subprocess.run([FFMPEG, "-hide_banner", "-y", "-i", src, "-af", af, "-ar", str(SR), "-c:a", "pcm_s16le", dst],
                   check=True, capture_output=True)


# ------------------------------------------------------------------ pemeriksaan
def check(mp4, dur):
    frames_dir = os.path.join(OUT, "frames_intro")
    os.makedirs(frames_dir, exist_ok=True)
    for f in os.listdir(frames_dir):
        os.remove(os.path.join(frames_dir, f))
    subprocess.run([FFMPEG, "-hide_banner", "-y", "-i", mp4, "-vf", rf"select=not(mod(n\,{FPS}))",
                    "-vsync", "vfr", os.path.join(frames_dir, "f_%03d.png")], check=True, capture_output=True)
    info = subprocess.run([FFMPEG, "-hide_banner", "-i", mp4], capture_output=True, text=True).stderr
    d = re.search(r"Duration: (\d+):(\d+):([\d.]+)", info)
    seconds = int(d.group(1)) * 3600 + int(d.group(2)) * 60 + float(d.group(3))
    ebu = subprocess.run([FFMPEG, "-hide_banner", "-i", mp4, "-af", "ebur128=peak=true", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    summary = ebu[ebu.rfind("Summary:"):]
    loud = re.search(r"I:\s+(-?[\d.]+) LUFS", summary).group(1)
    peak = re.search(r"Peak:\s+(-?[\d.]+) dBFS", summary).group(1)
    print(f"Durasi {seconds:.2f} dtk | loudness {loud} LUFS | true peak {peak} dBTP")
    for kind, desc in re.findall(r"Stream #\S+: (Video|Audio): ([^\n]+)", info):
        print(f"  {kind}: {desc[:120]}")
    ok = abs(seconds - dur) < 0.15 and float(peak) < -1.0
    print("LULUS" if ok else "GAGAL: durasi atau peak di luar batas")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--nasyid", help="berkas audio nasyid untuk latar (dari pemilik)")
    ap.add_argument("--preview", help="detik dipisah koma: simpan PNG saja, tanpa video")
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    film = Film(build())

    if args.preview:
        for s in args.preview.split(","):
            film.frame(float(s)).save(os.path.join(OUT, f"pratinjau_{float(s):05.2f}.png"))
        print("pratinjau tersimpan di", OUT)
        return

    raw, norm = os.path.join(OUT, "intro-audio-mentah.wav"), os.path.join(OUT, "intro-audio.wav")
    build_audio(film, raw, args.nasyid)
    loudnorm(raw, norm)

    mp4 = os.path.join(OUT, "myquran-perkenalan.mp4")
    frames = int(film.dur * FPS)
    cmd = [FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
           "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
           "-i", norm,
           "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-profile:v", "high",
           "-c:a", "aac", "-b:a", "192k", "-ar", str(SR), "-shortest", "-movflags", "+faststart", mp4]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for i in range(frames):
        proc.stdin.write(film.frame(i / FPS).tobytes())
        if i % (FPS * 5) == 0:
            print(f"frame {i}/{frames}", flush=True)
    proc.stdin.close()
    if proc.wait() != 0:
        sys.exit("ffmpeg gagal")
    print(f"Tersimpan: {mp4}")
    sys.exit(0 if check(mp4, film.dur) else 1)


if __name__ == "__main__":
    main()
