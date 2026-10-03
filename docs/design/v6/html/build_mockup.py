"""Bangun mockup HTML v6 MyQuran dari font & teks asli repo, lalu render PNG.

Teks ayat dan terjemahan DIBACA dari berkas Tanzil di repo, tidak diketik.
Jalankan: python3 build.py  (butuh playwright + chromium terpasang)
"""
import base64, html, pathlib, re

REPO = pathlib.Path(__file__).resolve().parents[4]  # akar repo
OUT = pathlib.Path(__file__).parent / 'out'
(OUT / 'html').mkdir(parents=True, exist_ok=True)
(OUT / 'screens').mkdir(parents=True, exist_ok=True)

RAW = REPO / 'assets/quran/raw'
AR = (RAW / 'tanzil_uthmani_v1.0.2.txt').read_text(encoding='utf-8').splitlines()
ID = {}
for line in (RAW / 'tanzil_id.indonesian_2010-06-04.txt').read_text(encoding='utf-8').splitlines():
    parts = line.split('|', 2)
    if len(parts) == 3 and parts[0].isdigit():
        ID[(int(parts[0]), int(parts[1]))] = parts[2]
XML = (RAW / 'quran-data.xml').read_text(encoding='utf-8')
def sura_name(n):
    return re.search(r'<sura index="%d"[^>]*?\sname="([^"]+)"' % n, XML).group(1)

def ayah(s, a):
    """Al-Fatihah = baris 1..7 berkas Tanzil (satu ayat per baris)."""
    assert s == 1
    return AR[a - 1]

FATIHAH = sura_name(1)
NABA = sura_name(78)

def font(name):
    b = (REPO / 'assets/fonts' / name).read_bytes()
    return 'data:font/ttf;base64,' + base64.b64encode(b).decode()

FONTS = f"""
@font-face{{font-family:'AmiriQuran';src:url({font('AmiriQuran-Regular.ttf')});}}
@font-face{{font-family:'Jakarta';src:url({font('PlusJakartaSans-wght-Latin.ttf')});font-weight:200 800;}}
@font-face{{font-family:'Garamond';src:url({font('EBGaramond-wght-Latin.ttf')});font-weight:400 800;}}
"""

# ---------- ikon garis (24, stroke 1.8) ----------
P = {
 'home': '<path d="M3.5 10.2 12 3.5l8.5 6.7V19a1.5 1.5 0 0 1-1.5 1.5h-4v-6h-6v6H5A1.5 1.5 0 0 1 3.5 19z"/>',
 'book': '<path d="M12 6.2C10 4.7 6.7 4.2 3.5 4.6v14.2c3.2-.4 6.5.1 8.5 1.6 2-1.5 5.3-2 8.5-1.6V4.6c-3.2-.4-6.5.1-8.5 1.6zM12 6.2v14.2"/>',
 'cap': '<path d="M2.5 9 12 4.5 21.5 9 12 13.5z"/><path d="M6.5 11.2v4.6c0 1.6 2.6 3.2 5.5 3.2s5.5-1.6 5.5-3.2v-4.6M21.5 9v5.5"/>',
 'layers': '<path d="M12 3.5 21 8l-9 4.5L3 8z"/><path d="m3 12 9 4.5 9-4.5M3 16l9 4.5 9-4.5"/>',
 'user': '<circle cx="12" cy="8" r="4"/><path d="M4.5 20.5c0-3.9 3.4-6.3 7.5-6.3s7.5 2.4 7.5 6.3"/>',
 'search': '<circle cx="11" cy="11" r="6.5"/><path d="m20 20-4.2-4.2"/>',
 'bookmark': '<path d="M6.5 3.5h11v17l-5.5-4-5.5 4z"/>',
 'repeat': '<path d="m17 2.5 3 3-3 3"/><path d="M4 11V9.5a4 4 0 0 1 4-4h12"/><path d="m7 21.5-3-3 3-3"/><path d="M20 13v1.5a4 4 0 0 1-4 4H4"/>',
 'timer': '<circle cx="12" cy="13.5" r="7.5"/><path d="M12 9.5v4l2.6 1.8M9.5 2.5h5"/>',
 'download': '<path d="M12 3.5v11.5M7 10.5l5 5 5-5M4.5 20.5h15"/>',
 'range': '<path d="M3.5 12h17M7.5 8l-4 4 4 4M16.5 8l4 4-4 4"/>',
 'chev': '<path d="m6 9 6 6 6-6"/>',
 'chevr': '<path d="m9 6 6 6-6 6"/>',
 'flame': '<path d="M12 3c.8 3.4 4.8 5.6 4.8 10.2a4.8 4.8 0 0 1-9.6 0c0-2 .9-3.3 1.9-4.3.1 1.8.9 2.8 1.9 2.8 0-2.9-.3-5.6 1-8.7z"/>',
 'head': '<path d="M4 15v-3a8 8 0 0 1 16 0v3"/><rect x="3" y="14" width="4.5" height="6.5" rx="1.6"/><rect x="16.5" y="14" width="4.5" height="6.5" rx="1.6"/>',
 'check': '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
 'book2': '<path d="M5 4.5h10.5a3 3 0 0 1 3 3v12H8a3 3 0 0 1-3-3z"/><path d="M5 16.5a3 3 0 0 1 3-3h10.5"/>',
}
def ic(name, size=22, sw=1.8, cls=''):
    return (f'<svg class="ic {cls}" width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" '
            f'stroke="currentColor" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">{P[name]}</svg>')
