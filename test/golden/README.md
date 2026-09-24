# Golden test — verifikasi visual

Tujuannya: Claude Code bisa melihat layar yang ia bangun sebagai PNG, lalu membandingkannya dengan `docs/design/v2/screens/*.png`.

Syarat:

- **Muat font asli** di `setUpAll`, supaya teks tidak tampil sebagai kotak Ahem. Font yang dimuat: Plus Jakarta Sans, EB Garamond, Amiri Quran. Caranya pakai `FontLoader` dengan `rootBundle.load('assets/fonts/…')`.
- **Ukuran layar:** `tester.view.physicalSize = const Size(390, 844) * 3; tester.view.devicePixelRatio = 3;` (844×390 untuk mushaf 2 halaman). Kembalikan ukurannya di `addTearDown`.
- **Setiap layar dirender:** terang, gelap, dan `MediaQuery(textScaler: TextScaler.linear(2.0))`.
- **Data palsu yang deterministik:** jam, tanggal, dan progres dibekukan lewat fake clock/repository.
- **Buat & perbarui golden:** `flutter test --update-goldens test/golden/`. PNG tersimpan di `test/golden/goldens/`.
- **Tambahan setelah golden cocok:** tes yang gagal bila ada `RenderFlex overflowed` atau teks yang terpotong `ellipsis` pada label wajib (tab, tombol, nama waktu salat).
