# 16-splash — Splash animasi

**Gambar acuan:** `screens/V3-Splash.png`, `screens/V3-Splash-Gelap.png` (frame akhir)
**HTML acuan:** `html/V3-Splash.html` (buka di browser, animasinya jalan)
**File kode terkait:** buat `lib/features/onboarding/presentation/splash_screen.dart`

## Tujuan
Jembatan halus dari splash sistem ke aplikasi: logo utama muncul tenang, lalu masuk ke Onboarding atau Beranda.

## Tata letak (atas → bawah)
1. Latar `bg` + pola geometri emas 6% yang memudar ke tepi.
2. Glow radial 380 dp dan bintang 8 sudut 300 dp, pusat di y=372.
3. Logo utama 250 dp, pusat di y=372.
4. Tagline `BACA · BELAJAR · HAFAL`, 54 dp dari bawah.

## Konten
- Tagline ditulis persis seperti itu (huruf kapital, dipisah titik tengah).

## Batasan
- Lini waktu, durasi min/maks, dan mode kurangi gerak mengikuti DESIGN.md §4b.
- Tidak ada spinner atau progress bar.
- Tidak memblokir aplikasi lebih dari 2500 ms.

## Selesai jika
- Golden frame akhir (terang & gelap) mirip acuan.
- Widget test: dengan `disableAnimations: true` hanya ada fade; navigasi ke Onboarding saat `onboarding.selesai.v1` belum ada, dan ke Beranda saat sudah ada.
- Tidak ada frame putih di antara splash native dan splash animasi (cek manual di perangkat).