def fill_ic(kind, size=22):
    d = {'play': '<path d="M8 5.2v13.6a1 1 0 0 0 1.5.86l11-6.8a1 1 0 0 0 0-1.72l-11-6.8A1 1 0 0 0 8 5.2z"/>',
         'pause': '<rect x="6" y="4.5" width="4.2" height="15" rx="1.3"/><rect x="13.8" y="4.5" width="4.2" height="15" rx="1.3"/>',
         'next': '<path d="M5 5.6v12.8a.9.9 0 0 0 1.4.75l9.3-6.4a.9.9 0 0 0 0-1.5L6.4 4.85A.9.9 0 0 0 5 5.6z"/><rect x="17.2" y="4.5" width="2.6" height="15" rx="1.2"/>',
         'prev': '<path d="M19 5.6v12.8a.9.9 0 0 1-1.4.75l-9.3-6.4a.9.9 0 0 1 0-1.5l9.3-6.4A.9.9 0 0 1 19 5.6z"/><rect x="4.2" y="4.5" width="2.6" height="15" rx="1.2"/>',
         'more': '<circle cx="5.5" cy="12" r="1.8"/><circle cx="12" cy="12" r="1.8"/><circle cx="18.5" cy="12" r="1.8"/>',
         'eq': '<rect x="4" y="9" width="3" height="10" rx="1.2"/><rect x="10.5" y="4" width="3" height="15" rx="1.2"/><rect x="17" y="11" width="3" height="8" rx="1.2"/>'}[kind]
    return f'<svg class="ic" width="{size}" height="{size}" viewBox="0 0 24 24" fill="currentColor">{d}</svg>'

def mihrab(w, h, arabic=None, fs=16, inner=True, num=None):
    """Lengkung mihrab (motif MyQuran) — viewBox 100x130."""
    ar = (f'<div class="mh-ar" style="font-size:{fs}px">{html.escape(arabic)}</div>' if arabic else '')
    nm = f'<div class="mh-num">{num}</div>' if num else ''
    inner_svg = ('<path d="M14 124 L14 56 C14 36 36 22 50 14 C64 22 86 36 86 56 L86 124 Z" fill="none" '
                 'stroke="var(--goldLine)" stroke-width="1.6"/>' if inner else '')
    return (f'<div class="mihrab" style="width:{w}px;height:{h}px"><svg viewBox="0 0 100 130" preserveAspectRatio="none">'
            '<path d="M8 130 Q0 130 0 122 L0 52 C0 27 28 11 50 0 C72 11 100 27 100 52 L100 122 Q100 130 92 130 Z" fill="var(--heroA)"/>'
            f'{inner_svg}</svg>{ar}{nm}</div>')

# ---------- tema ----------
THEMES = {
 'light': dict(bg='#F4F1EA', surf='#FCF9F8', surf2='#EAE6DC', ink='#1B1C1C', sec='#5F625D', ter='#9A9D97',
               hair='rgba(27,28,28,.08)', primary='#003527', primaryText='#00513B', primarySoft='#E0ECE5',
               gold='#C9A13B', goldText='#7A5A0E', goldSoft='#FBF0CC', goldBtn='#F4CF5D', onGoldBtn='#1F1A08',
               heroA='#0D5843', heroB='#063B2D', onHero='#FBF7EC', onHeroSec='rgba(251,247,236,.78)', goldLine='#E2C36A',
               teal='#1F6F78', tealSoft='#DCEEEF', sky1='#FCF9F8', sky2='#E3EEF2',
               glass='rgba(252,249,248,.42)', glassRim1='rgba(255,255,255,.75)', glassRim2='rgba(255,255,255,.18)',
               lens='rgba(224,236,229,.92)', shadow='0 10px 30px rgba(20,30,25,.14), 0 2px 6px rgba(20,30,25,.08)',
               cardShadow='0 1px 2px rgba(20,30,25,.05), 0 6px 18px rgba(20,30,25,.05)', statusInk='#1B1C1C'),
 'dark': dict(bg='#08110E', surf='#111C18', surf2='#1A2823', ink='#ECEFEA', sec='#9DA79F', ter='#646D67',
              hair='rgba(236,239,234,.08)', primary='#8FD7B8', primaryText='#9ADDBF', primarySoft='rgba(143,215,184,.14)',
              gold='#FED65B', goldText='#F4D679', goldSoft='rgba(254,214,91,.12)', goldBtn='#F4CF5D', onGoldBtn='#1F1A08',
              heroA='#0F4A39', heroB='#082A20', onHero='#F3F1E8', onHeroSec='rgba(243,241,232,.74)', goldLine='#D6B04A',
              teal='#7CCFD6', tealSoft='rgba(124,207,214,.14)', sky1='#111C18', sky2='#132733',
              glass='rgba(17,28,24,.46)', glassRim1='rgba(255,255,255,.22)', glassRim2='rgba(255,255,255,.04)',
              lens='rgba(143,215,184,.20)', shadow='0 12px 34px rgba(0,0,0,.5), 0 2px 6px rgba(0,0,0,.35)',
              cardShadow='0 1px 0 rgba(255,255,255,.03) inset', statusInk='#ECEFEA'),
}
def vars_css(t):
    return ':root{' + ''.join(f'--{k}:{v};' for k, v in THEMES[t].items()) + '}'

