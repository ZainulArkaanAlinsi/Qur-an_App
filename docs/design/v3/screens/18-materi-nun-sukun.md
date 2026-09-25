# 18-materi-nun-sukun — Materi tajwid tahap 6–16 (contoh: tahap 10)

**Gambar acuan:** `screens/V3-Materi.png`, `screens/V3-Materi-Gelap.png`, `screens/V3-Materi-Mutlak.png`
**HTML acuan:** `html/V3-Materi.html`, `html/V3-Materi-Mutlak.html`
**File kode terkait:** `assets/learn/curriculum.json`, `lib/screens/lesson_screen.dart`, `lib/features/learn/`

## Tujuan
Menampilkan materi tajwid tahap 6–16 secara lengkap: penjelasan bertahap, huruf, **contoh ayat untuk tiap huruf dengan kata yang disorot**, cara melatih, kesalahan umum, dan soal latihan. Tahap 10 (nun sukun & tanwin) mengikuti urutan pemilik: izhar halqi, idgham bighunnah (pengecualian izhar mutlak), idgham bilaghunnah, iqlab, ikhfa.

## Tata letak (atas → bawah)
1. Tombol tutup, bar progres, "3/8". Lencana DRAF di debug.
2. Eyebrow "TAHAP 10 · NUN SUKUN DAN TANWIN", judul halaman (`heading` blok), teks.
3. Kartu huruf (4 sejajar; 15 huruf ikhfa → grid 5 kolom).
4. Kartu contoh: ayat Tanzil berwarna tajwid + `note`.
5. Kotak tip (hijau lembut).
6. CTA Lanjut.

## Konten
- Semua teks, huruf, contoh, dan soal berasal dari `curriculum.json`. Aplikasi tidak menambah kalimat sendiri.
- Kata yang disorot berasal dari field `words` (DESIGN.md §6). Naskah peninjau ada di `docs/content/tajwid/`.

## Batasan
- Status tetap `draft` sampai 2 peninjau bersanad setuju (docs/RELIGIOUS_CONTENT_GOVERNANCE.md). Di rilis, tahapnya terkunci dengan "Materi sedang ditinjau".
- Jangan menaikkan status ke `published` tanpa perintah pemilik.
- Blok audio tetap `asset: null` ("Audio contoh sedang disiapkan").

## Selesai jika
- `test/curriculum_test.dart` lulus tanpa diubah (termasuk "tahap hukum tajwid belum diterbitkan").
- Golden halaman "Idgham bighunnah" (terang/gelap) dan "Pengecualian: izhar mutlak" mirip acuan.
- Kartu huruf ي dan م tidak menimpa nama hurufnya. Grid 15 huruf dan daftar ringkas 15 contoh tidak overflow di text scale 2.0.
- Unit test: `words` di luar jangkauan ditolak; indeks memakai `tanzilWords`, sama dengan mushaf.
