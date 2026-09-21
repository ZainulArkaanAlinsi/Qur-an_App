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

- [ ] Aktifkan provider Google di Firebase Console lalu jalankan ulang `flutterfire configure` (lihat `docs/CLOUD_SYNC.md`).
- [ ] Buat keystore rilis, daftarkan SHA-1/SHA-256-nya ke aplikasi Firebase, dan jalankan ulang `flutterfire configure`; tanpa ini Google Sign-In gagal pada build rilis.
- [ ] Batasi API key Android di Google Cloud Console ke package `com.zainularkaan.quran` dan SHA-1 yang terdaftar.
- [ ] Perbarui kebijakan privasi dan formulir Data safety: aplikasi kini menyimpan UID, email akun Google, sesi baca (waktu, durasi, ayat terakhir, zona waktu, ID perangkat acak), dan bookmark di Firestore (Jakarta) bila pengguna masuk; ada fitur hapus akun beserta data.
- [ ] Ganti label aplikasi di `AndroidManifest.xml` (`android:label` masih `quran_app_2025`).
- [ ] Uji di dua perangkat: masuk, sinkron, baca bersamaan, hapus bookmark di satu perangkat, keluar, ganti akun, hapus akun.
