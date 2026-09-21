# Audit awal — 20 September 2026

## Temuan

- Repo adalah aplikasi Flutter yang sudah ada; tidak dibuat ulang dari nol.
- Worktree sudah memiliki berkas tak terlacak milik pengguna (`.claude/`, `.gitattributes`, `CLAUDE.md`, dan panduan ini). Berkas tersebut tidak diubah.
- UI awal menggunakan beberapa warna hijau yang tidak konsisten, placeholder Search/Settings/Bookmarks, dan tes counter bawaan yang tidak sesuai aplikasi.
- Fallback daftar surah lama menyimpan teks Arab yang sudah rusak encoding. Fallback itu tidak lagi dipakai.
- Reader lama mengambil konten melalui endpoint publik tanpa manifest, versi, hash, atribusi, atau bundle offline. Audio lama masih memetakan URL yang belum divalidasi terhadap ayat/resource.
- Tidak ada dataset Qur’an, font Arab berlisensi, skema database, atau konfigurasi cloud yang dapat diaudit di repo.

## Baseline dan risiko

- `flutter pub get` berhasil dijalankan. Analisis jalur UI aktif selesai tanpa error; info lint tersisa berada pada layar legacy yang tidak dipakai.
- `flutter test --no-pub test/widget_test.dart --reporter expanded` lulus untuk pencarian/filter, metadata Juz, dan snapshot streak.
- Reader memakai teks Arab Tanzil Uthmani offline dengan font Amiri, checksum, dan atribusi tercatat.
- Terjemahan Indonesia berlisensi, audio per-ayat dengan resource yang tervalidasi, backend berita HTTPS, signing release, serta uji perangkat nyata masih menjadi blocker rilis publik.

## Tahap yang dikerjakan

Tahap lokal awal: shell aplikasi, navigasi V1, tampilan Sacred Serenity, katalog navigasi, bookmark/last-read lokal, pengaturan tema dan ukuran teks, serta keadaan loading/error yang jujur.

Pembaruan berikutnya menambahkan teks Arab offline Tanzil Uthmani versi 1.0.2,
font Amiri berlisensi OFL, Juz tervalidasi, progres pembacaan lokal, jadwal
salat/kalendar Hijriah, serta reminder lokal. Detail sumber ada di
`docs/DATASET_ATTRIBUTION.md`.
