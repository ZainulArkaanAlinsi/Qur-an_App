# Rilis ke Google Play — MyQuran 1.10.1 (21)

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
- Package id `com.zainularkaan.quran`, versionCode 21, versionName 1.10.1,
  targetSdk 36, minSdk 24.

### Hasil cek build 1.10.1 (2 Oktober 2026, Flutter 3.44.8)

- `app-release.aab` 67,6 MB, ditandatangani kunci rilis `CN=Ruang Tilawah`
  (SHA-256 `3A:F7:E6:FD:…:24:D8:FE:AA`), bukan kunci debug.
- Manifest gabungan (`bundletool dump manifest`): targetSdk 36, minSdk 24.
- Izin di AAB: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_COARSE_LOCATION`,
  `ACCESS_FINE_LOCATION`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`,
  `RECORD_AUDIO`, `WAKE_LOCK`, `VIBRATE`, `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `USE_BIOMETRIC`, `USE_FINGERPRINT`, `READ_GSERVICES`,
  dan `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` milik aplikasi sendiri.
  - **Tidak ada** `REQUEST_INSTALL_PACKAGES` dan tidak ada FileProvider pembaruan.
  - Asal izin tambahan menurut `build/app/outputs/logs/manifest-merger-release-report.txt`:
    `USE_BIOMETRIC`/`USE_FINGERPRINT` dari `androidx.biometric:biometric:1.1.0`
    (dependensi transitif), dan `READ_GSERVICES` dari
    `com.google.android.recaptcha:recaptcha:18.6.1` (ikut `firebase-auth`). Kode MyQuran
    tidak memakai biometrik.
- 16 KB page size:
  - semua `.so` 64-bit (`arm64-v8a`, `x86_64`) punya segmen LOAD dengan alignment
    ≥ 16384;
  - `zipalign -c -P 16 -v 4` lulus untuk 86 APK split hasil `bundletool build-apks`.

### Catatan rilis 1.11.0 (22) — update v6

Diunggah ke track tes tertutup yang sama setelah 1.10.1. Maksimal 500 karakter
(ID 386, EN 403). Hanya fitur yang ada di build rilis yang disebut (qari berstatus
`pending` tidak).

Bahasa Indonesia:

```
Beranda baru: salat berikutnya dan satu langkah untuk hari ini. Murottal kini menampilkan ayat yang dibaca qari dan ikut bergulir. Waktu salat bisa mengikuti lokasi otomatis (dibulatkan sekitar 3 km) atau kota pilihan, dengan pilihan metode, mazhab Asar, dan koreksi menit. Pemilih qari baru: cari, saring, dan dengar contoh. Pengaturan Efek kaca di tab Saya untuk HP yang terasa berat.
```

English:

```
New Home: your next prayer and one step for today. Murottal now shows the verse being recited and scrolls along with it. Prayer times can follow your location automatically (rounded to about 3 km) or a chosen city, with a choice of calculation method, Asr school and minute adjustments. New reciter picker: search, filter and play a sample. A Glass effect setting in the Saya (Me) tab for slower phones.
```

Di hari yang sama dengan unggahan 1.11.0: ubah Data safety (baris *Approximate
location*, §3) dan jalankan `firebase deploy --only hosting` supaya `privacy.html`
versi lokasi otomatis tayang.

### Catatan rilis 1.10.1 (kolom "Yang baru" di Play Console)

1.10.1 adalah unggahan Play pertama, jadi catatannya menyebut fitur utama 1.10.0 dan
perbaikan 1.10.1. Maksimal 500 karakter (ID 372, EN 412).

Bahasa Indonesia:

```
Sesi hari ini: sekitar 10 menit sehari untuk mengulang, belajar satu materi kecil, menemukannya di ayat, lalu menirukan qari. Rekaman tetap di HP dan aplikasi tidak menilai bacaan. Perbaikan 1.10.1: tombol Unduh di layar Murottal kini berfungsi, hapus unduhan ditanyakan dulu, catatan internal dihapus dari layar, dan akun bisa dihapus lewat email tanpa memasang aplikasi.
```

English:

```
Today's session: about 10 minutes a day to review, learn one small step, find it in a real verse, then repeat after a reciter. Recordings stay on your phone and the app never grades your recitation. Fixes in 1.10.1: the Download button on the Murottal screen now works, deleting a download asks first, internal notes are gone from the screens, and you can delete your account by email without installing the app.
```

## 2. Wajib sebelum unggah

- [ ] **Akun developer pribadi baru** (dibuat setelah 13 November 2023): Google mewajibkan
  *closed testing* dengan minimal **12 penguji selama 14 hari berturut-turut** sebelum
  bisa mengajukan akses Production. Jadi pada hari pertama, unggah ke **Internal
  testing** atau **Closed testing**, bukan langsung Production.
- [x] **Kunci penandatanganan aplikasi** (3 Oktober 2026): Play memakai **kunci buatan
  Google**, bukan kunci rilis lama. Saran awal di sini adalah memakai kunci lama lewat
  PEPK, tapi unggahan pertama terjadi dengan kunci Google, dan kunci app signing tidak
  bisa diganti dengan cara biasa. Akibatnya:
  - `ruang-tilawah-release.jks` sekarang hanya **kunci upload** Play.
  - APK GitHub (kunci lama) **tidak bisa diperbarui langsung** ke versi Play. Pengguna
    harus mencopot versi GitHub dulu, dan data lokal hilang kecuali sudah disinkron.

  | Kunci | SHA-1 | SHA-256 |
  | --- | --- | --- |
  | App signing Play (Google) | `ED:D3:47:CC:75:1B:8C:86:20:EB:AA:FE:B6:40:7E:1C:90:2A:0B:24` | `44:B6:3B:3C:…:47:66:DC:25` |
  | Upload / APK GitHub (`CN=Ruang Tilawah`) | `F4:BA:11:D8:…:9E:8A:3A:54` | `3A:F7:E6:FD:…:24:D8:FE:AA` |

  SHA-1 dan SHA-256 di atas dibaca langsung dari APK universal yang ditandatangani Play
  (`apksigner verify --print-certs`), bukan disalin dari layar.
- [x] **Daftarkan kunci Play di dua tempat** (sudah, 3 Oktober 2026). Kalau salah satu
  terlewat, **Masuk dengan Google gagal** di aplikasi yang dipasang dari Play:
  1. Firebase Console › Project settings › Android app `com.zainularkaan.quran` ›
     *Add fingerprint*: tambahkan SHA-1 dan SHA-256 kunci Play.
  2. Google Cloud Console › APIs & Services › Credentials › API key Android
     (`current_key` di `google-services.json`) › *Application restrictions › Android
     apps*: tambahkan `com.zainularkaan.quran` + SHA-1 kunci Play.

  Kalau langkah 2 terlewat, jendela akun Google tetap muncul, tapi Firebase Auth gagal
  dengan kode `unknown`. Server mengembalikan
  `403 API_KEY_ANDROID_APP_BLOCKED`. Cara mengeceknya tanpa HP: kirim `POST`
  `accounts:signInWithIdp` dengan header `X-Android-Package` dan `X-Android-Cert`. SHA
  yang belum terdaftar mendapat 403, sedangkan SHA yang terdaftar mendapat
  `INVALID_IDP_RESPONSE` untuk token palsu.

  `google-services.json` **tidak perlu** diunduh ulang dan aplikasi **tidak perlu**
  di-build ulang. Login memakai client Web yang tidak berubah. Sudah diuji: 1.10.1 (21)
  dari Internal testing di Samsung SM-A556E berhasil masuk.
- [x] **Kebijakan privasi & halaman hapus akun**: deploy `hosting/public/` yang sudah
  diperbarui (privasi versi 2 Oktober 2026 + halaman baru `hapus-akun.html`):
  `firebase deploy --only hosting`. Lalu cantumkan di Play Console:
  - Privacy policy: `https://quran-app-zainularkaan.web.app/privacy`
  - Data safety › *Delete account URL*: `https://quran-app-zainularkaan.web.app/hapus-akun`
    (bisa dipakai tanpa memasang aplikasi, lewat email `zainaril13@gmail.com`)

  Deploy 3 Oktober 2026 dari worktree `rilis/1.10.1`, sehingga yang tayang adalah privasi
  versi 1.10.1 (tanpa lokasi otomatis). Saat 1.11.0 dirilis, deploy ulang dari
  `fitur/v6` / `main`.
