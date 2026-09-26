# Rilis ke Google Play — MyQuran 1.10.0 (20)

Panduan singkat untuk unggahan pertama ke Play Console. Butir bertanda **wajib** akan
membuat aplikasi ditolak atau tidak bisa tayang bila dilewati.

## 1. Build yang diunggah

```
flutter build appbundle --release
```

- Hasil: `build/app/outputs/bundle/release/app-release.aab`.
- Build ini adalah **build Play**: tanpa izin `REQUEST_INSTALL_PACKAGES`, tanpa
  FileProvider pembaruan, dan tanpa pengunduh APK dari GitHub. Pembaruan lewat Play
  (in-app update).
- Build untuk GitHub Releases dibuat terpisah:
  `flutter build apk --release --dart-define=DISTRIBUTION=github`
  (izin pasang APK dan pengunduh pembaruan hanya ada di build ini).
- Ditandatangani kunci upload dari `android/key.properties`. **Jangan pernah** mengunggah
  build yang ditandatangani kunci debug (Gradle memberi peringatan bila `key.properties`
  tidak ada).
- Package id `com.zainularkaan.quran`, versionCode 20, versionName 1.10.0,
  targetSdk 36, minSdk 24.

### Catatan rilis (kolom "Yang baru" di Play Console)

Bahasa Indonesia:

```
Baru: Sesi hari ini. Sekitar 10 menit sehari: ulang soal lama, pelajari satu potong materi, temukan hurufnya di ayat asli, dengarkan qari, lalu rekam dan bandingkan dengan suaramu. Rekaman tetap di HP, dan aplikasi tidak menilai bacaan. Sesi yang selesai ikut dihitung istiqamah, dan ada pengingat hariannya.
```

English:

```
New: Today's session. About 10 minutes a day: review earlier questions, learn one small step, find it in a real verse, listen to a reciter, then record yourself and compare. Recordings stay on your phone and the app never grades your recitation. Completed sessions count towards your streak, with an optional daily reminder.
```

## 2. Wajib sebelum unggah

- [ ] **Akun developer pribadi baru** (dibuat setelah 13 November 2023): Google mewajibkan
  *closed testing* dengan minimal **12 penguji selama 14 hari berturut-turut** sebelum
  bisa mengajukan akses Production. Jadi pada hari pertama, unggah ke **Internal
  testing** atau **Closed testing**, bukan langsung Production.
- [ ] **Pilih kunci penandatanganan aplikasi saat membuat app**: Play Console menawarkan
  kunci buatan Google atau kunci sendiri. Disarankan **memakai kunci rilis yang sudah ada**
  (`ruang-tilawah-release.jks`, opsi *Use existing app signing key*, ikuti panduan PEPK di
  Play Console). Dengan begitu pengguna APK GitHub bisa langsung memperbarui lewat Play
  tanpa mencopot aplikasi (tanda tangan sama), dan SHA di Firebase tidak berubah. Kalau
  memilih kunci buatan Google, pengguna lama harus mencopot versi GitHub dulu (data lokal
  hilang kecuali sudah disinkron) dan langkah SHA di bawah wajib.
- [ ] **Play App Signing**: setelah unggahan pertama, salin SHA-1 dan SHA-256 dari
  *Setup › App signing › App signing key certificate* ke Firebase Console
  (Project settings › Android app `com.zainularkaan.quran`), lalu unduh ulang
  `google-services.json`. Tanpa ini, **Masuk dengan Google gagal** di aplikasi yang
  diunduh dari Play (kunci Play berbeda dari kunci upload). Tambahkan SHA yang sama ke
  pembatasan API key Android di Google Cloud Console.
- [ ] **Kebijakan privasi**: deploy `hosting/public/privacy.html` yang sudah diperbarui
  (nama MyQuran, mikrofon, semua layanan pihak ketiga):
  `firebase deploy --only hosting`, lalu cantumkan
  `https://quran-app-zainularkaan.web.app/privacy` di Play Console.
