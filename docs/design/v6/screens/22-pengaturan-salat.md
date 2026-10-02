# 22-pengaturan-salat — Lokasi & cara hitung waktu salat

**Kode:** `lib/screens/prayer_screen.dart` (lembar "Ganti kota" lama diganti), `lib/services/prayer_service.dart`, `lib/services/shared_preferences_service.dart`
**Pintu masuk:** (1) Salat → baris lokasi "Ganti" · (2) Saya → Pengaturan → **Waktu salat** (baris baru) · (3) Beranda → `PrayerHorizon` status "Atur kota untuk jadwal salat" · (4) tahan lama `PrayerHorizon`.

## Kondisi sekarang (1.10.0)

Kota diketik manual (kota + negara) lalu dikirim ke AlAdhan dengan metode tetap **Kemenag RI (20)**. Tidak ada lokasi otomatis, tidak ada pilihan mazhab Asar, tidak ada koreksi menit.

## Lembar "Waktu salat" (satu lembar, `showGlassSheet` v4: kepala berkaca, isi padat)

### A. Lokasi
`SegmentedPill`: **Otomatis** | **Pilih kota**

- **Otomatis**
  - Tombol "Pakai lokasi sekarang". Izin lokasi diminta **saat tombol ditekan** dengan kalimat satu baris: "Lokasi dipakai untuk menghitung jadwal salat. Koordinat dibulatkan ±1 km dan tidak disimpan di server kami."
  - `Geolocator` (sudah dipakai kiblat), akurasi `LocationAccuracy.low` cukup.
  - Koordinat dibulatkan **2 desimal** sebelum dikirim ke `api.aladhan.com/v1/timings?latitude=..&longitude=..` (endpoint koordinat). Zona waktu diambil dari `meta.timezone`.
  - Tampilan: "Lokasi sekarang · -6,30, 107,15 · Asia/Jakarta" + "Perbarui".
  - Saat aplikasi dibuka dan mode Otomatis: bila izin masih ada, ambil posisi terakhir (`getLastKnownPosition`); kalau berpindah > 25 km dari yang tersimpan, perbarui diam-diam dan jadwalkan ulang pengingat. Tanpa izin → tetap pakai lokasi tersimpan, tidak meminta izin otomatis.
- **Pilih kota**: isian kota + negara (perilaku lama, termasuk pesan galat), ditambah daftar 5 kota terakhir dipakai.
- Izin ditolak permanen: teks "Izin lokasi ditolak. Pilih kota secara manual atau buka Pengaturan HP." + tombol buka pengaturan aplikasi.

### B. Cara hitung
- **Metode**: daftar pilihan dengan Kemenag RI sebagai bawaan dan di urutan teratas, diikuti: Muslim World League (3), Umm al-Qura Makkah (4), Egyptian General Authority (5), JAKIM Malaysia (17), MUIS Singapura (11), ISNA (2). ID mengikuti daftar resmi aladhan.com/calculation-methods — **cek ulang ID di halaman itu sebelum menulis kode**, jangan dari ingatan.
- **Asar**: Standar (Syafi'i, Maliki, Hanbali) — bawaan · Hanafi. (AlAdhan `school` 0/1.)
- Keterangan kecil: "Bawaan mengikuti Kementerian Agama RI."

### C. Koreksi menit (lanjutan, terlipat)
- Per waktu (Subuh, Dzuhur, Ashar, Maghrib, Isya): stepper −10 … +10 menit, bawaan 0. Dikirim lewat parameter `tune` AlAdhan; tampilan menunjukkan jam hasil koreksi secara langsung.
- Tombol "Kembalikan ke bawaan".

### D. Simpan
- Menyimpan → ambil ulang jadwal → jadwalkan ulang semua pengingat salat (logika yang sudah ada saat ganti kota) → `PrayerHorizon` & layar Salat ikut berubah.
- Cache jadwal memakai kunci tempat yang memuat mode + metode + asar + tune, supaya pergantian setelan tidak memakai cache lama.

## Data (tambahan `SharedPreferencesService`)

| Kunci | Isi |
| --- | --- |
| `salat.lokasi.mode` | `otomatis` / `kota` (bawaan `kota` untuk pengguna lama yang sudah punya kota) |
| `salat.lokasi.koordinat` | `"-6.30,107.15"` (sudah dibulatkan) |
| `salat.metode` | int, bawaan 20 |
| `salat.asar` | 0 / 1, bawaan 0 |
| `salat.koreksi` | `"0,0,0,0,0"` (Subuh,Dzuhur,Ashar,Maghrib,Isya) |
| `salat.kotaTerakhir` | daftar maks 5 `kota|negara` |

Tidak ikut sinkron cloud.

## Privasi (wajib diperbarui bersamaan)

- `hosting/public/privacy.html`: tambahkan bahwa mode Otomatis mengirim **koordinat yang dibulatkan ±1 km** ke AlAdhan untuk menghitung jadwal, tidak disimpan oleh MyQuran di server.
- `docs/PLAY_STORE_RELEASE.md` → Data safety: **Approximate location — dikumpulkan, opsional, tidak dibagikan, tujuan: fungsi aplikasi**. Lokasi presisi tidak dikumpulkan.
- Izin manifest: `ACCESS_COARSE_LOCATION` cukup untuk salat; `ACCESS_FINE_LOCATION` tetap hanya bila kiblat membutuhkannya (cek manifest sekarang, jangan menambah izin baru tanpa alasan).

## Selesai jika

- Tes unit: pembulatan koordinat; pembentukan URL (koordinat, method, school, tune); kunci cache berubah saat setelan berubah; pengguna lama tetap mode `kota` dengan kotanya.
- Tes widget: izin ditolak → pesan + tetap bisa pilih kota; simpan → pengingat dijadwalkan ulang (mock).
- Golden lembar: terang/gelap, teks 2.0.
- Kebijakan privasi & Data safety diperbarui di commit yang sama.
