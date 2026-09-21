# Atribusi dataset Arab offline

- **Teks:** Tanzil Quran Text, Uthmani versi 1.0.2
- **Berkas:** `assets/quran/raw/tanzil_uthmani_v1.0.2.txt`
- **SHA-256:** `3BCDCF93E06FD7B932E023916A8C4B4046BFE8346ED1876FB23FF76884CC9169`
- **Unduhan proyek:** 20 September 2026
- **Sumber asal dan pembaruan:** [Tanzil.net](https://tanzil.net/) dan [halaman pembaruan](https://tanzil.net/updates/)

## Metadata navigasi Juz

- **Berkas:** `assets/quran/raw/quran-data.xml`
- **Versi:** Tanzil metadata 1.0
- **SHA-256:** `8867C1D88191472ADEC9DB694B3CD9F135B1A2EF580574D32CF888DCB22C5C7A`
- **Penggunaan:** batas awal 30 Juz untuk membuka surah dan ayat yang tepat.

Teks disimpan verbatim. Berkas sumber membawa pemberitahuan hak cipta Tanzil
dan lisensi Creative Commons Attribution 3.0. Syarat utamanya: teks tidak boleh
diubah, sumber Tanzil harus ditampilkan, tautan ke Tanzil disediakan, serta
pemberitahuan hak cipta harus ikut dalam salinan/substansi turunannya.

Catatan: endpoint unduhan Tanzil yang dicoba pada 20 September 2026 memberikan
HTTP 404. Berkas diperoleh dari salinan publik yang menyertakan blok atribusi
Tanzil utuh. Sebelum rilis, perbarui dari sumber resmi saat endpoint tersedia,
bandingkan checksum/diff, lalu minta review konten manusia yang kompeten.

## Sumber online (belum dibundel) — diperiksa 21 September 2026

### Terjemahan Indonesia (`id.indonesian`)

- **Dimuat dari:** `https://api.alquran.cloud/v1/surah/{n}/id.indonesian`.
- **Metadata API:** `name: "Bahasa Indonesia"`, `englishName: "Unknown"` —
  Al Quran Cloud sendiri tidak mencantumkan penerjemah.
- **Sumber hulu:** katalog [Tanzil Translations](https://tanzil.net/trans/)
  mencantumkan edisi *Bahasa Indonesia* dengan penerjemah **Indonesian
  Ministry of Religious Affairs** (Kementerian Agama RI).
- **Ketentuan Tanzil:** "The translations provided at this page are for
  non-commercial purposes only. If used otherwise, you need to obtain
  necessary permission from the translator or the publisher."
- **Ketentuan Al Quran Cloud (Section IV):** penerbit ulang terjemahan diminta
  menyebut nama penerjemah.
- **Belum diketahui:** edisi/tahun terjemahan Kemenag yang dipakai (misalnya
  sebelum atau sesudah revisi 2019) dan apakah teks identik dengan rilis resmi
  Kemenag. Kesamaan teks belum dibandingkan.

### Murottal (`ar.alafasy`)

- **URL:** `https://cdn.islamic.network/quran/audio/128/ar.alafasy/{nomorGlobal}.mp3`.
- **Ketentuan Al Quran Cloud (Section IV):** "Recitations are licensed to us by
  the reciters or their estates for free, non-commercial redistribution at the
  bitrates we publish. You may stream, embed and download them for personal
  and educational use. You may bundle them into a commercial product, but
  please note that copyrights lie with the reciters and they may ask you to
  remove the content."
- **Section III:** CDN audio tanpa batas per klien; pengembang diminta
  melakukan cache agresif. API teks memakai soft rate limit per IP.
- **Kesimpulan:** streaming di aplikasi gratis tanpa iklan sesuai ketentuan.
  Unduhan offline untuk pemakaian pribadi diizinkan; membundel audio di APK
  tidak direkomendasikan karena qari dapat meminta penghapusan.

### Status monetisasi aplikasi

Pada commit ini tidak ada iklan, pembelian dalam aplikasi, atau langganan
(`pubspec.yaml`/`lib` diperiksa). Menambahkan salah satunya mengubah status
non-komersial dan mewajibkan izin dari Kemenag untuk terjemahan.

### Regulasi Indonesia: tanda tashih

Permenag No. 44 Tahun 2016 mendefinisikan mushaf Al-Qur'an sebagai media berisi
ayat Al-Qur'an "baik cetak maupun digital" (Pasal 1) dan mewajibkan setiap
mushaf yang diterbitkan/diedarkan di Indonesia memperoleh Surat Tanda Tashih
atau Surat Izin Edar dari LPMQ (Pasal 2). Layanan tashih LPMQ menerima jenis
naskah "Mushaf Al-Qur'an Digital" (biaya tercantum Rp1.000.000 per surat,
tambahan materi seperti terjemah Rp500.000 per item). Sumber:
[teks Permenag 44/2016](https://pasal.id/peraturan/permen/permenag-no-44-tahun-2016),
[PDF resmi LPMQ](https://tashih.kemenag.go.id/uploads/1/2018-05/pma_nomor_44_tahun_2016.pdf)
(hasil pindai, belum dibaca langsung), dan
[standar pelayanan tashih](https://tashih.kemenag.go.id/info-layanan-pentashihan/read/standar-pelayanan-permohonan-surat-tanda-tashih).
Ini bukan nasihat hukum; konfirmasi ke LPMQ sebelum publikasi.
