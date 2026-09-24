# 01-beranda — Beranda

**Gambar acuan:** `screens/V2-Beranda.png` · gelap: `screens/V2-Beranda-Gelap.png`  
**HTML acuan:** `html/V2-Beranda.html`  
**File kode terkait:** lib/screens/home_screen.dart

## Tujuan
Pintu masuk harian: langsung lanjut membaca, lihat target & istiqamah, lalu tugas belajar/murajaah hari ini.

## Tata letak (atas → bawah)
1. Header: tanggal Masehi (13/700) + Hijriah Indonesia satu baris (13/500 sec), kanan tombol Cari & Bookmark (40).
2. Sapaan: "Assalamu'alaikum," 15/600 sec + nama EB Garamond 38 (kalau belum login: "Sahabat Qur'an").
3. Kartu hero art (radius 28): sampul mihrab 76×98 berisi nama surah Arab, eyebrow LANJUTKAN MEMBACA, nama surah serif 30, info "Halaman · Juz · Mode". Tombol Lanjutkan (emas, lebar penuh) + tombol ikon headphones 48.
4. Grid 2 kolom: Target baca (cincin 46 + "2/5 mnt" + "3 mnt lagi") dan Istiqamah (angka + pill MENUNGGU bila hari ini belum tercapai + titik 7 hari, hari ini putus-putus).
5. Grup HARI INI (InsetGrouped): Lanjutkan belajar (cincin progres tahap) dan Murajaah hari ini (pill jumlah ayat).
6. Strip salat 54: gradien langit periode sekarang, nama + jam, pill hitung mundur.
7. Tab bar 5 tab.

## Konten & data
- Tanggal, target, istiqamah, lanjut baca, tahap belajar, murajaah jatuh tempo, jadwal salat: semua data nyata.
- Hijriah pakai nama bulan Indonesia (Muharram, Safar, Rabiulawal, Rabiulakhir, Jumadilawal, Jumadilakhir, Rajab, Syakban, Ramadan, Syawal, Zulkaidah, Zulhijah) + "H".

## Batasan
- Tidak ada baris pintasan 4 tombol (yang sebelumnya terpotong "Sur… Bel…").
- Tidak ada teks terpotong: tombol Dengarkan jadi ikon saja; bulan Hijriah tidak diulang.
- Ayat pilihan (kalau ditampilkan) dari daftar terkurasi, bukan acak.

## Selesai jika
- Golden 390×844 terang & gelap mirip acuan (selisih hanya karena data nyata).
- Tidak ada teks terpotong/overflow di text scale 1.0 dan 2.0.
- `flutter analyze` bersih, test lulus.
