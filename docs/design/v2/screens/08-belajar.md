# 08-belajar — Belajar

**Gambar acuan:** `screens/V2-Belajar.png` · gelap: `screens/V2-Belajar-Gelap.png`  
**HTML acuan:** `html/V2-Belajar.html`  
**File kode terkait:** lib/screens/learn_screen.dart, learn_path.dart

## Tujuan
Jalur belajar dari nol (huruf) sampai mahir (gharib), jelas posisinya sekarang.

## Tata letak (atas → bawah)
1. LargeTitle Belajar + subjudul. Segmented Dasar / Tajwid / Mahir.
2. Kotak info emas: saran belajar berurutan + tautan tes penempatan.
3. Jalur vertikal: node 44 + garis penghubung. Tahap aktif = kartu (judul, pill "2 / 6", ringkasan, bar progres, tombol Lanjutkan).

## Konten & data
- Judul & ringkasan tahap dari assets/learn/curriculum.json. Akademi Tajwid digabung ke jalur ini (tahap 10–16), bukan layar kosong terpisah.

## Batasan
- Daftar Juz 'Amma TIDAK ada di sini (itu di Hafalan).
- Materi berstatus draf hanya tampil di debug dengan label.

## Selesai jika
- Golden 390×844 terang & gelap mirip acuan (selisih hanya karena data nyata).
- Tidak ada teks terpotong/overflow di text scale 1.0 dan 2.0.
- `flutter analyze` bersih, test lulus.