- [ ] **Verifikasi developer Android** (lihat bagian 2a). APK MyQuran juga dibagikan
  lewat GitHub Releases, jadi package-nya wajib didaftarkan manual.
- [x] **Backup keystore** `C:/Users/USER/keystores/ruang-tilawah-release.jks` dan
  `android/key.properties` (sudah di OneDrive sejak 23 September 2026). Kunci ini menjadi
  kunci upload Play; kehilangannya berarti harus mengajukan reset kunci ke Google.

## 2a. Verifikasi developer Android

Sumber: https://developer.android.com/developer-verification (dicek 2 Oktober 2026).

- Mulai **30 September 2026**, perangkat Android tersertifikasi (Android 7+) di
  **Brasil, Indonesia, Singapura, dan Thailand** hanya memasang aplikasi dari developer
  yang terverifikasi. Pemberlakuan global menyusul pada 2027.
- Google Play mendaftarkan otomatis sebagian besar aplikasi yang **hanya** ada di Play.
  Aplikasi yang **juga dibagikan di luar Play**, termasuk APK di GitHub Releases, harus
  didaftarkan manual di Play Console.
- Langkah pemilik:
  1. Selesaikan verifikasi identitas akun developer di Play Console.
  2. Daftarkan package `com.zainularkaan.quran` di bagian *Android developer
     verification* Play Console, dengan kunci penandatanganan yang sama dengan APK
     GitHub (`F4:BA:11:D8:…`, bukan kunci app signing Play).
  3. Setelah terdaftar, uji pasang APK GitHub di HP Android Indonesia. Pemasangan harus
     berjalan tanpa peringatan "developer tidak terverifikasi".

