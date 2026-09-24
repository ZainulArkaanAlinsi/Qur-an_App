# 11-sesi-hafalan — SesiHafalan

**Gambar acuan:** `screens/V2-SesiHafalan.png`  
**HTML acuan:** `html/V2-SesiHafalan.html`  
**File kode terkait:** lib/screens/practice_screen.dart

## Tujuan
Menghafal satu ayat dengan langkah yang jelas.

## Tata letak (atas → bawah)
1. Atas: tutup, "An-Naba' · Ayat 3" + "Ziyadah · ayat 3 dari 1–5".
2. Stepper 5 langkah: Dengar, Baca, Tutup, Uji, Sambung (selesai = emas, aktif = CTA).
3. Kartu ayat: kata yang sudah dibuka tampil, sisanya kotak tertutup; petunjuk; tombol "Buka kata berikutnya".
4. Grup: Ulangi ayat (stepper 3×, berhenti otomatis), Rekam bacaanku (opsional, lokal).
5. Bawah: "Bagaimana hafalanmu?" Salah / Ragu / Lancar.

## Konten & data
- Hitungan ulang harus benar-benar berhenti (perbaiki bug LoopMode.all).

## Batasan
- Rekaman tidak diunggah tanpa izin eksplisit.

## Selesai jika
- Golden 390×844 terang mirip acuan (selisih hanya karena data nyata).
- Tidak ada teks terpotong/overflow di text scale 1.0 dan 2.0.
- `flutter analyze` bersih, test lulus.
