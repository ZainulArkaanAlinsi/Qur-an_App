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

Teks disimpan verbatim.

**Penyimpanan byte-per-byte (21 September 2026):** `.gitattributes` menandai
`assets/quran/raw/**` sebagai `-text` agar Git tidak menormalisasi akhir baris.
Sebelumnya blob di Git telah dinormalisasi ke LF sehingga checkout baru tidak
cocok dengan checksum di atas; blob sekarang disimpan ulang dari salinan asli
(Uthmani: CRLF, XML: campuran) dan checksum index = checksum dokumen. Diff
dengan CR diabaikan kosong, jadi isi teks tidak berubah. Berkas sumber membawa pemberitahuan hak cipta Tanzil
dan lisensi Creative Commons Attribution 3.0. Syarat utamanya: teks tidak boleh
diubah, sumber Tanzil harus ditampilkan, tautan ke Tanzil disediakan, serta
pemberitahuan hak cipta harus ikut dalam salinan/substansi turunannya.

Catatan: endpoint unduhan Tanzil yang dicoba pada 20 September 2026 memberikan
HTTP 404. Berkas diperoleh dari salinan publik yang menyertakan blok atribusi
Tanzil utuh. Sebelum rilis, perbarui dari sumber resmi saat endpoint tersedia,
bandingkan checksum/diff, lalu minta review konten manusia yang kompeten.

## Terjemahan dan murottal — diperiksa 21 September 2026

### Terjemahan Indonesia (`id.indonesian`) — dibundel offline

- **Berkas:** `assets/quran/raw/tanzil_id.indonesian_2010-06-04.txt`, disalin
  byte-per-byte tanpa perubahan.
- **Unduhan:** `https://tanzil.net/trans/?transID=id.indonesian&type=txt-2`
  (identik dengan `https://tanzil.net/trans/id.indonesian`), 21 September 2026.
- **SHA-256 berkas hulu (akhir baris LF, 1.159.449 byte):**
  `70428E875C50C3C42D3829654D2BD386E146F0FA68CC20C34FDD4EA3B53E21A8`.
- **Header berkas:** Name: Bahasa Indonesia · Translator: Indonesian Ministry
  of Religious Affairs · ID: id.indonesian · Last Update: June 4, 2010 ·
  Source: Tanzil.net. Artinya edisi ini **sebelum** revisi terjemahan Kemenag
  2019.
- **Validasi:** 6.236 baris `surah|ayat|teks`, 114 surah, tanpa duplikat,
  jumlah ayat per surah cocok dengan manifest (`test/translation_test.dart`).
  Teks identik dengan respons `api.alquran.cloud` untuk surah 1, 2, 9, 27, dan
  114 (0 perbedaan).
- **Ketentuan Tanzil:** "The translations provided at this page are for
  non-commercial purposes only. If used otherwise, you need to obtain
  necessary permission from the translator or the publisher."
- **Ketentuan Al Quran Cloud (Section IV):** penerbit ulang terjemahan diminta
  menyebut nama penerjemah. Atribusi tampil di Pengaturan > Konten & sumber.

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
