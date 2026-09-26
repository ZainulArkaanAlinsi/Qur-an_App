# Sesi hari ini: spesifikasi v5

Satu sesi sekitar 10 menit sehari yang menyambungkan fitur-fitur yang sudah ada menjadi satu jalur belajar: ulang yang lama, pelajari yang baru, lihat di ayat asli, dengar qari, tirukan, lalu bandingkan. Inilah pembeda MyQuran. Aplikasi lain punya kepingannya satu per satu, sedangkan di sini semuanya dirangkai jadi satu kebiasaan harian.

## 0. Batasan (tidak boleh dilanggar)

- **Gratis dan tanpa server.** Semua berjalan di HP. Tidak ada paket berbayar, server, atau penyimpanan cloud untuk rekaman. Paket yang dipakai hanya yang sudah ada di `pubspec.yaml`: `just_audio`, `record`, `path_provider`, `shared_preferences`.
- **Aplikasi tidak menilai bacaan.** Tidak ada skor otomatis atau AI yang "mengoreksi" bacaan (RELIGIOUS_CONTENT_GOVERNANCE). Pengguna menilai dirinya sendiri, dan aplikasi menyarankan untuk disimak guru.
- **Teks ayat dan terjemahan tidak diubah.** Penyorotan hanya di level kata (`words`, indeks sama dengan `tanzilWords`).
- **Materi draf tetap terkunci di rilis.** Sesi hanya memakai pelajaran `published`. Di build debug, materi draf boleh ikut dengan lencana DRAF.
- **Rekaman hanya di HP.** Tidak ikut sinkron cloud dan bisa dihapus pengguna kapan saja.

## 1. Alur sesi (5 langkah)

| # | Langkah | Isi | Waktu | Sumber yang sudah ada |
| --- | --- | --- | --- | --- |
| 1 | **Pemanasan** | 3–5 soal ulang dari pelajaran yang sudah dibuka. Soal yang pernah salah didahulukan, lalu yang paling lama tidak dijawab. | 1–2 mnt | `getQuizHistory`, `quiz_session.dart` |
| 2 | **Materi baru** | Potongan berikutnya dari pelajaran aktif: 1–3 blok (`text`/`tip`/`letters`) sampai kuis pertama berikutnya, lalu kuis itu. Bukan satu pelajaran penuh. | 3–4 mnt | `getLessonStep`/`setLessonStep`, `lesson_screen.dart` |
| 3 | **Temukan di ayat** | Satu ayat asli. Kata yang memuat materi hari ini disorot, dan tajwid bisa diketuk. Ada pertanyaan ringan: "Ketuk kata yang bertanwin." Jawabannya dicek dari data kata, bukan dari suara. | 1–2 mnt | `words`, `tanzilWords`, tajweed panel |
| 4 | **Dengar & tirukan** | Qari membacakan ayat itu (bisa 3× dan kecepatan 0.75). Pengguna merekam bacaannya, lalu memutar **Qari ↔ Suaraku** bergantian. | 2–3 mnt | `QuranAudioService`, `record` di `practice_screen.dart` |
| 5 | **Selesai** | Penilaian diri: "Sudah mirip" / "Masih beda". Ringkasan satu layar, tanda hari ini di istiqamah, dan saran besok. | 30 dtk | `reading_progress_service.dart` |

Aturan tambahan:

- Setiap langkah bisa dilewati, kecuali langkah 5.
- Kalau keluar di tengah sesi, lanjutkan dari langkah yang sama pada hari yang sama.
- Kalau pengguna offline dan audio ayat belum diunduh, langkah 4 berubah menjadi "Rekam saja". Qari bisa didengar nanti, dan sesi tetap dihitung selesai.

## 2. Memilih ayat untuk langkah 3–4

Urutan prioritas:

1. **Blok `example` dari pelajaran aktif** yang punya `words`. Pakai contoh yang belum pernah muncul di sesi, lalu berputar.
2. **Kalau pelajaran aktif tidak punya contoh** (tahap 1 huruf hijaiyah, tahap 2 bentuk sambung), pakai **huruf hari ini**. Satu huruf dari 28 diputar harian, sesuai urutan di `letters`/kuis. Ayatnya diambil dari Juz 30 dan Al-Fatihah: ayat pendek (≤ 8 kata) yang memuat huruf itu. Kata yang memuat hurufnya disorot.
3. **Tahap 3–5 (harakat, tanwin, sukun & tasydid)** memakai contoh yang ada. Kalau sudah habis, cari ayat Juz 30 yang katanya memuat tanda yang dipelajari:
   - tanwin: U+064B–U+064D,
   - tasydid: U+0651,
   - sukun: U+0652.

   Tanda-tanda ini sudah dicek ada di teks Tanzil repo. Tanzil tidak memakai U+06E1 atau U+08F0–08F2.

