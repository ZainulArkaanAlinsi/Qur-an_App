from PIL import Image, ImageDraw, ImageFont
import pathlib
S = pathlib.Path(__file__).parent/'out/screens'
FONTS = pathlib.Path(__file__).resolve().parents[4] / 'assets/fonts'
F = str(FONTS / 'PlusJakartaSans-wght-Latin.ttf')
G = str(FONTS / 'EBGaramond-wght-Latin.ttf')
def fnt(p, s, w=None):
    f = ImageFont.truetype(p, s)
    if w:
        try: f.set_variation_by_axes([w])
        except Exception: pass
    return f
phones = [('V6-Beranda','Beranda · terang'),('V6-Beranda-Diputar','Beranda · murottal diputar'),('V6-Beranda-Gelap','Beranda · gelap'),
          ('V6-Murottal','Murottal · teks'),('V6-Murottal-Gelap','Murottal · gelap')]
pw, ph, gap, pad = 390*2, 844*2, 80, 120
comp = Image.open(S/'V6-Komponen.png')
W = pad*2 + len(phones)*pw + (len(phones)-1)*gap
cw = W - pad*2; ch = int(comp.height * cw / comp.width)
H = pad + 260 + 70 + ph + 140 + 70 + ch + pad
img = Image.new('RGB', (W, H), '#E9E4D8'); d = ImageDraw.Draw(img)
d.text((pad, pad), 'MyQuran v6 — Tenang & Terarah', font=fnt(G, 120, 500), fill='#003527')
d.text((pad, pad+150), 'Beranda "Langkah berikutnya" · Horizon salat · Kartu Hari ini · Dock (tab + murottal) · Murottal mode teks',
       font=fnt(F, 46, 600), fill='#5F625D')
y = pad + 260
for i,(n,lab) in enumerate(phones):
    x = pad + i*(pw+gap)
    d.text((x, y), lab, font=fnt(F, 44, 800), fill='#1B1C1C')
    im = Image.open(S/f'{n}.png').convert('RGB')
    m = Image.new('L', im.size, 0); ImageDraw.Draw(m).rounded_rectangle([0,0,im.width-1,im.height-1], 90, fill=255)
    sh = Image.new('RGBA', (pw+40, ph+40), (0,0,0,0))
    img.paste(im, (x, y+70), m)
y2 = y + 70 + ph + 140
d.text((pad, y2), 'Komponen & status (logika untuk Claude Code)', font=fnt(F, 44, 800), fill='#1B1C1C')
img.paste(comp.resize((cw, ch), Image.LANCZOS), (pad, y2+70))
img.save(S/'V6-Papan.png', optimize=True)
small = img.resize((W//2, H//2), Image.LANCZOS); small.save(S/'V6-Papan-kecil.png', optimize=True)
print(img.size, small.size)
