"""Render video promo MyQuran: 20 detik, 1920x1080, 60 fps, H.264 + AAC.

Semua layar aplikasi berasal dari golden test asli (test/golden/goldens/, render
aplikasi sungguhan dengan font asli). Tidak ada UI yang digambar ulang. Frame HP
di sekelilingnya polos dan tanpa merek.

Pakai (dari root repo, lihat tool/promo/README.md):
    tool/promo/.venv/Scripts/python.exe tool/promo/render.py
    tool/promo/.venv/Scripts/python.exe tool/promo/render.py --tenang
"""
import argparse
import json
import math
import os
import re
import subprocess
import sys
import wave

import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "tool", "promo", "out")
GOLDEN = os.path.join(ROOT, "test", "golden", "goldens")
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

W, H, FPS, DUR = 1920, 1080, 60, 20.0
FRAMES = int(DUR * FPS)
SR = 48000

# SacredTokens.light dan token v6 (lib/app/sacred_tokens.dart).
BG = (0xF4, 0xF1, 0xEA)
SEC = (0x5F, 0x62, 0x5D)
PRIMARY = (0x00, 0x35, 0x27)
PRIMARY_TEXT = (0x00, 0x51, 0x3B)
GOLD = (0xC9, 0xA1, 0x3B)
HERO_A = (0x0D, 0x58, 0x43)
HERO_B = (0x06, 0x3B, 0x2D)
ON_HERO = (0xFB, 0xF7, 0xEC)
GOLD_BUTTON = (0xF4, 0xCF, 0x5D)
ON_GOLD_BUTTON = (0x1F, 0x1A, 0x08)
DEVICE = (0x14, 0x19, 0x17)
DEVICE_EDGE = (0x3A, 0x42, 0x3E)

FONT_SERIF = os.path.join(ROOT, "assets", "fonts", "EBGaramond-wght-Latin.ttf")
FONT_SANS = os.path.join(ROOT, "assets", "fonts", "PlusJakartaSans-wght-Latin.ttf")

# Detik pergantian adegan; dipakai juga untuk bunyi ketuk.
CUTS = [3.0, 7.0, 11.0, 14.0, 17.0]

SCENES = [
    # (mulai, selesai, eyebrow, judul, anak judul)
    (3.0, 7.0, "BERANDA BARU", "Satu langkah untuk hari ini",
     "Salat berikutnya tampil paling atas, lalu satu hal yang perlu dikerjakan hari ini."),
    (7.0, 11.0, "MUROTTAL", "Ikuti ayat yang dibaca",
     "Ayat yang sedang dibaca qari tampil bersama terjemahannya dan ikut bergulir."),
    (11.0, 14.0, "WAKTU SALAT", "Sesuai tempatmu",
     "Lokasi otomatis atau kota pilihan, dengan metode Kemenag RI sebagai bawaan."),
    (14.0, 17.0, "QARI & SESI HARI INI", "Dengar, tirukan, istiqamah",
     "Pilih qari dan dengar contohnya. Sesi hari ini sekitar 10 menit."),
]

# HP utama: layar berganti di dalam satu frame HP.
MAIN_SCREENS = [("beranda", 3.0), ("murottal", 7.0), ("salat", 11.0), ("qari", 14.0)]
GOLDENS = {
    "beranda": "19_beranda_baru_light.png",
    "murottal": "20_murottal_teks_light.png",
    "salat": "22_waktu_salat_light.png",
    "qari": "23_qari_light.png",
    "sesi": "19_sesi_tirukan_light.png",
}
MAIN_H, PAIR_H = 940, 860


# ------------------------------------------------------------------ util waktu
def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def prog(t, a, b):
    return clamp((t - a) / (b - a))


def ease_out(x):
    return 1 - (1 - x) ** 3


def ease_in_out(x):
    return 4 * x ** 3 if x < 0.5 else 1 - (-2 * x + 2) ** 3 / 2


def lerp(a, b, x):
    return a + (b - a) * x


# ------------------------------------------------------------------ teks
_fonts = {}


