# Lisensi aset v3: semua gratis, dan ini syaratnya

Ini ringkasan, bukan nasihat hukum. Untuk data Al-Qur'an, rujukan utamanya tetap `docs/DATA_SOURCES_AND_LICENSES.md` dan `docs/DATASET_ATTRIBUTION.md`.

## 1. Logo & ikon

| Aset | Asal | Status |
| --- | --- | --- |
| Gambar logo utama & sekunder | Dibuat pemilik aplikasi dengan alat pembuat gambar pilihannya | **Cek ketentuan alat itu**: harus mengizinkan penggunaan komersial dan mengakui hak pengguna atas hasilnya. Simpan buktinya (akun, tanggal, prompt). |
| Tulisan Arab "القرآن الكريم" di logo | Dirender ulang dengan font **Amiri** (SIL OFL 1.1), lalu dilengkungkan | OFL mengizinkan font dipakai untuk membuat gambar/logo. Hasil gambarnya tidak terikat OFL. |
| Latar transparan, versi gelap, ikon adaptif, monokrom, splash | Diolah dari gambar pemilik | Milik pemilik, sama seperti gambar asalnya |

**Nama "MyQuran":** banyak aplikasi di Play Store memakai nama ini (misalnya com.tws.myquran, com.assistindo.myquran, com.kodelokus.quran). Pakai nama ini sebagai **nama tampilan**, bedakan judul toko (misalnya "MyQuran: Baca, Tajwid, Hafalan"), dan jangan meniru ikon atau warna aplikasi lain. Kalau ingin didaftarkan sebagai merek, cek dulu di PDKI (pdki-indonesia.dgip.go.id).

## 2. Font (sudah dibundel di `assets/fonts/`, semuanya SIL OFL 1.1)

| Font | Berkas lisensi |
| --- | --- |
| Plus Jakarta Sans | `OFL-PlusJakartaSans.txt` |
| EB Garamond | `OFL-EBGaramond.txt` |
| Amiri | `OFL-Amiri.txt` |
| Amiri Quran | `OFL-AmiriQuran.txt` |

Syarat OFL saat font ikut di dalam APK: teks lisensinya harus ikut disertakan. Daftarkan lewat `LicenseRegistry.addLicense` supaya tampil di halaman lisensi aplikasi. Font tidak boleh dijual terpisah.

## 3. Paket & animasi

| Paket | Lisensi | Dipakai untuk |
| --- | --- | --- |
| Flutter SDK (`AnimationController`, `PageView`, `AnimatedBuilder`) | BSD-3 | Semua animasi splash & onboarding |
| `flutter_native_splash` | MIT | Splash bawaan sistem |
| `flutter_launcher_icons` | MIT (dev dependency) | Membuat ikon |
| `shared_preferences` | BSD-3 | Menyimpan status onboarding & titik mulai |

**Tidak dipakai:** Lottie/Rive/animasi dari marketplace, ilustrasi stok, ikon berbayar. Ikon garis di desain digambar sendiri sebagai SVG/`CustomPainter`.

## 4. Data yang tampil di layar v3

| Data | Sumber | Syarat |
| --- | --- | --- |
| Teks ayat (onboarding hal. 2, contoh materi) | Tanzil Uthmani 1.0.2 (sudah dibundel) | Verbatim, atribusi + tautan ke tanzil.net |
| Terjemahan QS 2:5 (onboarding hal. 2) | Tanzil `id.indonesian` (Kemenag 2010) | **Non-komersial.** Kalau aplikasi nanti memasang iklan atau berbayar, ganti ke terjemahan yang izinnya jelas (lihat `claude/api-quran-gratis.md` di project, mis. QuranEnc) |
| Warna tajwid | Sumber tajwid yang aktif di aplikasi | Pilihan gratis yang cocok dengan teks Tanzil: `cpfair/quran-tajweed` (CC BY 4.0, wajib atribusi) |
| Materi tajwid tahap 6–16 | Penjelasan ditulis orisinal oleh asisten AI (draf), mengikuti pembagian dalam matan *Tuhfatul Athfal* dan *Al-Muqaddimah al-Jazariyyah* (karya klasik, domain publik). Tidak menyalin terjemahan atau syarah modern. Contoh ayat hanya berupa rujukan + posisi kata dari Tanzil, dicek silang dengan cpfair/quran-tajweed (CC BY 4.0) | Status draf sampai ditinjau 2 guru bersanad. Kalau aplikasi menampilkan atribusi, sebutkan cpfair/quran-tajweed (CC BY 4.0) sebagai alat bantu pemilihan contoh |

## 5. Cek kontras mockup
Dihitung dari token dengan rumus WCAG. Baris "glow penuh" adalah kasus terburuk, karena teks sebenarnya berada di bawah area glow.
| Pasangan | Rasio | Lolos 4.5:1 |
| --- | --- | --- |
| Terang: sec #5F625D di atas bg | 5.49:1 | ya |
| Terang: sec di atas glow emas penuh | 4.81:1 | ya |
| Terang: sec di atas glow mint penuh | 4.75:1 | ya |
| Terang: judul ink #1B1C1C di atas bg | 15.14:1 | ya |
| Terang: CTA ctaInk di atas cta #003527 | 13.65:1 | ya |
| Terang: Lewati priText #00513B di atas bg | 8.31:1 | ya |
| Terang: tagline goldText #7A5A0E di atas bg | 5.65:1 | ya |
| Gelap: sec #9DA79F di atas bg | 7.71:1 | ya |
| Gelap: sec di atas glow mint penuh | 6.14:1 | ya |
| Gelap: CTA #1F1A05 di atas #FED65B | 12.40:1 | ya |
| Gelap: Lewati priText #9ADDBF di atas bg | 12.28:1 | ya |
| Gelap: tagline goldText #F4D679 di atas bg | 13.44:1 | ya |

