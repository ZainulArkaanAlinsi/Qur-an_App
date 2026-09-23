# Revisi v2 — Tahap 1: pemeriksaan lisensi sebelum mode Mushaf

Diperiksa 23 September 2026. Ini bukan nasihat hukum. Tiap baris di bawah
punya kutipan verbatim dari sumbernya; yang tidak punya kutipan ditulis
**TIDAK JELAS**, bukan dilunakkan jadi "boleh".

## Kesimpulan satu kalimat

**Mode Mushaf persis cetakan tidak bisa masuk rilis sekarang**, karena
satu-satunya bahan yang wajib ada — data tata letak baris — adalah satu-satunya
bahan yang lisensinya tidak jelas. Tiga bahan lainnya justru bersih.

## Tabel keputusan

| Bahan | Untuk apa | Verdik | Boleh dibundel di APK gratis? |
|---|---|---|---|
| **QUL mushaf layout** (KFGQPC V1/V2) | Baris & kata per halaman | **TIDAK JELAS** | **Tidak, sampai ada izin tertulis** |
| KFGQPC Uthmanic Hafs (font Unicode) | Bentuk huruf | Boleh, bersyarat | Ya |
| `cpfair/quran-tajweed` (datanya) | Warna tajwid per huruf | CC BY 4.0 | Ya |
| Tanzil Uthmani (sudah dibundel) | Teks Arab | Boleh | Ya (sudah) |
| QuranEnc | Terjemahan banyak bahasa | Boleh, 7 syarat | Ya |
| `cpfair/quran-tajweed` (kodenya) | — | **Tanpa lisensi** | **Tidak** |
| Font glyph QCF per halaman | Bentuk huruf per halaman | Belum diperiksa | Jangan diasumsikan sama |

## 1. QUL mushaf layout — pemblokirnya

Halaman tiap resource layout di qul.tarteel.ai (termasuk `KFGQPC V1 layout
(1405H)` dan `KFGQPC V2 layout (1421H)`) **tidak memuat field lisensi sama
sekali** — hanya judul, deskripsi, tag, tautan unduh, dan pratinjau.

FAQ-nya sendiri melempar tanggung jawab itu ke tempat yang tidak ada isinya:

> "The resources available on QUL vary in their copyright status. Some are in
> the public domain, while others may be subject to specific licenses. We
> recommend reviewing the licensing information provided by each resource's
> author before use."

Lisensi MIT pada repo Tarteel berlaku untuk **perangkat lunak Rails**-nya, bukan
datanya. Pemegang hak hulu untuk layout KFGQPC adalah KFGQPC, dan notice KFGQPC
bersifat restriktif.

Artinya: tidak ada izin tertulis, dan tidak ada larangan tertulis. Untuk
aplikasi yang diedarkan publik, "tidak ada izin tertulis" harus diperlakukan
sebagai belum boleh. Banyak aplikasi besar memakainya, tapi praktik bukan
lisensi.

**Yang perlu Anda lakukan:** kirim email ke Tarteel atau buka issue di
`TarteelAI/quranic-universal-library`, tanyakan lisensi eksplisit untuk resource
`mushaf-layout`. Setelah ada jawaban tertulis, Tahap 1–2 bisa jalan.

## 2. KFGQPC Uthmanic Hafs — boleh, dengan dua larangan keras

Situs KFGQPC tidak bisa dijangkau, jadi EULA-nya dibaca langsung dari **name
table di dalam berkas fontnya** (name ID 13), yang justru lebih otoritatif:

> "Permission is hereby granted, Free of Cost, to any person obtaining a copy of
> this Font accompanying this license, the rights to Use, Copy, Distribute,
> subject to the following conditions:
> 1. The Font Software cannot be Sold, Modified, Altered, Translated, Reverse
> Engineered, Decompiled, Disassembled, Reproduced or Attempted to discover the
> Source Code of this Font in no means."

Konsekuensi teknis yang mengikat kita:

- **Jangan subset font.** Jangan konversi TTF → WOFF2/OTF. Jangan ganti nama
  family. Bundel berkas TTF aslinya apa adanya.
