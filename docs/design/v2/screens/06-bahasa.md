# 06-bahasa — Bahasa

**Gambar acuan:** `screens/V2-Bahasa.png`  
**HTML acuan:** `html/V2-Bahasa.html`  
**File kode terkait:** baru: lib/screens/translation_picker.dart

## Tujuan
Memilih bahasa & penerjemah.

## Tata letak (atas → bawah)
1. ‹ Kartu, LargeTitle Terjemahan + "Pilih maksimal 2 · 67 bahasa", search, InsetGrouped: nama bahasa (asli) + penerjemah, kanan centang atau Unduh.
2. Catatan sumber di bawah.

## Konten & data
- Daftar dari API QuranEnc (cache lokal); ukuran unduhan ditampilkan saat diketahui.

## Batasan
- Tidak ada terjemahan tanpa nama penerjemah.

## Selesai jika
- Golden 390×844 terang mirip acuan (selisih hanya karena data nyata).
- Tidak ada teks terpotong/overflow di text scale 1.0 dan 2.0.
- `flutter analyze` bersih, test lulus.