BASE_CSS = """
*{box-sizing:border-box;margin:0;padding:0}
body{background:var(--bg);color:var(--ink);font-family:'Jakarta',sans-serif;word-spacing:.12em;-webkit-font-smoothing:antialiased}
.phone{width:390px;height:844px;position:relative;overflow:hidden;background:var(--bg)}
.phone.tall{height:auto;min-height:844px;padding-bottom:150px}
.status{height:44px;display:flex;align-items:center;justify-content:space-between;padding:0 26px 0 30px;font-weight:700;font-size:15px;color:var(--statusInk)}
.status .r{display:flex;gap:6px;align-items:center;font-size:12px}
.status .bat{border:1.5px solid var(--statusInk);border-radius:5px;padding:0 4px;font-size:11px;line-height:15px}
.ic{display:block;flex:none}
.px{padding:0 20px}
.row{display:flex;align-items:center}
.circle{width:40px;height:40px;border-radius:50%;background:var(--surf);display:grid;place-items:center;color:var(--ink);box-shadow:var(--cardShadow);border:1px solid var(--hair)}
.serif{font-family:'Garamond',serif}
.eyebrow{font-size:11px;font-weight:800;letter-spacing:1.4px;text-transform:uppercase}
.tab{font-variant-numeric:tabular-nums}
.mihrab{position:relative;flex:none}
.mihrab svg{position:absolute;inset:0;width:100%;height:100%}
.mh-ar{position:absolute;left:0;right:0;top:44%;text-align:center;font-family:'AmiriQuran';color:var(--goldLine);direction:rtl;line-height:1.6}
.mh-num{position:absolute;left:0;right:0;bottom:16%;text-align:center;color:var(--goldLine);font-weight:800;font-size:12px}
.home-ind{position:absolute;bottom:8px;left:50%;transform:translateX(-50%);width:134px;height:5px;border-radius:3px;background:var(--ink);opacity:.85}
/* ---- dock (tab bar + now playing), satu permukaan kaca ---- */
.dock{position:absolute;left:12px;right:12px;bottom:26px;border-radius:32px;overflow:hidden;
  background:var(--glass);backdrop-filter:blur(18px) saturate(1.7);-webkit-backdrop-filter:blur(18px) saturate(1.7);
  box-shadow:var(--shadow)}
.dock::before{content:'';position:absolute;inset:0;border-radius:inherit;padding:1px;pointer-events:none;
  background:linear-gradient(170deg,var(--glassRim1),var(--glassRim2) 55%,var(--glassRim1));
  -webkit-mask:linear-gradient(#000 0 0) content-box,linear-gradient(#000 0 0);-webkit-mask-composite:xor;mask-composite:exclude}
.dock::after{content:'';position:absolute;left:0;right:0;top:0;height:55%;pointer-events:none;
  background:linear-gradient(180deg,rgba(255,255,255,.16),rgba(255,255,255,0))}
.tabs{display:flex;height:64px;padding:4px;position:relative;z-index:1}
.tabs .t{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;color:var(--ink);font-size:11px;font-weight:600;border-radius:26px;position:relative}
.tabs .t.on{color:var(--primaryText);font-weight:800;background:var(--lens);
  box-shadow:inset 0 1px 0 rgba(255,255,255,.55),0 1px 3px rgba(0,0,0,.06)}
.np{position:relative;z-index:1;display:flex;align-items:center;gap:12px;padding:10px 10px 6px 12px;height:62px}
.np .meta{flex:1;min-width:0}
.np .meta b{display:block;font-size:14px;font-weight:800;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.np .meta span{display:block;font-size:12px;color:var(--sec);font-weight:600;margin-top:1px}
.np .btn{width:42px;height:42px;border-radius:50%;display:grid;place-items:center;color:var(--ink)}
.np .btn.main{background:var(--primary);color:var(--surf)}
.npTrack{position:relative;z-index:1;display:flex;gap:3px;padding:0 16px 2px}
.npTrack i{flex:1;height:3px;border-radius:2px;background:var(--hair)}
.npTrack i.done{background:var(--primaryText)}
.npTrack i.cur{background:linear-gradient(90deg,var(--gold) var(--p),var(--hair) var(--p))}
.npSep{position:relative;z-index:1;height:1px;margin:6px 14px 0;background:var(--hair)}
"""

def status(time='10:35', bat=90):
    return (f'<div class="status"><span>{time}</span><span class="r">'
            '<svg width="17" height="12" viewBox="0 0 17 12" fill="currentColor"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="4.5" y="5.5" width="3" height="6.5" rx="1"/><rect x="9" y="3" width="3" height="9" rx="1"/><rect x="13.5" y="0" width="3" height="12" rx="1"/></svg>'
            f'<span class="bat">{bat}</span></span></div>')

TABS = [('home', 'Beranda'), ('book', "Qur'an"), ('cap', 'Belajar'), ('layers', 'Hafalan'), ('user', 'Saya')]
def dock(active=0, playing=None):
    tabs = ''.join(f'<div class="t{" on" if i == active else ""}">{ic(k, 22, 2.2 if i == active else 1.8)}<span>{l}</span></div>'
                   for i, (k, l) in enumerate(TABS))
    np = ''
    if playing:
        segs = ''.join('<i class="done"></i>' if i < playing['ayah'] - 1 else
                       (f'<i class="cur" style="--p:{playing["p"]}%"></i>' if i == playing['ayah'] - 1 else '<i></i>')
                       for i in range(playing['total']))
        np = (f'<div class="np">{mihrab(34, 42, None, inner=True, num=playing["ayah"])}'
              f'<div class="meta"><b>{playing["title"]}</b><span>{playing["sub"]}</span></div>'
              f'<div class="btn main">{fill_ic("pause", 18)}</div><div class="btn">{fill_ic("next", 20)}</div></div>'
              f'<div class="npTrack">{segs}</div><div class="npSep"></div>')
    return f'<div class="dock">{np}<div class="tabs">{tabs}</div></div>'

def page(theme, body, extra_css='', tall=False):
    return (f'<!doctype html><html lang="id"><head><meta charset="utf-8"><style>{FONTS}{vars_css(theme)}{BASE_CSS}{extra_css}</style></head>'
            f'<body><div class="phone{" tall" if tall else ""}">{body}</div></body></html>')

