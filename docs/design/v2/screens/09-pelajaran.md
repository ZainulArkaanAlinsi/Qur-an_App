# 09-pelajaran — Pelajaran

**Gambar acuan:** `screens/V2-Pelajaran.png`  
**HTML acuan:** `html/V2-Pelajaran.html`  
**File kode terkait:** lib/screens/lesson_screen.dart, lesson_quiz_screen.dart

## Tujuan
Satu pelajaran singkat: paham → dengar → coba.

## Tata letak (atas → bawah)
1. Atas: tombol tutup, bar progres, "3/5".
2. Eyebrow tahap, judul serif 32, penjelasan 15/22 (maks 2–3 kalimat per blok).
3. Kartu huruf besar (Amiri 52) dengan nama & ciri.
4. Tombol audio contoh (atau state "sedang disiapkan").
5. Kartu LATIHAN: pertanyaan + 3 pilihan besar; jawaban benar diberi cincin hijau + penjelasan singkat.
6. Tombol Lanjut CTA di bawah.

## Konten & data
- Ciri huruf harus akurat (contoh: ب 1 titik di bawah, ت 2 titik di atas, ث 3 titik di atas).

## Batasan
- Tanpa TTS/AI untuk suara. Tanpa penilaian bacaan otomatis.

## Selesai jika
- Golden 390×844 terang mirip acuan (selisih hanya karena data nyata).
- Tidak ada teks terpotong/overflow di text scale 1.0 dan 2.0.
- `flutter analyze` bersih, test lulus.
