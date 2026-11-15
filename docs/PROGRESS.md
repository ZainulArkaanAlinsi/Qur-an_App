# Progres implementasi

## Selesai dan terhubung ke aplikasi

- **Sesi hari ini (v5, `docs/design/v5-sesi-harian/`)**, 26 September 2026. Satu sesi ±10 menit dari Beranda: pemanasan 3–5 soal ulang (yang pernah salah dulu, lalu yang paling lama tidak dijawab), satu bagian materi baru dari pelajaran aktif lalu satu soal, temukan huruf/tanda di ayat asli (ketuk kata, dicek dari nomor kata `tanzilWords`), dengar & tirukan (qari satu ayat 1×/3×, kecepatan 1/0,75, rekam, Suaraku, Bergantian maks. 3 putaran, bar amplitudo), lalu penilaian diri "Sudah mirip/Masih beda".
  - Pemilih ayat murni (`lib/features/session/domain/verse_picker.dart`): huruf dicocokkan persis per code point (ة/ى/hamzah tidak disamakan), tanwin U+064B–064D, tasydid U+0651, sukun U+0652, fathah/kasrah/dhammah untuk tahap 3. Kolam ayat pendek: Al-Fatihah 2–7 + Juz 30 dengan ≤ 8 kata menurut `tanzilWords()` = **543 ayat** (spesifikasi menyebut 508; selisihnya karena spesifikasi menghitung token berspasi, sedangkan tanda waqaf di sini ikut kata sebelumnya). Setiap 28 huruf ada di ≥ 17 ayat.
  - Materi draf tidak dipakai di rilis (materi, pemanasan, dan contoh ayat); di debug tampil dengan lencana DRAF. Semua langkah bisa dilewati kecuali Selesai; keluar di tengah sesi melanjutkan langkah yang sama pada hari yang sama; sesi kemarin tidak dibawa ke hari baru.
  - Offline tanpa audio terunduh: langkah 4 menjadi "Rekam saja" dan sesi tetap selesai. Izin mikrofon baru diminta saat Rekam ditekan; ditolak pun sesi tetap bisa selesai. Antrean murottal yang sedang berjalan disimpan, dihentikan, lalu dipulihkan (tanpa diputar otomatis) setelah sesi ditutup.
  - Data lokal: `sesi.hari.<tanggal>`, `sesi.riwayatAyat` (60), `sesi.nilaiDiri` (90 hari), `sesi.rekamanSemat`, rekaman di `<documents>/rekaman_sesi/<surah>_<ayah>_<tanggal>.m4a` (dihapus otomatis > 30 hari kecuali disematkan). `QuizRecord` kini menyimpan tanggal terakhir dijawab (`t`).
  - Sesi selesai dihitung istiqamah (`StreakCalculator.sessionDates`, aturan lama tidak berubah). Sinkron cloud hanya membawa tanggal: `users/{uid}/sessionDays/{yyyy-mm-dd}` berisi `date` + `syncedAt`, dan rules menolak field lain (rekaman, nilai diri, ayat). Gagal sinkron tanggal tidak menggagalkan sinkron lain. Pengingat harian "Sesi hari ini" (ID 201) di Salat dan Saya.
  - Kartu Beranda: paling atas untuk titik mulai nol/tajwid (dan bila belum memilih), di bawah Lanjutkan membaca untuk hafalan; setelah selesai "Selesai hari ini · besok: <judul>".
  - Belum ada: rekaman bunyi 28 huruf dari guru bersanad (blok audio tetap "sedang disiapkan", tanpa TTS), dan uji di HP nyata untuk mikrofon, pemulihan murottal, serta pengingat.

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

