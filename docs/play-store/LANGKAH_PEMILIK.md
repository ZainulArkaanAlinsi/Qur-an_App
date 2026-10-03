# Langkah pemilik di Play Console (bukan untuk Claude Code)

Urutan tercepat ke Production untuk akun pribadi baru. Detail teknis: `docs/PLAY_STORE_RELEASE.md`.

## Minggu 0 — sekarang

- [ ] Verifikasi identitas (sudah diunggah, tunggu email Google).
- [ ] Verifikasi perangkat Android: pasang aplikasi **Google Play Console** di HP, masuk dengan akun developer.
- [ ] Verifikasi nomor telepon (terbuka setelah dua di atas).
- [ ] Kumpulkan **minimal 12 penguji**, idealnya 15–20 untuk cadangan (ada yang lupa ikut). Minta alamat **Gmail/akun Google** mereka. Sumber: keluarga, teman kelas PPLG, grup kajian, rekan magang.
- [x] Jalankan **Prompt 1** di Claude Code → dapat AAB 1.10.1.

## Hari 1 — setelah akun terverifikasi

- [x] **Create app**: nama `MyQuran`, App, Free. Bahasa default ternyata **en-US**, sehingga catatan rilis & listing Indonesia tidak muncul sebelum terjemahan `id-ID` ditambahkan (*Listing toko utama › Kelola terjemahan*). Bahasa default juga bisa diubah ke Indonesia.
- [x] **Pengujian internal** (3 Oktober 2026): 1.10.1 (21) lalu 1.11.0 (22). Login Google di 1.10.1 dari Play sudah diuji. 1.11.0 perlu diuji di HP sebelum Pengujian tertutup (`docs/PLAY_STORE_RELEASE.md §6`).
- [x] Kunci penandatanganan: Play memakai **kunci buatan Google** (3 Oktober 2026). `ruang-tilawah-release.jks` menjadi kunci upload. Rinciannya ada di `docs/PLAY_STORE_RELEASE.md §2`.
- [x] SHA kunci Play didaftarkan di **Firebase** (sidik jari) dan di **pembatasan API key Android** di Google Cloud Console. Kalau salah satu terlewat, Masuk dengan Google gagal di versi Play. Aplikasi tidak perlu di-build ulang.
- [ ] **App content**: isi sesuai tabel di `docs/PLAY_STORE_RELEASE.md §3` (privasi, iklan: tidak, akses: tanpa login, rating konten, target 13+, Data safety, layanan latar media playback + video demo layar mati). Karena 1.11.0 sudah diunggah, Data safety **wajib** memuat baris *Approximate location*.
- [ ] **Store listing**: salin dari `docs/play-store/LISTING.md` + gambar v6 di `docs/play-store/<bahasa>/` (gambar ini dibuat dari UI 1.11).
- [ ] **Testing → Closed testing**: buat track, tambahkan daftar email penguji, unggah AAB **1.11.0 (22)** (sama dengan yang di Pengujian internal), kirim untuk ditinjau.
- [ ] Bagikan **tautan ikut tes** ke penguji. Pastikan mereka menekan "Jadi penguji" lalu memasang dari Play Store.
- [ ] Kalau APK GitHub tetap dibagikan: menu **Verifikasi developer Android** → daftarkan package `com.zainularkaan.quran`.

## Hari 1–14 — masa tes

- [ ] Cek tiap 2–3 hari bahwa jumlah penguji yang ikut tetap ≥ 12 (penguji yang keluar sebelum 14 hari tidak dihitung, dan hitungannya harus berturut-turut).
- [ ] Minta penguji benar-benar memakai aplikasi dan memberi masukan (Google menanyakannya saat pengajuan).
- [ ] Update berikutnya (1.11.x dan seterusnya) diunggah ke track yang sama. Update **tidak** mengulang hitungan 14 hari.

## Hari 15+ — ajukan Production

- [ ] Dashboard → **Apply for production**. Jawab pertanyaan tentang tes tertutup (berapa penguji, masukan apa yang diterima, apa yang diperbaiki — catat dari masa tes).
- [ ] Setelah disetujui: rilis ke Production, mulai dari *staged rollout* 20%.

## Yang tetap menunggu (tidak menghalangi rilis)

KFGQPC (kirim ulang surat ke Sekretaris Jenderal), LPMQ tashih, QUL #768, Islamic Network, MP3Quran, equran.id, izin qari populer, 2 peninjau materi tajwid, rekaman bunyi huruf.
