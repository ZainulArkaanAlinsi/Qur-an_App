# Checklist rilis

- [ ] Dataset, terjemahan, font, dan audio memiliki lisensi/atribusi yang dicatat.
- [ ] Manifest 114 surah, checksum, verse key, dan render Arab telah direview manusia yang kompeten.
- [ ] Reader offline, bookmark, last-read, dan migrasi data diuji.
- [ ] Audio/streak diuji sesuai edge case pada panduan proyek.
- [ ] `flutter analyze`, test, build, dan uji perangkat direkam dengan hasil nyata.
- [ ] Permission, privacy policy, signing, dan persetujuan publikasi selesai.

## Audio latar belakang

- [ ] Isi deklarasi *Foreground service permissions* di Play Console untuk `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (jenis Media playback) beserta video demo murottal diputar dengan layar mati.
- [ ] Siapkan ikon notifikasi monokrom; saat ini notifikasi memakai `mipmap/launcher_icon` yang bisa tampil sebagai kotak putih di sebagian perangkat.
- [ ] Uji kontrol notifikasi, layar kunci, headset Bluetooth, panggilan masuk, dan layar mati lebih dari 10 menit pada Android 12+.

## Lisensi konten dan regulasi

- [ ] Konfirmasi ke LPMQ Kemenag apakah aplikasi memerlukan Surat Tanda Tashih (Permenag 44/2016 mencakup mushaf digital); ajukan melalui tashih.kemenag.go.id bila perlu. Status pemohon harus penerbit berbadan usaha/yayasan/lembaga.
- [ ] Pastikan aplikasi tetap non-komersial (tanpa iklan/IAP/langganan) selama memakai terjemahan Tanzil/Kemenag, atau minta izin tertulis Kemenag sebelum monetisasi.
- [ ] Terjemahan terbundel adalah edisi Tanzil pembaruan 4 Juni 2010 (sebelum revisi Kemenag 2019). Putuskan apakah tetap memakai edisi ini atau beralih ke sumber resmi Kemenag yang terversi, lalu bandingkan dan minta review manusia.
- [ ] Jangan membundel audio Alafasy di APK; unduhan offline hanya untuk pemakaian pribadi.
- [ ] Tampilan atribusi di Pengaturan > Konten & sumber sudah sesuai rilis final.
