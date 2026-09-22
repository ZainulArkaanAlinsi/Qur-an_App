# Checklist rilis

- [ ] Dataset, terjemahan, font, dan audio memiliki lisensi/atribusi yang dicatat.
- [ ] Manifest 114 surah, checksum, verse key, dan render Arab telah direview manusia yang kompeten.
- [ ] Reader offline, bookmark, last-read, dan migrasi data diuji.
- [ ] Audio/streak diuji sesuai edge case pada panduan proyek.
- [ ] `flutter analyze`, test, build, dan uji perangkat direkam dengan hasil nyata.
- [ ] Permission, privacy policy, signing, dan persetujuan publikasi selesai.

## Audio latar belakang

- [ ] Isi deklarasi *Foreground service permissions* di Play Console untuk `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (jenis Media playback) beserta video demo murottal diputar dengan layar mati.
- [x] Ikon notifikasi monokrom `drawable/ic_stat_quran` (Material Symbols menu_book, Apache 2.0) dipakai murottal dan pengingat. Cek tampilannya di status bar perangkat nyata.
- [ ] Uji kontrol notifikasi, layar kunci, headset Bluetooth, panggilan masuk, dan layar mati lebih dari 10 menit pada Android 12+.

## Lisensi konten dan regulasi

- [ ] Konfirmasi ke LPMQ Kemenag apakah aplikasi memerlukan Surat Tanda Tashih (Permenag 44/2016 mencakup mushaf digital); ajukan melalui tashih.kemenag.go.id bila perlu. Status pemohon harus penerbit berbadan usaha/yayasan/lembaga.
- [ ] Pastikan aplikasi tetap non-komersial (tanpa iklan/IAP/langganan) selama memakai terjemahan Tanzil/Kemenag, atau minta izin tertulis Kemenag sebelum monetisasi.
- [ ] Terjemahan terbundel adalah edisi Tanzil pembaruan 4 Juni 2010 (sebelum revisi Kemenag 2019). Putuskan apakah tetap memakai edisi ini atau beralih ke sumber resmi Kemenag yang terversi, lalu bandingkan dan minta review manusia.
- [ ] Jangan membundel audio Alafasy di APK; unduhan offline hanya untuk pemakaian pribadi.
- [ ] Tampilan atribusi di Pengaturan > Konten & sumber sudah sesuai rilis final.

## Sinkronisasi cloud

- [x] Provider Google aktif di Firebase Console dan `google-services.json` memuat web OAuth client (22 September 2026).
- [x] Keystore rilis dibuat, SHA-1/SHA-256-nya terdaftar di Firebase, dan `google-services.json` diperbarui (22 September 2026; lihat `docs/RELEASE.md`).
- [x] API key Android dibatasi ke `com.zainularkaan.quran` + SHA-1 debug/rilis; diverifikasi ditolak untuk klien tanpa identitas, package lain, dan sertifikat lain.
- [x] Kebijakan privasi terbit di https://quran-app-zainularkaan.web.app/privacy dan ditautkan dari Pengaturan > Tentang aplikasi. (Formulir Data safety hanya berlaku bila kelak terbit di Play Store.)
- [x] Nama aplikasi: Ruang Tilawah.
- [ ] Uji di dua perangkat: masuk, sinkron, baca bersamaan, hapus bookmark di satu perangkat, keluar, ganti akun, hapus akun.

## Distribusi APK langsung (dipilih 22 September 2026)

Aplikasi didistribusikan gratis lewat GitHub Releases, bukan Google Play.
Butir khusus Play Console di atas (deklarasi foreground service, Data safety,
akun developer US$25, tes tertutup 12 penguji) tidak berlaku kecuali kelak
beralih ke Play Store.

- [ ] Backup `C:/Users/USER/keystores/ruang-tilawah-release.jks` dan `android/key.properties` ke tempat aman di luar laptop.
- [ ] Pasang APK rilis di HP nyata: masuk Google, sinkron, murottal dengan layar mati, mode pesawat.
- [ ] Terbitkan rilis GitHub `v1.1.0` dengan APK dan SHA-256-nya (draft disiapkan).
