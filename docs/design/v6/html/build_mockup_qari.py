"""Mockup pemilih qari v6.1 — memakai gaya & font dari build.py v6."""
import importlib.util, json, pathlib, html
HERE = pathlib.Path(__file__).parent
spec = importlib.util.spec_from_file_location('b', HERE / 'build_mockup.py')  # dari paket v6
b = importlib.util.module_from_spec(spec); spec.loader.exec_module(b)
CAT = json.load(open(HERE.parents[3] / 'assets/audio/qari_katalog.json', encoding='utf-8'))
SRC = CAT['sumber']
def granted(q):
    return any(SRC[s['sumber']]['status'] == 'granted' for s in q['sumber'])

CSS = """
.top{display:flex;align-items:center;justify-content:space-between;padding:6px 20px 0}
.top b{font-size:17px;font-weight:800}
.search{margin:14px 20px 0;height:44px;border-radius:22px;background:var(--surf);border:1px solid var(--hair);display:flex;align-items:center;gap:10px;padding:0 14px;color:var(--sec);font-size:14px;font-weight:600}
.chips{display:flex;gap:8px;padding:12px 20px 4px;overflow:hidden;white-space:nowrap}
.chip{padding:8px 13px;border-radius:999px;background:var(--surf);border:1px solid var(--hair);font-size:13px;font-weight:700;color:var(--ink);flex:none}
.chip.on{background:var(--primary);color:var(--surf);border-color:var(--primary)}
.sec{padding:16px 20px 8px;font-size:12px;font-weight:800;letter-spacing:1.4px;color:var(--sec);display:flex;justify-content:space-between}
.sec span{letter-spacing:0;font-weight:600}
.grp{margin:0 20px;border-radius:22px;background:var(--surf);border:1px solid var(--hair);overflow:hidden}
.q{display:flex;align-items:center;gap:12px;padding:10px 12px 10px 14px;min-height:64px}
.q+.q{border-top:1px solid var(--hair)}
.av{width:40px;height:40px;border-radius:50%;display:grid;place-items:center;font-weight:800;font-size:14px;flex:none;background:var(--primarySoft);color:var(--primaryText)}
.q.sel .av{background:var(--primary);color:var(--surf)}
.q .tx{flex:1;min-width:0}
.q .tx b{display:block;font-size:14.5px;font-weight:800;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.q .tx span{display:flex;gap:6px;align-items:center;font-size:12px;color:var(--sec);font-weight:600;margin-top:2px;white-space:nowrap;overflow:hidden}
.tag{font-style:normal;flex:none;font-size:10.5px;font-weight:800;padding:2px 7px;border-radius:999px;background:var(--goldSoft);color:var(--goldText)}
.tag.p{background:var(--surf2);color:var(--sec)}
.pv{width:40px;height:40px;border-radius:50%;display:grid;place-items:center;background:var(--bg);color:var(--ink);flex:none}
.ck{color:var(--primaryText);flex:none}
.debug{margin:14px 20px 0;padding:10px 12px;border-radius:14px;background:var(--goldSoft);color:var(--goldText);font-size:12.5px;font-weight:700}
"""
TAGLBL = {'tenang': 'Adem', 'merdu': 'Merdu', 'hafalan': 'Hafalan', 'belajar': 'Belajar', 'imam_dua_masjid': 'Haramain', 'populer': 'Populer'}
def init(n):
    w = [x.split('-')[-1] for x in n.split('(')[0].split() if x[0].isalpha()]
    return (w[0][0] + w[-1][0]).upper() if len(w) > 1 else w[0][:2].upper()

def row(q, sel=False, pending=False):
    tags = [t for t in q['suasana'] if t != 'populer'][:1]
    tg = ''.join(f'<i class="tag">{TAGLBL[t]}</i>' for t in tags)
    if pending:
        tg = '<i class="tag p">MENUNGGU IZIN</i>'
    sub = q["gaya"].capitalize() if pending else f'{q["gaya"].capitalize()} · {q["negara"]}'
    right = (f'<div class="ck">{b.ic("check", 22, 2.4)}</div>' if sel else f'<div class="pv">{b.fill_ic("play", 16)}</div>')
    return (f'<div class="q{" sel" if sel else ""}"><div class="av">{init(q["nama"])}</div><div class="tx"><b>{html.escape(q["nama"])}</b>'
            f'<span>{sub}{tg}</span></div>{right}</div>')

def page(theme, debug=False):
    by = {q['id']: q for q in CAT['qari']}
    filt = 'tenang'
    chips = ''.join(f'<span class="chip{" on" if k == filt else ""}">{v if k != "imam_dua_masjid" else "Haramain"}</span>'
                    for k, v in [('semua', 'Semua'), ('tenang', 'Adem'), ('populer', 'Populer'), ('hafalan', 'Hafalan'), ('merdu', 'Merdu'), ('imam_dua_masjid', '')])
    vis = [q for q in CAT['qari'] if (granted(q) or debug) and filt in q['suasana'] and q['id'] != 'hudhaify']
    if debug:
        vis.sort(key=lambda q: (granted(q), q['nama']))
    rows = ''.join(row(q, pending=not granted(q)) for q in vis[:7])
    body = (b.status('10:41', 88) +
            f'<div class="top"><div class="circle">{b.ic("chev", 20)}</div><b>Pilih qari</b><div style="width:40px"></div></div>'
            f'<div class="search">{b.ic("search", 18)}Cari nama qari</div><div class="chips">{chips}</div>'
            + ('<div class="debug">Build debug: qari dari sumber yang belum berizin ikut tampil. Di build rilis mereka tersembunyi.</div>' if debug else '')
            + f'<div class="sec">DIPILIH</div><div class="grp">{row(by["hudhaify"], sel=True)}</div>'
            f'<div class="sec">ADEM · {len(vis)} QARI<span>{"semua sumber" if debug else "berizin"}</span></div><div class="grp">{rows}</div>'
            '<div class="home-ind"></div>')
    return b.page(theme, body, CSS)

if __name__ == '__main__':
    from playwright.sync_api import sync_playwright
    out = HERE.parent / 'screens'; out.mkdir(parents=True, exist_ok=True)
    hdir = HERE; hdir.mkdir(parents=True, exist_ok=True)
    pages = {'V6-Qari': page('light'), 'V6-Qari-Debug-Gelap': page('dark', debug=True)}
    with sync_playwright() as p:
        br = p.chromium.launch()
        for n, h in pages.items():
            f = HERE / f'{n}.html'; f.write_text(h, encoding='utf-8')
            pg = br.new_page(viewport={'width': 390, 'height': 844}, device_scale_factor=2)
            pg.goto(f.as_uri()); pg.wait_for_timeout(300)
            pg.locator('.phone').screenshot(path=str(out / f'{n}.png')); pg.close()
        br.close()
    print('ok')
