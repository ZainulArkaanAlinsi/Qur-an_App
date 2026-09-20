# Progres implementasi

## Selesai dan terhubung ke aplikasi

- Shell Flutter native dengan navigasi Beranda, Qur’an, Progres, dan Pengaturan.
- Sacred Serenity diterapkan pada Beranda, daftar surah, Reader, Progres, Pengaturan, Bookmark, dan navigasi: token resmi emerald/ivory/gold, layering tonal, garis batas lembut, spacing mobile 20 px, serta light/dark mode.
- Liquid glass native dipakai terbatas pada navigation bar dan panel statis Pengaturan/Bookmark. Blur tidak dipakai untuk list ayat/surah agar scrolling tetap ringan.
- Katalog navigasi 114 surah dengan pencarian nama/nomor dan filter tempat turunnya.
- Teks Arab Uthmani Tanzil offline (6.236 ayat) dengan font Amiri, manifest runtime, checksum, dan atribusi di `DATASET_ATTRIBUTION.md`.
- Reader RTL lazily rendered, ukuran huruf Arab tersimpan, bookmark lokal, lanjut baca per surah, mode fokus, serta status offline/error yang jelas.
- Target 5/10/15/30 menit, tracker foreground lokal, dan tampilan statistik/streak lokal dasar.
- APK debug dan APK release berhasil dibangun pada 20 September 2026. Artefak release lokal: `build/app/outputs/flutter-apk/app-release.apk` (57.5 MB, SHA-256 `7BC53F14EC2EAB58929867A07F91687CE2F05A810095718ADD6D6080758D83B2`). Release saat ini masih memakai konfigurasi signing debug proyek, sehingga bukan artefak Play Store.

## Bukti pemeriksaan terbaru

- `dart format` dijalankan pada file UI dan test yang diubah.
- `dart analyze lib/app lib/data lib/models lib/screens lib/services test` selesai dengan 26 info lint pada layar legacy `surah_details_screen.dart`; tidak ada error/warning pada jalur UI aktif yang diubah.
- `flutter pub get` berhasil setelah perbaikan registrasi plugin splash Android.
- `dart analyze` untuk komponen liquid glass, navigation, Pengaturan, dan Bookmark selesai dengan `No issues found`.
- `assembleRelease` sukses; 232 task diproses dan artefak APK release terbentuk.
- Widget test telah diperbarui untuk pencarian/filter dan integritas tampilan nama surah. Eksekusinya belum dapat direkam: proses `flutter test` pada terminal otomasi ini tidak menulis hasil dan dihentikan agar tidak menahan toolchain.

## Belum selesai / blocker yang tidak boleh diklaim selesai

- Tab Juz dengan batas ayat tervalidasi, navigasi ke ayat awal, dan pencarian terjemahan/Arab.
- Terjemahan Indonesia berlisensi dan terversi, serta review konten manusia.
- Audio per `verseKey`, queue, repeat, background lifecycle, interruption, dan pemeriksaan hak offline. UI saat ini tidak menampilkan kontrol audio palsu.
- Sesi reading lengkap: UUID, snapshot target, zona IANA, split tengah malam, rekonsiliasi dan fake-clock test.
- Rencana khatam berbasis unit edisi tervalidasi, sync/auth/outbox/rules.
- Uji perangkat nyata: 200% font, screen reader, airplane mode, reader panjang, dan metrik profile/release 60 FPS.
- applicationId produksi, keystore sendiri, signing release, privacy policy, store data safety, serta persetujuan rilis.

## Tahap berikutnya

1. Bangun indeks Juz dengan boundary yang tervalidasi dan reader posisi ayat.
2. Tambahkan test deterministik untuk bookmark, last read, streak, dan aksesibilitas Reader.
3. Integrasikan terjemahan/audio hanya setelah sumber, lisensi, dan resource ID telah disetujui.