- [x] **Backup keystore** `C:/Users/USER/keystores/ruang-tilawah-release.jks` dan
  `android/key.properties` (sudah di OneDrive sejak 23 September 2026). Kunci ini menjadi
  kunci upload Play; kehilangannya berarti harus mengajukan reset kunci ke Google.

## 3. App content (Play Console › Policy › App content)

| Deklarasi | Jawaban yang sesuai kode |
| --- | --- |
| Privacy policy | URL di atas |
| Ads | Tidak ada iklan |
| App access | Semua fitur bisa dipakai tanpa login (login Google opsional) |
| Content rating | Isi kuesioner: referensi/pendidikan, tanpa kekerasan, tanpa konten pengguna |
| Target audience | 13+ (jangan pilih di bawah 13 kecuali siap memenuhi Families Policy) |
| News app | Bukan aplikasi berita (daftar berita GDELT hanya pelengkap) |
| Data safety | Lihat tabel di bawah |
| Foreground service | `FOREGROUND_SERVICE_MEDIA_PLAYBACK` → jenis *Media playback*; sertakan video murottal diputar dengan layar mati |
| Government app | Tidak |
| Financial features | Tidak ada |
| Health | Tidak ada |

### Data safety

| Data | Dikumpulkan? | Dibagikan? | Keterangan |
| --- | --- | --- | --- |
| Email, nama (Personal info) | Ya, **opsional** (hanya bila masuk Google) | Tidak | Akun & sinkronisasi (Firebase Auth) |
| User IDs | Ya, opsional | Tidak | ID pengguna Firebase |
| App activity (riwayat baca, bookmark) | Ya, opsional | Tidak | Sinkronisasi antar perangkat |
| Device or other IDs | Ya, opsional | Tidak | ID perangkat acak untuk sesi baca yang disinkron |
| Lokasi | Tidak dikumpulkan | — | Kiblat dihitung di perangkat, tidak dikirim |
| Audio (rekaman) | Tidak dikumpulkan | — | Rekaman hafalan dan Sesi hari ini hanya di perangkat, tidak pernah diunggah |

Enkripsi saat transit: **Ya** (HTTPS). Pengguna bisa meminta penghapusan data: **Ya**
(Saya › kartu profil › Hapus akun & data cloud).

## 4. Store listing (7 bahasa)

- Teks listing Indonesia, Inggris, Arab, Melayu, Turki, Urdu, dan Prancis ada di
  `docs/play-store/LISTING.md`. Batas karakter sudah dicek, dan hanya fitur yang ada di
  rilis yang disebut.
- Gambar per bahasa ada di `docs/play-store/<kode>/`: `feature-graphic.jpg` (1024×500)
  dan `screenshot-1…7.jpg` (1080×1920). Ikon 512: `docs/play-store/icon-512.png`.
- Membuat ulang gambar: lihat komentar di `tool/store/store_assets_test.dart`.
- Kategori: Books & Reference atau Education.
- Jangan memakai ikon/warna aplikasi lain dan jangan mengklaim "resmi Kemenag".

## 5. Konten agama

- Tahap 6–16 (tajwid) masih **draf** dan **terkunci di build rilis** ("Materi sedang
  ditinjau"). Naskah untuk 2 peninjau bersanad: `docs/content/tajwid/`.
- Terjemahan Kemenag (via Tanzil) berlisensi **non-komersial**: jangan pasang iklan,
  pembelian dalam aplikasi, atau langganan tanpa izin tertulis.

## 6. Uji di HP sebelum mengirim ke penguji

- [ ] Pasang dari Internal testing (bukan dari kabel) supaya kunci Play ikut teruji.
- [ ] Buka pertama kali: splash → onboarding 4 halaman (geser maju/mundur, tombol
  kembali), pilih titik mulai → tab yang benar terbuka.
- [ ] Buka kedua kali: splash → langsung Beranda (onboarding tidak muncul lagi).
- [ ] Ikon bulat & squircle, themed icon Android 13+, splash terang/gelap tanpa kedip.
- [ ] Masuk Google, sinkron, murottal dengan layar mati, mode pesawat.
