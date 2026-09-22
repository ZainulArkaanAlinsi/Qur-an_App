# Sumber data dan lisensi

Status: draf Fase 0 · 22 September 2026. Rincian checksum dan kutipan
ketentuan untuk data yang **sudah dibundel** ada di
`docs/DATASET_ATTRIBUTION.md`. Ini bukan nasihat hukum.

## Ringkasan status

| Sumber | Dipakai untuk | Status | Syarat kunci |
|---|---|---|---|
| Tanzil Uthmani 1.0.2 | Teks Arab card (dibundel) | **Aktif** | CC BY 3.0, verbatim, atribusi + tautan |
| Tanzil `id.indonesian` (Kemenag, 2010) | Terjemahan (dibundel) | **Aktif** | **Non-komersial**; edisi pra-2019 |
| Al Quran Cloud CDN (`ar.alafasy`) | Murottal streaming | **Aktif** | Hak pada qari; bisa diminta hapus; cache |
| Quran Foundation Content API | Tajwid, QCF V2/V4, page layout, qari, timing | **Belum** — perlu client credentials | Secret hanya di server; jangan jual/redistribusi raw data; ikuti cache/Content Sync; atribusi |
| Qur'an Kemenag API (LPMQ) | MSI, terjemahan 2019, Tafsir Ringkas/Tahlili | **Belum** — perlu surat permohonan + token | Token hanya di server; ketentuan biaya belum dikonfirmasi |
| Materi Iqro (AMM) | — | **Tidak dipakai** | Butuh izin tertulis; default: kurikulum orisinal |

## Catatan per sumber

### Quran Foundation

- Akses resmi: OAuth2 client credentials (scope `content`) lewat BFF di
  `bff/`; dokumentasi provider melarang alur ini dijalankan dari aplikasi
  mobile. Lingkungan prelive hanya memuat surah 1–2.
- Developer Terms: konten tidak boleh disimpan lebih dari 1 minggu kecuali
  lewat Content Sync (sinkron ulang minimal tiap 7 hari); menjual atau
  meredistribusi raw API data butuh lisensi komersial tertulis.
- Riset spike 22 September 2026 memakai endpoint publik
  `api.quran.com/api/v4/quran/verses/uthmani_tajweed` **hanya untuk analisis
  format**. Aplikasi produksi tidak boleh memanggilnya langsung; gunakan
  Content API resmi lewat BFF setelah menyetujui developer terms.
- Dump tidak di-commit. Fixture uji
  (`test/fixtures/qf_uthmani_tajweed_sample.json`) berisi 9 ayat + 1 ayat cacat,
  verbatim, hanya untuk tes, tidak dibundel ke APK.
- Class yang ditemukan pada 6.236 ayat (17): `ham_wasl, laam_shamsiyah, slnt,
  madda_normal, madda_permissible, madda_obligatory, madda_necessary, qalaqah,
  ikhafa, ikhafa_shafawi, idgham_ghunnah, idgham_wo_ghunnah, idgham_shafawi,
  idgham_mutajanisayn, idgham_mutaqaribayn, iqlab, ghunnah` + `span.end`.
- Teks tajwid **berbeda edisi** dengan Tanzil (1.256/6.236 identik). Lihat
  SDD ADR-2.
- Cacat data: 32:3 (tag pembuka hilang). Laporkan ke provider.
- `text_uthmani` QF berbeda encoding dengan `text_uthmani_tajweed`
  (2.026/6.236 identik); keduanya perlu dianggap edisi/encoding berbeda.
- Layar pratinjau debug memanggil api.quran.com langsung dari perangkat;
  dibatasi `kDebugMode` sehingga tidak ada di build rilis.
- Layout QCF adalah Mushaf Madinah; tampilkan namanya dengan jujur, jangan
  sebut Mushaf Standar Indonesia.

### LPMQ Kemenag

- Portal: https://quran-api.lpmqkemenag.id/ — akses dengan pendaftaran, surat
  permohonan, aktivasi, token. Jangan menyebut gratis selamanya sebelum
  dikonfirmasi.
- Jika target tampilan MSI: gunakan hanya font Isep Misbah/page map/aset resmi
  yang diizinkan.
- Tanda tashih: Permenag 44/2016 mencakup mushaf digital (lihat
  `DATASET_ATTRIBUTION.md`). Konfirmasi ke LPMQ sebelum publikasi luas.

### Audio

Setiap `Reciter`/`RecitationTrack` menyimpan provider, lisensi, dan flag
`enabled` yang dapat dimatikan dari server (tanpa update aplikasi) bila ada
permintaan penghapusan. Jangan mengklaim semua audio bebas komersial.

### Font

| Font | Lisensi | Status |
|---|---|---|
| Amiri (dibundel) | OFL 1.1 (`assets/fonts/OFL-Amiri.txt`) | Aktif; perlu uji glyph penuh Fase 1 |
| QPC/Uthmanic Hafs | Periksa lisensi KFGQPC | Kandidat default card |
| QCF V2/V4 per halaman | Dari Quran Foundation | Hanya dengan glyph/halaman yang sesuai |
| Isep Misbah (LPMQ) | Butuh izin | Belum |
| Inter/Noto Sans/Source Sans 3/Lora/Literata | OFL | Kandidat UI, verifikasi sebelum bundel |

## Menu Sumber & Lisensi

Pengaturan > Konten & sumber sudah menampilkan atribusi Tanzil dan terjemahan.
Setiap sumber baru wajib ditambahkan di sana sebelum dirilis.
