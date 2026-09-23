# Spesifikasi Revisi v2 — Qur'an App

Pasangan dari `RISET_SUMBER.md`. Taruh keduanya di `docs/revisi-v2/` di repo.
Aturan dasar tetap: `QURAN_APP_GUIDE_DAN_PROMPT_CODEX.md`, `docs/RELIGIOUS_CONTENT_GOVERNANCE.md`, `docs/design/ios-redesign/DESIGN_SPEC.md`.

Tujuan revisi: orang yang **belum bisa membaca sama sekali** bisa belajar di aplikasi ini sampai **lancar dan bertajwid**, lalu lanjut menghafal — dengan tampilan rapi, konsisten, dan konten yang akurat.

---

## A. Tiga mode baca

Pilihan ada di Pembaca (tombol tampilan) dan di Pengaturan › Membaca › Mode bawaan.

### A1. Mushaf 1 halaman (potret)
- Tata letak **persis cetakan** Mushaf Madinah KFGQPC 15 baris, 604 halaman, ayat pojok: kata per baris, baris per halaman, posisi judul surah, basmalah, baris rata tengah, nomor halaman — semua mengikuti data layout, **bukan dihitung ulang**.
- **Tanpa terjemahan.** Tap ayat → toolbar kecil (putar, bookmark, salin rujukan, tafsir/terjemahan di sheet).
- Hiasan halaman berwarna seperti mushaf cetak di foto: bingkai ornamen, pita judul surah, penanda juz/hizb/rubu' di margin, tab warna per juz di tepi, nomor halaman dalam medali, tanda sajdah. Ornamen digambar **orisinal** (CustomPainter/SVG sendiri) dengan token warna — jangan menjiplak ornamen penerbit tertentu.
- Kertas bisa: Putih gading, Sepia, Malam. Warna tinta & tajwid menyesuaikan (lihat C).

### A2. Mushaf 2 halaman (landscape)
- Muncul saat HP dimiringkan atau dipilih manual. Halaman **ganjil di kanan, genap di kiri** (mushaf dibuka dari kanan). Ada bayangan lipatan tengah.
- Geser **kanan → kiri** untuk maju. Jika lebar per halaman terlalu kecil, otomatis kembali ke 1 halaman (prototipe repo sudah punya logika ini).
- Tanpa terjemahan; aturan layout sama persis dengan A1.

### A3. Kartu per ayat
- Satu kartu = satu ayat: nomor, teks Arab (opsional berwarna tajwid), terjemahan bahasa pilihan, aksi (putar, ulangi, bookmark, bagikan rujukan).
- **Bahasa terjemahan bisa diganti** (67 bahasa via QuranEnc; unduh saat dipilih; tampilkan nama penerjemah + versi + sumber). Bisa tampilkan 2 terjemahan sekaligus (mis. Indonesia + Inggris).
- Opsi: sembunyikan terjemahan, ukuran teks, per kata (hanya jika data terjemah per kata berlisensi tersedia).

### Pendekatan teknis yang disarankan (harus di-spike & dibuktikan dulu)
1. **Layout**: data QUL KFGQPC V2 (1421H) — cek lisensinya. Simpan offline sebagai asset/DB read-only dengan checksum.
2. **Mode polos (tanpa warna)**: font glyph QPC V2 per halaman → bentuk huruf identik cetakan.
3. **Mode tajwid berwarna**, dua jalur — pilih yang lolos uji di perangkat nyata:
   - (a) Konversi font V4 COLRv1 → COLRv0 (fontTools) dan ganti palet CPAL ke warna standar Kemenag. Flutter mendukung COLRv0. Periksa lisensi font dulu.
   - (b) Font Unicode KFGQPC Hafs + data baris QUL + span warna per huruf dari `cpfair/quran-tajweed` (teks Tanzil). Isi tiap baris & halaman tetap sama persis; perbedaan hanya di justifikasi mikro.
4. Uji: bandingkan screenshot halaman 1, 2, 3, 50, 187 (awal At-Taubah), 273, 379, 582, 604 dengan mushaf cetak; kata pertama & terakhir tiap baris harus sama.

---

## B. Belajar dari nol sampai lancar (tab/section "Belajar")