# =====================================================================
# BERANDA v6
# =====================================================================
HOME_CSS = """
.hdr{display:flex;justify-content:space-between;align-items:center;padding:6px 20px 0}
.hdr .d b{display:block;font-size:13px;font-weight:800}
.hdr .d span{display:block;font-size:13px;color:var(--sec);font-weight:500;margin-top:1px}
.greet{padding:14px 20px 0}
.greet span{font-size:15px;color:var(--sec);font-weight:600}
.greet h1{font-family:'Garamond';font-weight:500;font-size:34px;line-height:1.08;letter-spacing:-.3px}
/* horizon salat */
.hz{margin:16px 20px 0;border-radius:22px;padding:14px 16px 12px;background:linear-gradient(135deg,var(--sky1) 45%,var(--sky2));box-shadow:var(--cardShadow);border:1px solid var(--hair)}
.hz .top{display:flex;justify-content:space-between;align-items:center}
.hz .top b{font-size:15px;font-weight:800}
.hz .top b em{font-style:normal;color:var(--sec);font-weight:600;font-size:13px;margin-right:6px}
.pill{font-size:12px;font-weight:800;padding:5px 10px;border-radius:999px;background:var(--primarySoft);color:var(--primaryText);white-space:nowrap}
.trk{position:relative;height:16px;margin:14px 8px 6px}
.trk .ln{position:absolute;left:0;right:0;top:7px;height:2px;background:var(--surf2);border-radius:2px}
.trk .ln.past{right:auto;background:var(--primaryText)}
.trk .n{position:absolute;top:3px;width:10px;height:10px;margin-left:-5px;border-radius:50%;background:var(--surf);border:2px solid var(--ter)}
.trk .n.past{background:var(--primaryText);border-color:var(--primaryText)}
.trk .n.next{top:0;width:16px;height:16px;margin-left:-8px;border:3px solid var(--gold);background:var(--surf);box-shadow:0 0 0 4px var(--goldSoft)}
.trk .now{position:absolute;top:2px;width:12px;height:12px;margin-left:-6px;border-radius:50%;background:var(--ink);box-shadow:0 0 0 3px var(--surf)}
.lbls{display:flex;justify-content:space-between;margin:0 -6px}
.lbls div{width:62px;text-align:center;font-size:11px;font-weight:700;color:var(--ink);line-height:1.3}
.lbls div span{display:block;font-weight:600;color:var(--sec)}
.lbls div.next{color:var(--ink);font-weight:800}
.lbls div.next span{color:var(--goldText);font-weight:800}
/* kartu langkah berikutnya */
.ns{margin:14px 20px 0;border-radius:28px;padding:18px 18px 16px;color:var(--onHero);position:relative;overflow:hidden;
  background:radial-gradient(120% 90% at 100% 0%,rgba(255,255,255,.08),rgba(255,255,255,0) 60%),linear-gradient(160deg,var(--heroA),var(--heroB));box-shadow:0 14px 30px rgba(6,59,45,.22)}
.ns .pat{position:absolute;inset:0;opacity:.07}
.ns .top{display:flex;justify-content:space-between;align-items:center;position:relative}
.ns .top .eyebrow{color:var(--goldLine)}
.ns .tm{font-size:12px;font-weight:800;padding:4px 10px;border-radius:999px;background:rgba(255,255,255,.12);color:var(--onHero)}
.ns h2{font-family:'Garamond';font-weight:500;font-size:31px;line-height:1.1;margin-top:8px;position:relative}
.ns p{font-size:14px;color:var(--onHeroSec);margin-top:4px;font-weight:500;position:relative}
.steps{position:relative;margin:16px 6px 4px;height:14px}
.steps .ln{position:absolute;left:0;right:0;top:6px;height:2px;background:rgba(255,255,255,.18)}
.steps .n{position:absolute;top:2px;width:10px;height:10px;margin-left:-5px;border-radius:50%;background:var(--heroB);border:2px solid rgba(255,255,255,.4)}
.steps .n.cur{top:-1px;width:16px;height:16px;margin-left:-8px;border:3px solid var(--goldLine);background:var(--heroA);box-shadow:0 0 0 4px rgba(217,182,83,.18)}
.slb{display:flex;justify-content:space-between;margin:0 -14px;position:relative}
.slb span{width:58px;text-align:center;font-size:10.5px;font-weight:700;color:var(--onHeroSec)}
.slb span.cur{color:var(--onHero)}
.cta{margin-top:16px;height:52px;border-radius:26px;background:var(--goldBtn);color:var(--onGoldBtn);display:flex;align-items:center;justify-content:center;gap:8px;font-weight:800;font-size:16px;position:relative}
.alt{margin-top:12px;position:relative;border-radius:18px;background:rgba(255,255,255,.07);border:1px solid rgba(255,255,255,.10)}
.alt .a{display:flex;align-items:center;gap:12px;padding:9px 12px;min-height:56px}
.alt .a+.a{border-top:1px solid rgba(255,255,255,.10)}
.alt .a .tx{flex:1;min-width:0}
.alt .a small{display:block;font-size:10.5px;font-weight:800;letter-spacing:1px;color:var(--goldLine);text-transform:uppercase}
.alt .a b{display:block;font-size:14px;font-weight:700;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.alt .a > .ic:last-child{color:var(--onHeroSec)}
.alt .ico{width:32px;height:38px;border-radius:11px;display:grid;place-items:center;background:rgba(255,255,255,.10);color:var(--goldLine);flex:none}
/* hari ini */
.sect{padding:22px 20px 8px;font-size:12px;font-weight:800;letter-spacing:1.4px;color:var(--sec);display:flex;justify-content:space-between}
.sect a{letter-spacing:0;font-weight:700;color:var(--primaryText)}
.today{margin:0 20px;border-radius:24px;background:var(--surf);padding:16px;box-shadow:var(--cardShadow);border:1px solid var(--hair)}
.today .grid{display:flex;gap:16px;align-items:center}
.lg{flex:1;display:flex;flex-direction:column;gap:10px}
.lg .r{display:flex;align-items:center;gap:8px;font-size:14px;font-weight:700}
.lg .r i{width:10px;height:10px;border-radius:50%;flex:none}
.lg .r span{flex:1}
.lg .r b{font-weight:800;font-variant-numeric:tabular-nums}
.lg .r b small{color:var(--sec);font-weight:600;font-size:12px}
.hint{margin-top:12px;font-size:13px;color:var(--sec);font-weight:600;padding:10px 12px;border-radius:14px;background:var(--bg)}
.week{display:flex;align-items:center;gap:10px;margin-top:14px;padding-top:14px;border-top:1px solid var(--hair)}
.week .st{display:flex;align-items:center;gap:6px;font-weight:800;font-size:14px;color:var(--goldText);white-space:nowrap}
.week .ds{flex:1;display:flex;justify-content:space-between}
.week .ds div{display:flex;flex-direction:column;align-items:center;gap:4px;font-size:10.5px;font-weight:700;color:var(--sec)}
.week .ds i{width:14px;height:14px;border-radius:50%;background:var(--surf2)}
.week .ds i.on{background:var(--gold)}
.week .ds i.td{background:transparent;border:2px dashed var(--gold)}
.week .ds div.t{color:var(--ink)}
"""

