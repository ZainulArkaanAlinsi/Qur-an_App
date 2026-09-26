# Rubrik audit liquid glass

Pakai rubrik ini untuk menjawab "sudah cukup liquid glass belum?" dengan angka. Ada 10 kriteria. Tiap kriteria diberi nilai 0, 1, atau 2 dan harus disertai bukti berupa berkas:baris, keluaran skrip, nama golden, atau angka tes. Nilai tanpa bukti dihitung 0.

**Lulus** kalau total ≥ 18/20, **tidak ada** kriteria bernilai 0, dan G6, G7, G8 masing-masing bernilai 2. Kalau belum lulus, perbaiki dulu kriteria dengan nilai terendah, lalu nilai ulang.

| # | Kriteria | 2 = beres | 1 = sebagian | 0 = belum |
| --- | --- | --- | --- | --- |
| G1 | **Lapisan lengkap** | Enam lapis §3 ada di satu komponen `LiquidGlass`. Bayangan di luar klip. | Blur + tint + salah satu dari tepi/kilau | Hanya blur + tint, atau bayangan terpotong klip |
| G2 | **Kaca terlihat hidup** | Backdrop terlihat 10–18%, tidak ada scrim padat di belakang kaca, warna hero atau gambar terlihat samar lewat tab bar di golden | Salah satu terpenuhi | Alfa tint > 60% atau ada scrim padat |
| G3 | **Gerak cair** | Lensa tab meluncur dengan pegas + regangan + efek tekan, nav pembaca sembunyi/muncul, tanpa ripple Material di kaca | Sebagian ada | Indikator berganti statis, ripple Material |
| G4 | **Konsisten** | Tab bar, nav pembaca, mini player, tombol mengambang, dan kepala sheet memakai `LiquidGlass`. Tidak ada warna mentah di chrome. | 1–2 komponen belum | ≥ 3 komponen belum atau memakai warna mentah |
| G5 | **Semua palet cocok** | Terang, gelap, sepia, dan kontras tinggi masing-masing punya token kaca dengan `lerp`. Kontras tinggi = padat. Golden keempat palet ada. | Token ada, golden belum lengkap | Kaca sama untuk semua palet atau tidak ada golden |
| G6 | **Teks di kaca terbaca** | Tes kontras lulus: ink ≥ 7, sec ≥ 4.5, primaryText ≥ 4.5 di semua latar terburuk §5, semua palet × tingkat | Lulus di latar biasa saja | Tidak ada tes, atau ada yang di bawah ambang |
| G7 | **Ayat terbaca** | Ayat di permukaan padat, tanpa efek di teks Arab, tajwid ≥ 4.5 di semua permukaan ayat, nav pembaca menyingkir saat membaca | Ada satu permukaan tajwid < 4.5 | Kaca di atas ayat, atau banyak permukaan < 4.5 |
| G8 | **Ringan** | `glass_audit.sh` bagian A lulus, ≤ 3 kaca terlihat, anggaran §7 lulus di HP asli | Audit statis lulus, tes kinerja belum dijalankan | Kaca per item daftar atau tanpa `BackdropGroup` |
| G9 | **Adaptif** | Tingkat penuh/ringan/padat, pengawas frame, pengaturan "Efek kaca", menghormati kontras tinggi & kurangi gerak | Sebagian | Tidak ada |
| G10 | **Terukur** | `glass_audit.sh` 0 GAGAL, tes kontras, golden, dan tes kinerja ada di repo serta dijalankan, dan hasilnya dicatat | Sebagian | Tidak ada |

## Cara menilai

1. Jalankan `bash tool/glass_audit.sh` dan salin keluarannya.
2. Jalankan `flutter test` (termasuk golden) dan `flutter analyze`.
3. Buka PNG golden dan lihat sendiri, jangan menebak:
   - Apakah tepi kaca terlihat menangkap cahaya di terang **dan** gelap?
   - Apakah warna hero hijau atau garis uji terlihat samar lewat tab bar?
   - Apakah label tab tidak aktif tetap jelas?
4. Kalau ada HP yang tersambung, jalankan tes kinerja dalam mode profile. Kalau tidak ada, G8 maksimal 1 dan tulis "belum diuji di HP".
5. Tulis hasilnya ke `docs/design/v4-liquid-glass/HASIL_AUDIT.md` dengan format:

```
## Audit <tanggal> — commit <sha>
| # | Nilai | Bukti |
| G1 | 2 | lib/app/glass/liquid_glass.dart:40-120; golden tab_bar_light_full.png |
...
Total: 17/20 — BELUM LULUS (G8 = 1: tes kinerja belum dijalankan di HP)
Perbaikan berikutnya: ...
```

## Audit awal: commit 9a8b258 (MyQuran 1.9.0), 25 Sep 2026

Dinilai dari kode di repo. Aplikasinya tidak dijalankan.

| # | Nilai | Bukti |
| --- | --- | --- |
| G1 | 0 | `lib/app/glass_surface.dart:36-60`: hanya blur σ14 + tint + satu garis tepi warna datar. Bayangan bawaan berada **di dalam** `ClipRRect` sehingga terpotong (dipakai `bookmark_screen.dart`). Tidak ada kilau, tepi bergradien, atau sorot dalam. |
| G2 | 0 | Tint 76% (`sacred_tokens.dart:145,185,226`), bawaan `GlassSurface` 86%. Tab bar berdiri di atas scrim `[tokens.bg, tokens.bg, …]` setinggi 140 (`sacred_controls.dart:305-313`), jadi yang diblur hanya warna latar polos dan kaca terlihat seperti kapsul datar. |
| G3 | 0 | Tab aktif = `Container` yang langsung berganti (`sacred_controls.dart:388-395`), tanpa luncuran atau pegas, dengan ripple `InkWell` Material di atas kaca. |
| G4 | 0 | Mini player memakai `SacredTheme.primaryContainer` + `Colors.white` mentah (`audio_mini_player.dart:51-177`), tidak berkaca, dan tidak ikut palet. Sheet memakai latar padat. Tombol mengambang belum memakai kaca yang sama. |
| G5 | 1 | Token kaca ada untuk 5 varian dan `lerp` ada, tapi belum ada golden per palet. Kontras tinggi masih memakai blur (alfa 94%). |
| G6 | 0 | Hitungan: `sec` di atas kaca hanya 3.32 (terang), 3.07 (gelap), 3.25 (sepia) pada latar terburuk. Belum ada tes. |
| G7 | 1 | Ayat sudah di permukaan padat (`reader_screen.dart:1685-1693`) dan kontras teks Arab 11–16 : 1. Tapi abu tajwid `#7A7A7A` hanya 3.54 di ayat aktif terang, 3.65 di sepia, dan mad wajib gelap 4.41–4.45. |
| G8 | 0 | `GlassSurface` dipakai per item di `ListView` penanda (`bookmark_screen.dart:40`). Tidak ada `BackdropGroup`. |
| G9 | 0 | Tidak ada tingkat kualitas, pengawas frame, atau pengaturan efek kaca. |
| G10 | 0 | Belum ada tes kontras kaca, golden kaca, atau tes kinerja. `glass_audit.sh`: 12 GAGAL. |

**Total: 2/20. Belum lulus.** Urutan perbaikan: G8 → G1/G2 → G6/G7 → G4 → G3 → G9 → G5/G10.