Soal pencocokan huruf (poin 2): huruf dicocokkan persis per code point. ة tidak disamakan dengan ه/ت, ى tidak disamakan dengan ي, dan أ إ ؤ ئ ٱ tidak disamakan dengan ا. Bentuk-bentuk ini materi tersendiri, jadi jangan dicampur. Sudah dicek: di Al-Fatihah + Juz 30 ada 508 ayat pendek (≤ 8 kata, tanpa basmalah pembuka), dan setiap huruf dari 28 huruf muncul di minimal 3 ayat, jadi rotasinya tidak akan buntu.

Detektor di poin 2 dan 3 adalah fungsi murni di `lib/features/session/domain/verse_picker.dart`. Uji dengan tes unit terhadap teks asli:

- setiap kata yang disorot benar-benar memuat huruf atau tandanya,
- indeks kata sama dengan `tanzilWords`,
- tidak ada ayat panjang yang terpilih.

**Yang tidak dilakukan:** menyorot per huruf. Pembentukan glif Arab membuat ketuk per huruf rapuh, jadi cukup per kata.

## 3. Bunyi huruf (celah yang perlu diisi)

Blok `audio` di tahap 1–5 masih `asset: null`, artinya **belum ada rekaman bunyi 28 huruf dan harakat.** Padahal untuk orang yang mulai dari nol, ini yang paling penting.

Cara gratis yang aman:

- Rekam sendiri bersama **guru Qur'an bersanad**, misalnya guru TPQ atau sekolah.
- Buat izin tertulis sederhana bahwa rekaman boleh dipakai di MyQuran. Simpan di `docs/lisensi/bukti/`.
- Format: satu berkas `.m4a` per huruf/suku kata, mono, 64 kbps. Total 28 huruf × (sukun + 3 harakat) masih di bawah ± 3 MB.

Selama rekaman belum ada, langkah 4 di tahap 1–2 memakai bacaan qari untuk ayat yang dipilih. Blok bunyi huruf tetap bertuliskan "Rekaman sedang disiapkan" dan tidak diganti suara sintetis (TTS).

## 4. Tampilan

- **Beranda:** kartu "Sesi hari ini" (±10 mnt, 5 titik langkah, tombol Mulai/Lanjutkan).
  - Posisinya **paling atas** kalau titik mulai onboarding = `nol` atau `tajwid`.
  - Kalau titik mulai = `hafalan`, posisinya **di bawah** kartu Lanjutkan membaca.
  - Setelah selesai, kartu berubah menjadi "Selesai hari ini ✓ · besok: <judul>".
- **Layar sesi:** satu layar penuh dengan penunjuk 5 langkah di atas (pakai gaya `_Stepper` dari `practice_screen.dart`), tombol tutup, dan tanpa tab bar.
- **Langkah 4:** dua tombol besar, **Qari** dan **Suaraku**, plus tombol rekam di tengah. Bar amplitudo sederhana diambil dari `onAmplitudeChanged` saat merekam dan disimpan sebagai daftar angka kecil, tidak perlu mendekode audio.
  - Tombol "Bergantian": Qari → Suaraku → Qari, maksimal 3 putaran.
  - Kalimat kecil: "Aplikasi tidak menilai bacaanmu. Minta guru menyimak bila bisa."
- **Pengingat:** di Saya → Pengingat, "Sesi hari ini" jadi pilihan pengingat harian. Pakai `reminder_service.dart` yang sudah ada.
- Semua warna diambil dari `SacredTokens`. Kaca hanya untuk chrome (spesifikasi v4). Layar ini diuji dengan golden terang, gelap, sepia, dan teks 2×.

## 5. Data (lokal)

| Kunci / berkas | Isi |
| --- | --- |
| `sesi.hari.<yyyy-mm-dd>` | Langkah terakhir, lessonId, ayat terpilih, selesai ya/tidak |
| `sesi.riwayatAyat` | 60 ayat terakhir yang sudah dipakai (supaya tidak berulang) |
| `sesi.nilaiDiri` | Riwayat "mirip/beda" per ayat, 90 hari |
| `<documents>/rekaman_sesi/<surah>_<ayah>_<tanggal>.m4a` | Rekaman. Otomatis dihapus setelah 30 hari kecuali disematkan. |

- Sesi selesai dihitung sebagai hari istiqamah. Aturan `StreakCalculator` ditambah, bukan diubah, dan tes lama tetap lulus.
- Sinkron cloud (kalau pengguna masuk) hanya membawa tanggal sesi selesai. Tidak membawa rekaman atau nilai diri.

## 6. Selesai kalau

- Sesi bisa diselesaikan penuh di build rilis **tanpa internet** (langkah 4 menjadi "Rekam saja") dan **dengan internet** (qari diputar).
- Tes unit `verse_picker` lulus untuk huruf 1–28, tanwin, tasydid, dan sukun.
- Tes widget alur 5 langkah lulus, termasuk lewati langkah, keluar-lanjut, dan hari berganti.
- Golden layar sesi dan kartu Beranda lulus (terang, gelap, sepia, teks 2×).
- `flutter analyze` bersih dan semua tes lama lulus. Materi draf tidak muncul di build rilis (ada tes).
- Tidak ada paket baru, tidak ada panggilan jaringan baru selain audio qari yang sudah dipakai murottal, dan rekaman tidak pernah meninggalkan HP.
