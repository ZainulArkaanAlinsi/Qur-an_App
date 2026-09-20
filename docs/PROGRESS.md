# Progres implementasi

## Selesai dalam tahap lokal awal

- Shell native Flutter: Beranda, Qur’an, Progres, Pengaturan.
- Tema Sacred Serenity terang/gelap memakai token yang ditentukan.
- Katalog navigasi 114 surah, pencarian nama/nomor, bookmark lokal, dan lanjut baca lokal.
- Reader RTL Arab offline dengan ukuran teks tersimpan, loading/retry/error yang jelas.
- Tes widget pencarian menggantikan tes counter bawaan yang salah (masih menunggu eksekusi test yang berhasil direkam).
- Teks Arab Uthmani lokal (6.236 ayat), manifest runtime, checksum, atribusi dan font Amiri offline.
- Target 5/10/15/30 menit, tracker reader foreground lokal, progres harian dan streak lokal dasar.
- Analisis seluruh jalur kode aktif (app, data, layar aktif, dan layanan aktif) selesai dengan `No issues found` pada 20 September 2026.
- Reader memakai render lazily melalui `ListView.separated`, batas repaint per kartu ayat, dan parsing aset pada isolate agar pembukaan surah tidak memblokir UI thread.

## Belum diverifikasi / belum selesai

- Dataset terjemahan offline, lisensi font/audio, dan review konten manusia. Teks Arab offline + manifest 6.236 ayat + checksum sudah ada; lihat `DATASET_ATTRIBUTION.md`.
- Audio yang dipasangkan per `verseKey`, queue, repeat, lifecycle background, dan hak offline.
- Sesi membaca, streak, target, fake-clock test, database/migrasi, khatam, sync/auth.
- Uji perangkat, accessibility 200%, dan hasil `flutter test` yang dapat direkam. `flutter analyze` sudah 0 error, dengan 46 info legacy/non-blocking.
- Build APK belum terverifikasi: perintah build berhenti tanpa status akhir pada terminal otomasi ini dan tidak membentuk `app-debug.apk`.
- Target 60 FPS harus divalidasi dengan Flutter DevTools pada perangkat fisik target; belum ada angka FPS perangkat yang boleh diklaim.
- Streak saat ini belum memiliki UUID session, snapshot target, zona IANA, rekonsiliasi lintas tengah malam yang diuji, atau sync idempoten. Jangan anggap fitur ini siap cloud.

## Langkah berikutnya

Tambahkan dataset berlisensi dan tervalidasi sebagai sumber read-only sebelum menyatakan reader offline/produksi. Sesudah itu, migrasikan reader dari endpoint jaringan sementara ke repository konten lokal dan tambah test integritas 114 surah.
