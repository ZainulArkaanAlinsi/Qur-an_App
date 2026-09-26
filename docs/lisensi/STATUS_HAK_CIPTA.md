# Status hak cipta & lisensi MyQuran (25 September 2026)

Ringkasan untuk memastikan aplikasi **tidak melanggar hak cipta**. Ini bukan nasihat hukum.
Dasar hukum Indonesia: UU No. 28 Tahun 2014 tentang Hak Cipta.

- **Pasal 42 huruf e:** tidak ada hak cipta atas kitab suci. Teks Al-Qur'an sendiri bebas.
- **Pasal 40 ayat (1) huruf n:** terjemahan, basis data, dan karya transformasi lain
  **dilindungi**. Yang perlu izin adalah terjemahan, tata letak/basis data mushaf, audio
  rekaman qari, dan font.
- **Pasal 44 ayat (1) huruf a:** pemakaian untuk pendidikan dengan menyebut sumber tidak
  dianggap pelanggaran, selama tidak merugikan kepentingan wajar pencipta. Karena itu
  aplikasi tetap nonkomersial dan selalu menyebut sumber, sambil meminta izin tertulis.
- **Pasal 80:** izin (lisensi) sebaiknya berupa perjanjian tertulis. Balasan email yang
  menyetujui sudah cukup sebagai bukti; **simpan semua balasan**.

## Per sumber

| Sumber | Dipakai untuk | Lisensi / syarat | Status | Tindakan |
| --- | --- | --- | --- | --- |
| Tanzil Uthmani 1.0.2 | Teks Arab (bawaan) | CC BY 3.0: salinan persis, **dilarang diubah**, sebut Tanzil + tautan tanzil.net | ✅ Aman | Atribusi sudah ada di *Saya › Sumber & lisensi* |
| Terjemahan Kemenag (via Tanzil `id.indonesian`) | Terjemahan Indonesia (bawaan) | Hak cipta Kemenag; Tanzil: terjemahan hanya untuk **nonkomersial** | ⚠️ Boleh selama nonkomersial + atribusi; izin tertulis diminta | Kirim **surat 01**. Jangan pasang iklan/berbayar |
| cpfair/quran-tajweed | Warna tajwid; bantu memilih contoh materi | CC BY 4.0: wajib atribusi | ✅ Aman | Atribusi sudah ada |
| QuranEnc | Terjemahan bahasa lain (unduhan) | Syarat QuranEnc: tanpa diubah, sebut sumber, penerjemah & versi | ✅ Sesuai syarat; konfirmasi diminta | Kirim **surat 07** |
| fawazahmed0/quran-api | Terjemahan cadangan bila QuranEnc gagal | Kode: Unlicense. **Teks terjemahan tetap milik penerjemahnya** | ⚠️ Risiko sedang | Pertimbangkan mematikan cadangan ini, atau hanya mengizinkan terjemahan yang lisensinya jelas |
| Islamic Network CDN (alquran.cloud) | Audio per ayat (streaming + simpan di HP) | Hak rekaman milik qari/penerbit; layanan gratis dengan atribusi | ⚠️ Konfirmasi diminta | Kirim **surat 04** |
| MP3Quran | Audio per surah | Hak rekaman milik qari/penerbit | ⚠️ Izin diminta | Kirim **surat 05** |
| equran.id | Audio cadangan | Lihat equran.id/terms | ⚠️ Izin diminta | Kirim **surat 06** |
| QUL / KFGQPC (tata letak mushaf) | Mushaf 1/2 halaman | Tidak ada lisensi tertulis di QUL | ⛔ **Tidak dipakai di rilis** (tampil "segera") | Kirim **surat 02** dan **03**. Aktifkan hanya setelah izin |
| AlAdhan | Jadwal salat | API gratis | ✅ Aman | Atribusi sudah ada |
| GDELT | Daftar judul berita + tautan | Data terbuka; isi berita milik penerbitnya | ✅ Aman (hanya judul + tautan) | — |
| Font Plus Jakarta Sans, EB Garamond, Amiri, Amiri Quran | Tampilan | SIL OFL 1.1 | ✅ Aman | Teks lisensi ikut di halaman lisensi aplikasi |
| Kode aplikasi | Seluruh `lib/`, tes, tool | **MIT** (`LICENSE`), hanya untuk kode & dokumen buatan pemilik | ✅ | Pengecualian (data, font, logo) tercantum di `NOTICE` |
| Logo MyQuran | Brand | Milik pemilik (dibuat dengan alat gambar) | ⚠️ Simpan bukti | Simpan bukti akun/tanggal/prompt dan cek ketentuan alatnya (LISENSI_ASET §1) |
| Materi tajwid tahap 6–16 | Belajar | Teks orisinal (draf); ayat hanya rujukan | ✅ Aman | Tetap draf sampai 2 ustadz meninjau |

## Pengaman yang sudah ada di aplikasi

- Teks ayat dan terjemahan ditampilkan **persis** dari dataset, tanpa diketik ulang.
- Halaman *Saya › Sumber & lisensi* menyebut nama, versi, lisensi, dan tautan tiap sumber.
- Tanpa iklan, tanpa pembelian, dan tanpa penjualan data (syarat nonkomersial).
- Mushaf 1/2 halaman **dikunci** di rilis sampai lisensi tata letak ada.
- Audio tidak dibundel di APK; hanya diputar atau disimpan di HP pengguna.

## Yang perlu diperhatikan

- **Onboarding halaman 2** sudah diubah di 1.9.2 menjadi "Baca ayat demi ayat" (kartu ayat,
  terjemahan, tajwid). Onboarding dan listing toko tidak lagi menjanjikan mode mushaf
  sebelum izin tata letak keluar.
- Jangan menambah iklan, langganan, atau fitur berbayar sebelum izin Kemenag dan penyedia
  audio keluar.
- Kalau ada pihak yang menolak atau meminta berhenti, hapus sumbernya paling lambat
  14 hari (sesuai janji di surat).
