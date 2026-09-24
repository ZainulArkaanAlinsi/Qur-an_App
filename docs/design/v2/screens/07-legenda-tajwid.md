# 07-legenda-tajwid — Legenda

**Gambar acuan:** `screens/V2-Legenda.png` · gelap: `screens/V2-Legenda-Gelap.png`  
**HTML acuan:** `html/V2-Legenda.html`  
**File kode terkait:** lib/features/tajweed/presentation/*

## Tujuan
Menjelaskan arti setiap warna di mushaf.

## Tata letak (atas → bawah)
1. ‹ Mushaf, LargeTitle "Warna tajwid", paragraf penjelasan singkat.
2. Grup HUKUM HURUF / HUKUM PANJANG / LAINNYA; tiap baris: titik warna, nama hukum, contoh kata berwarna di kanan.

## Konten & data
- Contoh kata diambil dari dataset dengan rujukan ayat (bukan diketik).

## Batasan
- Warna sama persis dengan yang dipakai di mushaf.

## Selesai jika
- Golden 390×844 terang & gelap mirip acuan (selisih hanya karena data nyata).
- Tidak ada teks terpotong/overflow di text scale 1.0 dan 2.0.
- `flutter analyze` bersih, test lulus.
