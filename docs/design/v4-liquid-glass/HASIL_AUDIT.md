# Hasil audit liquid glass v4

## Catatan SDK

Diperiksa langsung di sumber SDK (`flutter --version`: Flutter 3.44.8 stable, Dart 3.12.2,
engine 13ffd72b2f).

| API | Ada? | Bukti |
| --- | --- | --- |
| `BackdropGroup` | Ya | `packages/flutter/lib/src/widgets/basic.dart:469` |
| `BackdropFilter.grouped` + parameter `enabled` | Ya | `basic.dart:672-678` (`this.enabled = true`) |
| `ImageFilter.compose(outer:, inner:)` | Ya | `sky_engine/lib/ui/painting.dart:4424` |
| `ColorFilter` sebagai `ImageFilter` | Ya | `painting.dart:4091` (`class ColorFilter implements ImageFilter`) |
| `ClipRSuperellipse` | Ya | `basic.dart:1123` |

Tidak perlu alternatif: semua API di LIQUID_GLASS.md §3 dan §7 tersedia.

## Audit 25 September 2026 — commit 22be6ce (main)

Kode di `lib/` identik dengan 9a8b258 (`git diff --stat 9a8b258 main -- lib` kosong); sejak
itu hanya dokumen, aset Play Store, dan tool yang berubah. Nilai sama dengan audit awal di
rubrik.

`bash tool/glass_audit.sh`: **12 GAGAL**, 1 perlu dicek.

```
A1 GAGAL  BackdropFilter di luar lib/app/glass/: lib/app/glass_surface.dart:38
A2 GAGAL  BackdropFilter biasa (harus .grouped): lib/app/glass_surface.dart:38
A2 GAGAL  Tidak ada BackdropGroup di mana pun
A3 GAGAL  Kaca per item daftar: lib/screens/bookmark_screen.dart:40
A4 LULUS
B1 GAGAL  Alfa kaca 76%: lib/app/sacred_tokens.dart:145 (light), :185 (dark), :226 (sepia)
B2 GAGAL  Scrim padat: lib/app/widgets/sacred_controls.dart:311
B3 GAGAL  Warna mentah: lib/widgets/audio_mini_player.dart:51, 55, 62, 87, 136, 168, 169, 177
B4 GAGAL  Belum ada tes kontras kaca
C1 GAGAL  Belum ada tingkat kualitas
C2 GAGAL  Kaca belum membaca highContrast/disableAnimations
C3 GAGAL  Belum ada pengawas frame
C4 GAGAL  Belum ada integration_test kinerja
C5 CEK    5 pemakaian kaca: glass_surface.dart:8 (definisi), sacred_controls.dart:333 (tab bar),
          bookmark_screen.dart:40 (item daftar) dan :150 (keadaan kosong), reader_screen.dart:912 (nav)
```

| # | Nilai | Bukti |
| --- | --- | --- |
| G1 | 0 | `lib/app/glass_surface.dart:36-60`: blur + tint + satu garis tepi datar. Bayangan di dalam `ClipRRect` sehingga terpotong. Tidak ada kilau, tepi bergradien, atau sorot dalam. |
| G2 | 0 | Tint 76% (`sacred_tokens.dart:145,185,226`). Scrim padat `[tokens.bg, tokens.bg, …]` di belakang tab bar (`sacred_controls.dart:311`). |
| G3 | 0 | Tab aktif berupa `Container` yang langsung berganti, dengan ripple `InkWell` di atas kaca (`sacred_controls.dart`, `_TabButton`). |
| G4 | 0 | Mini player memakai `SacredTheme.primaryContainer` + `Colors.white` (`audio_mini_player.dart:51-177`). Sheet padat. Tombol mengambang belum memakai kaca yang sama. |
| G5 | 1 | Token `glass`/`glassBorder` ada untuk 5 varian beserta `lerp` (`sacred_tokens.dart`), tetapi golden per palet belum ada, dan kontras tinggi masih blur. |
| G6 | 0 | Belum ada tes kontras. Hitungan §5: `sec` di atas kaca 3.32 (terang), 3.07 (gelap), 3.25 (sepia). |
| G7 | 1 | Ayat di permukaan padat (`reader_screen.dart`, kartu ayat), tetapi abu tajwid `#7A7A7A` 3.54 di ayat aktif terang dan mad wajib gelap `#7F8CFF` 4.41–4.45. |
| G8 | 0 | Kaca per item daftar (`bookmark_screen.dart:40`), tanpa `BackdropGroup`. |
| G9 | 0 | Tidak ada tingkat kualitas, pengawas frame, atau pengaturan efek kaca. |
| G10 | 0 | `glass_audit.sh` 12 GAGAL. Belum ada tes kontras, golden kaca, atau tes kinerja. |

**Total: 2/20 — BELUM LULUS.**

Urutan perbaikan (mengikuti rubrik): G8 → G1/G2 → G6/G7 → G4 → G3 → G9 → G5/G10, lewat
Prompt 1–5.
