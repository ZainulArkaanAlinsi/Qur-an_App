# Sinkronisasi cloud

Membaca tidak memerlukan akun atau internet. Sinkronisasi bersifat opsional:
setelah pengguna masuk dengan Google, sesi baca dan bookmark disalin ke
Firestore agar dapat dipakai di perangkat lain.

## Infrastruktur

| Komponen | Nilai |
|---|---|
| Firebase project | `quran-app-zainularkaan` (paket Spark, tanpa billing) |
| Firestore | database `(default)`, lokasi `asia-southeast2` (Jakarta) |
| Auth | Google Sign-In (`google_sign_in` 7 + `firebase_auth`) |
| Aplikasi Android | `com.zainularkaan.quran` |
| Cloud Functions | tidak dipakai |

Konfigurasi klien (`lib/firebase_options.dart`, `android/app/google-services.json`)
bukan rahasia; keamanan data ditentukan oleh `firestore.rules`.

## Struktur data

```
users/{uid}/sessions/{sessionId}
  id, deviceId, startedAt, endedAt, activeSeconds, timezone,
  localDate, mode, lastVerseKey, syncedAt (waktu server)
users/{uid}/bookmarks/{surah_ayah}
  surah, ayah, collection, deleted, updatedAtMs, syncedAt (waktu server)
```

Tidak ada statistik di server. Setiap perangkat menghitung total harian dan
streak dari sesi, sehingga tidak ada nilai authoritative yang bisa dipalsukan
klien.

## Aturan sinkronisasi

- **Outbox:** sesi yang sudah ditutup berstatus `syncStatus: local` sampai
  berhasil diunggah. Unggahan memakai ID sesi sebagai ID dokumen, jadi retry
  tidak menggandakan sesi.
- **Tarik data:** berdasarkan `syncedAt` > cursor, dengan tumpang-tindih 5
  menit untuk menangkap penulisan yang terlambat commit. Menerapkan ulang
  item yang sama tidak berpengaruh.
- **Dua perangkat bersamaan:** total harian memakai `mergedActiveSeconds`;
  waktu tumpang-tindih antar perangkat berbeda dihitung sekali. Sesi dari satu
  perangkat selalu dijumlahkan penuh.
- **Bookmark:** last-write-wins berdasarkan `updatedAtMs` (jam klien). Hapus
  meninggalkan tombstone (`deleted: true`) agar salinan lama tidak
  menghidupkannya kembali.
- **Tamu ke akun:** data lokal diklaim akun pertama yang masuk. Jika akun lain
  masuk kemudian, data cloud akun sebelumnya dihapus dari perangkat lebih dulu;
  data yang belum pernah diunggah tetap ada.
- **Keluar:** data di perangkat tetap tersedia offline.
- **Hapus akun:** menghapus semua dokumen pengguna di Firestore, lalu akun
  Firebase. Data di perangkat tetap ada dan kembali menjadi lokal.
- **Pemicu:** saat masuk, saat aplikasi kembali aktif (paling sering sekali per
  menit), saat keluar dari Reader, dan tombol **Sinkronkan** di Pengaturan.

Batasan yang diketahui:
- Total harian sebelum fitur sesi (`reading_legacy_seconds_*`) tidak diunggah.
- Konflik bookmark bergantung pada jam perangkat.
- Riwayat sesi tersimpan di SharedPreferences; untuk riwayat sangat panjang
  sebaiknya dipindah ke SQLite.

## Menguji security rules

Membutuhkan Node 20 dan Java 17+ (JBR Android Studio cukup):

```powershell
cd firestore-tests
npm install
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
npm test
```

Test menjalankan emulator Firestore dengan project demo (`demo-quran-rules`),
tidak menyentuh data produksi.

## Deploy

```powershell
firebase deploy --only firestore:rules,firestore:indexes --project quran-app-zainularkaan
```

Deploy hanya setelah `npm test` lulus.

## Langkah manual di Firebase Console

1. Authentication > Sign-in method > **Google** > Enable, pilih support email.
2. Setelah itu, perbarui konfigurasi agar memuat web OAuth client:
   `flutterfire configure --project=quran-app-zainularkaan --platforms=android --android-package-name=com.zainularkaan.quran --yes`
3. Untuk rilis: daftarkan SHA-1/SHA-256 keystore rilis
   (`firebase apps:android:sha:create <appId> <hash>`), lalu jalankan ulang
   langkah 2.
