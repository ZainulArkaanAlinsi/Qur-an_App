# Hasil kinerja liquid glass v4

## Status: BELUM DIUKUR DI HP

Per 25 September 2026 tidak ada HP yang tersambung ke mesin pengembangan
(`flutter devices` hanya menampilkan Windows, Chrome, dan Edge). Sesuai
LIQUID_GLASS.md §7, emulator dan desktop tidak dihitung, jadi **belum ada angka
kinerja yang sah**. Tabel di bawah sengaja dikosongkan sampai diukur di HP asli.

Alur keenam skenario (A/B/C × penuh/padat) sudah dijalankan sampai selesai di
Windows desktop (mode debug, `flutter test integration_test/glass_perf_test.dart
-d windows`, 25 September 2026: 6 lulus). Ini hanya membuktikan skrip tesnya
berjalan; angka dari desktop tidak dicatat karena tidak berlaku untuk HP.

## Cara mengukur

1. Sambungkan HP Android (aktifkan *USB debugging*) atau iPhone, lalu pastikan
   muncul di `flutter devices`. Pakai HP paling lemah yang tersedia; Android lama
   tanpa Vulkan adalah kasus terberat.
2. Jalankan dari akar repo, mode profile:

   ```
   flutter drive --profile \
     --driver=test_driver/perf_driver.dart \
     --target=integration_test/glass_perf_test.dart
   ```

3. Hasilnya ada di `build/glass_perf_<skenario>_<tingkat>.json` (6 berkas:
   A/B/C × penuh/padat). Salin angka berikut ke tabel di bawah:
   `90th_percentile_frame_build_time_millis`,
   `90th_percentile_frame_rasterizer_time_millis`,
   `missed_frame_build_budget_count`, `missed_frame_rasterizer_budget_count`,
   dan `frame_count`.
4. Frame terlewat (%) = `missed_frame_rasterizer_budget_count` / `frame_count`.
5. Memori: buka DevTools → Memory saat skenario A berjalan 3 menit, catat selisih
   RSS awal dan akhir.

Skenario (integration_test/glass_perf_test.dart):

- **A**: gulir pembaca Al-Baqarah 15 detik dengan tajwid aktif (nav ikut sembunyi dan muncul).
- **B**: ganti tab 20 kali.
- **C**: buka/tutup sheet murottal 10 kali.

Tiap skenario dijalankan dua kali: tingkat **penuh** (`glass_preference = full`) dan
**padat** (`off`).

## HP yang diukur

| Model | Android/iOS | Refresh rate | Renderer (Impeller/Skia, Vulkan/GL) |
| --- | --- | --- | --- |
| – | – | – | – |

## Anggaran §7

| Ukuran | Batas 60 Hz | Batas 90/120 Hz | A penuh | A padat | B penuh | B padat | C penuh | C padat | Lulus? |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Build p90 | ≤ 6 ms | ≤ 4 ms | – | – | – | – | – | – | – |
| Raster p90 | ≤ 10 ms | ≤ 7 ms | – | – | – | – | – | – | – |
| Frame terlewat | ≤ 1% | ≤ 2% | – | – | – | – | – | – | – |
| Selisih raster p90 penuh vs padat | ≤ 2 ms | ≤ 1.5 ms | – | | – | | – | | – |
| Kenaikan memori 3 menit | ≤ 15 MB | ≤ 15 MB | – | | | | | | – |

## Pengawas frame

Di HP yang lemah, pengawas harus terbukti menurunkan tingkat saat mode Otomatis:
jalankan skenario A dengan `glass_preference = auto`, lalu periksa
`glass_tier_auto` di preferensi (atau buka Saya → Efek kaca: pratinjau Otomatis
berubah dari penuh ke ringan/padat). Logika hitungannya sudah diuji di
`test/glass_governor_test.dart` (dua jendela 120 frame dengan > 8% frame lambat →
turun satu tingkat; tidak pernah naik; reset sekali per versi).

## Bila anggaran gagal

Cari penyebabnya di timeline DevTools (raster thread, jumlah `saveLayer`, jumlah
`BackdropFilter` per frame), perbaiki, lalu ukur ulang. Menurunkan sigma di bawah
tingkat ringan bukan perbaikan.