- Ada ketegangan harfiah antara "Copy, Distribute" yang diizinkan dan
  "Reproduced" yang dilarang. Pembacaan wajarnya: yang dilarang adalah
  mereproduksi **desain** typeface-nya, bukan menyalin berkasnya. Itu tafsir,
  bukan teks lisensi — catat sebagai risiko yang diterima.

Kredit yang harus dipasang di Tentang:

> Quran text rendered with KFGQPC HAFS Uthmanic Script. Copyright (c) 2010 King
> Fahd Glorious Quran Printing Complex (KFGQPC), Al-Madinah Al-Munawarrah,
> Kingdom of Saudi Arabia. All rights reserved. Used under the KFGQPC Electronic
> End-User License Agreement.

## 3. cpfair/quran-tajweed — paling bersih, tapi ada jebakan teks

Repo **tidak punya berkas LICENSE**; pernyataannya hanya ada di README dan hanya
menyangkut **berkas datanya**:

> "This data file is licensed under a Creative Commons Attribution 4.0
> International License, while the original Tanzil.net text file linked above is
> made available under the Tanzil.net terms of use."

**Jebakannya**, dan ini penting untuk kita:

> "the encoding of the files available from Tanzil.net has changed slightly since
> the annotations were generated, so please use this copy of the Qur'an text file
> … (downloaded ca. Apr 6, 2017). If you use a different Qur'an text file, you
> must rebuild the data file from scratch (at your own risk)"

Offset anotasinya menunjuk ke **codepoint** pada salinan Tanzil April 2017. Teks
yang kita bundel adalah Tanzil Uthmani v1.0.2 yang lebih baru. Jadi anotasinya
**tidak boleh langsung ditempel** ke teks kita sebelum dicocokkan ayat per ayat —
persis pola kesalahan yang sudah dilarang ADR-2 untuk markup Quran Foundation.
Itu pekerjaan pertama Tahap 2, dan harus ada tesnya.

Kodenya (`tajweed_classifier.py`, `tree.py`) **tanpa lisensi** = hak cipta penuh.
Jangan disalin.

Atribusi:

> Tajweed annotation data by Collin Fair (cpfair/quran-tajweed), licensed under
> CC BY 4.0. Source: https://github.com/cpfair/quran-tajweed

## 4. QuranEnc — boleh dibundel, tapi menimbulkan kewajiban berkelanjutan

> "Contents of the translations can be downloaded and re-published, with the
> following terms and conditions:
> 1. No modification, addition, or deletion of the content.
> 2. Clearly referring to the publisher and the source (QuranEnc.com).
> 3. Mentioning the version number when re-publishing the translation.
> 4. Keeping the transcript information inside the document.
> 5. Notifying the source (QuranEnc.com) of any note on the translation.
> 6. Updating the translation according to the latest version issued from the
> source (QuranEnc.com).
> 7. Inappropriate advertisements must not be included when displaying
> translations of the meanings of the Noble Quran."

Syarat 3 dan 6 mengubah desain: nomor versi tiap terjemahan **wajib tampil**, dan
aplikasi **wajib punya mekanisme pembaruan** — terjemahan beku di dalam APK tanpa
jalur update melanggar syarat 6. Syarat 1 berarti `footnotes` yang dikembalikan
API harus ikut ditampilkan, tidak boleh dibuang. Syarat 5 berarti perlu jalur
lapor kesalahan; API-nya menyediakan `POST /api/v1/translations/note`.

## 5. Yang dikerjakan sebagai gantinya

Karena Tahap 1 mentok di §1, tidak ada data layout yang diunduh, dibundel, atau
dirilis. Waktunya dipakai untuk tahap yang tidak terhalang: Qari (§E), Hafalan
(§D), dan sebagian Beranda/Pengaturan (§E). Rinciannya di `docs/PROGRESS.md`.

## 6. Keputusan yang diperlukan

1. **QUL**: perlu dibantu menyusun email/issue permintaan lisensinya?
2. **Alternatif**: kalau QUL tidak menjawab, satu-satunya jalur lain yang sah
   adalah Quran Foundation lewat akun Developer Console — yang statusnya belum
   ada. Mau didaftarkan?
3. **QuranEnc**: terjemahan multi-bahasa membawa kewajiban pembaruan seumur
   aplikasi. Tetap dikerjakan, atau cukup Kemenag offline dulu?
