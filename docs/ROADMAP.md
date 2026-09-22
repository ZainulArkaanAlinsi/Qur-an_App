# Roadmap

Status per 22 September 2026. Fase berikutnya tidak dimulai sebelum kriteria
lulus fase aktif terpenuhi. Definition of Done umum ada di
`docs/QA_CHECKLIST.md`.

## Pekerjaan tertunda dari v1.1.x

- [ ] Uji v1.1.2 di perangkat Android nyata (sync, audio latar, pengingat).
- [ ] Backup keystore rilis ke tempat aman di luar laptop.

## Fase 0 — fondasi dan validasi (AKTIF)

- [x] Audit repo, baseline `flutter analyze` bersih, 87 tes lulus.
- [x] PRD, SDD, sumber & lisensi, governance, roadmap, QA checklist.
- [x] Spike parser `text_uthmani_tajweed` whitelist + tes + audit 6.236 ayat
      (6.235 lulus, 32:3 cacat di sumber ditolak).
- [ ] **Keputusan pemilik:** edisi teks untuk Mode Card bertajwid (teks QF
      sendiri vs tetap Tanzil tanpa warna). Rekomendasi: Card memakai teks
      Tanzil saat tajwid mati, teks edisi QF saat tajwid hidup, dengan label
      edisi.
- [ ] **Keputusan pemilik:** posisi jadwal salat/kiblat/berita di navigasi 5 tab.
- [ ] **Aksi pemilik:** daftar Quran Foundation API (client credentials) dan
      ajukan permohonan akses Qur'an Kemenag API.
- [x] Widget tajwid kartu ayat + layar pratinjau debug.
- [ ] Uji font Amiri terhadap encoding teks tajwid QF (alif wavy hamza,
      dotless beh, small high rounded zero) — cek di perangkat via pratinjau.
- [x] Spike font QCF V2/V4: halaman 1, 2, 50, 76, 603, 604 dirender di host;
      audit layout 604 halaman (603 lulus, 589 ditolak karena cacat data).
- [x] Prototipe tiga layout (card, 1 halaman, 2 halaman), khusus debug.
- [ ] Uji prototipe di perangkat: COLRv1 di Impeller, rotasi, swipe, zoom.
- [ ] Bandingkan heuristik baris tengah dengan render resmi (atau dapatkan
      data layout baris resmi yang memuat penanda baris tengah).
- [ ] BFF minimal (proxy + cache + rate limit) di lingkungan staging.
- [ ] Reviewer tajwid memeriksa nama hukum + prototipe.

Kriteria lulus: tiga prototipe jalan di emulator & perangkat nyata, tanpa secret
di APK, keputusan edisi tercatat, reviewer tajwid sudah memberi catatan.

## Fase 1 — MVP pembaca

Daftar surah/juz, tiga mode baca, terjemahan di card, banyak qari dinamis +
mini-player, bookmark/terakhir dibaca per mode, pencarian, setting font &
tema (terang/gelap/sepia/high contrast), download teks dan audio dasar.

## Fase 2 — belajar

Akademi Tajwid, tajwid interaktif per ayat (chip + tap segmen), kurikulum
Belajar Membaca orisinal, mode anak/dewasa, hub Juz Amma.

## Fase 3 — hafalan

Target, blok (warna di background/border, bukan glyph), repeat 1–40, ayat
berikutnya tersembunyi, spaced repetition yang bisa dijelaskan, rekam lokal.

## Fase 4 — pemahaman dan institusi

Tafsir terkurasi, tema ayat terverifikasi, dashboard guru/TPQ, admin editorial
dengan audit trail.