- 15 November 2026 (mushaf lewat BFF): pembaca dulu memasang `QfDebugMushafSource` (langsung ke api.quran.com) dan menyalakan mode mushaf hanya di build debug, sehingga rilis tidak punya jalan menuju data tata letak. Kini `createMushafSource` / `mushafModesAvailable` (`lib/features/mushaf/data/mushaf_source_factory.dart`) memilih `BffMushafSource` bila build diberi `--dart-define=BFF_BASE_URL`, dan hanya build debug tanpa BFF yang memanggil api.quran.com langsung. Tanpa alamat BFF, rilis berperilaku sama dengan 1.11.1 (mode mushaf tetap "segera"). `tool/build_release.ps1` membaca `MYQURAN_BFF_URL` (hanya `https://`). Sumber & Lisensi menampilkan kredit tata letak mushaf hanya pada build berBFF. Bukti: 5 tes baru di `test/mushaf_source_factory_test.dart`; `flutter analyze` bersih; suite penuh 832 lulus (827 sebelumnya + 5), tidak ada golden berubah; skrip rilis lulus uji sintaks PowerShell dan regex alamat (`https://bff.contoh.com` diterima; `http://`, `https://` kosong, dan alamat bersepasi ditolak). **Belum terbukti:** BFF belum di-deploy dan belum pernah dipanggil dari aplikasi di perangkat; prelive Quran Foundation hanya memuat Al-Fatihah dan Al-Baqarah; izin KFGQPC/QUL baru pernyataan pemilik (`docs/lisensi/bukti/2026-11-15-pernyataan-pemilik-mushaf.md`), salinan tertulis belum ada. Karena itu rilis publik tidak menyalakan mode mushaf.

- 15 November 2026 (materi tajwid 6–16 tampil sebagai draf berlabel): atas keputusan pemilik (pengecualian seperti 24 Sep 2026 untuk nama hukum dan palet; `docs/RELIGIOUS_CONTENT_GOVERNANCE.md`, `docs/decisions.md`), `showDraftLessons` tidak lagi `kDebugMode`: kini bendera kompilasi `SHOW_DRAFT_LESSONS` (bawaan `true`, `false` menyembunyikannya per build). Materi tetap berstatus `draft`; yang berubah hanya tampilannya. Setiap materi draf tampil dengan lencana DRAF dan kalimat `draftLessonNotice` ("Materi ini masih draf dan belum ditinjau guru. Cocokkan dengan gurumu.") di layar pelajaran dan langkah Materi sesi harian. Tes gerbang `test/curriculum_review_gate_test.dart` tidak diubah dan tetap menolak `published`/`approved` tahap 6 ke atas tanpa dua peninjau. Penjelasan cara membaca tiap hukum tetap kosong (harus ditulis guru). Bukti: dua asersi baru di `test/learn_v3_test.dart` (pemberitahuan ada pada draf dan tidak ada pada materi terbit) dan satu tes baru di `test/session_screen_test.dart` (pemberitahuan di langkah Materi); suite penuh 828 lulus, 0 gagal. 10 golden `18_materi_*` diperbarui: selisihnya 14 sampai 29 persen piksel karena satu baris baru menggeser isi di bawahnya (kotak perubahan dimulai tepat di baris pemberitahuan); satu golden 1x dan satu 2x dilihat, pemberitahuan terbaca penuh dan tidak terpotong. Dokumen yang mengklaim materi dikunci di rilis (`README.md`, `docs/PRD.md`, `docs/DATA.md`, `docs/LEARN_CONTENT.md`, `docs/content/paket-peninjau/README.md`) disesuaikan. Batas: belum dilihat di HP fisik.

- 15 November 2026 (sumber qari berizin): atas pernyataan pemilik (bukan surat dari pihak sumber; `docs/lisensi/bukti/2026-11-15-pernyataan-pemilik.md`), equran.id, MP3Quran, QUL/Tarteel, dan Quran Foundation berstatus granted di `lib/data/audio_sources.dart` dan JSON katalog. Karena hanya Islamic Network dan equran.id yang tersambung di kode (fase 8b/8c lainnya belum), efek tampilannya: 17 jadi 21 qari di rilis (Yasser Al-Dosari, Al-Juhany, Ibrahim Al-Dossari, Abdul Muhsin Al-Qasim), dan cadangan equran.id/MP3Quran aktif di rilis saat CDN utama gagal. Empat qari yang hanya bergantung pada MP3Quran/QUL/Quran Foundation sengaja tidak tampil karena belum bisa diputar (`QariEntry.playableSource`); `visible()` kini menuntut sumber yang bisa diputar, bukan sekadar granted. Bukti: 4 tes `test/qari` yang menjaga keadaan lama gagal lalu diperbarui (21 qari, daftar granted, urutan Populer dan Adem, equran.id bisa diputar di rilis) ditambah dua tes baru (qari tanpa sumber tersambung tidak tampil; cadangan aktif karena granted); 69 tes qari, audio, murottal, dan sumber data lulus. Suite penuh: 824 lulus dan 5 gagal, semuanya di `test/golden/screen_23_qari_test.dart`: satu tes perilaku (contoh Yasser dan angka Adem) diperbarui, empat golden diperbarui setelah selisih pikselnya dihitung (terang dan gelap hanya kotak 145x28 piksel pada judul "ADEM · 12 QARI"; debug_dark bergeser karena urutan daftar debug) dan golden terang dilihat; berkas itu lalu lulus 9 dari 9, dan suite penuh diulang setelahnya: 829 lulus, 0 gagal. Belum ada izin tertulis yang disimpan; sampai itu, status granted bersandar pada pernyataan pemilik.