def font(path, size, weight):
    key = (path, size, weight)
    if key not in _fonts:
        f = ImageFont.truetype(path, size)
        f.set_variation_by_axes([weight])
        _fonts[key] = f
    return _fonts[key]


def line_width(text, fnt, tracking):
    return fnt.getlength(text) + tracking * max(0, len(text) - 1)


def wrap(text, fnt, max_w, tracking=0):
    lines, cur = [], ""
    for word in text.split():
        cand = word if not cur else cur + " " + word
        if line_width(cand, fnt, tracking) <= max_w:
            cur = cand
            continue
        if not cur:
            sys.exit(f"Teks terpotong: kata '{word}' lebih lebar dari {max_w}px")
        lines.append(cur)
        cur = word
    if cur:
        lines.append(cur)
    return lines


def text_block(text, fnt, color, max_w, line_h, tracking=0, align="left"):
    """Teks dibungkus ke RGBA. Berhenti dengan galat (bukan memotong) bila satu kata tidak muat."""
    lines = wrap(text, fnt, max_w, tracking)
    widths = [line_width(ln, fnt, tracking) for ln in lines]
    w = int(math.ceil(max(widths))) + 4 if align == "center" else max_w
    img = Image.new("RGBA", (w, line_h * len(lines) + line_h // 3), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, (ln, lw) in enumerate(zip(lines, widths)):
        x = (w - lw) / 2 if align == "center" else 0
        y = i * line_h
        if tracking:
            for ch in ln:
                d.text((x, y), ch, font=fnt, fill=color)
                x += fnt.getlength(ch) + tracking
        else:
            d.text((x, y), ln, font=fnt, fill=color)
    return img


def with_alpha(img, a):
    if a >= 0.999:
        return img
    out = img.copy()
    out.putalpha(out.getchannel("A").point(lambda v: int(v * a)))
    return out


def paste(canvas, img, x, y, a=1.0):
    """Tempel RGBA; bagian di luar kanvas (saat masuk/keluar layar) dipotong."""
    if a <= 0.003:
        return
    x, y = int(round(x)), int(round(y))
    if x >= W or y >= H or x + img.width <= 0 or y + img.height <= 0:
        return
    src = img.crop((max(0, -x), max(0, -y), min(img.width, W - x), min(img.height, H - y)))
    if src.width <= 0 or src.height <= 0:
        return
    canvas.alpha_composite(with_alpha(src, a), (max(0, x), max(0, y)))


# ------------------------------------------------------------------ HP
def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return m


class Phone:
    """Frame HP polos (tanpa merek). Layar berisi golden asli, hanya diskalakan."""

    def __init__(self, names, height):
        ref = Image.open(os.path.join(GOLDEN, GOLDENS[names[0]]))
        self.bezel = round(height * 0.016)
        r_out = round(height * 0.072)
        sh = height - 2 * self.bezel
        sw = round(sh * ref.width / ref.height)
        w = sw + 2 * self.bezel
        body = Image.new("RGBA", (w, height), (0, 0, 0, 0))
        d = ImageDraw.Draw(body)
        d.rounded_rectangle((0, 0, w - 1, height - 1), r_out, fill=DEVICE + (255,))
        d.rounded_rectangle((1, 1, w - 2, height - 2), r_out - 1, outline=DEVICE_EDGE + (255,), width=2)
        self.body = body
        self.screen_size = (sw, sh)
        self.mask = rounded_mask((sw, sh), r_out - self.bezel)
        self.screens = {
            n: Image.open(os.path.join(GOLDEN, GOLDENS[n])).convert("RGBA").resize((sw, sh), Image.LANCZOS)
            for n in names
        }
        blur, pad = 34, 102
        shadow = Image.new("RGBA", (w + 2 * pad, height + 2 * pad), (0, 0, 0, 0))
        shadow.paste(Image.new("RGBA", (w, height), (8, 26, 20, 95)), (pad, pad), rounded_mask((w, height), r_out))
        self.shadow = shadow.filter(ImageFilter.GaussianBlur(blur))

    def draw(self, canvas, layers, cx, cy, scale=1.0, angle=0.0, a=1.0):
        """layers: [(nama layar, geser)]. Geser 0 = di tempat, 1 = satu lebar layar ke kanan.

        Pergantian layar memakai dorongan di dalam layar HP (seperti pindah halaman),
        bukan silang-pudar, supaya dua UI tidak pernah tampak bertumpuk.
        """
        if a <= 0.003:
            return
        sw, sh = self.screen_size
        screen = Image.new("RGBA", (sw, sh), DEVICE + (255,))
        for name, dx in layers:
            x = round(dx * sw)
            if -sw < x < sw:
                screen.alpha_composite(self.screens[name], (max(0, x), 0), (max(0, -x), 0))
        img = self.body.copy()
        img.paste(screen, (self.bezel, self.bezel), self.mask)
        shadow = self.shadow
        if abs(scale - 1) > 1e-3:
            img = img.resize((round(img.width * scale), round(img.height * scale)), Image.BICUBIC)
            shadow = shadow.resize((round(shadow.width * scale), round(shadow.height * scale)), Image.BICUBIC)
        if abs(angle) > 0.05:
            img = img.rotate(angle, resample=Image.BICUBIC, expand=True)
            shadow = shadow.rotate(angle, resample=Image.BICUBIC, expand=True)
        paste(canvas, shadow, cx - shadow.width / 2, cy - shadow.height / 2 + 26 * scale, a * 0.9)
        paste(canvas, img, cx - img.width / 2, cy - img.height / 2, a)


# ------------------------------------------------------------------ latar
def radial_bg(base, glow, center, radius):
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.sqrt((xx - center[0]) ** 2 + (yy - center[1]) ** 2) / radius
    k = np.clip(1 - d, 0, 1)[..., None] ** 2
    arr = np.array(base, float) * (1 - k) + np.array(glow, float) * k
    return Image.fromarray(arr.astype(np.uint8), "RGB").convert("RGBA")


def hero_bg():
    yy, xx = np.mgrid[0:H, 0:W]
    k = np.clip((xx / W) * 0.45 + (yy / H) * 0.55, 0, 1)[..., None]
    arr = np.array(HERO_A, float) * (1 - k) + np.array(HERO_B, float) * k
    return Image.fromarray(arr.astype(np.uint8), "RGB").convert("RGBA")


# ------------------------------------------------------------------ video
def build_assets():
    a = {}
    a["bg"] = radial_bg(BG, (0xFB, 0xF7, 0xEC), (W * 0.72, H * 0.42), W * 0.75)
    a["hero"] = hero_bg()
    logo = Image.open(os.path.join(ROOT, "assets", "brand", "logo_utama.png")).convert("RGBA")
    a["logo"] = logo.resize((round(logo.width * 430 / logo.height), 430), Image.LANCZOS)
    logo_d = Image.open(os.path.join(ROOT, "assets", "brand", "logo_utama_gelap.png")).convert("RGBA")
    a["logo_gelap"] = logo_d.resize((round(logo_d.width * 330 / logo_d.height), 330), Image.LANCZOS)
    a["tagline"] = text_block("Baca, belajar, dan istiqamah setiap hari.",
                              font(FONT_SANS, 44, 600), SEC, 1400, 60, align="center")

    a["main"] = Phone([n for n, _ in MAIN_SCREENS], MAIN_H)
    a["sesi"] = Phone(["sesi"], PAIR_H)

    a["text"] = []
    for i, (_, _, eyebrow, title, sub) in enumerate(SCENES):
        col = 700 if i == 3 else 780
        a["text"].append((
            text_block(eyebrow, font(FONT_SANS, 26, 800), PRIMARY_TEXT, col, 36, tracking=4),
            text_block(title, font(FONT_SERIF, 88, 500), PRIMARY, col, 96),
            text_block(sub, font(FONT_SANS, 34, 500), SEC, col, 50),
        ))

    a["gratis"] = text_block("Gratis. Tanpa iklan.", font(FONT_SERIF, 96, 500), ON_HERO, 1500, 110, align="center")
    label = text_block("Tersedia di Google Play", font(FONT_SANS, 36, 700), ON_GOLD_BUTTON, 900, 48, align="center")
    pill = Image.new("RGBA", (label.width + 96, 92), (0, 0, 0, 0))
    ImageDraw.Draw(pill).rounded_rectangle((0, 0, pill.width - 1, pill.height - 1), 46, fill=GOLD_BUTTON + (255,))
    pill.alpha_composite(label, ((pill.width - label.width) // 2, (pill.height - 48) // 2 - 4))
    a["pill"] = pill
    a["rule"] = Image.new("RGBA", (64, 5), GOLD + (255,))
    return a


def draw_scene_text(canvas, a, i, t):
    start, end = SCENES[i][0], SCENES[i][1]
    eyebrow, title, sub = a["text"][i]
    items = [(a["rule"], 0.0, 22), (eyebrow, 0.0, 22), (title, 0.12, 28), (sub, 0.24, 0)]
    block_h = sum(img.height + gap for img, _, gap in items)
    y = (H - block_h) / 2
    out = 1 - ease_in_out(prog(t, end - 0.45, end - 0.05))
    for img, delay, gap in items:
        p = ease_out(prog(t, start + 0.15 + delay, start + 0.85 + delay))
        paste(canvas, img, 150 + (1 - p) * -40, y + (1 - p) * 30 - (1 - out) * 18, p * out)
        y += img.height + gap


def main_layers(t):
    """Layar HP utama: dorongan 0,5 dtk di tiap batas, layar lama bergeser sedikit (paralaks)."""
    k = 0
    for i, (_, s) in enumerate(MAIN_SCREENS):
        if t >= s - 0.25:
            k = i
    name, s = MAIN_SCREENS[k]
    p = 1.0 if k == 0 else ease_in_out(prog(t, s - 0.25, s + 0.25))
    if p >= 1.0:
        return [(name, 0.0)]
    return [(MAIN_SCREENS[k - 1][0], -0.3 * p), (name, 1.0 - p)]


def draw_phones(canvas, a, t):
    if not 2.8 <= t < 17.4:
        return
    float_y = math.sin(2 * math.pi * t / 4.5) * 6  # melayang pelan, bukan goyang
    exit_p = ease_in_out(prog(t, 16.75, 17.35))

    # HP utama masuk dari kanan sambil tegak, lalu bergeser ke kiri saat HP kedua masuk.
    enter = ease_out(prog(t, 2.8, 3.8))
    move = ease_in_out(prog(t, 14.0, 14.8))
    cx = lerp(lerp(W + 380, 1340, enter), 1110, move)
    cy = 540 + float_y + exit_p * 120
    scale = lerp(1.0, PAIR_H / MAIN_H, move)
    a["main"].draw(canvas, main_layers(t), cx, cy, scale, lerp(-10, 0, enter), 1 - exit_p)

    # HP kedua (Sesi hari ini) masuk dari kanan pada 14,3 dtk.
    p = ease_out(prog(t, 14.3, 15.2))
    if p > 0:
        a["sesi"].draw(canvas, [("sesi", 0.0)], lerp(W + 360, 1565, p),
                       560 - float_y + exit_p * 120, 1.0, lerp(10, 0, p), p * (1 - exit_p))


def render_frame(a, t):
    canvas = a["bg"].copy()

    # 0–3 dtk: logo + kalimat pembuka.
    if t < 3.2:
        p = ease_out(prog(t, 0.15, 1.1))
        out = 1 - ease_in_out(prog(t, 2.35, 2.85))
        logo = a["logo"]
        s = lerp(0.92, 1.0, p) * lerp(1.0, 1.04, 1 - out)
        img = logo.resize((round(logo.width * s), round(logo.height * s)), Image.BICUBIC)
        paste(canvas, img, (W - img.width) / 2, 330 - img.height / 2, p * out)
        q = ease_out(prog(t, 0.7, 1.5))
        tag = a["tagline"]
        paste(canvas, tag, (W - tag.width) / 2, 640 + (1 - q) * 26, q * out)

    # 3–17 dtk: teks adegan + HP.
    for i, sc in enumerate(SCENES):
        if sc[0] <= t < sc[1]:
            draw_scene_text(canvas, a, i, t)
    draw_phones(canvas, a, t)

    # 17–20 dtk: latar hijau, logo versi gelap (berkasnya sendiri), pesan akhir.
    if t >= 16.8:
        canvas.alpha_composite(with_alpha(a["hero"], ease_in_out(prog(t, 16.8, 17.5))))
        p = ease_out(prog(t, 17.3, 18.1))
        logo = a["logo_gelap"]
        paste(canvas, logo, (W - logo.width) / 2, 120 + (1 - p) * 30, p)
        q = ease_out(prog(t, 17.6, 18.4))
        g = a["gratis"]
        paste(canvas, g, (W - g.width) / 2, 500 + (1 - q) * 30, q)
        r = ease_out(prog(t, 18.0, 18.7))
        pill = a["pill"]
        s = lerp(0.94, 1.0, r)
        img = pill.resize((round(pill.width * s), round(pill.height * s)), Image.BICUBIC)
        paste(canvas, img, (W - img.width) / 2, 690 + (pill.height - img.height) / 2, r)
    return canvas.convert("RGB")


# ------------------------------------------------------------------ suara
def tick(n, sr):
    t = np.arange(n) / sr
    env = np.exp(-t / 0.028) * np.clip(t / 0.002, 0, 1)
    tone = np.sin(2 * np.pi * 1320 * t) + 0.35 * np.sin(2 * np.pi * 1980 * t)
    rng = np.random.default_rng(7)
    noise = np.convolve(rng.standard_normal(n), np.ones(6) / 6, mode="same") * np.exp(-t / 0.006)
    return (tone * env + 0.25 * noise) * 0.32


def synth_audio(path, tenang):
    n = int(DUR * SR)
    t = np.arange(n) / SR
    left = np.zeros(n)
    right = np.zeros(n)
    rng = np.random.default_rng(11)
    if not tenang:
        # Pad tanpa ritme dan tanpa melodi: akord diam (D, A, D, E) dengan napas sangat pelan.
        for f, amp, pan in ((146.83, 0.50, 0.5), (220.0, 0.32, 0.35), (293.66, 0.22, 0.65), (329.63, 0.10, 0.45)):
            for det in (-0.18, 0.18):
                ph = rng.uniform(0, 2 * np.pi)
                v = amp * np.sin(2 * np.pi * (f + det) * t + ph)
                v += amp * 0.12 * np.sin(2 * np.pi * 2 * (f + det) * t + ph)
                swell = 0.78 + 0.22 * np.sin(2 * np.pi * 0.06 * t + ph)
                left += v * swell * (1 - pan)
                right += v * swell * pan
        bed = np.clip(t / 1.5, 0, 1) * np.clip((DUR - t) / 1.8, 0, 1) * 0.22
        left *= bed
        right *= bed
    else:
        # Desis halus: derau yang dihaluskan, sangat pelan.
        k = np.ones(48) / 48
        left += np.convolve(rng.standard_normal(n), k, mode="same") * 0.05
        right += np.convolve(rng.standard_normal(n), k, mode="same") * 0.05
    tk = tick(int(0.16 * SR), SR)
    for c in CUTS:
        s = int(c * SR)
        e = min(n, s + len(tk))
        left[s:e] += tk[: e - s] * 0.9
        right[s:e] += tk[: e - s]
    fade = np.clip(t / 0.5, 0, 1) * np.clip((DUR - t) / 0.5, 0, 1)
    stereo = np.stack([left * fade, right * fade], axis=1)
    stereo *= 0.5 / max(1e-9, np.abs(stereo).max())
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((stereo * 32767).astype("<i2").tobytes())


def loudnorm(src, dst):
    target = "I=-16:TP=-2.0:LRA=7"
    p1 = subprocess.run([FFMPEG, "-hide_banner", "-i", src, "-af", f"loudnorm={target}:print_format=json",
                         "-f", "null", "-"], capture_output=True, text=True)
    m = json.loads(re.search(r"\{[^{}]*\"input_i\"[^{}]*\}", p1.stderr, re.S).group(0))
    af = (f"loudnorm={target}:measured_I={m['input_i']}:measured_TP={m['input_tp']}:"
          f"measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:"
          f"offset={m['target_offset']}:linear=true")
    subprocess.run([FFMPEG, "-hide_banner", "-y", "-i", src, "-af", af, "-ar", str(SR), "-c:a", "pcm_s16le", dst],
                   check=True, capture_output=True)


# ------------------------------------------------------------------ pemeriksaan
def check(mp4):
    frames_dir = os.path.join(OUT, "frames")
    os.makedirs(frames_dir, exist_ok=True)
    for f in os.listdir(frames_dir):
        os.remove(os.path.join(frames_dir, f))
    # Satu frame tiap detik (frame ke-0, 60, 120, ...) ditambah frame terakhir.
    subprocess.run([FFMPEG, "-hide_banner", "-y", "-i", mp4, "-vf", rf"select=not(mod(n\,{FPS}))",
                    "-vsync", "vfr", os.path.join(frames_dir, "detik_%02d.png")], check=True, capture_output=True)
    subprocess.run([FFMPEG, "-hide_banner", "-y", "-sseof", "-0.05", "-i", mp4, "-frames:v", "1",
                    os.path.join(frames_dir, "akhir.png")], check=True, capture_output=True)
    info = subprocess.run([FFMPEG, "-hide_banner", "-i", mp4], capture_output=True, text=True).stderr
    dur = re.search(r"Duration: (\d+):(\d+):([\d.]+)", info)
    seconds = int(dur.group(1)) * 3600 + int(dur.group(2)) * 60 + float(dur.group(3))
    ebu = subprocess.run([FFMPEG, "-hide_banner", "-i", mp4, "-af", "ebur128=peak=true", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    summary = ebu[ebu.rfind("Summary:"):]
    loud = re.search(r"I:\s+(-?[\d.]+) LUFS", summary).group(1)
    peak = re.search(r"Peak:\s+(-?[\d.]+) dBFS", summary).group(1)
    print(f"Durasi {seconds:.2f} dtk | loudness {loud} LUFS | true peak {peak} dBTP")
    for kind, desc in re.findall(r"Stream #\S+: (Video|Audio): ([^\n]+)", info):
        print(f"  {kind}: {desc[:120]}")
    print(f"Frame pengecekan: {len(os.listdir(frames_dir))} berkas di {frames_dir}")
    ok = abs(seconds - DUR) < 0.1 and float(peak) < -1.0
    print("LULUS" if ok else "GAGAL: durasi atau peak di luar batas")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tenang", action="store_true", help="tanpa pad: hanya ketuk + desis halus")
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)

    raw = os.path.join(OUT, "audio-mentah.wav")
    norm = os.path.join(OUT, "audio.wav")
    synth_audio(raw, args.tenang)
    loudnorm(raw, norm)

    mp4 = os.path.join(OUT, "myquran-promo.mp4")
    a = build_assets()
    cmd = [FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
           "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
           "-i", norm,
           "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-profile:v", "high",
           "-c:a", "aac", "-b:a", "192k", "-ar", str(SR), "-shortest", "-movflags", "+faststart", mp4]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for i in range(FRAMES):
        proc.stdin.write(render_frame(a, i / FPS).tobytes())
        if i % (FPS * 2) == 0:
            print(f"frame {i}/{FRAMES}", flush=True)
    proc.stdin.close()
    if proc.wait() != 0:
        sys.exit("ffmpeg gagal")
    print(f"Tersimpan: {mp4}")
    sys.exit(0 if check(mp4) else 1)


if __name__ == "__main__":
    main()
