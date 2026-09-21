# Progres implementasi

## Selesai dan terhubung ke aplikasi

- Sinkronisasi cloud opsional (rincian di `docs/CLOUD_SYNC.md`): Firebase project `quran-app-zainularkaan` (Spark), Firestore Jakarta, Google Sign-In. Outbox sesi idempoten, tarik berbasis cursor `syncedAt`, penggabungan waktu tumpang-tindih antar perangkat, bookmark last-write-wins dengan tombstone, klaim data tamu, pemisahan data saat ganti akun, keluar, dan hapus akun beserta data cloud. Tidak ada statistik di server. Security rules ter-deploy setelah 29 test emulator lulus. applicationId kini `com.zainularkaan.quran`.

- Terjemahan Indonesia `id.indonesian` dibundel offline dari Tanzil (penerjemah Kementerian Agama RI, pembaruan 4 Juni 2010, SHA-256 tercatat), divalidasi per verseKey terhadap manifest; Reader tidak lagi membutuhkan internet untuk terjemahan. Syarat Tanzil: non-komersial.
- Murottal per ayat (Alafasy, `ar.alafasy`, streaming dari cdn.islamic.network), dipetakan melalui `globalAyahNumber`. Satu player dengan playlist per surah (`AudioQueue`): ▶ pada kartu memutar berurutan mulai ayat itu; mini-player Reader berisi sebelumnya/putar-jeda/berikutnya, mode Putar berurutan / Ulangi ayat / Ulangi rentang (pilih dari–sampai), dan tutup. Ayat aktif diambil dari indeks player sebenarnya, disorot, dan layar mengikuti. Mini-player tampil juga di atas navigasi utama (ketuk judul untuk kembali ke ayat), dan `audio_service` 0.18.19 menyediakan kontrol notifikasi/layar kunci/headset serta playback saat layar mati melalui foreground service `mediaPlayback`.

- Shell Flutter native dengan navigasi Beranda, Qur’an, Progres, dan Pengaturan.
- Sacred Serenity diterapkan pada Beranda, daftar surah, Reader, Progres, Pengaturan, Bookmark, dan navigasi: token resmi emerald/ivory/gold, layering tonal, garis batas lembut, spacing mobile 20 px, serta light/dark mode.
- Liquid glass native dipakai terbatas pada navigation bar dan panel statis Pengaturan/Bookmark. Blur tidak dipakai untuk list ayat/surah agar scrolling tetap ringan.
- Katalog navigasi 114 surah dengan pencarian nama/nomor dan filter tempat turunnya.
- Tab Juz berisi 30 batas Tanzil tervalidasi; setiap pilihan membuka Reader pada surah dan ayat awal Juz.
- Teks Arab Uthmani Tanzil offline (6.236 ayat) dengan font Amiri, manifest runtime, checksum, dan atribusi di `DATASET_ATTRIBUTION.md`.
- Reader RTL lazily rendered, ukuran huruf Arab tersimpan, bookmark lokal dengan koleksi Umum/Hafalan/Favorit, lanjut baca hingga ayat terakhir yang terlihat, tombol buka nomor ayat, mode fokus, serta status offline/error yang jelas.
- Target 5/10/15/30 menit, tracker foreground lokal, snapshot target per tanggal, jeda saat tidak aktif, dan tampilan statistik/streak lokal dasar.
- Sesi baca lokal (`ReadingSession`): UUID v4, ID perangkat pseudonim, waktu mulai/selesai UTC, detik aktif monotonik, zona IANA, tanggal lokal, ayat terakhir, `syncStatus: local`. Satu sesi per rentang aktif per tanggal; berakhir saat jeda, aplikasi ke latar, konfirmasi "Masih membaca?", keluar Reader, atau lewat tengah malam. Total harian dihitung ulang dari total lama (dimigrasi sekali) + jumlah sesi, sehingga menyimpan ulang sesi yang sama idempoten.
- Aturan streak bagian 6 dipisah menjadi `StreakCalculator` murni: satu kenaikan per hari, status *pending* hari ini bila kemarin tercapai, reset setelah hari terlewat, longest tetap. Split tengah malam memakai `splitActiveSeconds`. Beranda menampilkan chip rentetan + sisa menit saat pending; Progres menampilkan strip 7 hari terakhir.
- Jadwal lima waktu salat dan kalender Hijriah dari AlAdhan; kota dapat diubah pengguna. Pengingat salat dipasang hingga 14 hari ke depan dan pengingat tilawah berulang harian setelah izin notifikasi diberikan.
- Layar berita Islam memakai GDELT DOC API gratis tanpa API key untuk artikel berbahasa Indonesia; endpoint backend yang lebih terkurasi tetap dapat dikonfigurasi saat build.
- APK debug dan APK release berhasil dibangun pada 20 September 2026. Artefak release lokal: `build/app/outputs/flutter-apk/app-release.apk` (57.5 MB, SHA-256 `7BC53F14EC2EAB58929867A07F91687CE2F05A810095718ADD6D6080758D83B2`). Release saat ini masih memakai konfigurasi signing debug proyek, sehingga bukan artefak Play Store.

## Bukti pemeriksaan terbaru

