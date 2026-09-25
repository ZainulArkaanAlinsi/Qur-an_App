# 17-onboarding — Onboarding 4 halaman yang bisa digeser

**Gambar acuan:** `screens/V3-Onb1.png` … `V3-Onb4.png` (+ `-Gelap`), gerak: `screens/gerak_1_ke_2_50.png`, `screens/gerak_2_ke_3_30.png`
**HTML acuan:** `html/V3-Onb1.html` … (statis), `html/V3-Onboarding.prototipe.dc.html` (sumber prototipe; logika geser ada di `renderVals()`, rumusnya sama dengan DESIGN.md §5c)
**File kode terkait:** buat `lib/features/onboarding/` (presentation + data preferensi)

## Tujuan
Dalam 4 geseran, pengguna baru paham tiga hal (baca, belajar, hafal), lalu memilih titik mulai. Geserannya harus terasa hidup: ilustrasi, judul, dan subjudul bergerak dengan kecepatan berbeda (parallax).

## Tata letak (atas → bawah)
1. "Lewati" di kanan atas (halaman 1–3).
2. Ilustrasi, area top 96 dp dan tinggi 400 dp.
3. Judul serif dan subjudul, mulai y=520, rata tengah (halaman 4: header rata kiri mulai y=118, opsi mulai y=290).
4. Titik halaman di y=716.
5. CTA pill "Lanjut" / "Mulai".

## Konten
- Teks, ilustrasi, dan efek tiap pilihan persis seperti DESIGN.md §5b.
- Ayat di ilustrasi halaman 2 = QS 2:5 dari Tanzil + terjemahan Kemenag dari dataset. Tidak diketik ulang.

## Batasan
- `PageView` + `AnimatedBuilder`. Tanpa paket animasi pihak ketiga, Lottie, atau gambar ilustrasi raster (kecuali logo).
- Rumus gerak, ambang geser, kurva, dan haptik mengikuti DESIGN.md §5c.
- Tampil sekali (`onboarding.selesai.v1`).
- Semua warna dari token.

## Selesai jika
- Golden 390×844 untuk halaman 1–4, terang & gelap, mirip acuan.
- Golden "tengah geser" dengan `PageController` di `page = 0.5` dan `1.3` mirip `gerak_*.png`.
- Tidak ada overflow di text scale 2.0 (halaman 1–4).
- Widget test:
  - Lewati → halaman 4.
  - Pilih opsi → Mulai → preferensi tersimpan dan tab tujuan terbuka.
  - Tombol kembali mundur satu halaman.
  - Mode kurangi gerak mematikan parallax.
