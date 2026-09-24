# 04-mushaf-2-halaman — Mushaf2

**Gambar acuan:** `screens/V2-Mushaf2.png`  
**HTML acuan:** `html/V2-Mushaf2.html`  
**File kode terkait:** lib/features/mushaf/*

## Tujuan
Membaca dua halaman sekaligus saat HP dimiringkan, seperti mushaf yang dibuka.

## Tata letak (atas → bawah)
1. Landscape 844×390. Halaman ganjil di KANAN, genap di KIRI (contoh 603 kanan, 604 kiri). Bayangan lipatan di tengah.
2. Tiap halaman sama persis dengan mode 1 halaman, hanya diperkecil.
3. Tombol kecil kembali ke 1 halaman di pojok.

## Konten & data
- Geser kanan→kiri untuk maju dua halaman.

## Batasan
- Kalau lebar halaman < 230 dp, kembali ke 1 halaman.
- Tanpa terjemahan.

## Selesai jika
- Golden 390×844 terang mirip acuan (selisih hanya karena data nyata).
- Tidak ada teks terpotong/overflow di text scale 1.0 dan 2.0.
- `flutter analyze` bersih, test lulus.
