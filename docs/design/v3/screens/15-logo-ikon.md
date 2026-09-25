# 15-logo-ikon — Logo, ikon aplikasi, splash bawaan

**Gambar acuan:** `screens/V3-Brand.png`
**HTML acuan:** `html/V3-Brand.html`
**File terkait:** `pubspec.yaml`, `assets/brand/`, `assets/icons/`, `android/app/build.gradle*` (appLabel), `ios/Runner/Info.plist`

## Tujuan
Aplikasi tampil sebagai **MyQuran** dengan logo milik pemilik, utuh dan konsisten di ikon, splash, dan halaman Tentang.

## Tata letak
Tidak ada layar baru. Yang dikerjakan:
1. Ikon launcher dari `assets/icons/*` (DESIGN.md §3).
2. Splash bawaan sistem (DESIGN.md §4a).
3. Halaman Tentang (Saya → Tentang): logo utama 160 dp di tengah, sesuai tema terang/gelap.

## Konten
- Nama tampilan `MyQuran` (debug: `MyQuran Debug`) di Android `appLabel` dan iOS `CFBundleDisplayName`.
- Berkas logo sesuai tabel DESIGN.md §2. `logo_utama_asli*.png` hanya arsip.

## Batasan
- Logo tidak digambar ulang, dipotong, diberi filter warna, atau diregangkan.
- Package id tidak diubah.
- Hanya memakai paket `flutter_launcher_icons` dan `flutter_native_splash`, keduanya MIT dan sudah ada di pubspec.

## Selesai jika
- `dart run flutter_launcher_icons` dan `dart run flutter_native_splash:create` sukses tanpa peringatan berkas hilang.
- Di emulator Android 14, ikon tampil benar dalam bentuk bulat maupun squircle, dan themed icon (Android 13+) muncul saat tema ikon diaktifkan.
- Splash native terang/gelap tidak berkedip putih.
- `flutter analyze` bersih.