- 15 November 2026 (rilis GitHub 1.11.1): dibangun dengan `tool/build_release.ps1` dari `main` commit `566fff0` (versi 1.11.1+23, PR #50). APK 46,7 MB (48.998.528 byte), SHA-256 `795259ad06d1fdedbac6664f46b385cb9a37b2955fe1f7f4e5d3c4ddb3e3fb0b`. `apksigner verify` lulus (skema v2) dan sertifikat SHA-256 `3af7e6fd…d8feaa` sama persis dengan `docs/RELEASE.md`; versi di dalam APK 1.11.1 (23), targetSdk 36, izin pasang APK ada (flavor GitHub). Hanya ARM yang dibundel (folder `lib/x86_64` hanya berisi `libdatastore_shared_counter.so` 6 KB dari dependensi, tanpa `libflutter`/`libapp`). Pindai isi APK: 0 kecocokan private key, `client_secret`, `storePassword`, dan token; tanpa berkas sensitif. Rilis `v1.11.1` berstatus latest (bukan draf, bukan pra-rilis), aset `myquran-1.11.1.apk` dan `myquran.apk`; digest GitHub sama dengan hash lokal; `releases/latest/download/myquran.apk` menjawab HTTP 200 dengan 48.998.528 byte; halaman unduh menampilkan "Versi 1.11.1 · 46,7 MB" dan SHA-256 yang sama. Batas bukti: belum dipasang atau diukur waktu startnya di HP fisik; perbaikan di dalamnya teruji tes otomatis dan emulator saja. Pengguna APK GitHub yang sudah terpasang akan ditawari pembaruan otomatis.

- 15 November 2026 ("Sesi besok" di Beranda): sapuan emulator menemukan layar penutup sesi menyebut "Besok: Membaca tandanya di mushaf" sementara baris "SESI BESOK" di Beranda menyebut "Mulai dari mana" untuk pengguna yang sama. Penyebab: `HomeController` memakai `Curriculum.nextAfter` (pelajaran pertama yang belum selesai menurut urutan global, selalu pelajaran perkenalan) sedangkan sesi dan tab Belajar memakai `activeLesson` (menurut titik mulai). Kini `HomeController` memakai `activeLesson` juga. Bukti: dua tes baru di `test/home/home_controller_test.dart` (titik mulai tajwid harus `nun`, titik mulai nol harus `huruf`) gagal sebelum perbaikan (`mulai` didapat) dan lulus sesudahnya; 24 tes folder `test/home` lulus. `docs/DATA.md §1` dan `docs/decisions.md` disesuaikan. Suite penuh: 815 lulus dan 3 golden Beranda keadaan semua-selesai bergeser; selisihnya terkurung di satu baris teks (kotak 445x33 piksel) yang berubah dari "Mulai dari mana" menjadi "Nun sukun dan tanwin", sesuai pelajaran aktif sesi; potongan lama dan baru disandingkan dan dibaca.

- 14 November 2026 (header Reader tembus): di emulator, pil "Indonesia / Tajwid" dan petunjuk "Ketuk huruf berwarna untuk melihat artinya." melayang di atas daftar tanpa latar, sehingga teks Arab yang tergulir di bawahnya (mis. saat murottal mengikuti bacaan) tembus dan menimpa tulisan petunjuk. `ReaderPinnedFilters` (`card_parts.dart`) kini membungkus keduanya dengan latar solid `tokens.bg` selebar layar (bukan kaca). Bukti: `test/reader_pinned_filters_test.dart` memuat `ReaderScreen` asli dan gagal sebelum perbaikan (0 `ColoredBox` membungkus kedua widget), lulus sesudahnya. Suite penuh: 12 golden Reader bergeser, semuanya hanya satu baris piksel (y=313, atau y=646 pada x2) dengan selisih warna maksimum 9 dari 255, yaitu ekor bayangan bilah navigasi yang kini terpotong blok solid; golden diperbarui dan satu dilihat. Perbandingan sebelum dan sesudah dirender dengan widget asli di atas teks ayat (komposisi sederhana, bukan layar Reader utuh): teks tembus hilang. Catatan metode: uji gulir pada `ReaderScreen` asli tidak mereproduksi bug karena header tersembunyi saat menggulir ke bawah; keadaan bug muncul saat gulir otomatis, jadi bukti visual memakai komposisi widget.

- 14 November 2026 (teks 200% di baris pengaturan): sapuan emulator Pixel 9 Pro dengan font sistem 200% menemukan judul baris pengaturan terpotong di tab Saya ("Terjemahan" jadi "Terjem…", "Warna tajwid" jadi "Warna …") karena nilai di kanan merebut lebar baris. `SettingsRow` kini menumpuk nilai di bawah judul mulai skala teks 1,3 (`SettingsRow.stackedTextScale`); di bawah itu tata letak tidak berubah. Bukti: `test/settings_row_large_text_test.dart` (3 pasangan judul-nilai nyata dari tab Saya, font asli dimuat) gagal 3 dari 6 sebelum perbaikan dan lulus 6 dari 6 sesudahnya; suite penuh 821 lulus dan 1 gagal, yaitu golden `12_saya_light_x2` yang memang berubah (selisih 0,45% piksel, terkurung di strip bawah y 2362–2532, yaitu baris bernilai yang mengintip di balik dock), lalu diperbarui dan dilihat. Tampilan 1x dan 2x dirender dan diperiksa mata. Kesalahan metode tes yang ditemukan di tengah jalan: font uji bawaan (Ahem) memotong semua teks, jadi tes teks harus memanggil `loadAppFonts()`.

- 14 November 2026 (murottal saat layar mati, emulator): Pixel 9 Pro, Android 16, build debug. Al-Baqarah diputar dari ayat 1, lalu layar dimatikan (`mWakefulness=Asleep`). Sesi media berstatus `PLAYING` dan foreground service aktif pada +60, +180, dan +300 detik, tetap `PLAYING` setelah layar dibangunkan, tanpa `FATAL EXCEPTION` atau `ForegroundServiceDidNotStart`. Setelah sekitar 5,5 menit dock menampilkan "Al-Baqarah · Ayat 22" dan Reader sudah bergulir ke ayat itu. Batas bukti ini: hanya emulator dan hanya 5,5 menit. Belum diuji di HP asli (penghemat baterai Samsung One UI, Bluetooth, panggilan masuk) dan belum 10 menit lebih. Catatan metode: tiga percobaan pertama tidak valid karena ketukan skrip jatuh di kartu "Terakhir dibaca" sehingga yang diputar Al-Fatihah (7 ayat, selesai sendiri); jangan memakai koordinat tetap untuk menguji ini lagi.

- 14 November 2026 (audit finalisasi, digabung lewat PR #42): `flutter analyze` bersih; `flutter test` 816 lulus. Emulator Pixel 9 Pro (Android 16) dengan build debug: onboarding, lima tab, Reader Al-Fatihah, dan murottal (status media session CONNECTING lalu PLAYING, ayat berurutan) berjalan tanpa exception, overflow, atau FATAL di logcat. Build rilis `--dart-define=DISTRIBUTION=github` sukses dan ditandatangani kunci rilis (`CN=Ruang Tilawah`); pindai isi APK: 0 kecocokan private key, `client_secret`, `storePassword`, atau token, dan tidak ada keystore di dalamnya. Temuan: `docs/RELEASE.md` langkah 3 tidak menyebut `--target-platform android-arm,android-arm64`, sehingga APK 68 MB (memuat x86_64) alih-alih sekitar 47 MB; dokumen diperbaiki, `tool/build_release.ps1` sudah benar. Halaman unduh baru di `hosting/public/` (versi, ukuran, dan SHA-256 diisi dari API rilis GitHub; dicek di 390 px dan 1280 px, terang dan gelap, tanpa geser horizontal dan tanpa gambar rusak); belum di-deploy. Belum diuji: HP asli (murottal layar mati, kiblat, notifikasi, sinkron dua perangkat), lihat `docs/QA_DEVICE_CHECKLIST.md`.

- 26 September 2026 (Sesi hari ini, v5): `flutter analyze` bersih; `flutter test` seluruhnya lulus, termasuk tes baru pemilih ayat (28 huruf + tanwin/tasydid/sukun terhadap teks Tanzil asli), `buildPlan`, penyimpanan, alur layar (lengkap, lewati, keluar-lanjut, hari berganti, izin mikrofon ditolak, offline), istiqamah, sinkron (hanya tanggal), dan kartu Beranda. Golden baru `19_sesi_*` (terang, gelap, sepia, teks 2×) dilihat satu per satu; golden Beranda dan Salat diperbarui karena kartu dan baris pengingat baru. `firestore-tests`: 38 rules lulus di emulator (7 baru untuk `sessionDays`).

- 22 September 2026 (1.1.2, review ronde 3): unggahan dan hapus akun kini menunggu antrean tulis Firestore yang tersimpan di disk (`waitForPendingWrites`, termasuk dari sesi aplikasi sebelumnya), sehingga hapus akun tidak bisa didahului unggahan tertunda dan outbox tidak diulang setelah restart; inisialisasi Firebase, Google Sign-In, audio, dan pengingat sebelum `runApp` diberi batas waktu dan tidak lagi bisa menggantung atau meng-crash startup; pengingat salat dijadwalkan di zona waktu kota (`meta.timezone` AlAdhan), bukan zona HP; pencarian ayat menampilkan error dan tombol coba lagi alih-alih spinner tanpa akhir. `flutter test` 82 lulus.

- 22 September 2026 (1.1.1, cek sebelum uji perangkat): semua commit/get Firestore dibatasi 30 detik dan dibaca dari server (sebelumnya sync bisa tertahan selamanya saat offline dan hapus akun offline hanya menghapus cache); waktu edit bookmark dibuat selalu naik dan unggah bookmark yang ditolak memicu penyelarasan ulang penuh (sebelumnya jam HP yang mundur bisa mengunci sync bookmark); sync tidak lagi mati diam-diam bila pembersihan lokal setelah hapus akun gagal. Dicek aman: izin INTERNET ada di manifest rilis, aturan R8 flutter_local_notifications v19 bawaan, pengingat memakai alarm tidak tepat (tanpa izin exact alarm). `flutter test` 75 lulus.

- 22 September 2026 (rilis 1.1.0): nama aplikasi Ruang Tilawah, keystore rilis di luar repo, signing rilis dari `key.properties`, SHA rilis terdaftar di Firebase, API key Android dibatasi dan diverifikasi, kebijakan privasi di Firebase Hosting, pemeriksa pembaruan GitHub Releases. `flutter test` 73 lulus; APK rilis ditandatangani kunci rilis (diverifikasi `apksigner`). Belum dipasang di perangkat nyata.

- 22 September 2026 (review PR #5): 4 temuan review diperbaiki: bookmark ditarik sebelum diunggah dan rules menolak update `updatedAtMs` yang lebih tua; hapus akun meminta konfirmasi Google dulu, menjeda sync, dan memulihkan data bila gagal; sync antrean selalu memakai akun terbaru dan berhenti saat keluar; waktu baca multi-perangkat memakai gabungan interval. `flutter test` 67 lulus, rules 31 lulus, rules ter-deploy ulang.

- 22 September 2026 (sync cloud): `flutter test` lulus 61 test termasuk `test/cloud_sync_test.dart` (12 skenario sync dengan remote palsu); `firestore-tests` lulus 29 test rules di emulator (isolasi akun A/B, larangan stats klien, validasi sesi/bookmark); `flutter analyze` tanpa error/warning; `flutter build apk --debug` sukses (plugin Kotlin dinaikkan ke 2.3.21 karena firebase-auth 24.2). Rules dan index ter-deploy ke produksi. Provider Google diaktifkan di Console pada 22 September 2026 dan `google-services.json` diperbarui (memuat web OAuth client); login Google belum diuji di perangkat.

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
- Sync: uji masuk/sinkron/keluar/hapus akun di dua perangkat nyata. Perubahan zona waktu belum ditunda ke hari berikutnya (hari mengikuti zona perangkat saat membaca).
- Rencana khatam berbasis unit edisi tervalidasi, sync/auth/outbox/rules.
- Uji perangkat nyata: 200% font, screen reader, airplane mode, reader panjang, dan metrik profile/release 60 FPS.
- applicationId produksi, keystore sendiri, signing release, privacy policy, store data safety, serta persetujuan rilis.

## Tahap berikutnya

1. Tambahkan test deterministik untuk bookmark, last read, streak, dan aksesibilitas Reader.
2. Uji pengingat pada perangkat nyata, termasuk setelah reboot dan mode hemat baterai.
3. Siapkan backend berita HTTPS dan konfigurasi signing rilis saat kredensial tersedia.

## Redesign "Sacred Serenity · edisi iOS" — Tahap 0 (23 September 2026)

Branch `redesign/ios-sacred` dari `main` (93aecef). Brief dan aset ada di
`quran-ios-redesign-handoff/docs/design/ios-redesign/`.

Baseline sebelum menyentuh tampilan: `flutter pub get` sukses,
`dart analyze lib test tool` tanpa isu, `flutter test` **186 lulus**.
Rilis terakhir v1.2.1.

### Pemetaan layar desain ke kode sekarang

| Layar desain | File sekarang | Tindakan |
|---|---|---|
| Pembuka | `flutter_native_splash` di `pubspec.yaml` | Samakan warna & ornamen |
| Beranda | `lib/screens/home_screen.dart` | Rombak: hero lanjut baca, target, istiqamah, pintasan, strip salat, ayat hari ini |
| Qur'an | `lib/screens/quran_library_screen.dart` | Rombak: segmented Surah/Juz/Halaman + terakhir dibaca |
| Cari | `lib/screens/quran_search_screen.dart`, `search_screen.dart` | Jadikan layar tersendiri; tombol bulat di tab bar |
| Pembaca | `lib/screens/reader_screen.dart` | Rombak: nav kaca, bingkai mihrab, penanda ayat |
| Fokus | mode fokus di `reader_screen.dart` | Rombak sesuai desain |
| Murottal | `lib/widgets/audio_mini_player.dart` | Tambah sheet murottal + mini player kaca |
| Progres | `lib/screens/progress_screen.dart` | Rombak: heatmap istiqamah, grid 30 juz |
| Salat | `lib/screens/prayer_screen.dart` | Rombak: gradien langit, metode & zona waktu tampil |
| Pengaturan | `lib/screens/settings_screen.dart` | Rombak: inset grouped, pratinjau tema & ukuran teks |
| Offline, Font 200% | — | Kondisi yang diuji, bukan layar baru |

### Yang tidak ada di desain

Desain memakai **4 tab** (Beranda, Qur'an, Progres, Pengaturan) + tombol Cari
bulat. Saat brief ini ditulis aplikasi memakai **5 tab** (Beranda, Baca, Belajar,
Hafalan, Profil) dengan tab Belajar (hub Juz Amma) dan Hafalan yang dirilis di
1.2.0–1.2.1. Keduanya tidak boleh hilang, jadi tempat barunya menunggu keputusan
pemilik.

> **Catatan 23 September 2026:** redesign berjalan terus dan tab bar sekarang
> **sudah 4 tab** (`lib/app/app_shell.dart:19-40`), sementara keputusan pemilik
> di atas belum pernah diambil. Belajar dan Hafalan kini hanya bisa dicapai dari
> tab Progres. Lihat `docs/revisi-v2/TAHAP_0_AUDIT.md` §3.3.

## Redesign "Sacred Serenity · edisi iOS" — selesai (23 September 2026)

Semua layar brief dibangun ulang dari nilai di mockup, dirilis sebagai **v1.4.0**
(tag `v1.4.0`, PR #16, squash `cebc758`). Beranda, Qur'an, Pembaca, Fokus,
Progres, Pengaturan, Salat, Cari dirombak; layar **Murottal penuh** dibuat baru
(sebelumnya hanya mini-player). Transisi halaman memakai
`CupertinoPageTransitionsBuilder` di semua platform.

Yang sengaja **tidak** dikarang: bentuk gelombang Murottal diganti posisi
pemutaran sungguhan (tidak ada data gelombang), tombol unduh di Murottal
dinonaktifkan beserta alasannya, dan waktu mendengar tetap tertulis "belum
dicatat" di Progres karena memang belum pernah dihitung.

Belum diuji di perangkat nyata: seluruh layar hasil rombakan v1.4.0.

## Revisi v2 — Tahap 0 (23 September 2026)

Branch `revisi-v2` dari `main` (`cebc758`), versi `1.4.0+9`. Brief pemilik ada di
`docs/revisi-v2/` (spesifikasi, riset sumber, foto referensi).

Baseline sebelum menyentuh apa pun: `flutter pub get` sukses,
`dart analyze lib test` **tanpa isu**, `flutter test` **252 lulus**.

Hasil audit lengkap beserta bukti baris-per-baris:
**`docs/revisi-v2/TAHAP_0_AUDIT.md`**. Ringkasnya: dari 23 klaim di brief,
**19 benar, 3 sebagian, 1 salah** (daftar Juz 'Amma tidak diduplikasi; yang
dipakai bersama hanya widget `MemorizationTile`).

Temuan tambahan yang tidak ada di brief:

- Halaman 273 pada foto (An-Nahl 55–64) **cocok persis** dengan batas halaman
  Tanzil di `assets/quran/raw/quran-data.xml`, jadi target tata letaknya
  terkonfirmasi Mushaf Madinah 604 halaman. Data **baris** (15 baris, rentang
  kata) belum ada dan masih diambil dari jaringan.
- Foto sampul referensi adalah mushaf **blok warna** (latar diwarnai), sedangkan
  spesifikasi §C mewajibkan standar LPMQ yang mewarnai **huruf + harakat**.
  Bertentangan; menunggu keputusan pemilik.
- Tidak ada font mushaf yang dibundel; font QCF diunduh runtime, dan
  membundelnya terikat syarat akun Quran Foundation Developer Console.

### Keputusan pemilik (23 September 2026)

| Pertanyaan | Keputusan |
|---|---|
| Struktur navigasi | **5 tab**: Beranda, Qur'an, **Belajar**, Progres, Pengaturan + tombol Cari. Hafalan berada **di dalam** Belajar |
| Gaya warna tajwid | **Huruf berwarna, standar LPMQ Kemenag** (bukan blok warna seperti foto sampul) |
| Kode mati | **Boleh dihapus**: `islamic_news_screen.dart` dan `search_screen.dart` |
| Akun Quran Foundation | **Belum ada.** Pakai jalur QUL + font KFGQPC Unicode + data tajwid `cpfair/quran-tajweed` (CC BY 4.0), lisensinya diperiksa satu per satu |

## Revisi v2 — Tahap 0.5: perbaikan yang tidak butuh keputusan (23 September 2026)

Disisipkan sebelum Tahap 1 karena Tahap 1 bergantung pada lisensi data yang
belum dipastikan, sedangkan semua di bawah ini murni bug dan kerapian.

**Bug pengulangan hafalan (spesifikasi §D).** `playRange` selalu memetakan ke
`LoopMode.all`, jadi 3×, 5×, 10×, dan "tanpa batas" berperilaku sama: tidak
pernah berhenti. Opsi 1× justru keluar dari mode rentang, yang memuat ulang
antrean sampai akhir surah — padahal tombolnya tertulis "Putar ayat 3–7".
Aturannya sekarang ada di `RangePlan`, nilai murni yang bisa diuji tanpa pemutar
sungguhan: satu putaran = daftar terbatas tanpa pengulangan; banyak putaran =
menghitung kembalinya indeks ke ayat pertama lalu mematikan pengulangan di ayat
terakhir putaran pamungkas, supaya daftar berakhir sendiri alih-alih terpotong
di tengah ayat pertama. Rentang satu ayat tidak pernah berpindah indeks, jadi
daftarnya digandakan; rentang panjang tidak pernah digandakan, sehingga
mengulang Al-Baqarah 10× tetap memuat 286 berkas, bukan 2.860.

**Bug dari 1.4.0 yang ikut ketahuan.** Tombol ulangi di layar Murottal berputar
lewat `AudioRepeat.range`, yang ditolak `setRepeat`, jadi sepertiga ketukan diam
saja. Sekarang hanya berpindah antara berurutan dan ulangi-ayat, karena memilih
rentang butuh ayat awal dan akhir yang hanya ditanyakan layar latihan.

**Navigasi 5 tab.** Belajar naik jadi tab dan memuat: jalur belajar membaca
(dinonaktifkan beserta alasannya karena materinya belum ditinjau), Akademi
Tajwid, Hafalan, dan daftar Juz Amma. Beranda dapat pintasan Belajar. Belajar
dan Hafalan tidak lagi menumpang di tab Progres.

**Judul "Pengaturan" dobel** diperbaiki: `app_shell` membungkus `SettingsScreen`
dengan kolom yang menambah `LargeTitle` kedua.

**`SacredTheme.light`/`dark` tidak membawa `SacredTokens`**, sehingga layar mana
pun yang memakai token mati di tes dengan "Null check operator used on a null
value". Keduanya kini lewat `themeFor`, jalur yang sama dengan aplikasi.

**Kode mati dihapus** atas izin pemilik: `islamic_news_screen.dart`,
`search_screen.dart`.

Pengujian: `dart analyze lib test` bersih, `flutter test` **258 lulus**
(6 tes baru untuk jumlah pengulangan). **Belum diuji di perangkat nyata**, dan
belum ada tangkapan layar terang/gelap karena tidak ada perangkat/emulator
tersambung; mode gelap, teks 200 %, dan layar sempit hanya tercakup oleh
`test/qa_states_test.dart`.

## Revisi v2 — Tahap 1: lisensi (23 September 2026)

Hasil lengkap: **`docs/revisi-v2/TAHAP_1_LISENSI.md`**.

**Mode Mushaf persis cetakan tidak bisa masuk rilis sekarang.** Data tata letak
baris dari QUL — satu-satunya bahan yang wajib ada — **tidak punya keterangan
lisensi sama sekali** di halaman resource mana pun; FAQ-nya menyuruh memeriksa
lisensi "yang disediakan pembuat resource", padahal keterangan itu tidak ada.
Tanpa izin tertulis, datanya tidak diunduh, tidak dibundel, dan tidak dirilis.

Tiga bahan lain justru bersih: font KFGQPC Uthmanic Hafs boleh didistribusikan
gratis (tapi **dilarang di-subset atau dikonversi**), data tajwid
`cpfair/quran-tajweed` CC BY 4.0 (**kodenya tanpa lisensi — jangan disalin**),
dan QuranEnc boleh dibundel dengan tujuh syarat, dua di antaranya mengubah
desain: nomor versi wajib tampil dan aplikasi wajib punya jalur pembaruan.

Catatan teknis penting untuk Tahap 2: offset anotasi cpfair menunjuk ke salinan
Tanzil April 2017, sedangkan yang dibundel di sini v1.0.2 yang lebih baru. Jadi
anotasinya **tidak boleh langsung ditempel** ke teks kita — persis pola yang
sudah dilarang ADR-2. Harus dicocokkan ayat per ayat lebih dulu, dengan tes.

## Revisi v2 — Tahap 3 & 5 & sebagian 6 (23 September 2026)

**Qari (§E).** Daftar qari sebelumnya adalah apa pun yang dikembalikan endpoint
Al Quran Cloud, tanpa penyaringan sama sekali — termasuk **audio terjemahan**
(`en.walk`, `ur.khan`, `fr.leclerc`) yang bukan bacaan, dan edisi **riwayat
Warsh** yang tidak cocok dengan teks Hafs di layar. Model `Reciter` kini membawa
gaya, riwayat, penyedia, atribusi, dan penanda data waktu per kata. Gaya dibaca
dari nama edisi penyedia; kalau tidak disebut, ditulis belum dipastikan, bukan
ditebak murattal. Cache lama tanpa field baru tetap terbaca.

**Hafalan (§D).** Status hafalan dulu hanya satu per surah tanpa jadwal apa pun,
sehingga tidak ada yang memberi tahu apa yang harus diulang hari ini. Sekarang
tiap ayat punya jarak ulang dan tanggal jatuh tempo sendiri, dengan tangga yang
bisa dibaca langsung di layar: 1 → 3 → 7 → 14 → 30 hari, naik saat lancar, tetap
saat ragu, kembali ke 1 hari saat salah. Layar latihan dapat tiga tombol penanda;
yang menilai tetap orangnya. Layar Hafalan menjelaskan ziyadah/murajaah/tasmi'.
Beranda menampilkan baris murajaah hanya bila memang ada yang jatuh tempo.

**Sinkronisasi cloud untuk data hafalan belum dikerjakan** — itu perlu mengubah
dan men-deploy aturan Firestore, dan itu tidak dilakukan tanpa pengawasan.

**Sebagian §E.** Lima warna lencana ikon dulu konstanta `const` yang ditulis dua
kali di dua layar, sehingga tetap pekat di mode gelap; sekarang satu tempat dan
ikut kecerahan tema. Baris sumber murottal dulu selalu menyebut "Alafasy, 128
kbps" apa pun qari yang dipilih karena grupnya `const`; sekarang menyebut qari
dan bitrate yang benar-benar dipakai.

### Belum dikerjakan dari daftar Tahap 0.5

Warna chip hardcode di Pengaturan dan Belajar, 23 warna hardcode di Beranda,
serta kartu lembut yang punya tiga implementasi — semuanya dipindahkan ke
Tahap 6 sesuai urutan di prompt, karena menyentuh token tema secara luas.
