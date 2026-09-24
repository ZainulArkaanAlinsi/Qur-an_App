# Cara pakai paket desain v2 dengan Claude Code

## Kenapa hasil sebelumnya meleset

Dari screenshot HP-mu:

- **Nama surah turun huruf per huruf** (Hafalan & Belajar). Teks di baris tidak dibungkus `Expanded`, jadi tertekan oleh pill status.
- **Tab terpotong** ("Beran…", "Penga…"). Ada 5 tab plus tombol cari; tidak muat di 390 dp.
- **Pintasan & tombol terpotong** ("Sur… Bel… Bo… Kh…", "Dengark…").
- **Bulan Hijriah dobel** ("…1448 Rabī' al-t…").
- **Teks di kartu langit Salat terpotong di atas lengkung**, dan "Magh…" terpotong.
- **Akademi Tajwid & Hafalan masih memakai Material mentah** (AppBar, FAB hijau mint).

Akar masalahnya: Claude Code menulis kode tanpa **melihat hasilnya dan membandingkannya dengan gambar acuan**. Karena itu paket ini menambahkan:

1. `CLAUDE.md` di root repo, berisi aturan tetap yang dibaca setiap sesi. Termasuk aturan baris list dan larangan label terpotong.
2. `docs/design/v2/DESIGN.md`, berisi sistem desain.
3. `docs/design/v2/screens/NN-*.md`: satu file per layar dengan format **Tujuan · Tata letak · Konten · Batasan · Selesai jika**, ditambah PNG & HTML acuan.
4. **Loop verifikasi visual** lewat golden test: Claude Code membuat screenshot layar dari kode, membuka PNG-nya, lalu membandingkannya dengan acuan.

## Langkah pemasangan

1. Ekstrak ZIP ke root repo. Isinya:
   - `CLAUDE.md` (gabungkan dengan yang lama; bagian graphify sudah ada di dalamnya).
   - `docs/design/v2/`.
   - `test/golden/README.md`.
2. Commit dulu dengan pesan `docs: paket desain v2`, supaya Claude Code selalu membaca versi yang sama.
3. Jalankan `claude` di root repo.

## Urutan prompt (satu layar per sesi)

### Prompt 0 — sekali di awal

```text
Baca CLAUDE.md, docs/design/v2/DESIGN.md, dan semua file di docs/design/v2/screens/
(buka juga PNG-nya). Jangan menulis kode dulu. Buat rencana:
1) komponen di DESIGN.md §4 yang belum ada di lib/app/widgets/,
2) setup golden test: muat font asli, ukuran 390×844 & 844×390, terang & gelap,
3) urutan layar 01→14.
Sebutkan juga bagian kode sekarang yang melanggar aturan CLAUDE.md, beserta file
dan barisnya. Tunggu persetujuan saya.
```

### Prompt 1 — fondasi

```text
Kerjakan rencana bagian 1 & 2: komponen dasar + infrastruktur golden test.
Buat golden untuk tiap komponen, terang & gelap. Buka PNG hasilnya lalu bandingkan
dengan potongan komponen yang sama di docs/design/v2/screens/. Laporkan selisih yang
tersisa.
```

### Prompt per layar (ulangi untuk 01 sampai 14)

```text
Kerjakan layar docs/design/v2/screens/<NN-nama>.md.
1. Baca md-nya dan buka PNG acuannya.
2. Implementasikan pakai token & komponen (tanpa warna hardcode, tanpa Material mentah).
3. Buat golden test/golden/<nn>_<nama>_test.dart (terang & gelap, text scale 1.0 dan 2.0).
4. Jalankan flutter test --update-goldens untuk file itu, buka PNG hasilnya, bandingkan
   dengan acuan, lalu tulis tabel selisih (elemen | acuan | hasil | tindakan).
5. Perbaiki sampai selisihnya hanya karena data nyata.
6. flutter analyze & flutter test harus bersih.
Laporkan dengan menyertakan path PNG acuan dan PNG hasil.
```

### Prompt kalau masih meleset

```text
Hasil <layar> belum sama dengan acuan. Buka lagi test/golden/goldens/<file>.png dan
docs/design/v2/screens/<acuan>.png. Ukur selisihnya: margin, ukuran font, tinggi baris,
radius, urutan elemen, dan teks yang terpotong. Perbaiki SATU per SATU sesuai
DESIGN.md. Jangan mengubah desain sendiri.
```

## Tentang "Claude Design"

Kanvas tempat mockup ini dibuat adalah fitur desain di Claude. Kamu bisa membuka, mengomentari, dan menyunting artboard-nya langsung. Claude Code tidak bisa membuka kanvas itu, jadi **PNG + HTML di folder ini adalah jembatannya**. Setiap kali desain di kanvas berubah, minta Claude mengekspor ulang PNG/HTML ke folder ini.

Tips dari praktik yang kamu kutip tetap berlaku:

- **Referensi visual:** sudah ada di `screens/*.png`.
- **Brief/sistem desain:** `DESIGN.md`.
- **Prompt terstruktur Tujuan–Tata letak–Konten–Batasan:** sudah ada di tiap `screens/*.md`.

Yang paling berpengaruh justru langkah keempat: **menyuruh Claude Code melihat hasil kodenya sendiri**.
