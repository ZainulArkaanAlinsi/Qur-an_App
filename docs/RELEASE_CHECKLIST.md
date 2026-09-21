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