- 22 September 2026 (sync cloud): `flutter test` lulus 61 test termasuk `test/cloud_sync_test.dart` (12 skenario sync dengan remote palsu); `firestore-tests` lulus 29 test rules di emulator (isolasi akun A/B, larangan stats klien, validasi sesi/bookmark); `flutter analyze` tanpa error/warning; `flutter build apk --debug` sukses (plugin Kotlin dinaikkan ke 2.3.21 karena firebase-auth 24.2). Rules dan index ter-deploy ke produksi. Login Google belum diuji di perangkat karena provider Google belum diaktifkan di Console.

- 21 September 2026 (sesi baca): `flutter test` lulus 49 test termasuk `test/reading_session_test.dart`; `flutter analyze` tanpa error/warning (27 info); `flutter build apk --debug` sukses. Tracker dengan jam nyata belum diuji di perangkat (pause/background/tengah malam).

- 21 September 2026 (ikon & legacy): `surah_details_screen.dart` dihapus (tidak diimpor di mana pun). Notifikasi murottal dan pengingat memakai ikon monokrom `ic_stat_quran` dengan `res/raw/keep.xml`. `flutter analyze` tanpa error/warning (36 info), `flutter test` lulus 38 test, `flutter build apk --debug` dan `--release` sukses; nama resource ada di `resources.arsc` APK release.

- 21 September 2026 (terjemahan offline): `flutter test` lulus 38 test termasuk `test/translation_test.dart`; `dart analyze lib test` tanpa error/warning (62 info lama); `flutter build apk --debug` sukses dan APK memuat aset terjemahan 1.159.449 byte.

- 21 September 2026 (audio latar belakang): `flutter test` lulus 29 test, `dart analyze lib test` tanpa error/warning (64 info lama), `flutter build apk --debug` sukses, dan manifest hasil merge memuat `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `AudioService`, dan `MediaButtonReceiver`. Belum diuji di perangkat.

- 21 September 2026 (antrean audio): `flutter test` lulus 29 test termasuk `test/audio_queue_test.dart`; `flutter analyze` tanpa error/warning (64 info lama); `flutter build apk --debug` sukses. Tidak ada perangkat Android tersambung, jadi playback berurutan, rentang, dan auto-scroll belum diuji di perangkat.

- 21 September 2026 (audio): nomor ayat global diverifikasi ke `api.alquran.cloud` untuk 1:1, 2:1, 2:255, 9:1, 27:30, 114:6 dan dijadikan test `globalAyahNumber`. `QuranAudioService` diperbaiki: token generasi mencegah race antar-ayat, state mengikuti player saat dijeda sistem/selesai/error, batas waktu load 20 detik, indikator buffering di tombol putar. `flutter test` lulus 24 test. Belum diuji di perangkat.

- 21 September 2026: `flutter test` lulus 23 test, termasuk `test/streak_test.dart` (299/300 detik, cicil 2+3 menit, contoh pending/putus panduan, kabisat, pergantian tahun, snapshot target, tanggal masa depan, split tengah malam, jam mundur). `dart analyze` pada file yang diubah: `No issues found`. Belum diuji di perangkat.

- `dart format` dijalankan pada file UI dan test yang diubah.
- `flutter pub get` berhasil setelah perbaikan registrasi plugin splash Android.
- `dart analyze` untuk komponen liquid glass, navigation, Pengaturan, dan Bookmark selesai dengan `No issues found`.
- `assembleRelease` sukses; 232 task diproses dan artefak APK release terbentuk.
- `flutter test --no-pub test/widget_test.dart --reporter expanded` lulus: pencarian/filter Surah, tab Juz, validasi metadata Juz, dan snapshot streak.

## Belum selesai / blocker yang tidak boleh diklaim selesai

- Keputusan edisi terjemahan (Tanzil 2010 vs revisi Kemenag 2019), izin bila aplikasi menjadi komersial, serta review konten manusia.
- Lisensi (diperiksa 21 September 2026, rincian di `DATASET_ATTRIBUTION.md`): terjemahan hanya boleh non-komersial dan edisinya belum teridentifikasi; audio boleh di-streaming/unduh untuk pemakaian pribadi; tanda tashih LPMQ untuk mushaf digital perlu dikonfirmasi sebelum rilis di Indonesia.
- Audio: belum diuji di perangkat: notifikasi dan tombol layar kunci/headset, layar mati lama, panggilan masuk, headphone dicabut, Android 12+ melanjutkan dari jeda saat aplikasi di latar belakang, serta iOS (butuh macOS/Xcode).
- Backend berita HTTPS dan kunci GNews belum dikonfigurasi/deploy. Aplikasi tetap dapat memuat berita dari GDELT, tetapi backend kurasi belum tersedia.
- Sync: aktifkan provider Google di Firebase Console, perbarui `google-services.json`, lalu uji masuk/sinkron/keluar/hapus akun di dua perangkat nyata. Perubahan zona waktu belum ditunda ke hari berikutnya (hari mengikuti zona perangkat saat membaca).
- Rencana khatam berbasis unit edisi tervalidasi, sync/auth/outbox/rules.
- Uji perangkat nyata: 200% font, screen reader, airplane mode, reader panjang, dan metrik profile/release 60 FPS.
- applicationId produksi, keystore sendiri, signing release, privacy policy, store data safety, serta persetujuan rilis.

## Tahap berikutnya

1. Tambahkan test deterministik untuk bookmark, last read, streak, dan aksesibilitas Reader.
2. Uji pengingat pada perangkat nyata, termasuk setelah reboot dan mode hemat baterai.
3. Siapkan backend berita HTTPS dan konfigurasi signing rilis saat kredensial tersedia.
