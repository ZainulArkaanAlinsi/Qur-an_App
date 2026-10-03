# Hasil kinerja liquid glass v4

Anggaran: `LIQUID_GLASS.md` §7. Hanya HP asli dalam mode profile yang dihitung; emulator tidak.

## Status per 3 Oktober 2026

**BELUM DIUKUR DI HP.** Saat Prompt 9 dikerjakan, `flutter devices` hanya menemukan Chrome dan Edge (tidak ada HP Android/iOS tersambung). Tidak ada angka yang ditulis di sini sampai pengukuran nyata dilakukan.

| Ukuran | Anggaran 60 Hz | Anggaran 90/120 Hz | Hasil |
| --- | --- | --- | --- |
| Build p90 | ≤ 6 ms | ≤ 4 ms | BELUM DIUKUR DI HP |
| Raster p90 | ≤ 10 ms | ≤ 7 ms | BELUM DIUKUR DI HP |
| Frame terlewat | ≤ 1% | ≤ 2% | BELUM DIUKUR DI HP |
| Selisih raster p90 penuh vs padat | ≤ 2 ms | ≤ 1.5 ms | BELUM DIUKUR DI HP |
| Kenaikan memori setelah 3 menit | ≤ 15 MB | ≤ 15 MB | BELUM DIUKUR DI HP |

## Cara mengukur (dijalankan pemilik)

1. Sambungkan HP Android (USB debugging aktif). Pakai HP paling lemah yang ada; Android lama tanpa Vulkan adalah kasus terberat.
2. Dari akar repo:

   ```
   flutter devices
   flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/glass_perf_test.dart
   ```

3. Ringkasan per skenario tersimpan di `build/glass_perf.json` (kunci `A_gulir_pembaca_full`, `A_gulir_pembaca_off`, `B_ganti_tab_*`, `C_lembar_murottal_*`). Nilai yang dipakai: `90th_percentile_frame_build_time_millis`, `90th_percentile_frame_rasterizer_time_millis`, `missed_frame_build_budget_count`, `missed_frame_rasterizer_budget_count`, `frame_count`.
4. Isi tabel di atas: model HP, versi Android, refresh rate (Pengaturan → Layar), lalu lulus/gagal per baris. Tingkat `off` = padat.
5. Kalau anggaran gagal: lihat timeline DevTools (raster thread, `saveLayer`, jumlah `BackdropFilter`), perbaiki, ukur ulang. Menurunkan sigma di bawah tingkat ringan bukan perbaikan.

## Pengawas frame

`lib/app/glass/glass_governor.dart`: jendela 120 frame, anggaran `1000 / refreshRate` ms, > 8% frame terlambat di dua jendela berturut-turut → turun satu tingkat (penuh → ringan → padat), disimpan di `glass_tier_auto` untuk versi aplikasi ini. Aturannya dites di `test/glass_governor_test.dart`; perilakunya di HP belum diamati.
