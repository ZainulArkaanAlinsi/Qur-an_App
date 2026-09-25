# Rilis APK (distribusi langsung, gratis)

Ruang Tilawah didistribusikan sebagai APK bertanda tangan melalui
[GitHub Releases](https://github.com/ZainulArkaanAlinsi/Qur-an_App/releases),
tanpa Google Play. Aplikasi memeriksa rilis terbaru di GitHub (paling sering
sekali sehari) dan menampilkan tombol **Unduh** bila ada versi baru.

Halaman publik (Firebase Hosting, gratis):
- Beranda dan tautan unduh: https://quran-app-zainularkaan.web.app
- Kebijakan privasi: https://quran-app-zainularkaan.web.app/privacy

## Kunci rilis — wajib dijaga

| Berkas | Lokasi | Di Git? |
|---|---|---|
| Keystore | `C:\Users\USER\keystores\ruang-tilawah-release.jks` | Tidak |
| Kata sandi & alias | `android/key.properties` | Tidak (di-ignore) |

- Alias: `upload`, RSA 4096, berlaku 10.000 hari, DN `CN=Ruang Tilawah, O=Ruang Tilawah, C=ID`.
- SHA-1: `F4:BA:11:D8:68:92:CE:7F:37:52:CC:B2:33:72:1A:A4:9E:8A:3A:54`
- SHA-256: `3A:F7:E6:FD:27:1D:9F:DB:CA:F8:0E:2C:8F:CE:99:90:DE:73:8F:09:72:22:D7:AD:E4:11:BC:51:24:D8:FE:AA`

**Backup keystore dan `key.properties` ke tempat aman di luar laptop.** Tanpa
Play Store tidak ada pemulihan kunci: jika hilang, APK baru tidak bisa dipasang
di atas versi lama, sehingga pengguna harus menghapus aplikasi (data lokal ikut
hilang).

Format `android/key.properties` (isi dengan nilai sebenarnya, jangan commit):

```properties
storePassword=<kata sandi keystore>
keyPassword=<kata sandi kunci>
keyAlias=upload
storeFile=C:/Users/USER/keystores/ruang-tilawah-release.jks
```

Tanpa berkas ini, build rilis memakai kunci debug dan Gradle menampilkan
peringatan; APK seperti itu tidak boleh dibagikan.

## Langkah rilis

1. Naikkan `version:` di `pubspec.yaml` (mis. `1.2.0+4`) dan `appVersion` di
   `lib/core/app_version.dart` — `test/app_version_test.dart` memastikan
   keduanya sama. `versionCode` (angka setelah `+`) harus selalu naik.
2. Pastikan lulus:
   ```powershell
   flutter analyze
   flutter test
   ```
3. Build dan verifikasi tanda tangan:
   ```powershell
   flutter build apk --release --dart-define=DISTRIBUTION=github
   & "$env:LOCALAPPDATA\Android\Sdk\build-tools\<versi>\apksigner.bat" verify --print-certs build\app\outputs\flutter-apk\app-release.apk
   ```
   SHA-256 sertifikat harus sama dengan di atas. `DISTRIBUTION=github` wajib
   untuk APK GitHub (pengunduh pembaruan + izin pasang APK); build Google Play
   memakai `flutter build appbundle --release` tanpa flag itu
   (docs/PLAY_STORE_RELEASE.md).
4. Buat rilis di GitHub dengan tag `v<versi>` (mis. `v1.2.0`), lampirkan APK
   dengan nama `ruang-tilawah-<versi>.apk`, dan cantumkan SHA-256 berkasnya.
   Tag harus diawali `v` dan berupa angka bertitik agar pemeriksa pembaruan
   di aplikasi dapat membandingkannya.

## Pembaruan otomatis di perangkat pengguna

Aplikasi memeriksa GitHub Releases maksimal sekali sehari, mengunduh APK
rilis terbaru di latar belakang, lalu membuka pemasang Android. Batas yang
tidak bisa dihindari: **Android selalu menampilkan dialog konfirmasi** untuk
APK di luar Play Store, dan pengguna harus memberi izin "pasang aplikasi tak
dikenal" satu kali (tersedia di Pengaturan > Pembaruan aplikasi).

Agar rantai ini bekerja, setiap rilis wajib:

- melampirkan berkas **`.apk`** sebagai aset rilis (pemeriksa memakai aset
  `.apk` pertama beserta `size`-nya untuk memastikan unduhan utuh);
- ditandatangani **kunci rilis yang sama**. Android menolak pemasangan APK
  dengan tanda tangan berbeda, sehingga rilis dari kunci lain tidak akan
  terpasang dan pengguna harus memasang ulang secara manual;
- memakai `versionName` yang naik, karena perbandingan versi memakai tag.

Pengguna dapat mematikan pembaruan otomatis di Pengaturan > Pembaruan
aplikasi; aplikasi lalu kembali menampilkan pemberitahuan versi baru saja.

## Firebase untuk build rilis

- SHA-1/SHA-256 kunci debug dan rilis terdaftar di aplikasi Firebase
  `com.zainularkaan.quran`, dan `android/app/google-services.json` memuat
  client OAuth untuk keduanya (Google Sign-In).
- API key Android dibatasi ke package `com.zainularkaan.quran` dengan SHA-1
  debug dan rilis (diuji: klien tanpa identitas, package lain, atau sertifikat
  lain ditolak). Jika kunci penandatanganan berubah, tambahkan SHA-1 barunya di
  Google Cloud Console › APIs & Services › Credentials, lalu jalankan ulang
  `flutterfire configure` (lihat `docs/CLOUD_SYNC.md`).
