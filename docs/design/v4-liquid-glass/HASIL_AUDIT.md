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

## Prompt 1 — fondasi (25 September 2026)

`lib/app/glass/`: `GlassTokens` (ThemeExtension, dipasang `SacredTheme.themeFor`),
`GlassTier`/`GlassPreference`/`GlassScope`, dan `LiquidGlass` enam lapis. `BackdropGroup`
di `AppShell` dan `ReaderScreen`. `GlassSurface` tinggal pembungkus `@Deprecated`.

### Angka yang menyimpang dari §4

| Token | §4 | Dipakai | Alasan |
| --- | --- | --- | --- |
| tint sepia | `surf` @ 42% | `surf` @ 48% (`0x7B`) | Dengan token sepia asli (`surf` #FBF4E4, `sec` #6E5D44), 42% memberi `sec` **4.41** di atas latar hitam (< 4.5). 48% memberi 8.94 / 4.55 / 6.72, sama dengan angka sepia di tabel §5. |
| tint gelap | `surf` @ 42% | `0x6C` (42.35%) | Pembulatan byte ke atas. Angka §5 gelap (9.98 / 4.67 / 7.43) dihitung dengan warna kaca lama #14201C; dengan `surf` #111C18 hasilnya 10.28 / 4.80 / 7.65. |

Model tes: latar polos → vibrancy (matriks yang sama dengan `LiquidGlass`) → tint. Hasil
terang cocok persis dengan §5 (12.62 / 4.57 / 6.92). Semua palet × tingkat × ukuran lolos
ambang ink 7, sec 4.5, primaryText 4.5 di 9 latar uji (`test/glass_contrast_test.dart`).

### Audit setelah Prompt 1

`bash tool/glass_audit.sh`: **5 GAGAL** (dari 12). Target Prompt 1 lulus: A1, A2, B1, B4,
C1, C2. Sisa: A3, B2, B3 (Prompt 2), C3, C4 (Prompt 4).

## Prompt 2 — permukaan (25 September 2026)

- Tab bar: scrim padat diganti gradien 20 px (alfa maks 40%); lensa meluncur dengan pegas
  420/32, regangan maks 1.12, tekan 0.94, geser jari lalu menempel, haptik; tanpa ripple.
- Nav pembaca: menumpang di atas daftar, dilipat setelah gulir turun > 24 px (220 ms,
  kurva v3), muncul saat gulir naik. Ayat tidak bergeser (tes `reader_screen_test.dart`,
  golden `05_kartu_gulir_*`). Tampilan awal identik piksel dengan sebelum perubahan.
- Mini player: LiquidGlass + token di 6 kombinasi palet; muncul dari bawah 280 ms.
- Sheet: `showGlassSheet()` (kepala kaca + grabber yang meregang, isi padat) untuk sheet
  murottal, Tampilan baca, dan aturan tajwid.
- Tombol bulat: `GlassCircleButton` (diameter 44) untuk tombol dengar di hero Beranda.
- Penanda: item daftar dan keadaan kosong kembali ke kartu padat.

### Jumlah kaca terlihat bersamaan

| Layar | Kaca | Jumlah maks | Batas |
| --- | --- | --- | --- |
| Beranda | tab bar, mini player (saat murottal aktif), tombol dengar di hero | 3 | 3 |
| Qur'an, Belajar, Hafalan, Saya | tab bar, mini player | 2 | 3 |
| Pembaca (kartu ayat) | nav, mini player | 2 | 2 |
| Pembaca + sheet terbuka | nav, kepala sheet (mini player tertutup isi sheet yang padat) | 2 | 2 |
| Pembaca mode fokus | mini player | 1 | 2 |
| Murottal, Penanda, Salat, Pelajaran | – | 0 | 3 |

Tidak ada kaca di item daftar (A3 lulus). `GlassSurface` tidak dipakai lagi; kelasnya tetap
ada sebagai pembungkus `@Deprecated`.

### Audit setelah Prompt 2

`bash tool/glass_audit.sh`: **2 GAGAL** (C3 pengawas frame, C4 tes kinerja: Prompt 4).
Target Prompt 2 lulus: A3, B2, B3.

## Prompt 3 — warna & keterbacaan (25 September 2026)

### Warna tajwid

Diukur di **semua permukaan ayat**: kartu (`surf`), latar (`bg`), ayat aktif (`primarySoft`)
dan ayat bertanda (`goldSoft`), masing-masing di atas kartu dan di atas latar; di palet hijau,
sepia, dan kontras tinggi; terang dan gelap. Sebelum revisi, 7 warna terang di bawah 4.5
(terendah abu hamzah washal **3.54** di ayat aktif) dan mad wajib gelap **4.41**.

Hanya nilai warna yang berubah; hukum, data, dan status draf tetap. Aturan hubungan:
abu tetap lebih redup daripada tinta; tiga mad tetap satu keluarga biru dengan urutan
terang-gelap yang sama; pasangan yang mudah tertukar (ΔE2000 < 15) tidak boleh menjadi
lebih mirip dan pasangan lain tetap ≥ 15. Syarat "tidak ada pasangan yang lebih mirip sama
sekali" tidak mungkin dipenuhi: semua warna terang harus digelapkan ke L* ≈ 44 supaya lolos
4.5, sehingga pasangan yang jauh (ΔE > 20) ikut menyusut sedikit. Itu sebabnya batas "mudah
tertukar" dipakai. Warna yang berubah ditandai ✱.

#### Terang

| Hukum | Lama | Baru | Kontras terburuk lama → baru | ΔE lama→baru |
| --- | --- | --- | --- | --- |
| hamzah washal / lam syamsiyah / tidak dibaca ✱ | `#7A7A7A` | `#676767` | 3.54 → **4.66** | 7.5 |
| mad thabi'i ✱ | `#2F5FE0` | `#0B5FE0` | 4.51 → **4.64** | 1.9 |
| mad jaiz | `#3340D0` | `#3340D0` | 6.21 → **6.21** | 0.0 |
| mad wajib | `#0A1596` | `#0A1596` | 11.09 → **11.09** | 0.0 |
| mad lazim | `#5A0F8C` | `#5A0F8C` | 9.19 → **9.19** | 0.0 |
| qalqalah | `#C8000A` | `#C8000A` | 5.00 → **5.00** | 0.0 |
| ikhfa haqiqi | `#8A009C` | `#8A009C` | 6.76 → **6.76** | 0.0 |
| ikhfa syafawi | `#B0009A` | `#B0009A` | 5.22 → **5.22** | 0.0 |
| idgham bighunnah ✱ | `#127A60` | `#00765F` | 4.35 → **4.60** | 1.8 |
| idgham bilaghunnah ✱ | `#1F7A12` | `#1D7810` | 4.49 → **4.62** | 0.7 |
| idgham mimi ✱ | `#3C8A00` | `#587000` | 3.58 → **4.63** | 11.2 |
| idgham mutajanisain / mutaqaribain ✱ | `#6E6E6E` | `#565656` | 4.20 → **6.05** | 8.9 |
| iqlab ✱ | `#0078B8` | `#017095` | 3.95 → **4.61** | 7.6 |
| ghunnah ✱ | `#C25400` | `#A05300` | 3.79 → **4.64** | 8.1 |

Pasangan yang mudah tertukar (ΔE2000 < 15), lama → baru:

| Pasangan | ΔE lama | ΔE baru |
| --- | --- | --- |
| hamzah washal / lam syamsiyah / tidak dibaca – idgham mutajanisain / mutaqaribain | 4.77 | 6.19 |
| idgham bilaghunnah – idgham mimi | 7.03 | 10.50 |
| ikhfa haqiqi – ikhfa syafawi | 8.14 | 8.14 |
| mad lazim – ikhfa haqiqi | 8.68 | 8.68 |
| mad wajib – mad lazim | 9.67 | 9.67 |
| mad thabi'i – mad jaiz | 9.75 | 10.43 |
| mad jaiz – mad wajib | 13.03 | 13.03 |
| mad thabi'i – iqlab | 13.09 | 14.44 |

Jarak terkecil antarhukum: 4.77 → 6.19. Semua pasangan lain ≥ 15 (terkecil baru 15.04).

#### Gelap

| Hukum | Lama | Baru | Kontras terburuk lama → baru | ΔE lama→baru |
| --- | --- | --- | --- | --- |
| hamzah washal / lam syamsiyah / tidak dibaca | `#9A9A9A` | `#9A9A9A` | 4.63 → **4.63** | 0.0 |
| mad thabi'i | `#8FA8FF` | `#8FA8FF` | 5.72 → **5.72** | 0.0 |
| mad jaiz | `#A0A8FF` | `#A0A8FF` | 5.92 → **5.92** | 0.0 |
| mad wajib ✱ | `#7F8CFF` | `#5A97FD` | 4.41 → **4.52** | 8.5 |
| mad lazim | `#C69BFF` | `#C69BFF` | 5.92 → **5.92** | 0.0 |
| qalqalah | `#FF7A7A` | `#FF7A7A` | 5.16 → **5.16** | 0.0 |
| ikhfa haqiqi | `#D98BFF` | `#D98BFF` | 5.64 → **5.64** | 0.0 |
| ikhfa syafawi | `#FF8AE6` | `#FF8AE6` | 6.23 → **6.23** | 0.0 |
| idgham bighunnah | `#52D6B0` | `#52D6B0` | 7.21 → **7.21** | 0.0 |
| idgham bilaghunnah | `#7DDB6E` | `#7DDB6E` | 7.59 → **7.59** | 0.0 |
| idgham mimi ✱ | `#8FE05A` | `#B5D943` | 8.06 → **8.05** | 8.0 |
| idgham mutajanisain / mutaqaribain | `#A8A8A8` | `#A8A8A8` | 5.48 → **5.48** | 0.0 |
| iqlab | `#5CCBFF` | `#5CCBFF` | 7.10 → **7.10** | 0.0 |
| ghunnah | `#FFA25C` | `#FFA25C` | 6.57 → **6.57** | 0.0 |

Pasangan yang mudah tertukar (ΔE2000 < 15), lama → baru:

| Pasangan | ΔE lama | ΔE baru |
| --- | --- | --- |
| mad thabi'i – mad jaiz | 3.88 | 3.88 |
| hamzah washal / lam syamsiyah / tidak dibaca – idgham mutajanisain / mutaqaribain | 4.26 | 4.26 |
| idgham bilaghunnah – idgham mimi | 4.49 | 11.78 |
| mad lazim – ikhfa haqiqi | 5.65 | 5.65 |
| mad thabi'i – mad wajib | 7.86 | 8.35 |
| mad jaiz – mad wajib | 8.53 | 11.87 |
| ikhfa haqiqi – ikhfa syafawi | 9.62 | 9.62 |
| mad jaiz – mad lazim | 10.60 | 10.60 |
| mad lazim – ikhfa syafawi | 13.57 | 13.57 |
| mad wajib – mad lazim | 14.09 | 21.51 |
| mad thabi'i – mad lazim | 14.47 | 14.47 |

Jarak terkecil antarhukum: 3.88 → 3.88. Semua pasangan lain ≥ 15 (terkecil baru 15.57).

Keterbatasan: mad thabi'i dan mad jaiz gelap tetap ΔE 3.88 seperti semula. Keduanya
sudah di batas gamut biru sRGB; setiap geseran rona membuat pasangan lain lebih mirip.
Warna bukan satu-satunya penanda: nama hukum selalu ada di chip, legenda, dan ketukan huruf.

Latar ayat aktif/bertanda di palet **kontras tinggi** dulu lebih pekat daripada palet hijau
(`primarySoft` #D7E7DF, `goldSoft` #F3E6BF; gelap alfa 24%/20%), dan justru di situ warna
tajwid paling samar (abu 3.35). Nilainya disamakan dengan palet hijau (#E0ECE5, #FBF0CC;
gelap alfa 13%/12%). Ayat aktif tetap tersorot; hurufnya kini ≥ 4.5 di semua palet.

Tes: `test/tajweed_widget_test.dart` memeriksa 17 hukum × 6 permukaan × 3 palet × terang/gelap
(≥ 4.5), abu lebih redup daripada tinta, dan urutan terang tiga mad.

### Golden kaca (`test/golden/goldens/glass/`)

Latar uji: garis putih, hitam, hijau hero, emas, merah, biru, teal; teks tebal hitam/putih;
kartu hero hijau. Bayangan dirender sungguhan.

| PNG | a. tepi menangkap cahaya | b. warna belakang samar | c. label tab tidak aktif jelas |
| --- | --- | --- | --- |
| `kaca_terang_penuh` | Ya, kiri-atas tab bar, mini player, kepala sheet | Ya, garis warna tampak pastel dan kabur di nav, sheet, mini player; teks di belakang tidak terbaca | Ya |
| `kaca_terang_padat` | Ya, tepi tetap | Tidak (padat, sesuai tingkat) | Ya |
| `kaca_gelap_penuh` | Ya, garis terang tipis di tepi atas | Ya, garis warna tampak gelap-samar | Ya |
| `kaca_gelap_padat` | Ya | Tidak (padat) | Ya |
| `kaca_sepia_penuh` | Ya | Ya, bernuansa krem | Ya |
| `kaca_sepia_padat` | Ya | Tidak (padat) | Ya |
| `kaca_kontras_tinggi_penuh` / `_padat` | Garis `outline` 1.5 px | Tidak: kontras tinggi selalu padat, kedua PNG identik | Ya |

Tombol bulat kaca di hero: cakram terang berikon gelap (terang/sepia), cakram gelap
bertepi terang (gelap). Bentuk dan ukuran sama di tingkat penuh dan padat.

### Golden pembaca tajwid (`05_tajwid_{fatihah,baqarah}_{terang,gelap,sepia}`)

Tajwid aktif, satu ayat aktif (1:2, 2:3). Ayat aktif bergulir ke tepat di bawah nav; tidak
ada huruf yang tertutup nav. Teks Arab tanpa bayangan, glow, gradien, atau blur. Warna
tajwid terbaca di kartu biasa dan di latar ayat aktif pada ketiga tema.

### Audit setelah Prompt 3

`bash tool/glass_audit.sh`: 2 GAGAL (C3, C4: Prompt 4). `flutter analyze` bersih,
`flutter test` 608 lulus.

## Prompt 4 — kinerja (25 September 2026)

- `lib/app/glass/glass_governor.dart`: pengawas frame (`addTimingsCallback`, jendela 120
  frame, anggaran 1000/refresh rate, > 8% frame lambat di dua jendela → turun satu
  tingkat, disimpan di `glass_tier_auto`, tidak naik di sesi yang sama, reset sekali per
  versi lewat `glass_tier_version`). Hanya mendengar di mode Otomatis dan selama layar
  berkaca (AppShell, pembaca) adalah rute teratas (`GlassGovernorScope`). Diuji di
  `test/glass_governor_test.dart`.
- Saya → Membaca → **Efek kaca**: Otomatis / Penuh / Ringan / Mati dengan pratinjau kaca
  asli di tingkat masing-masing dan keterangan "Otomatis menurunkan efek bila HP terasa
  berat." Golden `12_saya_efek_kaca_{light,dark}`.
- `integration_test/glass_perf_test.dart` + `test_driver/perf_driver.dart`: skenario A/B/C
  × penuh/padat dengan `watchPerformance`. Alurnya lulus di Windows desktop; **belum
  diukur di HP** (tidak ada HP tersambung), lihat `HASIL_KINERJA.md`.

`bash tool/glass_audit.sh`: **0 GAGAL** (1 CEK: 6 pemakaian kaca di luar lib/app/glass/, semuanya
chrome mengambang: tab bar, nav pembaca, mini player, pratinjau Efek kaca, dan pembungkus
`GlassSurface` yang tidak lagi dipakai). `flutter analyze` bersih, `flutter test` 616 lulus.
