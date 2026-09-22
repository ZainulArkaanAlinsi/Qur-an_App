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

## Materi belajar membaca

Default: kurikulum orisinal **Belajar Membaca Al-Qur'an** (12 level di PRD),
disusun dan direview guru Al-Qur'an, audio contoh dari manusia. Nama/susunan
Iqro hanya dipakai setelah ada izin tertulis AMM.

## Admin editorial (Fase 4)

Admin mengelola pelajaran, tema, kuis, reviewer, revisi, publikasi, sumber.
Admin **tidak dapat** mengedit teks Arab Al-Qur'an (tidak ada endpoint/field
yang memungkinkannya).
