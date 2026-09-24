# 05-kartu-ayat — Kartu

**Gambar acuan:** `screens/V2-Kartu.png`  
**HTML acuan:** `html/V2-Kartu.html`  
**File kode terkait:** lib/screens/reader_screen.dart

## Tujuan
Membaca per ayat dengan arti, dalam bahasa pilihan.

## Tata letak (atas → bawah)
1. Nav kaca: ‹ Surah, judul surah + "Kartu ayat · N ayat", tombol Aa.
2. Chip bahasa aktif ("Indonesia + English ▾") dan chip Tajwid.
3. Kartu per ayat: rosette nomor, aksi putar & bookmark, Arab 30 bertajwid (line-height 62), terjemahan berlabel kode bahasa (ID/EN) 15/22.
4. Bahasa kedua yang belum diunduh tampil sebagai baris "EN English · Saheeh International  [Unduh]".

## Konten & data
- Terjemahan Indonesia dari dataset bawaan; bahasa lain dari QuranEnc, verbatim, dengan nama penerjemah & versi.

## Batasan
- Maksimal 2 terjemahan sekaligus.

## Selesai jika
- Golden 390×844 terang mirip acuan (selisih hanya karena data nyata).
- Tidak ada teks terpotong/overflow di text scale 1.0 dan 2.0.
- `flutter analyze` bersih, test lulus.
