# 12-saya — Saya

**Gambar acuan:** `screens/V2-Saya.png` · gelap: `screens/V2-Saya-Gelap.png`  
**HTML acuan:** `html/V2-Saya.html`  
**File kode terkait:** lib/screens/settings_screen.dart + progress_screen.dart

## Tujuan
Profil, ringkasan progres, dan pengaturan yang rapi dalam satu tab.

## Tata letak (atas → bawah)
1. LargeTitle Saya (sekali saja — bug judul dobel harus hilang).
2. Kartu profil + 3 statistik (istiqamah, menit minggu ini, juz khatam).
3. Baris Progres lengkap ›.
4. MEMBACA: Mode bawaan, Tajwid berwarna, Terjemahan, Tema.
5. AUDIO & KEBIASAAN: Qari, Target harian, Pengingat.
6. Lanjutan (di bawah, tidak tampak di mockup): Salat, Sumber & lisensi (dinamis), Tentang & pembaruan (digabung).

## Konten & data
- Semua nilai dari pengaturan nyata.

## Batasan
- Ikon kotak berwarna memakai token, bukan hex hardcode.

## Selesai jika
- Golden 390×844 terang & gelap mirip acuan (selisih hanya karena data nyata).
- Tidak ada teks terpotong/overflow di text scale 1.0 dan 2.0.
- `flutter analyze` bersih, test lulus.