## 2b. Closed testing: 12 penguji × 14 hari berturut-turut

Wajib untuk akun developer pribadi baru sebelum bisa mengajukan Production.

1. Play Console › Testing › **Closed testing** › buat track (mis. "Penguji awal").
2. Tambahkan penguji: daftar email (minimal 12 akun Google) atau satu Google Group.
3. Unggah `app-release.aab` 1.10.1 (21) ke track itu, isi catatan rilis, kirim untuk
   ditinjau.
4. Setelah disetujui, bagikan *opt-in link* ke penguji. Setiap penguji harus menekan
   "Become a tester", lalu memasang aplikasi dari Play Store.
5. **Saat mengajukan Production, minimal 12 penguji harus sedang ikut dan sudah ikut
   tanpa putus selama 14 hari sebelumnya.** Penguji yang ikut kurang dari 14 hari lalu
   keluar tidak dihitung. Siapkan cadangan 2–3 orang.
6. Pembaruan selama masa tes (mis. 1.11.0 = v6) diunggah ke track yang sama. Panduan
   Play tidak menyebut bahwa pembaruan mengulang hitungan; syaratnya hanya pada penguji
   yang ikut tanpa putus.
7. Setelah syarat terpenuhi: Dashboard › **Apply for production**. Isi tiga bagian:
   "About your closed test", "About your app/game", dan "About your production
   readiness".

Sumber: https://support.google.com/googleplay/android-developer/answer/14151465
(dicek 2 Oktober 2026).

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
| App activity (riwayat baca, bookmark, tanggal Sesi hari ini selesai) | Ya, opsional | Tidak | Sinkronisasi antar perangkat |
| Device or other IDs | Ya, opsional | Tidak | ID perangkat acak untuk sesi baca yang disinkron |
| Approximate location | Ya, **opsional** (mulai 1.11: Waktu salat mode Otomatis) | Tidak | Fungsi aplikasi (jadwal salat). Koordinat dibulatkan ke kisi 0,025° (±3 km; sel ≥ 3 km² = definisi *approximate* Play) lalu dikirim ke AlAdhan saat pengguna menekan "Pakai lokasi sekarang"; "tidak dibagikan" mengikuti pengecualian Play *user-initiated action* (pengguna diberi tahu di layar). Kiblat tetap dihitung di perangkat |
| Precise location | Tidak dikumpulkan | — | Koordinat presisi tidak pernah keluar dari perangkat |
| Audio (rekaman) | Tidak dikumpulkan | — | Rekaman hafalan dan Sesi hari ini hanya di perangkat, tidak pernah diunggah |

Kapan diubah di Play Console: baris *Approximate location* hanya berlaku untuk build
yang memuat Waktu salat v6 (1.11, `fitur/v6`). Ubah formulir Data safety **bersamaan**
dengan unggahan 1.11, dan deploy `hosting/public/privacy.html` versi ini
(`firebase deploy --only hosting`) di hari yang sama. Build 1.10.x tidak mengirim
lokasi, jadi formulir & halaman privasi 1.10.1 tetap benar sampai saat itu.
Sumber definisi: https://support.google.com/googleplay/android-developer/answer/10787469
(*Approximate location* = area ≥ 3 km²; *sharing* tidak termasuk transfer berdasarkan
aksi yang dimulai pengguna).

Enkripsi saat transit: **Ya** (HTTPS). Pengguna bisa meminta penghapusan data: **Ya**
(Saya › kartu profil › Hapus akun & data cloud). Penghapusan juga bisa diminta tanpa
aplikasi, lewat https://quran-app-zainularkaan.web.app/hapus-akun (email ke
`zainaril13@gmail.com`, diproses paling lambat 30 hari).

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