Kurikulum **orisinal** (tidak menyalin Iqro' atau metode bermerek lain tanpa izin). Setiap pelajaran: tujuan singkat → penjelasan pendek bergambar → contoh audio → latihan → kuis → selesai.

| Tahap | Isi | Latihan |
|---|---|---|
| 0. Mulai | Tes penempatan singkat ("Sudah bisa membaca?"), adab membaca Al-Qur'an | — |
| 1. Huruf hijaiyah | 28 huruf, nama & bunyi, huruf mirip (ب ت ث, ج ح خ, د ذ, ر ز, س ش, ص ض, ط ظ, ع غ, ف ق) | dengar → pilih huruf |
| 2. Bentuk sambung | Bentuk awal/tengah/akhir, huruf yang tidak menyambung ke kiri (ا د ذ ر ز و) | cocokkan bentuk |
| 3. Harakat | Fathah, kasrah, dhammah | baca suku kata |
| 4. Tanwin | Fathatain, kasratain, dhammatain | — |
| 5. Sukun & tasydid | Huruf mati, huruf ganda | — |
| 6. Mad asli | Alif, waw, ya' sebagai pemanjang 2 harakat; alif kecil (khanjariyah) | — |
| 7. Alif lam | Qamariyah & syamsiyah, lafzul jalalah (tafkhim/tarqiq) | — |
| 8. Tanda di mushaf | Hamzah washal, tanda waqaf (م، لا، ج، صلى، قلى، ∴), sajdah, rubu'/hizb | — |
| 9. Membaca ayat pendek | Al-Fatihah & Juz 'Amma dengan audio qari pengajar (mis. Husary Muallim) | ikuti & ulangi |
| 10. Nun sukun & tanwin | Izhhar, idgham (bighunnah, bilaghunnah), iqlab, ikhfa' | temukan di ayat |
| 11. Mim sukun & ghunnah | Ikhfa' syafawi, idgham mimi, izhhar syafawi, nun/mim bertasydid | — |
| 12. Mad far'i | Wajib muttashil, jaiz munfashil, 'aridh lissukun, lazim (4 macam), badal, 'iwadh, lin, shilah | — |
| 13. Qalqalah, ra', lam | Qalqalah sughra/kubra, tafkhim/tarqiq ra', lam jalalah | — |
| 14. Makharij & sifat | 17 makhraj (Al-Jazariyyah), sifat berlawanan & tidak | — |
| 15. Waqaf & ibtida' | Cara berhenti & memulai yang benar | — |
| 16. Bacaan gharib Hafs | Saktah (4 tempat), isymam (Yusuf 12:11), imalah (Hud 11:41), tashil (Fushshilat 41:44), naql (Al-Hujurat 49:11) | — |

Aturan konten:
- Penjelasan ditulis ulang dengan bahasa sederhana untuk semua umur (Claude boleh membantu merapikan bahasa), **berdasarkan** rujukan di `RISET_SUMBER.md`, dicantumkan sumbernya, lalu **wajib direview** minimal 2 pengajar bersanad sebelum terbit. Rilis hanya menampilkan materi berstatus terbit; debug boleh menampilkan draf berlabel.
- Contoh ayat selalu diambil dari dataset (pakai rujukan surah:ayat), tidak diketik.
- Audio huruf/makhraj harus rekaman manusia yang berkualitas & berizin. **Tidak memakai TTS atau AI** untuk bacaan. Jika belum ada rekaman, tampilkan state jujur "Audio contoh sedang disiapkan".
- Tidak ada penilaian bacaan otomatis (sesuai governance repo). Latihan berbasis dengar-pilih, tandai sendiri, atau setor ke guru.
- Hubungkan dengan mushaf: tap huruf berwarna di Pembaca → buka pelajaran hukum itu.
- Progres tersimpan per pelajaran; ada "Lanjutkan belajar" di Beranda.

Format materi: JSON per pelajaran di `assets/learn/` (skema yang sudah ada di `TajweedLessonRepository` diperluas: `level`, `order`, `objectives`, `blocks[]` [text|example|tip|audio|quiz], `sources[]`, `review`).

---

## C. Warna tajwid

Ikuti **Pedoman Tajwid Sistem Warna LPMQ Kemenag (2011)**: warna diberikan pada **huruf beserta harakatnya**, bukan latar/blok. Pemetaan warna **wajib dicocokkan langsung dengan PDF-nya** — ringkasan awal:

| Kelompok | Hukum | Warna dasar Kemenag |
|---|---|---|
| Hukum huruf | Idgham bilaghunnah | Merah |
| | Idgham bighunnah & ghunnah | Magenta |
| | Iqlab | Cyan |
| | Ikhfa' (haqiqi & syafawi) | Hijau |
| | Qalqalah | Biru |
| Panjang | Mad 6 harakat (lazim) | Magenta |
| | Mad 4–5 harakat | Cyan |
| | Mad 2 atau 4–5 (jaiz/'aridh) | Hijau |
| Lainnya | Huruf tidak dibaca | Abu-abu |
| Waqaf | Wajib berhenti / boleh / lebih baik lanjut | Merah / Biru / Hijau |

Aturan tampil:
- Hue mengikuti Kemenag, tapi **nilai warnanya disetel per kertas** agar kontras terhadap latar ≥ 3:1 (teks Arab besar) — warna huruf **tidak boleh sama/mirip dengan latar**. Cyan & magenta murni di atas krem tidak cukup kontras; pakai versi yang lebih gelap di kertas terang dan lebih terang di kertas malam.
- Buat palet untuk 3 kertas (terang, sepia, malam) + tes otomatis kontras.
- Pewarnaan per klaster (huruf + harakat) agar shaping Arab tidak rusak.
- Legenda selalu bisa dibuka; toggle tajwid on/off; mode buta warna (tambahan garis bawah/titik) sebagai opsi.

---

## D. Hafalan (Tahfizh)

Tujuan yang dijelaskan di layar: **ziyadah** (menambah hafalan baru), **murajaah** (mengulang supaya tidak lupa), **tasmi'** (setoran/menguji diri).

- Rencana: pilih target (disarankan mulai Juz 'Amma dari An-Nas mundur), jumlah baris/ayat per hari, hari libur.
- Sesi ziyadah terpandu: dengar ayat N kali → baca sambil lihat → sembunyikan kata demi kata → uji dengan petunjuk kata pertama → sambungkan dengan ayat sebelumnya (rabth) → tandai lancar/ragu/salah.
- Murajaah terjadwal dengan pengulangan berjarak yang bisa dijelaskan (mis. 1-3-7-14-30 hari; diperpanjang kalau lancar, dipendekkan kalau salah).
- Status **per ayat**, bukan cuma per surah; catatan bagian yang sering salah.
- Rekam suara sendiri **opsional & hanya lokal** untuk didengar ulang/dikirim ke guru.
- Perbaiki bug: hitungan ulang 3×/5×/10× tidak berhenti; 1× malah memutar sampai akhir surah.
- Masukkan ke sinkronisasi cloud (data milik pengguna, aturan keamanan seperti data lain).

---

## E. Beranda, Pengaturan, Qari

**Beranda** (urutan tetap mengikuti panduan): lanjut baca → target & istiqamah → **lanjut belajar** (pelajaran berikutnya) → **murajaah hari ini** (jumlah ayat jatuh tempo) → pintasan → strip salat kecil → ayat pilihan. Ganti "ayat acak" dengan **daftar ayat pilihan yang dikurasi & direview**. Semua warna dari token; hapus widget duplikat (`_SoftCard`, `_CircleButton`).

**Pengaturan** — susunan baru:
1. Akun & sinkronisasi
2. Tampilan (tema, palet, kontras tinggi)
3. Membaca (mode bawaan 1 halaman/2 halaman/kartu, kertas mushaf, tajwid berwarna + legenda, ukuran & jarak teks)
4. Terjemahan (tampil/sembunyi, bahasa & sumber, terjemahan kedua)
5. Audio (qari dengan tombol dengar contoh, kualitas/hemat kuota, unduhan & penyimpanan)
6. Kebiasaan & pengingat (target 5/10/15/30, pengingat baca, pengingat murajaah)
7. Salat (kota, metode, notifikasi) — pindahan dari layar lain
8. Sumber & lisensi (dinamis sesuai qari/terjemahan/mushaf yang aktif)
9. Tentang & pembaruan (digabung)
Perbaikan: judul "Pengaturan" dobel, warna chip hardcode, baris murottal yang hardcode Alafasy.

**Qari**: model `Reciter` baru {id, nama, namaArab, gaya (murattal/mujawwad/muallim), riwayat (Hafs saja ditampilkan), penyedia, pola URL, bitrate, punya timing per kata?, atribusi}. Gabungkan Al Quran Cloud + EveryAyah (+ Quran Foundation lewat BFF bila kredensial ada). Setiap qari diverifikasi (HEAD ke 1:1 dan 114:6) sebelum tampil. Daftar dikelompokkan, ada pencarian & tombol dengar contoh. Sorot per kata hanya untuk qari yang punya data timing.