def rings(vals, size=108):
    """vals: list of (fraction, color) dari luar ke dalam."""
    sw, gap = 10, 4
    out = [f'<svg width="{size}" height="{size}" viewBox="0 0 {size} {size}" style="flex:none">']
    r = size / 2 - sw / 2
    for frac, col in vals:
        c = 2 * 3.14159 * r
        out.append(f'<circle cx="{size/2}" cy="{size/2}" r="{r:.1f}" fill="none" stroke="var(--surf2)" stroke-width="{sw}"/>')
        if frac > 0:
            out.append(f'<circle cx="{size/2}" cy="{size/2}" r="{r:.1f}" fill="none" stroke="var(--{col})" stroke-width="{sw}" '
                       f'stroke-linecap="round" stroke-dasharray="{c*frac:.1f} {c:.1f}" transform="rotate(-90 {size/2} {size/2})"/>')
        r -= sw + gap
    out.append('</svg>')
    return ''.join(out)

STAR_PAT = ('<svg class="pat" width="100%" height="100%"><defs><pattern id="st" width="46" height="46" patternUnits="userSpaceOnUse">'
            '<path d="M23 4l5.5 13.5L42 23l-13.5 5.5L23 42l-5.5-13.5L4 23l13.5-5.5z" fill="none" stroke="#fff" stroke-width="1"/>'
            '</pattern></defs><rect width="100%" height="100%" fill="url(#st)"/></svg>')

def home(theme, playing=False, tall=False, state='mulai'):
    # horizon salat — contoh jam (di aplikasi dari PrayerService)
    prayers = [('Subuh', '04:22'), ('Dzuhur', '11:42'), ('Ashar', '14:50'), ('Maghrib', '17:49'), ('Isya', '18:58')]
    pos = [0, 25, 50, 75, 100]
    now_frac = 0 + 25 * (373 / 440)  # 10:35 di antara Subuh & Dzuhur
    nodes = ''.join(f'<div class="n {"past" if i == 0 else ("next" if i == 1 else "")}" style="left:{p}%"></div>' for i, p in enumerate(pos))
    lbls = ''.join(f'<div class="{"next" if i == 1 else ""}">{n}<span>{t}</span></div>' for i, (n, t) in enumerate(prayers))
    hz = (f'<div class="hz"><div class="top"><b><em>Berikutnya</em>Dzuhur 11:42</b><span class="pill">1 j 7 m lagi</span></div>'
          f'<div class="trk"><div class="ln"></div><div class="ln past" style="width:{now_frac:.1f}%"></div>{nodes}'
          f'<div class="now" style="left:{now_frac:.1f}%"></div></div><div class="lbls">{lbls}</div></div>')

    steps_lbl = ['Ulang', 'Baru', 'Ayat', 'Tirukan', 'Selesai']
    sn = ''.join(f'<div class="n{" cur" if i == 0 else ""}" style="left:{i*25}%"></div>' for i in range(5))
    sl = ''.join(f'<span class="{"cur" if i == 0 else ""}">{s}</span>' for i, s in enumerate(steps_lbl))
    listen = (f'<div class="ico">{fill_ic("eq", 16)}</div>' if playing else mihrab(34, 42, FATIHAH, fs=9, inner=False))
    ns = (f'<div class="ns">{STAR_PAT}<div class="top"><span class="eyebrow">Langkah berikutnya</span><span class="tm">±10 mnt</span></div>'
          '<h2>Sesi hari ini</h2><p>Langkah 1 dari 5 · Pemanasan, ulang 4 soal</p>'
          f'<div class="steps"><div class="ln"></div>{sn}</div><div class="slb">{sl}</div>'
          f'<div class="cta">{fill_ic("play", 16)} Mulai sesi</div>'
          f'<div class="alt"><div class="a">{listen}<div class="tx"><small>{"Diputar" if playing else "Baca"}</small><b>Al-Fatihah · ayat 3</b></div>{ic("chevr", 16, 2)}</div>'
          f'<div class="a"><div class="ico">{ic("layers", 18)}</div><div class="tx"><small>Murajaah</small><b>An-Naba\' 1 · 1 ayat</b></div>{ic("chevr", 16, 2)}</div></div></div>')

    rg = rings([(0.0, 'primaryText'), (0.0, 'gold'), (0.0, 'teal')])
    days = [('S', ''), ('S', ''), ('R', ''), ('K', ''), ('J', 'td'), ('S', ''), ('M', '')]
    ds = ''.join(f'<div class="{"t" if c == "today" else ""}"><i class="{c}"></i>{d}</div>' for d, c in days)
    today = (f'<div class="sect">HARI INI <a>Progres</a></div><div class="today"><div class="grid">{rg}<div class="lg">'
             '<div class="r"><i style="background:var(--primaryText)"></i><span>Baca</span><b>0<small>/5 mnt</small></b></div>'
             '<div class="r"><i style="background:var(--gold)"></i><span>Sesi</span><b>0<small>/5 langkah</small></b></div>'
             '<div class="r"><i style="background:var(--teal)"></i><span>Murajaah</span><b>0<small>/1 ayat</small></b></div>'
             '</div></div><div class="hint">Hari pertama. Lima menit membaca sudah cukup untuk mulai.</div>'
             f'<div class="week"><div class="st">{ic("flame", 18)} 0 hari</div><div class="ds">{ds}</div></div></div>')

    pl = dict(ayah=3, total=7, p=40, title='Al-Fatihah · Ayat 3', sub='Hudhaify · per ayat') if playing else None
    body = (status('10:35') +
            f'<div class="hdr"><div class="d"><b>Jumat, 2 Oktober</b><span>21 Rabiulakhir 1448 H</span></div>'
            f'<div class="row" style="gap:10px"><div class="circle">{ic("search", 20)}</div><div class="circle">{ic("bookmark", 20)}</div></div></div>'
            '<div class="greet"><span>Assalamu\'alaikum,</span><h1>Zainul</h1></div>' + hz + ns + today +
            ('' if tall else dock(0, pl)) + '<div class="home-ind"></div>')
    if tall:
        body = body.replace('<div class="home-ind"></div>', '')
    return page(theme, body, HOME_CSS, tall)

