# Hasil audit liquid glass v4

Rubrik: `AUDIT_RUBRIK.md`. Spesifikasi: `LIQUID_GLASS.md`. Nilai tanpa bukti dihitung 0.

## Catatan SDK

Dicek langsung di sumber SDK yang terpasang (2 Oktober 2026):
- Flutter 3.44.8 (stable, framework `058e0af2c2`), Dart 3.12.2.

| API | Tersedia | Bukti di SDK |
| --- | --- | --- |
| `BackdropGroup` | Ya | `packages/flutter/lib/src/widgets/basic.dart:469` |
| `BackdropFilter.grouped` + `enabled` | Ya | `basic.dart:672` (`this.enabled = true` di `:678`) |
| `ImageFilter.compose` | Ya | `bin/cache/pkg/sky_engine/lib/ui/painting.dart:4424` |
| `ColorFilter implements ImageFilter` | Ya | `painting.dart:4091` |
| `ClipRSuperellipse` | Ya | `basic.dart:1123` |

Semua API yang dibutuhkan §3 dan §7 tersedia, jadi tidak perlu jalan alternatif.

`BackdropFilter.grouped` tanpa `BackdropGroup` di atasnya akan memakai kunci `null` (`basic.dart:735`). Artinya ia berperilaku seperti `BackdropFilter` biasa dan tidak gagal. Meski begitu, setiap rute yang punya kaca tetap dipasangi `BackdropGroup`.

## Audit 2 Oktober 2026 — commit 5b661f4 (sebelum v4)

Commit 5b661f4 berisi kode MyQuran 1.10.0 ditambah dokumen v6. Penilaian dilakukan dari kode, tanpa menjalankan aplikasi.

`bash tool/glass_audit.sh`: **12 GAGAL, 1 CEK** (A1, A2, A3, B1, B2, B3, B4, C1, C2, C3, C4 gagal; A4 lulus; C5 = 5 pemakaian kaca di luar `lib/app/glass/`).

| # | Nilai | Bukti |
| --- | --- | --- |
| G1 | 0 | `lib/app/glass_surface.dart:36-60`: hanya blur σ14 + tint + garis tepi datar. Bayangan bawaan ada di dalam `ClipRRect` sehingga terpotong (dipakai `bookmark_screen.dart:40,150`). Tidak ada kilau, tepi bergradien, atau sorot dalam. |
| G2 | 0 | Tint 76% (`lib/app/sacred_tokens.dart:145,185,226`). Tab bar di atas scrim `[tokens.bg, tokens.bg, …]` setinggi 140 (`lib/app/widgets/sacred_controls.dart:305-314`). |
| G3 | 0 | Tab aktif berupa `Container` dengan dekorasi yang berganti (`sacred_controls.dart:390-392`) di bawah `InkWell` (`:387`). Tanpa luncuran atau pegas. Nav pembaca tidak pernah menyingkir. |
| G4 | 0 | Mini player memakai `SacredTheme.primaryContainer`/`gold` dan `Colors.white`/`black` mentah (`lib/widgets/audio_mini_player.dart:51-177`, temuan B3). Sheet memakai latar padat. Tombol mengambang belum memakai kaca yang sama. |
| G5 | 1 | Token `glass`/`glassBorder` ada untuk 5 varian, lengkap dengan `lerp` (`sacred_tokens.dart:145-146,185-186,226-227,269-270,310-311,423-424`). Belum ada golden kaca per palet. Kontras tinggi masih blur dengan alfa 95% (`:269,310`). |
| G6 | 0 | Belum ada tes kontras kaca (B4 gagal). Hitungan di §5: `sec` di atas kaca 3.32 (terang), 3.07 (gelap), 3.25 (sepia). |
| G7 | 1 | Ayat di permukaan padat. Tajwid sudah ≥ 4.5 di semua permukaan ayat sejak 1.9.1 (`test/tajweed_widget_test.dart:233-265` memeriksa kartu, latar, ayat aktif, dan ayat bertanda di semua palet). Nilainya tetap 1 karena nav pembaca (`reader_screen.dart:912`) tidak menyingkir saat membaca. |
| G8 | 0 | `GlassSurface` per item di `ListView` penanda (`bookmark_screen.dart:40`, temuan A3). Tidak ada `BackdropGroup` (A2). |
| G9 | 0 | Tidak ada tingkat kualitas, pengawas frame, atau pengaturan efek kaca (C1–C3). |
| G10 | 0 | Belum ada tes kontras kaca, golden kaca, dan tes kinerja (B4, C4). |

**Total: 2/20. Belum lulus.**

Nilainya sama dengan audit awal di rubrik (commit 9a8b258). Yang berbeda hanya alasan G7. Masalah tajwid (abu `#7A7A7A` 3.54 di ayat aktif) sudah diperbaiki di 1.9.1 (#33). Yang masih kurang tinggal nav pembaca yang tidak menyingkir.

Urutan perbaikan: G8 → G1/G2 → G6 → G4 → G3 → G9 → G5/G10.
