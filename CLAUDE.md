# CLAUDE.md — Qur'an App

Baca file ini setiap mulai sesi. Isinya aturan tetap proyek; detail ada di file yang dirujuk.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

## Sumber kebenaran (urut prioritas)

1. `QURAN_APP_GUIDE_DAN_PROMPT_CODEX.md` + `docs/RELIGIOUS_CONTENT_GOVERNANCE.md` — konten, data, streak, audio, keamanan. Selalu menang.
2. `docs/design/v2/DESIGN.md` — sistem desain (token, komponen, aturan tata letak).
   `docs/design/v3/DESIGN.md` — tambahan v3: logo MyQuran, ikon, splash, onboarding, materi nun sukun. Berlaku bersama v2.
3. `docs/design/v2/screens/NN-*.md` + `.png` dan `docs/design/v3/screens/15–18-*.md` + `.png` — spesifikasi & gambar acuan per layar. **Gambar acuan adalah target visual.** Kalau ragu, cocokkan ke PNG-nya.
4. `docs/revisi-v2/SPESIFIKASI_REVISI_V2.md`, `docs/revisi-v2/RISET_SUMBER.md` — fitur & sumber data.

## Aturan UI yang tidak boleh dilanggar

- Semua warna, radius, jarak, font dari `SacredTokens` / `SacredText`. Tidak ada `Color(0x…)`, `Colors.*`, `Theme.of(context).colorScheme` mentah di layar. Pengecualian hanya palet tajwid & ornamen mushaf yang punya file token sendiri.
- Tidak ada widget Material bawaan yang tampak mentah: `AppBar`, `FloatingActionButton`, `Card`, `ListTile`, `Chip`, `NavigationBar`. Pakai komponen `lib/app/widgets/` (LargeTitle, InsetGroupedList, SettingsRow, SegmentedPill, IosToggle, SacredCircleButton, MihrabClipper, RosetteBadge, dst.).
- **Baris list**: teks di tengah SELALU `Expanded` + `maxLines: 1` + `overflow: TextOverflow.ellipsis`; elemen kanan (pill/status/toggle) ukurannya intrinsik dan tidak boleh memakan ruang teks. Penyebab bug "nama surah turun huruf per huruf" adalah baris tanpa `Expanded`.
- **Label tidak boleh terpotong** di ukuran 390 dp dengan skala teks 1.0. Kalau tidak muat, ubah desain (ikon saja / label lebih pendek), bukan elipsis.
- Tab bar: 5 tab (Beranda, Qur'an, Belajar, Hafalan, Saya), tanpa tombol cari terpisah. Cari ada di header Beranda & Qur'an.
- Teks Arab: `SacredText.quran`, RTL, tanpa tinggi tetap, line-height ≥ 2.0, tidak pernah di-clip.
- Setiap layar punya versi terang & gelap yang lolos kontras (teks 4.5:1; teks Arab besar & warna tajwid 3:1).

## Aturan brand & onboarding (v3)

- Logo hanya dari `assets/brand/` lewat `Image.asset`, **utuh**: tidak digambar ulang, dipotong, diregangkan, atau diberi filter warna. Versi gelap dipilih lewat berkasnya sendiri. `logo_utama_asli*.png` hanya arsip.
- Nama tampilan aplikasi: **MyQuran**. Package id tidak diubah tanpa izin pemilik.
- Animasi hanya dengan API bawaan Flutter. Tanpa Lottie/Rive/aset animasi pihak ketiga. Hormati `MediaQuery.disableAnimationsOf`.
- Onboarding tampil sekali (`onboarding.selesai.v1`). Rumus gerak di DESIGN v3 §5c adalah spesifikasi, bukan saran.
- Semua font, paket, dan aset harus gratis dengan lisensi yang jelas (lihat `docs/design/v3/LISENSI_ASET.md`). Jangan menambah yang berbayar.

## Aturan konten

- Ayat & terjemahan hanya dari dataset berlisensi, verbatim, dengan atribusi & versi. Tidak diketik ulang, tidak dari AI, tidak dari mockup.
- Tidak ada doa/fadhilah/amalan tanpa dalil shahih; tidak ada amalan khas golongan. Materi belajar berstatus draf → 2 reviewer → terbit.
- Angka di mockup adalah contoh. Di aplikasi semuanya dari data nyata.

## Cara kerja wajib (loop verifikasi visual)

Untuk setiap layar yang dikerjakan:
1. Baca `docs/design/v2/screens/NN-*.md` dan **lihat PNG acuannya** (Read tool bisa membuka gambar).
2. Implementasikan pakai token & komponen.
3. Buat/perbarui golden test di `test/golden/` ukuran 390×844 (dan 844×390 untuk mushaf 2 halaman), font asli dimuat, terang + gelap.
4. Jalankan `flutter test --update-goldens test/golden/<file>` lalu **buka PNG hasilnya** dan bandingkan dengan acuan. Tulis daftar selisih (jarak, ukuran, warna, urutan, teks terpotong).
5. Perbaiki sampai selisihnya hanya karena data nyata. Ulangi di text scale 2.0.
6. Baru lapor selesai. Sertakan kedua gambar (acuan & hasil).

Jangan menandai layar selesai tanpa langkah 4.

## Perintah

```
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter test --update-goldens test/golden/
```

## Larangan

Jangan push, deploy, mengaktifkan layanan berbayar, menghapus fitur, atau mengganti state management tanpa izin pemilik.