# =====================================================================
# MUROTTAL v6
# =====================================================================
PLAYER_CSS = """
.ptop{display:flex;align-items:center;justify-content:space-between;padding:4px 20px 0}
.ptop .c{text-align:center}
.ptop .c .eyebrow{color:var(--sec);font-size:10.5px}
.ptop .c b{display:block;font-size:17px;font-weight:800;margin-top:1px}
.chips{display:flex;justify-content:space-between;align-items:center;padding:14px 20px 4px}
.qari{white-space:nowrap;display:flex;align-items:center;gap:8px;padding:5px 12px 5px 5px;border-radius:999px;background:var(--surf);border:1px solid var(--hair);font-weight:800;font-size:13px;box-shadow:var(--cardShadow)}
.qari .av{width:28px;height:28px;border-radius:50%;background:var(--primary);color:var(--surf);display:grid;place-items:center;font-size:12px;font-weight:800}
.qari em{font-style:normal;color:var(--sec);font-weight:600}
.seg{display:flex;padding:3px;border-radius:999px;background:var(--surf2);font-size:12.5px;font-weight:800}
.seg span{padding:6px 12px;border-radius:999px;color:var(--sec)}
.seg span.on{background:var(--surf);color:var(--ink);box-shadow:0 1px 3px rgba(0,0,0,.08)}
.list{position:absolute;left:0;right:0;top:150px;bottom:0;overflow:hidden;padding:0 20px}
.list .fadeTop{position:absolute;left:0;right:0;top:0;height:34px;background:linear-gradient(var(--bg),rgba(0,0,0,0));z-index:2}
.ay{padding:14px 16px;border-radius:22px;margin-bottom:6px;position:relative}
.ay .ar{font-family:'AmiriQuran';direction:rtl;text-align:right;font-size:25px;line-height:2.15;color:var(--sec)}
.ay .tr{font-size:13.5px;line-height:1.55;color:var(--sec);margin-top:4px;font-weight:500}
.ay .no{display:inline-grid;place-items:center;width:26px;height:26px;border-radius:50%;border:1.6px solid var(--ter);font-size:11px;font-weight:800;color:var(--sec);margin-bottom:2px}
.ay.on{background:var(--surf);box-shadow:var(--cardShadow);border:1.5px solid var(--primarySoft)}
.ay.on .ar{color:var(--ink);font-size:29px}
.ay.on .tr{color:var(--ink);font-size:14px}
.ay.on .no{border-color:var(--gold);color:var(--goldText);background:var(--goldSoft)}
.ay .now{position:absolute;left:16px;top:16px;display:flex;align-items:center;gap:6px;font-size:11px;font-weight:800;color:var(--primaryText);letter-spacing:.6px}
.panel{position:absolute;left:0;right:0;bottom:0;background:var(--surf);border-radius:30px 30px 0 0;padding:16px 22px 34px;z-index:3;
  box-shadow:0 -10px 30px rgba(0,0,0,.08);border-top:1px solid var(--hair)}
.panel .lbl{display:flex;justify-content:space-between;font-size:13px;font-weight:800}
.panel .lbl span{color:var(--sec);font-weight:600;font-variant-numeric:tabular-nums}
.segs{display:flex;gap:4px;margin:10px 0 4px}
.segs i{flex:1;height:7px;border-radius:4px;background:var(--surf2)}
.segs i.done{background:var(--primaryText)}
.segs i.cur{background:linear-gradient(90deg,var(--gold) var(--p),var(--surf2) var(--p));box-shadow:0 0 0 3px var(--goldSoft)}
.tp{display:flex;align-items:center;justify-content:space-between;margin-top:14px}
.sm{display:flex;flex-direction:column;align-items:center;gap:4px;font-size:10.5px;font-weight:800;color:var(--sec);width:66px;white-space:nowrap}
.sm .b{width:46px;height:46px;border-radius:50%;display:grid;place-items:center;background:var(--bg);color:var(--ink);position:relative}
.sm .b.on{background:var(--goldSoft);color:var(--goldText)}
.sm .b sup{position:absolute;right:2px;top:2px;min-width:17px;height:17px;border-radius:9px;background:var(--gold);color:#1F1A08;font-size:10px;font-weight:800;display:grid;place-items:center;padding:0 4px}
.nav{width:52px;height:52px;display:grid;place-items:center;color:var(--ink)}
.play{width:78px;height:78px;border-radius:50%;background:var(--primary);color:var(--surf);display:grid;place-items:center;box-shadow:0 10px 24px rgba(0,53,39,.28),inset 0 1px 0 rgba(255,255,255,.18)}
.acts{display:flex;gap:8px;margin-top:16px}
.acts div{flex:1;height:44px;border-radius:22px;border:1px solid var(--hair);background:var(--bg);display:flex;align-items:center;justify-content:center;gap:6px;font-size:13px;font-weight:800;color:var(--ink);white-space:nowrap}
.acts div em{font-style:normal;color:var(--sec);font-weight:700}
"""

