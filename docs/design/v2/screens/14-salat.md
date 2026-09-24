# 14-salat — Salat

**Gambar acuan:** `screens/V2-Salat.png`  
**HTML acuan:** `html/V2-Salat.html`  
**File kode terkait:** lib/screens/prayer_screen.dart

## Tujuan
Jadwal salat yang jelas tanpa teks terpotong.

## Tata letak (atas → bawah)
1. ‹ Beranda, LargeTitle Salat + tombol Kiblat.
2. Lokasi + Ganti kota; baris metode & zona waktu.
3. Kartu langit mihrab 190: hitung mundur di panel bawah kiri, satu info waktu di bawah kanan. TIDAK ada teks di bagian atas lengkung (sebelumnya "Terbit/Terbenam" terpotong di sana).
4. List: kolom nama lebar tetap 88 ("Maghrib" utuh), jam tabular, pill "berikutnya", toggle adzan.
5. Baris Pengingat tilawah.

## Konten & data
- Jam dari AlAdhan sesuai kota & metode.

## Batasan
- Tidak ada elipsis pada nama waktu salat.

## Selesai jika
- Golden 390×844 terang mirip acuan (selisih hanya karena data nyata).
- Tidak ada teks terpotong/overflow di text scale 1.0 dan 2.0.
- `flutter analyze` bersih, test lulus.
