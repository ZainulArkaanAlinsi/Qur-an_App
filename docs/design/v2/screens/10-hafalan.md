# 10-hafalan — Hafalan

**Gambar acuan:** `screens/V2-Hafalan.png` · gelap: `screens/V2-Hafalan-Gelap.png`  
**HTML acuan:** `html/V2-Hafalan.html`  
**File kode terkait:** lib/screens/memorization_screen.dart, widgets/memorization_tile.dart

## Tujuan
Menjelaskan tujuan hafalan dan menunjukkan apa yang harus dilakukan hari ini.

## Tata letak (atas → bawah)
1. LargeTitle Hafalan + target ("Juz 'Amma · 5 ayat per hari").
2. 3 kartu tujuan: Ziyadah (tambah hafalan baru), Murajaah (ulang agar tak lupa), Tasmi' (setor/uji diri).
3. Kartu hero ZIYADAH HARI INI: rentang ayat, perkiraan waktu, tombol Mulai sesi.
4. Baris Murajaah jatuh tempo + pill jumlah ayat.
5. SURAH YANG DIHAFAL: rosette nomor, nama (1 baris), "18/40 ayat", bar progres, pill status di kanan.

## Konten & data
- Status per ayat; jadwal murajaah 1→3→7→14→30 hari yang bisa dijelaskan.

## Batasan
- BUG LAMA: nama surah turun huruf per huruf. Kolom teks wajib Expanded + 1 baris; pill status intrinsik.
- Tidak ada FAB Material; tambah surah lewat tombol di header atau baris terakhir list.

## Selesai jika
- Golden 390×844 terang & gelap mirip acuan (selisih hanya karena data nyata).
- Tidak ada teks terpotong/overflow di text scale 1.0 dan 2.0.
- `flutter analyze` bersih, test lulus.
