# 13-qari — Qari

**Gambar acuan:** `screens/V2-Qari.png`  
**HTML acuan:** `html/V2-Qari.html`  
**File kode terkait:** lib/screens/reciter_picker.dart

## Tujuan
Memilih qari dari banyak pilihan dan mendengar contohnya.

## Tata letak (atas → bawah)
1. ‹ Saya, LargeTitle Qari + "Riwayat Hafs · N qari", search, segmented Semua/Murattal/Mujawwad/Muallim.
2. Baris: inisial bulat, nama (1 baris), subjudul nama Arab · gaya · bitrate · sumber, tombol dengar, centang terpilih.

## Konten & data
- Sumber: Al Quran Cloud + EveryAyah (+ Quran Foundation bila ada). Setiap qari diverifikasi URL-nya dulu.

## Batasan
- Riwayat selain Hafs & audio terjemahan tidak masuk daftar.

## Selesai jika
- Golden 390×844 terang mirip acuan (selisih hanya karena data nyata).
- Tidak ada teks terpotong/overflow di text scale 1.0 dan 2.0.
- `flutter analyze` bersih, test lulus.
