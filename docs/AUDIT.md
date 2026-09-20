# Audit awal — 20 September 2026

## Temuan

- Repo adalah aplikasi Flutter yang sudah ada; tidak dibuat ulang dari nol.
- Worktree sudah memiliki berkas tak terlacak milik pengguna (`.claude/`, `.gitattributes`, `CLAUDE.md`, dan panduan ini). Berkas tersebut tidak diubah.
- UI awal menggunakan beberapa warna hijau yang tidak konsisten, placeholder Search/Settings/Bookmarks, dan tes counter bawaan yang tidak sesuai aplikasi.
- Fallback daftar surah lama menyimpan teks Arab yang sudah rusak encoding. Fallback itu tidak lagi dipakai.
- Reader lama mengambil konten melalui endpoint publik tanpa manifest, versi, hash, atribusi, atau bundle offline. Audio lama masih memetakan URL yang belum divalidasi terhadap ayat/resource.
- Tidak ada dataset Qur’an, font Arab berlisensi, skema database, atau konfigurasi cloud yang dapat diaudit di repo.

## Baseline dan risiko

- `flutter pub get` berhasil dijalankan dan mengubah lockfile/generator plugin sesuai resolusi dependency saat ini. `flutter analyze` selesai dengan **0 error**, tetapi masih melaporkan 46 info dari layar legacy yang belum dipakai dan beberapa API Flutter baru.
- `flutter test test/widget_test.dart` tidak menghasilkan hasil akhir pada sesi terminal ini (proses Dart menjadi macet), sehingga test belum dapat dinyatakan lulus.
- Konten reader saat ini tetap bergantung jaringan. Ini belum memenuhi syarat offline V1 dan tidak boleh disebut siap rilis.
- Dataset, terjemahan, font, audio, dan lisensinya adalah blocker untuk rilis konten.

## Tahap yang dikerjakan

Tahap lokal awal: shell aplikasi, navigasi V1, tampilan Sacred Serenity, katalog navigasi, bookmark/last-read lokal, pengaturan tema dan ukuran teks, serta keadaan loading/error yang jujur.

Pembaruan berikutnya menambahkan teks Arab offline Tanzil Uthmani versi 1.0.2,
font Amiri berlisensi OFL, dan progres pembacaan lokal dasar. Detail sumber ada
di `docs/DATASET_ATTRIBUTION.md`.
