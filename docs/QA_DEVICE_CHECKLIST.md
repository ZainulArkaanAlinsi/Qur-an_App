# Daftar uji di HP nyata (v1.11.x)

Semua butir di bawah belum bisa dibuktikan oleh `flutter test`, karena butuh perangkat,
akun, atau waktu nyata. Sumbernya: bagian "Belum diuji di perangkat" di `docs/PROGRESS.md`,
`docs/ROADMAP.md`, dan `docs/RELEASE_CHECKLIST.md`.

Cara pakai: pasang APK dari GitHub Releases dan, kalau sudah ada, build Play (Pengujian
internal). Centang setelah dicoba. Kalau gagal, tulis model HP, versi Android, dan langkahnya.

## 1. Pasang dan perbarui
- [ ] Pasang `myquran.apk` di HP bersih. Aplikasi terbuka, onboarding tampil sekali.
- [ ] Pasang v1.10.0 lalu timpa dengan v1.11.0 lewat pembaruan dalam aplikasi. Data tetap ada.
- [ ] Bandingkan SHA-256 APK yang diunduh dengan yang tertulis di halaman rilis.

## 2. Murottal dan layar mati (Android 12 ke atas)
- [ ] Putar satu surah, matikan layar 10 menit lebih. Audio terus jalan.
  (Emulator Pixel 9 Pro, Android 16, 14 Nov 2026: lulus 5,5 menit dengan layar mati. HP asli dan
  durasi 10 menit lebih belum diuji, termasuk penghemat baterai Samsung One UI.)
- [ ] Kontrol di notifikasi dan layar kunci: putar/jeda, berikutnya, sebelumnya.
- [ ] Headset Bluetooth: tombol putar/jeda bekerja.
- [ ] Panggilan masuk: audio berhenti, lalu pulih setelah panggilan selesai.
- [ ] Ulangi ayat dan ulangi rentang ayat.
- [ ] Mode pesawat: surah yang sudah diunduh tetap terputar.

## 3. Akun dan sinkron (butuh dua perangkat)
- [ ] Masuk dengan Google dari APK GitHub, lalu dari build Play. Keduanya berhasil.
- [ ] Baca di HP A, buka HP B: sesi dan penanda muncul.
- [ ] Hapus penanda di A: hilang di B setelah sinkron.
- [ ] Keluar, ganti akun, data tidak tercampur.
- [ ] Hapus akun: data cloud ikut hilang.

## 4. Pengingat dan lokasi
- [ ] Izin notifikasi (Android 13 ke atas) diminta dan bisa ditolak tanpa crash.
- [ ] Pengingat salat berbunyi di waktu yang benar untuk kota yang dipilih.
- [ ] Pengingat tilawah dan "Sesi hari ini" berbunyi.
- [ ] Arah kiblat: GPS dan kompas, bandingkan dengan aplikasi kiblat lain.
- [ ] Izin lokasi ditolak: kota manual tetap bisa dipilih.

## 5. Belajar dan mikrofon
- [ ] Sesi hari ini sampai selesai, termasuk rekam dan bandingkan suara.
- [ ] Izin mikrofon ditolak: sesi tetap bisa diselesaikan.
- [ ] Keluar di tengah sesi dan buka lagi: lanjut di langkah yang sama.
- [ ] Murottal yang sedang jalan dipulihkan setelah sesi ditutup.

## 6. Tampilan di perangkat
- [ ] Ukuran font sistem 200%: tidak ada teks Arab terpotong atau overflow.
- [ ] Layar sempit dan mode landscape.
- [ ] Tajwid berwarna: sambungan huruf di batas warna terlihat benar.
- [ ] Tema Terang, Gelap, Sepia, Kontras tinggi.

## 7. Offline
- [ ] Mode pesawat: baca teks Arab dan terjemahan Indonesia.
- [ ] Kondisi offline menampilkan pesan yang jelas, bukan spinner tanpa akhir.
- [ ] Baca, putar audio, beri penanda, matikan jaringan, restart aplikasi: semuanya masih ada.
