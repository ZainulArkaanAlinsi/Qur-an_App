# Video promo MyQuran

Video listing Play Store berdurasi 20 detik (1920×1080, 30 fps, H.264 + AAC). Semua
layar aplikasi diambil dari golden test asli di `test/golden/goldens/`. Tidak ada UI
yang digambar ulang, dan teks ayat tampil apa adanya dari render aplikasi.

Folder ini terpisah dari aplikasi: tidak menyentuh `pubspec.yaml` dan tidak menambah
paket Flutter.

## Sekali saja

```
python -m venv --system-site-packages tool/promo/.venv
tool/promo/.venv/Scripts/python.exe -m pip install imageio-ffmpeg
```

`imageio-ffmpeg` membawa binary ffmpeg sendiri. numpy dan Pillow dipakai dari Python
sistem.

## Render

```
tool/promo/.venv/Scripts/python.exe tool/promo/render.py            # pad lembut + ketuk
tool/promo/.venv/Scripts/python.exe tool/promo/render.py --tenang   # tanpa pad: ketuk + desis halus
```

Hasilnya `tool/promo/out/myquran-promo.mp4`. Frame pengecekan (satu per detik) ada di
`tool/promo/out/frames/`.

## Video perkenalan (56 detik, YouTube + listing Play)

```
tool/promo/.venv/Scripts/python.exe tool/promo/render_intro.py --nasyid <berkas-nasyid.m4a>
tool/promo/.venv/Scripts/python.exe tool/promo/render_intro.py --preview 12,20,45   # PNG saja
```

Hasilnya `tool/promo/out/myquran-perkenalan.mp4`. Video ini memakai HP 3D, zoom dengan
penanda emas, teks per kata, transisi sapuan atau zoom, dan karosel 3D. Suaranya nasyid
(berkas dari pemilik) ditambah whoosh, swish, ketuk, dan pop buatan skrip, dinormalisasi ke
−14 LUFS.

Hak cipta nasyid ada di tangan pemiliknya. Tanpa izin, video bisa kena klaim Content ID di
YouTube. Tanpa `--nasyid`, video hanya berisi efek suara.

## Aturan isi

- Hanya fitur yang ada di build rilis 1.11.0: Beranda, Murottal, Waktu salat, pemilih
  qari, dan Sesi hari ini. Tidak menyebut tajwid tahap 6–16, qari `pending`, atau
  "resmi Kemenag".
- Suara dibuat dengan numpy: tanpa vokal, tanpa bacaan Qur'an, dan tanpa musik
  berhak cipta. Dinormalisasi ke −16 LUFS.
- Kalau golden berubah, render ulang supaya video tetap sama dengan aplikasi.