def murottal(theme):
    def card(a, on=False):
        now = (f'<div class="now">{fill_ic("eq", 13)} DIPUTAR</div>' if on else '')
        return (f'<div class="ay{" on" if on else ""}">{now}<div style="text-align:right"><span class="no">{a}</span></div>'
                f'<div class="ar">{html.escape(ayah(1, a))}</div><div class="tr">{html.escape(ID[(1, a)])}</div></div>')
    segs = ''.join('<i class="done"></i>' if i < 4 else (f'<i class="cur" style="--p:20%"></i>' if i == 4 else '<i></i>') for i in range(7))
    body = (status('10:32', 91) +
            f'<div class="ptop"><div class="circle">{ic("chev", 20)}</div><div class="c"><div class="eyebrow">Murottal · per ayat</div><b>Al-Fatihah</b></div>'
            f'<div class="circle">{fill_ic("more", 20)}</div></div>'
            f'<div class="chips"><div class="qari"><span class="av">H</span>Hudhaify{ic("chev", 14, 2.2)}</div>'
            '<div class="seg"><span class="on">Teks</span><span>Sampul</span></div></div>'
            f'<div class="list"><div class="fadeTop"></div>{card(4)}{card(5, True)}{card(6)}{card(7)}</div>'
            f'<div class="panel"><div class="lbl">Ayat 5 dari 7<span>0:01 / 0:06</span></div><div class="segs">{segs}</div>'
            f'<div class="tp"><div class="sm"><div class="b">{ic("repeat", 20)}</div>Ulang</div>'
            f'<div class="nav">{fill_ic("prev", 26)}</div><div class="play">{fill_ic("pause", 30)}</div>'
            f'<div class="nav">{fill_ic("next", 26)}</div><div class="sm"><div class="b" style="font-weight:800;font-size:14px">1×</div>Kecepatan</div></div>'
            f'<div class="acts"><div>{ic("timer", 17)} Timer</div><div>{ic("download", 17)} Unduh</div><div>{ic("range", 17)} 1–7</div></div>'
            '</div><div class="home-ind" style="z-index:4"></div>')
    return page(theme, body, PLAYER_CSS)

