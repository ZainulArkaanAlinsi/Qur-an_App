# Riset Sumber — Qur'an App Revisi v2

Diperiksa 23 September 2026. Lisensi dan ketersediaan bisa berubah; cek ulang sebelum rilis.

## 1. Buku tajwid untuk kamu unduh & pelajari

Dipakai sebagai **rujukan belajar** dan bahan menulis materi aplikasi dengan bahasa sendiri. Jangan menyalin isi buku berhak cipta mentah-mentah ke aplikasi; tulis ulang, cantumkan rujukan, lalu minta ustadz/guru bersanad memeriksanya.

| Buku | Kenapa bagus | Link |
|---|---|---|
| **Pedoman Tajwid Sistem Warna** — Lajnah Pentashihan Mushaf Al-Qur'an (LPMQ) Kemenag, 2011 | Standar resmi pewarnaan tajwid di mushaf Indonesia. Pewarnaan diterapkan pada **huruf dan harakat, bukan latar**. Wajib jadi acuan warna layout Mushaf. | [PDF resmi tashih.kemenag.go.id](https://tashih.kemenag.go.id/uploads/1/2019-08/buku_pedoman_tajwid_sistem_warna.pdf) · [kajian di Jurnal Suhuf](https://jurnalsuhuf.kemenag.go.id/suhuf/article/view/587) |
| **Matan Tuhfatul Athfal** — Sulaiman al-Jamzuri (abad ke-12 H), terjemah Abu Razin Al-Batawiy | Matan klasik tajwid dasar (nun/mim sukun, mad, lam, idgham). Diajarkan di hampir semua lembaga tahsin ahlussunnah. Matannya domain publik. | [Internet Archive](https://archive.org/details/TerjemahMatanTuhfatulAthfal) |
| **Al-Muqaddimah al-Jazariyyah** — Imam Ibnul Jazari (w. 833 H) | Matan lanjutan: makharijul huruf, sifatul huruf, waqaf. Domain publik. Pasangan Tuhfatul Athfal. | (banyak edisi; minta guru merekomendasikan syarah) |
| **Tajweed Rules of the Qur'an** (3 jilid) — Kareema Carol Czerepinski, ditinjau Muhammad Abdurraouf | Paling rapi & lengkap untuk pemula sampai mahir, banyak contoh. Berbahasa Inggris. Tersedia gratis di IslamHouse. | [IslamHouse](https://islamhouse.com/en/books/396784/) · [Internet Archive](https://archive.org/details/tajweed-rules-of-the-quran-full-kareema-carol) |
| **Buku Panduan Ilmu Tajwid** — Dr. Zulkarnain Umar (repositori Universitas Islam Riau) | Bahasa Indonesia, akademik, terstruktur. | [PDF repositori UIR](https://repository.uir.ac.id/5429/1/BUKU%20PANDUAN%20ILMU%20TAJWID_Dr%20Zulkarnain%20Umar.pdf) |

Catatan: ilmu tajwid adalah ilmu riwayat bacaan Hafs 'an 'Ashim yang disepakati; tidak ada perbedaan manhaj di dalamnya. Yang perlu dijaga ketat justru konten **di luar tajwid** (doa, fadhilah, hadits) — lihat bagian 6.

## 2. Tata letak mushaf yang persis cetakan (layout 1 & 2)

Mushaf di foto (15 baris, ayat pojok, hlm. 273 = An-Nahl 55–64) tampaknya mengikuti tata letak **Mushaf Madinah KFGQPC 604 halaman**. Claude Code wajib memverifikasi dengan membandingkan beberapa halaman.

| Sumber | Isi | Link |
|---|---|---|
| **QUL — Quranic Universal Library (Tarteel)** | Layout per halaman & per baris (SQLite: `page_number`, `line_number`, `line_type` ayah/surah_name/basmallah, `is_centered`, `first_word_id`/`last_word_id`). Ada KFGQPC V1 (1405H), V2 (1421H), V4 (1441H), Indopak, dll. Lisensi **berbeda tiap resource** — cek satu per satu. | [Dokumentasi layout](https://qul.tarteel.ai/docs/mushaf-layout) · [Daftar layout](https://qul.tarteel.ai/resources/mushaf-layout) · [FAQ lisensi](https://qul.tarteel.ai/faq) |
| **Font glyph QPC V1/V2** (per halaman) | Bentuk huruf identik cetakan. Repo sudah punya prototipe V2 lewat Quran Foundation. | via Quran Foundation / QUL |
| **Font QPC V4 tajwid (COLRv1)** | Glyph berwarna per huruf. **Masalah:** Flutter belum bisa merender COLRv1 (tampil kosong di Skia & Impeller; COLRv0 didukung). | [flutter/flutter#134897](https://github.com/flutter/flutter/issues/134897) |
| **KFGQPC Uthmanic Hafs (Unicode)** | Font teks Unicode dari Mujamma' Malik Fahd; bisa diwarnai per huruf lewat TextSpan. | [nuqayah/qpc-fonts](https://github.com/nuqayah/qpc-fonts) · [Tanzil: Quranic fonts](https://tanzil.net/docs/quranic_fonts) |

Jika yang diinginkan justru **Mushaf Standar Indonesia (MSI)** Kemenag, layoutnya berbeda dan datanya harus lewat LPMQ. Distribusi mushaf digital di Indonesia juga terkait **tanda tashih LPMQ** (Permenag 44/2016) — sudah dicatat di `docs/DATA_SOURCES_AND_LICENSES.md` repo.

## 3. Data tajwid per huruf

| Sumber | Catatan | Link |
|---|---|---|
| **cpfair/quran-tajweed** | Anotasi 16 hukum tajwid sebagai rentang karakter (codepoint) di atas **teks Tanzil Uthmani** (≈ April 2017). Lisensi **CC BY 4.0**. Tidak lagi dirawat; wajib cocokkan dulu dengan file Tanzil di repo. Cocok dengan ADR repo yang melarang menempel markup Quran Foundation ke teks Tanzil. | [GitHub](https://github.com/cpfair/quran-tajweed) |
| **Quran Foundation `text_uthmani_tajweed`** | Sudah diparse di repo (`TajweedMarkupParser`). Butuh kredensial & BFF; teksnya bukan Tanzil. | — |

## 4. Qari (audio per ayat)

| Penyedia | Jumlah | Catatan | Link |
|---|---|---|---|
| **Al Quran Cloud / Islamic Network CDN** (yang dipakai sekarang) | ± 15 qari Arab + beberapa audio terjemahan | Pola: `cdn.islamic.network/quran/audio/{bitrate}/{edition}/{nomorAyatGlobal}.mp3`. Buang edisi terjemahan (en.walk, ur.khan, zh.chinese, fr.leclerc, ru.*, kk.*, uz.*) dari daftar qari. | [daftar edisi](https://api.alquran.cloud/v1/edition?format=audio&type=versebyverse) |
| **EveryAyah.com** | ± 60 folder qari Arab (murattal, mujawwad, **Husary Muallim** untuk belajar) | Pola: `https://everyayah.com/data/{Folder}/{SSS}{AAA}.mp3` (mis. `Alafasy_128kbps/001001.mp3`). Tidak ada halaman syarat pakai yang jelas → hubungi pengelola, beri atribusi. Ada juga folder **riwayat Warsh** — sembunyikan/beri label karena aplikasi memakai teks Hafs. | [daftar qari](https://everyayah.com/recitations_ayat.html) |
| **Quran Foundation (Quran.com)** | puluhan | Ada `segments` = **timestamp per kata** → sorot per kata jadi sah. Butuh kredensial (lewat BFF repo). | [Audio API](https://api-docs.quran.foundation/docs/sdk/javascript/audio/) · [recitation per surah](https://api-docs.quran.foundation/docs/content_apis_versioned/4.0.0/list-surah-recitation/) |

Contoh qari tambahan dari EveryAyah: Abdul Basit (murattal & mujawwad), Minshawi (murattal & mujawwad), Husary (murattal, mujawwad, muallim), Mahmoud Ali Al-Banna, Muhammad Jibreel, Maher Al-Muaiqly, Saud Asy-Syuraim, Abdurrahman As-Sudais, Abdullah Basfar, Abu Bakr Asy-Syatiri, Hani Ar-Rifa'i, Ali Jaber, Ahmad Al-Ajmi, Nasser Al-Qatami, Yasser Ad-Dossary, Salah Al-Budair, Fares Abbad, Muhammad Ayyub, Ali Al-Hudzaifi, Khalid Al-Qahtani, Muhsin Al-Qasim, Abdullah Al-Juhani, Salah Bukhatir, Ibrahim Al-Akhdar, Ayman Suwaid, Muhammad Al-Tablawi, Mustafa Ismail.

## 5. Terjemahan banyak bahasa (layout 3)

| Sumber | Isi | Syarat | Link |
|---|---|---|---|
| **QuranEnc (Ensiklopedia Al-Qur'an)** | **121 terjemahan, 67 bahasa**; API JSON per surah/ayat, ada nomor versi. Indonesia: `indonesian_affairs` (Kemenag), `indonesian_complex` (Mujamma' Malik Fahd), `indonesian_sabiq`. Inggris: `english_saheeh`, `english_rwwad`, `english_hilali_khan`. | Tidak boleh diubah, sebut penerbit & QuranEnc, sertakan versi, laporkan kesalahan, tanpa iklan tidak pantas. | [API](https://quranenc.com/en/home/api/) |
| Tanzil translations | Banyak bahasa | Non-komersial | — |

Rekomendasi: QuranEnc jadi sumber utama; unduh per bahasa saat dipilih (jangan dibundel semua); Kemenag 2010 dari Tanzil tetap sebagai bawaan offline.

## 6. Kebijakan konten (sesuai permintaan: tanpa bid'ah, tanpa amalan khas golongan)

- Isi aplikasi fokus: **Al-Qur'an, tajwid, hafalan, murajaah**. Tidak menampilkan doa khatam, fadhilah surah, wirid, atau amalan yang tidak punya dalil shahih.
- Kalau suatu hari menampilkan hadits: wajib ada takhrij (kitab, nomor) dan derajat shahih/hasan dari muhaddits yang diakui. Hadits dha'if/palsu tidak ditampilkan.
- Tidak ada konten amalan/perayaan khas ormas mana pun; tidak ada konten yang merendahkan kelompok lain.
- Materi tajwid mengikuti riwayat **Hafs 'an 'Ashim thariq Asy-Syathibiyyah** (standar mushaf Madinah & Indonesia), rujukan matan Tuhfatul Athfal & Al-Jazariyyah.
- Semua materi keagamaan tetap lewat alur review repo (`docs/RELIGIOUS_CONTENT_GOVERNANCE.md`): draf → minimal 2 reviewer bersanad → terbit.
