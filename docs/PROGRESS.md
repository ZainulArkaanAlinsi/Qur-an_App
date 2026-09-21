# Progres implementasi

## Selesai dan terhubung ke aplikasi

- Shell Flutter native dengan navigasi Beranda, Qur’an, Progres, dan Pengaturan.
- Sacred Serenity diterapkan pada Beranda, daftar surah, Reader, Progres, Pengaturan, Bookmark, dan navigasi: token resmi emerald/ivory/gold, layering tonal, garis batas lembut, spacing mobile 20 px, serta light/dark mode.
- Liquid glass native dipakai terbatas pada navigation bar dan panel statis Pengaturan/Bookmark. Blur tidak dipakai untuk list ayat/surah agar scrolling tetap ringan.
- Katalog navigasi 114 surah dengan pencarian nama/nomor dan filter tempat turunnya.
- Tab Juz berisi 30 batas Tanzil tervalidasi; setiap pilihan membuka Reader pada surah dan ayat awal Juz.
- Teks Arab Uthmani Tanzil offline (6.236 ayat) dengan font Amiri, manifest runtime, checksum, dan atribusi di `DATASET_ATTRIBUTION.md`.
- Reader RTL lazily rendered, ukuran huruf Arab tersimpan, bookmark lokal dengan koleksi Umum/Hafalan/Favorit, lanjut baca hingga ayat terakhir yang terlihat, tombol buka nomor ayat, mode fokus, serta status offline/error yang jelas.
- Target 5/10/15/30 menit, tracker foreground lokal, snapshot target per tanggal, jeda saat tidak aktif, dan tampilan statistik/streak lokal dasar.
- Jadwal lima waktu salat dan kalender Hijriah dari AlAdhan; kota dapat diubah pengguna. Pengingat salat dipasang hingga 14 hari ke depan dan pengingat tilawah berulang harian setelah izin notifikasi diberikan.
- Layar berita Islam memakai endpoint backend yang dapat dikonfigurasi saat build; backend tersebut ditujukan memakai GNews bahasa Indonesia agar kunci API tidak dibundel dalam APK.
- APK debug dan APK release berhasil dibangun pada 20 September 2026. Artefak release lokal: `build/app/outputs/flutter-apk/app-release.apk` (57.5 MB, SHA-256 `7BC53F14EC2EAB58929867A07F91687CE2F05A810095718ADD6D6080758D83B2`). Release saat ini masih memakai konfigurasi signing debug proyek, sehingga bukan artefak Play Store.

## Bukti pemeriksaan terbaru

- `dart format` dijalankan pada file UI dan test yang diubah.
- `dart analyze lib/app lib/data lib/models lib/screens lib/services test` selesai dengan 26 info lint pada layar legacy `surah_details_screen.dart`; tidak ada error/warning pada jalur UI aktif yang diubah.
- `flutter pub get` berhasil setelah perbaikan registrasi plugin splash Android.
- `dart analyze` untuk komponen liquid glass, navigation, Pengaturan, dan Bookmark selesai dengan `No issues found`.
- `assembleRelease` sukses; 232 task diproses dan artefak APK release terbentuk.
- `flutter test --no-pub test/widget_test.dart --reporter expanded` lulus: pencarian/filter Surah, tab Juz, validasi metadata Juz, dan snapshot streak.

## Belum selesai / blocker yang tidak boleh diklaim selesai

- Terjemahan Indonesia berlisensi dan terversi, serta review konten manusia.
- Audio per `verseKey`, queue, repeat, background lifecycle, interruption, dan pemeriksaan hak offline. UI saat ini tidak menampilkan kontrol audio palsu.
- Backend berita HTTPS dan kunci GNews belum dikonfigurasi/deploy, sehingga layar berita memberi status konfigurasi sampai URL backend diberikan saat build.
- Sesi reading lengkap: UUID, snapshot target, zona IANA, split tengah malam, rekonsiliasi dan fake-clock test.
- Rencana khatam berbasis unit edisi tervalidasi, sync/auth/outbox/rules.
- Uji perangkat nyata: 200% font, screen reader, airplane mode, reader panjang, dan metrik profile/release 60 FPS.
- applicationId produksi, keystore sendiri, signing release, privacy policy, store data safety, serta persetujuan rilis.

## Tahap berikutnya

1. Tambahkan test deterministik untuk bookmark, last read, streak, dan aksesibilitas Reader.
2. Uji pengingat pada perangkat nyata, termasuk setelah reboot dan mode hemat baterai.
3. Siapkan backend berita HTTPS dan konfigurasi signing rilis saat kredensial tersedia.
