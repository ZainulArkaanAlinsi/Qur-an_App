# Langkah pemilik di Play Console (bukan untuk Claude Code)

Urutan tercepat ke Production untuk akun pribadi baru. Detail teknis: `docs/PLAY_STORE_RELEASE.md`.

## Minggu 0 — sekarang

- [ ] Verifikasi identitas (sudah diunggah, tunggu email Google).
- [ ] Verifikasi perangkat Android: pasang aplikasi **Google Play Console** di HP, masuk dengan akun developer.
- [ ] Verifikasi nomor telepon (terbuka setelah dua di atas).
- [ ] Kumpulkan **minimal 12 penguji**, idealnya 15–20 untuk cadangan (ada yang lupa ikut). Minta alamat **Gmail/akun Google** mereka. Sumber: keluarga, teman kelas PPLG, grup kajian, rekan magang.
- [ ] Jalankan **Prompt 1** di Claude Code → dapat AAB 1.10.1.

## Hari 1 — setelah akun terverifikasi

- [ ] **Create app**: nama `MyQuran`, bahasa default Indonesia, App, Free.
- [ ] Pilih kunci penandatanganan → **Use existing app signing key** (kunci `ruang-tilawah-release.jks`), ikuti panduan PEPK. Alasan: pengguna APK GitHub bisa update langsung & SHA Firebase tetap.
- [ ] Setelah unggahan pertama: salin SHA-1 & SHA-256 dari *App signing* ke Firebase Console, unduh ulang `google-services.json` (kalau tidak, Masuk dengan Google gagal di versi Play).
- [ ] **App content**: isi sesuai tabel di `docs/PLAY_STORE_RELEASE.md §3` (privasi, iklan: tidak, akses: tanpa login, rating konten, target 13+, Data safety, layanan latar media playback + video demo layar mati).
- [ ] **Store listing**: salin dari `docs/play-store/LISTING.md` + gambar di `docs/play-store/<bahasa>/`.
- [ ] **Testing → Closed testing**: buat track, tambahkan daftar email penguji, unggah AAB, kirim untuk ditinjau.
- [ ] Bagikan **tautan ikut tes** ke penguji. Pastikan mereka menekan "Jadi penguji" lalu memasang dari Play Store.
- [ ] Kalau APK GitHub tetap dibagikan: menu **Verifikasi developer Android** → daftarkan package `com.zainularkaan.quran`.

## Hari 1–14 — masa tes

- [ ] Cek tiap 2–3 hari bahwa jumlah penguji yang ikut tetap ≥ 12 (penguji yang keluar sebelum 14 hari tidak dihitung, dan hitungannya harus berturut-turut).
- [ ] Minta penguji benar-benar memakai aplikasi dan memberi masukan (Google menanyakannya saat pengajuan).
- [ ] Unggah update v6 (1.11.0) ke track yang sama setelah Prompt 9 selesai. Update **tidak** mengulang hitungan 14 hari.

## Hari 15+ — ajukan Production

- [ ] Dashboard → **Apply for production**. Jawab pertanyaan tentang tes tertutup (berapa penguji, masukan apa yang diterima, apa yang diperbaiki — catat dari masa tes).
- [ ] Setelah disetujui: rilis ke Production, mulai dari *staged rollout* 20%.

## Yang tetap menunggu (tidak menghalangi rilis)

KFGQPC (kirim ulang surat ke Sekretaris Jenderal), LPMQ tashih, QUL #768, Islamic Network, MP3Quran, equran.id, izin qari populer, 2 peninjau materi tajwid, rekaman bunyi huruf.
