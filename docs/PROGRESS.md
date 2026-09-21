# Progres implementasi

## Selesai dan terhubung ke aplikasi

- Terjemahan Indonesia (`id.indonesian`, api.alquran.cloud) dimuat online per surah dan disembunyikan bila jumlah ayat tidak cocok. Nama penerjemah/lisensi belum diverifikasi, jadi belum layak rilis.
- Murottal per ayat (Alafasy, `ar.alafasy`, streaming dari cdn.islamic.network), dipetakan melalui `globalAyahNumber`. Satu player dengan playlist per surah (`AudioQueue`): ▶ pada kartu memutar berurutan mulai ayat itu; mini-player Reader berisi sebelumnya/putar-jeda/berikutnya, mode Putar berurutan / Ulangi ayat / Ulangi rentang (pilih dari–sampai), dan tutup. Ayat aktif diambil dari indeks player sebenarnya, disorot, dan layar mengikuti. Audio berhenti saat Reader ditutup karena kontrol belum ada di luar Reader.

- Shell Flutter native dengan navigasi Beranda, Qur’an, Progres, dan Pengaturan.
- Sacred Serenity diterapkan pada Beranda, daftar surah, Reader, Progres, Pengaturan, Bookmark, dan navigasi: token resmi emerald/ivory/gold, layering tonal, garis batas lembut, spacing mobile 20 px, serta light/dark mode.
- Liquid glass native dipakai terbatas pada navigation bar dan panel statis Pengaturan/Bookmark. Blur tidak dipakai untuk list ayat/surah agar scrolling tetap ringan.
- Katalog navigasi 114 surah dengan pencarian nama/nomor dan filter tempat turunnya.
- Tab Juz berisi 30 batas Tanzil tervalidasi; setiap pilihan membuka Reader pada surah dan ayat awal Juz.
- Teks Arab Uthmani Tanzil offline (6.236 ayat) dengan font Amiri, manifest runtime, checksum, dan atribusi di `DATASET_ATTRIBUTION.md`.
- Reader RTL lazily rendered, ukuran huruf Arab tersimpan, bookmark lokal dengan koleksi Umum/Hafalan/Favorit, lanjut baca hingga ayat terakhir yang terlihat, tombol buka nomor ayat, mode fokus, serta status offline/error yang jelas.
- Target 5/10/15/30 menit, tracker foreground lokal, snapshot target per tanggal, jeda saat tidak aktif, dan tampilan statistik/streak lokal dasar.
- Aturan streak bagian 6 dipisah menjadi `StreakCalculator` murni: satu kenaikan per hari, status *pending* hari ini bila kemarin tercapai, reset setelah hari terlewat, longest tetap. Split tengah malam memakai `splitActiveSeconds`. Beranda menampilkan chip rentetan + sisa menit saat pending; Progres menampilkan strip 7 hari terakhir.
- Jadwal lima waktu salat dan kalender Hijriah dari AlAdhan; kota dapat diubah pengguna. Pengingat salat dipasang hingga 14 hari ke depan dan pengingat tilawah berulang harian setelah izin notifikasi diberikan.
- Layar berita Islam memakai GDELT DOC API gratis tanpa API key untuk artikel berbahasa Indonesia; endpoint backend yang lebih terkurasi tetap dapat dikonfigurasi saat build.
- APK debug dan APK release berhasil dibangun pada 20 September 2026. Artefak release lokal: `build/app/outputs/flutter-apk/app-release.apk` (57.5 MB, SHA-256 `7BC53F14EC2EAB58929867A07F91687CE2F05A810095718ADD6D6080758D83B2`). Release saat ini masih memakai konfigurasi signing debug proyek, sehingga bukan artefak Play Store.

## Bukti pemeriksaan terbaru

- 21 September 2026 (antrean audio): `flutter test` lulus 29 test termasuk `test/audio_queue_test.dart`; `flutter analyze` tanpa error/warning (64 info lama); `flutter build apk --debug` sukses. Tidak ada perangkat Android tersambung, jadi playback berurutan, rentang, dan auto-scroll belum diuji di perangkat.

- 21 September 2026 (audio): nomor ayat global diverifikasi ke `api.alquran.cloud` untuk 1:1, 2:1, 2:255, 9:1, 27:30, 114:6 dan dijadikan test `globalAyahNumber`. `QuranAudioService` diperbaiki: token generasi mencegah race antar-ayat, state mengikuti player saat dijeda sistem/selesai/error, batas waktu load 20 detik, indikator buffering di tombol putar. `flutter test` lulus 24 test. Belum diuji di perangkat.

- 21 September 2026: `flutter test` lulus 23 test, termasuk `test/streak_test.dart` (299/300 detik, cicil 2+3 menit, contoh pending/putus panduan, kabisat, pergantian tahun, snapshot target, tanggal masa depan, split tengah malam, jam mundur). `dart analyze` pada file yang diubah: `No issues found`. Belum diuji di perangkat.

- `dart format` dijalankan pada file UI dan test yang diubah.
- `dart analyze lib/app lib/data lib/models lib/screens lib/services test` selesai dengan 26 info lint pada layar legacy `surah_details_screen.dart`; tidak ada error/warning pada jalur UI aktif yang diubah.
- `flutter pub get` berhasil setelah perbaikan registrasi plugin splash Android.
- `dart analyze` untuk komponen liquid glass, navigation, Pengaturan, dan Bookmark selesai dengan `No issues found`.
- `assembleRelease` sukses; 232 task diproses dan artefak APK release terbentuk.
- `flutter test --no-pub test/widget_test.dart --reporter expanded` lulus: pencarian/filter Surah, tab Juz, validasi metadata Juz, dan snapshot streak.

## Belum selesai / blocker yang tidak boleh diklaim selesai

- Terjemahan Indonesia berlisensi dan terversi, serta review konten manusia.
- Audio: background service (`audio_service`) dengan kontrol notifikasi/layar kunci dan mini-player global, serta pemeriksaan hak unduh offline. Belum diuji di perangkat: panggilan masuk, headphone dicabut, layar mati.
- Backend berita HTTPS dan kunci GNews belum dikonfigurasi/deploy. Aplikasi tetap dapat memuat berita dari GDELT, tetapi backend kurasi belum tersedia.
- Sesi reading lengkap: UUID per sesi, zona IANA tersimpan, outbox dan rekonsiliasi multi-perangkat. (Snapshot target, split tengah malam, dan fake-clock test untuk perhitungan harian sudah ada.)
- Rencana khatam berbasis unit edisi tervalidasi, sync/auth/outbox/rules.
- Uji perangkat nyata: 200% font, screen reader, airplane mode, reader panjang, dan metrik profile/release 60 FPS.
- applicationId produksi, keystore sendiri, signing release, privacy policy, store data safety, serta persetujuan rilis.

## Tahap berikutnya

1. Tambahkan test deterministik untuk bookmark, last read, streak, dan aksesibilitas Reader.
2. Uji pengingat pada perangkat nyata, termasuk setelah reboot dan mode hemat baterai.
3. Siapkan backend berita HTTPS dan konfigurasi signing rilis saat kredensial tersedia.
