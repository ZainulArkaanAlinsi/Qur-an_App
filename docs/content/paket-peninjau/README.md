# Paket peninjauan materi tajwid dan panduan rekaman

Folder ini berisi bahan untuk menerbitkan dua hal yang saat ini terkunci di rilis, **dengan cara yang
sesuai aturan proyek** (`docs/RELIGIOUS_CONTENT_GOVERNANCE.md`): materi hukum tajwid tahap 6–16 dan
contoh bunyi (audio).

## Yang perlu diketahui lebih dulu

- Materi tahap 6–16 **ditulis oleh asisten AI** atas permintaan pemilik (tercatat di `provenance` tiap
  pelajaran di `assets/learn/curriculum.json`). Paket ini mengatakannya terus terang kepada peninjau.
  Isinya tidak boleh dianggap benar sebelum diperiksa guru.
- Skrip pengekspor **tidak menulis atau mengubah isi agama**. Teks pelajaran disalin apa adanya. Ayat
  contoh diambil dari dataset Tanzil dengan fungsi pemecah kata yang sama dengan aplikasi
  (`exampleWords`), jadi kata yang diberi warna kuning sama dengan yang tampil di layar.
- Bagian yang hanya boleh ditulis guru (penjelasan cara membaca tiap hukum) sengaja dibiarkan kosong.
- Paket ini **belum membuktikan materinya benar**. Ia hanya memudahkan guru memeriksanya.

## Isi folder

| Berkas | Untuk siapa | Isi |
| --- | --- | --- |
| `paket-peninjau-tajwid-tahap-6-16.pdf` (dan `.html`) | Dua guru tajwid | 505 butir dari 11 tahap, nama 17 hukum, formulir penjelasan yang diisi guru, lembar pengesahan. 109 halaman. |
| `panduan-rekaman-audio.pdf` (dan `.html`) | Guru yang akan merekam | 11 slot audio, saran teknis, templat surat izin. |

Guru boleh memeriksa per tahap, tidak harus sekaligus. Foto atau pindaian lembar yang sudah diisi sudah
cukup; sebut nomor butir (mis. `T10.07`).

## Alur dari serah terima sampai terbit

1. Serahkan PDF ke **dua** guru Al-Qur'an/tajwid yang kompeten dan independen.
2. Kumpulkan lembar yang sudah diisi. Butir bertanda **Perbaiki** atau **Salah** diperbaiki dengan
   kata-kata dari guru, bukan oleh AI, lalu diubah di `assets/learn/curriculum.json`.
3. Bila dua peninjau menyetujui **seluruh butir satu tahap**, ubah tahap itu di `curriculum.json`:
   ```json
   "review": "published",
   "reviewers": [{"name": "...", "qualification": "..."}, {"name": "...", "qualification": "..."}],
   "reviewedAt": "2026-12-01"
   ```
   Perbarui juga `provenance` agar jujur menyebut siapa yang memeriksa dan kapan.
4. Jalankan `flutter analyze` dan `flutter test`. `test/curriculum_review_gate_test.dart` akan gagal bila ada
   tahap 6 ke atas yang terbit tanpa dua nama peninjau berbeda dan tanggal tinjauan.
5. Rilis versi baru seperti biasa (`docs/RELEASE.md`).

Penjelasan cara membaca tiap hukum (Bagian C) diisi ke `assets/learn/tajweed_explanations.json` setelah guru
menulisnya, dengan aturan yang sama (minimal dua peninjau).

## Audio

Satu slot sama dengan satu berkas; itulah model aplikasi saat ini. Langkah memasangnya ada di
`panduan-rekaman-audio.pdf`. Tes yang sama memeriksa bahwa berkas audio yang diisi benar-benar ada dan
terdaftar di `pubspec.yaml`, supaya tidak ada tautan rusak di rilis.

## Membuat ulang paket

Dari akar repo:

```
dart run tool/export_review_package.dart
```

Perintah ini menulis ulang kedua berkas `.html`. Untuk PDF, buka HTML di Chrome atau Edge lalu pilih
Cetak, Simpan sebagai PDF (ukuran A4, aktifkan "Grafik latar belakang"). Jalankan ulang setiap kali
`curriculum.json` berubah, supaya paket yang dibaca guru sama dengan yang ada di aplikasi.

## Batas yang jujur

- Bahan ini tidak menggantikan penilaian guru, dan tidak mengesahkan apa pun.
- Aplikasi belum menampilkan nama peninjau di layar. Nama tercatat di `curriculum.json` dan layar
  *Sumber dan lisensi* bila ingin dicantumkan.
- Mode mushaf 1 dan 2 halaman, serta qari tambahan, tidak dibahas di sini: keduanya menunggu izin
  sumber, bukan peninjauan guru.