# =====================================================================
# KOMPONEN & STATUS (lembar lebar)
# =====================================================================
def components(theme):
    css = HOME_CSS + PLAYER_CSS + """
.sheet{width:1180px;padding:36px 40px 48px;background:var(--bg)}
.sheet h3{font-size:13px;font-weight:800;letter-spacing:1.4px;color:var(--sec);text-transform:uppercase;margin:26px 0 12px}
.sheet h3:first-child{margin-top:0}
.cols{display:flex;gap:20px;align-items:flex-start}
.cell{width:350px;flex:none}
.cell .cap{font-size:12.5px;color:var(--sec);font-weight:600;margin-top:8px;line-height:1.45}
.cell .cap b{color:var(--ink)}
.mini .ns{margin:0}
.dockbox{position:relative;height:150px;border-radius:24px;overflow:hidden;
  background:linear-gradient(160deg,var(--heroA),var(--heroB) 40%,var(--bg) 40.5%)}
.dockbox .stripes{position:absolute;inset:0;background:repeating-linear-gradient(90deg,transparent 0 26px,rgba(201,161,59,.35) 26px 30px)}
.dockbox .dock{bottom:14px}
.today.mini{margin:0}
"""
    def ns_variant(eyebrow, title, sub, cta, alts, extra=''):
        a = ''.join(f'<div class="a"><div class="ico">{ic(i, 18)}</div><div class="tx"><small>{s}</small><b>{b}</b></div>{ic("chevr", 16, 2)}</div>' for i, s, b in alts)
        return (f'<div class="ns">{STAR_PAT}<div class="top"><span class="eyebrow">{eyebrow}</span><span class="tm">{extra}</span></div>'
                f'<h2 style="font-size:27px">{title}</h2><p>{sub}</p><div class="cta">{fill_ic("play", 16)} {cta}</div>'
                f'<div class="alt">{a}</div></div>')
    v1 = ns_variant('Langkah berikutnya', 'Lanjutkan sesi', 'Langkah 3 dari 5 · Temukan di ayat', 'Lanjutkan',
                    [('book2', 'Baca', 'Al-Fatihah · 3'), ('layers', 'Murajaah', "An-Naba' 1 · 1 ayat")], '±6 mnt')
    v2 = ns_variant('Langkah berikutnya', "Murajaah An-Naba' 1–10", '10 ayat jatuh tempo · 2 hari terlewat', 'Mulai murajaah',
                    [('cap', 'Sesi hari ini', 'Belum dimulai · ±10 mnt'), ('book2', 'Baca', 'Al-Mulk · 12')], '10 ayat')
    v3 = ns_variant('Langkah berikutnya', 'Al-Kahf · ayat 23', 'Sesi selesai ✓ · murajaah tuntas · 3 mnt lagi ke target', 'Lanjut membaca',
                    [('head', 'Dengar', 'Murottal mulai ayat 23'), ('cap', 'Sesi besok', 'Tanwin · bagian 2')], 'Hal. 296')
    def tcard(vals, nums, hint, streak, on):
        days = ['S', 'S', 'R', 'K', 'J', 'S', 'M']
        ds = ''.join(f'<div class="{"t" if i == 4 else ""}"><i class="{"on" if i < on else ("td" if i == 4 else "")}"></i>{d}</div>' for i, d in enumerate(days))
        rows = ''.join(f'<div class="r"><i style="background:var(--{c})"></i><span>{l}</span><b>{n}</b></div>' for (l, c), n in
                       zip([('Baca', 'primaryText'), ('Sesi', 'gold'), ('Murajaah', 'teal')], nums))
        h = f'<div class="hint">{hint}</div>' if hint else ''
        return (f'<div class="today mini"><div class="grid">{rings(vals, 96)}<div class="lg">{rows}</div></div>{h}'
                f'<div class="week"><div class="st">{ic("flame", 18)} {streak}</div><div class="ds">{ds}</div></div></div>')
    t1 = tcard([(0, 'primaryText'), (0, 'gold'), (0, 'teal')], ['0<small>/5 mnt</small>', '0<small>/5</small>', '0<small>/1</small>'],
               'Hari pertama. Lima menit membaca sudah cukup untuk mulai.', '0 hari', 0)
    t2 = tcard([(.6, 'primaryText'), (.4, 'gold'), (0, 'teal')], ['3<small>/5 mnt</small>', '2<small>/5</small>', '0<small>/10</small>'],
               None, '4 hari', 4)
    t3 = tcard([(1, 'primaryText'), (1, 'gold'), (1, 'teal')], ['7<small>/5 mnt</small>', '5<small>/5</small>', '10<small>/10</small>'],
               'Semua target hari ini tercapai. Alhamdulillah.', '5 hari', 5)
    idle = '<div class="dockbox"><div class="stripes"></div>' + dock(1) + '</div>'
    play = ('<div class="dockbox" style="height:210px"><div class="stripes"></div>' +
            dock(0, dict(ayah=5, total=7, p=20, title='Al-Fatihah · Ayat 5', sub='Hudhaify · per ayat')) + '</div>')
    long_ = ('<div class="dockbox" style="height:210px"><div class="stripes"></div>' +
             dock(3, dict(ayah=1, total=60, p=0, title="An-Naba' · Ayat 12", sub='Rentang 1–20 · 2/3')).replace(
                 '<div class="npTrack">', '<div class="npTrack" data-long>') + '</div>')
    # rentang panjang: bar kontinu
    long_ = re.sub(r'<div class="npTrack" data-long>.*?</div>', '<div class="npTrack"><i class="cur" style="--p:30%"></i></div>', long_, flags=re.S)
    body = (f'<div class="sheet">'
            '<h3>Kartu Langkah Berikutnya — keluaran NextStepEngine</h3>'
            f'<div class="cols"><div class="cell mini">{v1}<div class="cap"><b>Sesi sedang berjalan</b> selalu menang (lanjutkan lebih penting daripada mulai baru).</div></div>'
            f'<div class="cell mini">{v2}<div class="cap"><b>Titik mulai hafalan</b> + ada murajaah jatuh tempo → murajaah jadi langkah utama.</div></div>'
            f'<div class="cell mini">{v3}<div class="cap"><b>Sesi & murajaah beres</b> → kembali ke bacaan terakhir; pilihan lain = dengar & materi besok.</div></div></div>'
            '<h3>Kartu Hari ini — kosong · sebagian · penuh</h3>'
            f'<div class="cols"><div class="cell">{t1}</div><div class="cell">{t2}</div><div class="cell">{t3}</div></div>'
            '<h3>Dock — satu permukaan kaca: tab saja · tab + sedang diputar · rentang panjang</h3>'
            f'<div class="cols"><div class="cell">{idle}<div class="cap"><b>Diam:</b> lensa tab aktif meluncur (pegas v4). Isi di belakang terlihat samar.</div></div>'
            f'<div class="cell">{play}<div class="cap"><b>Diputar:</b> dock memanjang ke atas 64 → 128. Geser atas = pemutar penuh, geser bawah = hentikan + Urungkan.</div></div>'
            f'<div class="cell">{long_}<div class="cap"><b>&gt; 40 ayat dalam antrean:</b> segmen diganti bar kontinu supaya tidak berupa garis rapat.</div></div></div>'
            '</div>')
    return (f'<!doctype html><html lang="id"><head><meta charset="utf-8"><style>{FONTS}{vars_css(theme)}{BASE_CSS}{css}</style></head>'
            f'<body>{body}</body></html>')

PAGES = {
 'V6-Beranda': lambda: home('light'),
 'V6-Beranda-Gelap': lambda: home('dark'),
 'V6-Beranda-Diputar': lambda: home('light', playing=True),
 'V6-Beranda-Penuh': lambda: home('light', tall=True),
 'V6-Murottal': lambda: murottal('light'),
 'V6-Murottal-Gelap': lambda: murottal('dark'),
 'V6-Komponen': lambda: components('light'),
 'V6-Komponen-Gelap': lambda: components('dark'),
}

if __name__ == '__main__':
    from playwright.sync_api import sync_playwright
    for name, fn in PAGES.items():
        (OUT / 'html' / f'{name}.html').write_text(fn(), encoding='utf-8')
    with sync_playwright() as p:
        b = p.chromium.launch()
        for name in PAGES:
            wide = name.startswith('V6-Komponen')
            pg = b.new_page(viewport={'width': 1180 if wide else 390, 'height': 844}, device_scale_factor=2)
            pg.goto((OUT / 'html' / f'{name}.html').as_uri())
            pg.wait_for_timeout(400)
            full = wide or name.endswith('Penuh')
            target = pg.locator('.sheet' if wide else '.phone')
            target.screenshot(path=str(OUT / 'screens' / f'{name}.png'))
            pg.close()
        b.close()
    print('ok')
