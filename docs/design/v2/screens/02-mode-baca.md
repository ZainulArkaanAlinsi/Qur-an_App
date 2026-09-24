# 02-mode-baca — ModeBaca

**Gambar acuan:** `screens/V2-ModeBaca.png`  
**HTML acuan:** `html/V2-ModeBaca.html`  
**File kode terkait:** lib/screens/reader_screen.dart (sheet baru)

## Tujuan
Satu tempat untuk memilih cara membaca: persis mushaf, dua halaman, atau kartu per ayat.

## Tata letak (atas → bawah)
1. Bottom sheet di atas pembaca yang diredupkan, radius atas 28, grabber.
2. Judul "Tampilan baca" + tautan Selesai.
3. 3 kartu mode sejajar: 1 Halaman (persis mushaf, tanpa terjemahan), 2 Halaman (miringkan HP), Kartu ayat (dengan terjemahan). Terpilih = cincin CTA 2px.
4. Grup: Tajwid berwarna (toggle, subjudul "Standar warna Kemenag"), Legenda warna (›).
5. KERTAS: Gading / Sepia / Malam.

## Konten & data
- Pilihan tersimpan & dipakai sebagai mode bawaan; posisi baca (surah:ayat/halaman) tetap saat berganti mode.

## Batasan
- Mode 1 & 2 tidak pernah menampilkan terjemahan.

## Selesai jika
- Golden 390×844 terang mirip acuan (selisih hanya karena data nyata).
- Tidak ada teks terpotong/overflow di text scale 1.0 dan 2.0.
- `flutter analyze` bersih, test lulus.
