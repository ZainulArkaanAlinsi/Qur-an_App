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

## Audit 2 Oktober 2026 — setelah fondasi (v6 Prompt 2 = v4 Prompt 0 + 1)

Dinilai dari kode, tes, dan golden. Tes kinerja belum dijalankan di HP.

`bash tool/glass_audit.sh`: **4 GAGAL, 1 CEK** (dari 12). Yang lulus: A1, A2, A3, A4, B1, B4, C1, C2. Masih gagal: B2 (scrim tab bar) dan B3 (warna mentah mini player), keduanya dikerjakan di Prompt 3 (Dock); C3 (pengawas frame) dan C4 (tes kinerja), keduanya di Prompt 9.

| # | Nilai | Bukti |
| --- | --- | --- |
| G1 | 2 | `lib/app/glass/liquid_glass.dart`: L0 bayangan digambar di luar bentuk (`_OutsideShadowPainter`), L1 `BackdropFilter.grouped` + `glassFilter`, L2/L3 `_FillPainter`, L4/L5 `_RimPainter` di `RepaintBoundary`. |
| G2 | 1 | Tint ≤ 60% dan backdrop terlihat 12,4% / 10,4% / 17,4% (terang/sepia/gelap; tes "backdrop yang terlihat 10–18%" di `test/glass_contrast_test.dart`). Scrim padat di belakang tab bar masih ada (B2, `sacred_controls.dart:311`). |
| G3 | 0 | Lensa tab belum meluncur, `InkWell` masih ada, nav pembaca belum menyingkir (Prompt 3 / jadwal terpisah). |
| G4 | 0 | Tab bar dan nav pembaca sudah `LiquidGlass`. Mini player (warna mentah, B3), tombol mengambang, dan kepala sheet belum. |
| G5 | 1 | `GlassTokens` untuk 5 palet, lengkap dengan `lerp` (`glass_tokens.dart`); kontras tinggi selalu padat (tes "kontras tinggi selalu padat"). Golden kaca sepia dan kontras tinggi belum ada. |
| G6 | 2 | `test/glass_contrast_test.dart`: 5 palet × 3 tingkat × 3 ukuran × 9 latar terburuk. ink ≥ 7, sec ≥ 4.5, primaryText ≥ 4.5 semuanya lulus. Tes penjaga: tint −10 poin → gagal. |
| G7 | 1 | Ayat tetap di permukaan padat dan tajwid ≥ 4.5 di semua permukaan. Nav pembaca belum menyingkir. |
| G8 | 1 | Audit bagian A lulus semua. Kaca terlihat: 1 di tab (tab bar), 1 di pembaca (nav). Anggaran kinerja §7: BELUM DIUKUR DI HP. |
| G9 | 1 | `GlassTier`/`GlassPreference`/`GlassScope` (`glass_tier.dart`); kontras tinggi (palet & sistem) → padat; kurangi gerak → paling tinggi ringan. Pengawas frame dan pengaturan "Efek kaca" belum ada. |
| G10 | 1 | Tes kontras kaca ada dan dijalankan (`flutter test`: 646 lulus). Audit masih 4 GAGAL. Golden kaca khusus dan tes kinerja belum ada. |

**Total: 10/20. Belum lulus.**

Golden yang diperbarui di langkah ini: 27 PNG dari 7 berkas tes (`components`, `01_beranda`, `02_mode_baca`, `05_kartu`, `08_belajar`, `10_hafalan`, `12_saya`). Semua PNG lama dan baru dibandingkan per piksel. Perubahannya hanya di zona tab bar (89,6–97,2% tinggi layar) atau nav pembaca (0–12,4%; teks 2.0 sampai 25,6% karena nav lebih tinggi). Tata letak, teks, dan ayat tidak berubah.

### Angka yang diganti dari LIQUID_GLASS.md §4

- **Tint sepia: 48%, bukan 42%.** Dengan 42%, `sec` sepia di atas kaca berlatar hitam hanya 4.41 (< 4.5). Dengan 48% hasilnya ink 8.93, sec 4.54, primaryText 6.71, persis baris sepia di tabel §5. Artinya tabel §5 memang dihitung dengan 48%, sedangkan 42% di tabel §4 tidak konsisten dengannya. Backdrop yang terlihat tetap 10,4%. Dikunci oleh tes "angka tabel §5 tingkat penuh".
- **Kontras tinggi: warna tepi.** `SacredTokens` tidak punya token `outline`, jadi dipakai warna outline tema kontras tinggi (`#3A3A3A` terang / `#9A9A9A` gelap, `sacred_theme.dart` `_recolor`), tebal 1.5 px.
- **Token lama `glass`/`glassBorder`**: ditandai `@Deprecated`, tidak dipakai lagi, dan nilainya disamakan dengan tint v4 supaya B1 lulus.

Perbaikan berikutnya: G3/G4/B2/B3 di Prompt 3 (Dock); nav pembaca menyingkir dan kepala sheet perlu dijadwalkan; G8/G9/G10 (pengawas frame, pengaturan Efek kaca, tes kinerja) di Prompt 9.
