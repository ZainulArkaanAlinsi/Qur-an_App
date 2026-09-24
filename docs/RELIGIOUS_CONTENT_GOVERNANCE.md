# Tata kelola konten agama

Status: draf Fase 0 · 22 September 2026

## Prinsip

1. Teks Al-Qur'an tidak pernah diedit, dinormalisasi, atau "diperbaiki" oleh
   aplikasi, admin, maupun skrip. Data rusak ditolak, bukan ditebak.
2. Tidak ada konten agama hasil AI generatif: tafsir, terjemahan tafsir, tema
   ayat, asbabun nuzul, kesimpulan, fatwa, deteksi tajwid, skor bacaan, contoh
   pelafalan (TTS).
3. Setiap konten punya sumber bernama; isi beberapa kitab tidak dicampur tanpa
   label; perbedaan penjelasan ditampilkan jujur beserta sumbernya.
4. Manhaj: mengikuti Al-Qur'an dan Sunnah dengan pemahaman Ahlus Sunnah wal
   Jamaah, diwujudkan lewat pemilihan sumber dan reviewer, bukan label
   pemasaran.

## Field wajib setiap item konten

`sourceId`, `title`, `author`, `translator?`, `publisher/provider`, `language`,
`license`, `attribution`, `version/revision`, `checksum?`, `reviewer[]`,
`reviewStatus`, `reviewedAt`, audit trail perubahan.

## Alur status

`draft → reviewed → approved → published → archived`

- `reviewed`: diperiksa minimal satu reviewer kompeten (guru Al-Qur'an/tajwid
  untuk tajwid & belajar membaca; ustaz untuk tafsir/tema).
- `approved`: disetujui dewan reviewer (minimal 2 orang untuk konten tajwid).
- Hanya `published` yang tampil di build rilis. Build debug boleh menampilkan
  `draft` dengan label **DRAF — belum direview** yang jelas.

## Konten yang saat ini berstatus draft

| Item | Lokasi | Butuh review |
|---|---|---|
| Nama Indonesia 17 hukum tajwid | `lib/features/tajweed/domain/tajweed_rule.dart` | Guru tajwid; khususnya pemetaan `madda_permissible` → "Mad Jaiz", `madda_obligatory` → "Mad Wajib", `slnt` → "Huruf tidak dibaca", `ham_wasl` → "Hamzah Washal" |
| Palet warna tajwid "Pratinjau" | `lib/features/tajweed/presentation/tajweed_palette.dart` | Guru tajwid + uji buta warna (kontras sudah diuji otomatis) |
| Pemetaan hukum cpfair → nama Indonesia | `lib/features/tajweed/data/tajweed_repository.dart` (`cpfairRules`) | Guru tajwid; khususnya `madd_246` (mad 'aridh/lin) → "Mad Jaiz" |
| Contoh kata di layar Warna tajwid | `lib/features/tajweed/presentation/tajweed_legend_screen.dart` | Guru tajwid (teks diambil dari Tanzil, pilihan contohnya yang perlu diperiksa) |
| Penjelasan cara membaca tiap hukum (untuk pembaca awam) | `assets/learn/tajweed_explanations.json` | **Masih kosong.** Diisi guru tajwid, minimal 2 reviewer; hanya `published` dengan ≥ 2 reviewer yang tampil di build rilis (dijaga `TajweedExplanation.publishable` dan diuji). |

## Pengecualian dari pemilik

**24 September 2026.** Pemilik mengizinkan **nama hukum tajwid dan palet
warna** (berstatus draf) tampil di build rilis mulai versi 1.7.0, dengan label
**DRAF — belum direview** yang jelas di layar Warna tajwid, lembar Tampilan
baca, dan lembar penjelasan hukum. Pengecualian ini **tidak** berlaku untuk
penjelasan cara membaca: teks itu tetap wajib ditulis dan disetujui guru
tajwid sebelum tampil di rilis. Pengecualian dicabut begitu reviewer
menyetujui nama dan palet.

## Materi belajar membaca

Default: kurikulum orisinal **Belajar Membaca Al-Qur'an** (12 level di PRD),
disusun dan direview guru Al-Qur'an, audio contoh dari manusia. Nama/susunan
Iqro hanya dipakai setelah ada izin tertulis AMM.

## Admin editorial (Fase 4)

Admin mengelola pelajaran, tema, kuis, reviewer, revisi, publikasi, sumber.
Admin **tidak dapat** mengedit teks Arab Al-Qur'an (tidak ada endpoint/field
yang memungkinkannya).
