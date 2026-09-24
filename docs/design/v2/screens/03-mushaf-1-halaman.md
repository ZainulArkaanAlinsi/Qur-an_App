# 03-mushaf-1-halaman — Mushaf

**Gambar acuan:** `screens/V2-Mushaf.png` · gelap: `screens/V2-Mushaf-Gelap.png`  
**HTML acuan:** `html/V2-Mushaf.html`  
**File kode terkait:** lib/features/mushaf/* (jadikan produksi)

## Tujuan
Membaca persis seperti mushaf cetak Madinah 15 baris ayat pojok, berwarna dan bertajwid.

## Tata letak (atas → bawah)
1. Header tipis: kembali, "Al-Ikhlas – An-Nas" + "Juz 30 · Halaman 604", tombol Aa (sheet mode).
2. Halaman kertas penuh lebar (margin 10), bingkai hijau tebal 3 + garis emas 1, rosette emas di 4 sudut, tab "JUZ 30" di tepi kanan.
3. 15 baris dari data layout (bukan dihitung ulang). Baris ayat rata kanan-kiri; baris pendek/is_centered rata tengah. Pita surah bersudut runcing isi hdrFill + garis emas ganda. Basmalah di barisnya sendiri.
4. Penanda akhir ayat: rosette emas + angka Arab-Indik.
5. Medali nomor halaman di bawah tengah.
6. Bar bawah kaca: Tajwid (tiga titik warna → legenda), Putar (CTA bulat), 2 halaman.

## Konten & data
- Mockup memakai data baris asli halaman 604 (fixture QF) + teks Tanzil + anotasi tajwid cpfair. Di aplikasi: layout QUL/QF, bukan heuristik.

## Batasan
- Tanpa terjemahan.
- Ornamen digambar sendiri, tidak menjiplak ornamen penerbit.
- Kertas malam memakai palet tajwid malam, bukan kertas terang dipaksakan.

## Selesai jika
- Golden 390×844 terang & gelap mirip acuan (selisih hanya karena data nyata).
- Tidak ada teks terpotong/overflow di text scale 1.0 dan 2.0.
- `flutter analyze` bersih, test lulus.
