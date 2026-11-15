# Pernyataan pemilik tentang izin sumber audio: 15 November 2026

**Ini pernyataan, bukan surat izin dari pihak sumber.** Berkas ini dibuat supaya perubahan
status di `lib/data/audio_sources.dart` punya jejak yang jujur, sesuai aturan registri
("status diubah hanya setelah bukti izin disimpan di `docs/lisensi/bukti/`").

## Pernyataan

Zainul Arkaan, pemilik MyQuran, menyatakan pada 15 November 2026 (lewat sesi kerja dengan
Claude Code) bahwa **izin sudah diperolehnya** dari empat sumber untuk memakai audio murottal
di MyQuran: **equran.id**, **MP3Quran**, **QUL / Tarteel**, dan **Quran Foundation (quran.com)**.

Sumber **izin langsung dari qari** tidak termasuk dan tetap `pending`.

## Yang belum ada

Berkas izin tertulis dari tiap pihak (balasan email, surat, atau tangkapan layar persetujuan).
`docs/lisensi/STATUS_HAK_CIPTA.md` menyebut bahwa balasan email yang menyetujui sudah cukup
sebagai bukti dan **semua balasan harus disimpan**.

**Tindak lanjut untuk pemilik:** simpan balasan itu di folder ini dengan nama
`<sumber>-<tanggal>.<ekstensi>` (mis. `equran-2026-11-10.eml`) dan tautkan di tabel di bawah.
Selama belum ada, status granted bersandar hanya pada pernyataan ini.

## Akibat di aplikasi

| Sumber | Status | Apa yang berubah |
| --- | --- | --- |
| equran.id | granted | 4 qari baru tampil dan bisa diputar per ayat di rilis; menjadi cadangan saat CDN utama gagal. |
| MP3Quran | granted | Cadangan satu-berkas-per-surah saat CDN utama dan equran.id gagal. |
| Quran Foundation | granted | **Belum ada perubahan tampilan.** Sumber ini belum tersambung di kode dan butuh server perantara (`bff/`) beserta kredensial. Unduhan tetap dinonaktifkan (Developer Terms: konten maksimal 7 hari). |
| QUL / Tarteel | granted | **Belum ada perubahan tampilan.** Belum tersambung di kode. |

Empat qari yang hanya punya sumber MP3Quran, QUL, atau Quran Foundation **tidak ditampilkan di
rilis**, karena belum bisa diputar. Mereka muncul sendiri begitu sumbernya tersambung.

## Jika ada izin yang ternyata tidak ada atau dicabut

Kembalikan status sumber itu ke `pending` di `lib/data/audio_sources.dart` **dan** di
`assets/audio/qari_katalog.json`, lalu jalankan `flutter test test/qari`. Qari yang hanya
bergantung pada sumber itu hilang dari rilis otomatis.
