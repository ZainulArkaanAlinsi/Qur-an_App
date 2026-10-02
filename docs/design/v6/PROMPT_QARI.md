# Prompt Claude Code — qari v6.1

Paket ini **menggantikan Prompt 8** di `PROMPT_CLAUDE_CODE.md` (v6). Ekstrak di akar repo; `23-qari.md` lama tertimpa versi baru.
Boleh dikerjakan kapan saja setelah Prompt 2 (token & LiquidGlass). Kirim satu per satu.

---

## Prompt 8a — Katalog, registri izin, pemilih qari baru

```
Baca docs/design/v6/screens/23-qari.md, docs/design/v6/data/qari_katalog.json,
docs/lisensi/SURAT_IZIN_QARI.md, dan lihat V6-Qari.png serta
V6-Qari-Debug-Gelap.png. Branch fitur/v6 (atau fitur/qari bila v6 belum ada).
Rencana dulu, tunggu persetujuan saya.

1. Pindahkan katalog ke assets/audio/qari_katalog.json dan daftarkan di
   pubspec.yaml. Jangan mengubah isi kurasi (nama, tag, urutan populer).
2. lib/data/audio_sources.dart: enum LicenseStatus {granted, pending},
   AudioSourceInfo, daftar 6 sumber sesuai katalog. Status awal: hanya
   islamic_network = granted.
3. lib/data/qari_catalog.dart: memuat katalog, menggabungkan dengan daftar
   dinamis alquran.cloud (ReciterRepository) lewat ref, mengambil nama Arab
   dari API bila ada. Di rilis: buang qari tanpa sumber granted. Di debug:
   tampilkan semua + flag pending.
4. Isi ref yang null HANYA untuk sumber yang API-nya bisa diakses tanpa izin
   khusus (mis. daftar edisi alquran.cloud, daftar qari equran.id v2).
   Catat URL sumber tiap ref di deskripsi PR. Jangan menebak.
5. reciter_picker.dart dirombak sesuai §Tampilan: cari, chip filter
   (Semua/Adem/Populer/Hafalan/Merdu/Haramain, tersimpan di qari.filter),
   Dipilih, bagian Populer sekarang + A–Z, dengar contoh (playPreview,
   hanya satu yang berbunyi), pilih → antrean dimuat ulang di ayat yang sama.
6. Qari per surah: keterangan di Murottal untuk Ulang ayat/Rentang; Sesi
   harian selalu memakai qari per ayat.
7. Tes (a)–(f) dari "Selesai jika" + golden V6-Qari (terang, gelap, teks 2.0)
   dan versi debug. Buka PNG golden, bandingkan dengan acuan, perbaiki selisih.
8. Tambah 2 baris ke docs/decisions.md (tanggal 2026-10-02):
   - "Katalog qari terkurasi (35) + registri izin; rilis hanya sumber granted."
   - "Quran Foundation diakses lewat bff/ di Cloudflare Workers (gratis);
      secret tidak di aplikasi; audio QF tanpa unduhan (batas 7 hari)."
9. JANGAN menambah URL audio dari YouTube/TikTok/Instagram/Drive atau sumber
   pending ke build rilis.
Commit "Qari v6.1: katalog 35 qari, registri izin, pemilih baru". PR, jangan merge.
```

---

## Prompt 8b — Quran Foundation lewat bff/ (setelah pemilik punya kredensial)

Kirim hanya setelah: (1) proyek dibuat di dev-console.quran.foundation, (2) kamu sudah punya `client_id`/`client_secret` (prelive cukup untuk uji).

```
Baca bff/README.md, docs/design/v6/screens/23-qari.md bagian
"Sumber Quran Foundation", dan Developer Terms
(api-docs.quran.foundation/legal/developer-terms). Branch fitur/qari-qf.
Rencana dulu.

1. bff/: tambah GET /v1/recitations/:id/chapters/:chapter/audio
   → [{verseKey, url, durationMs?}] dalam bentuk milik aplikasi. Cek dulu di
   dokumentasi API endpoint audio per ayat yang benar dan bentuk URL-nya
   (relatif/absolut); jangan menebak. Cache ≤ 7 hari, secret hanya dari env,
   tes vitest.
2. Siapkan deploy Cloudflare Workers (adapter Hono untuk Workers, wrangler.toml,
   secret lewat `wrangler secret put`). Tulis langkahnya di bff/README.md untuk
   saya jalankan sendiri. Jangan deploy, jangan menaruh secret di repo.
3. Aplikasi: AudioRepository mendukung sumber quran_foundation lewat URL BFF
   (dari --dart-define=BFF_URL, kosong = sumber dimatikan). Unduh disembunyikan
   untuk qari dari sumber ini.
4. Status quran_foundation tetap pending. Saya yang mengubahnya ke granted
   setelah akses produksi disetujui (commit tersendiri dengan bukti).
5. Tes Dart untuk pembentukan URL & penyembunyian Unduh; tes BFF.
Commit "Quran Foundation via BFF (belum aktif di rilis)". PR, jangan merge.
```

---

## Prompt 8c — Mengaktifkan sumber setelah izin datang (pakai berulang)

```
Izin <nama sumber> sudah saya simpan di docs/lisensi/bukti/<berkas>.
1. Buka berkasnya dan ringkas syaratnya (atribusi, boleh unduh atau tidak,
   batas lain).
2. Ubah status <sumber> menjadi granted di audio_sources.dart dan
   qari_katalog.json. Terapkan syaratnya (mis. sembunyikan Unduh bila tidak
   boleh, teks atribusi di layar Sumber & lisensi).
3. Isi ref yang masih null untuk sumber ini dari API resminya.
4. Perbarui docs/decisions.md (1 baris), docs/play-store/LISTING.md bila
   jumlah qari disebut, dan layar Sumber & lisensi.
5. Tes + golden pemilih qari. Commit tersendiri "Aktifkan sumber audio <nama>".
```
