# Pesan izin qari — dikirim oleh Zainul sendiri

Aturan: alamat/kanal **hanya dari halaman resmi** masing-masing (jangan menebak email). Simpan semua balasan di `docs/lisensi/bukti/` (tangkapan layar + tanggal). Status sumber baru diubah setelah ada bukti.

Urutan yang paling berdampak: **(1) Quran Foundation** (Yasser Al-Dosari, Saad Al-Ghamdi, Al-Minshawi, Bandar Baleela) → **(2) equran.id** (Abdullah Al-Juhany, Yasser Al-Dosari) → (3) MP3Quran / QUL → (4) qari Indonesia.

---

## 1. Quran Foundation — permintaan akses produksi

**Kanal:** Developer Console (dev-console.quran.foundation) → proyek → *Request production access*. Bila ada kolom deskripsi, isi:

```
App: MyQuran (Android, package com.zainularkaan.quran), free, no ads, no in-app purchases.
Developer: Zainul Arkaan Al Insi, Indonesia.
Use: stream verse-by-verse recitation audio (URLs from the Content API) inside the app's
murottal player, and show chapter metadata. Credentials stay on our server proxy (never in
the app). We follow the Developer Terms: no caching over 7 days, no redistribution, text
unmodified, attribution to Quran Foundation on the Sources screen.
Recitations of interest: Yasser Ad-Dussary, Saad al-Ghamdi, Mohamed Siddiq al-Minshawi,
Mahmoud Khalil Al-Husary (Muallim), Bandar Baleela.
Question: do any of these recordings have separate rights holders whose permission we
need for in-app streaming? If so, who should we contact?
```

---

## 2. equran.id

**Kanal:** kontak yang tercantum di equran.id (halaman Terms/Kontak). Bahasa Indonesia.

```
Assalamu'alaikum warahmatullahi wabarakatuh,

Saya Zainul Arkaan Al Insi, pengembang aplikasi MyQuran (Android, gratis, tanpa iklan,
tanpa pembelian dalam aplikasi; package com.zainularkaan.quran).

Saya ingin meminta izin memutar audio per ayat dari API equran.id v2 di dalam aplikasi,
khususnya qari Abdullah Al-Juhany, Yasser Al-Dosari, Ibrahim Al-Dossari, dan Abdul Muhsin
Al-Qasim. Audio diputar langsung dari CDN equran.id (streaming), dengan atribusi
"Audio: equran.id" di layar Sumber. Bila diizinkan, pengguna juga dapat menyimpan audio
untuk didengar tanpa internet di HP-nya sendiri; bila tidak, fitur unduh untuk sumber ini
kami matikan.

Mohon kabarnya apakah penggunaan ini diperbolehkan, dan apakah ada syarat atribusi
atau batasan yang perlu kami ikuti. Kami juga ingin tahu apakah hak rekaman para qari
tersebut sudah termasuk dalam izin equran.id.

Jazakumullahu khairan.
Zainul Arkaan Al Insi — zainaril13@gmail.com
```

---

## 3. MP3Quran

**Kanal:** formulir mp3quran.net/eng/contact-us (teks permintaan umum sudah ada di `docs/lisensi/`). Tambahkan kalimat ini:

```
In particular we would like to offer these reciters (full-surah audio): Idrees Abkr,
Khalid Al-Jileel, Mohammed Al-Lohaidan, Mohammed Siddiq Al-Minshawi, and, if available
in your library, Yasser Al-Dosari and Nasser Al-Qatami.
```

---

## 4. Qari Indonesia (Muzammil Hasballah, Salim Bahanan)

**Kanal:** email manajemen/booking yang tercantum di profil resmi (bio Instagram/YouTube resmi). Jangan lewat komentar publik.

```
Assalamu'alaikum warahmatullahi wabarakatuh,

Saya Zainul Arkaan Al Insi, pengembang MyQuran, aplikasi Al-Qur'an Android yang gratis,
tanpa iklan, dan tanpa pembelian dalam aplikasi.

Banyak pengguna kami ingin mendengarkan bacaan Ustadz [NAMA]. Kami ingin memohon izin
memuat rekaman murottal beliau di aplikasi, dengan ketentuan:
- diputar per surah (atau per ayat bila tersedia) di pemutar murottal,
- nama beliau dicantumkan jelas beserta tautan kanal resmi,
- rekaman tidak dijual, tidak dipakai untuk iklan, dan tidak diubah.

Bila berkenan, kami mohon arahan berkas atau sumber rekaman resmi yang boleh dipakai,
serta syarat lain yang perlu kami penuhi. Bila belum berkenan, kami hormati sepenuhnya.

Jazakumullahu khairan.
Zainul Arkaan Al Insi — zainaril13@gmail.com
```

---

## Setelah izin datang

1. Simpan bukti di `docs/lisensi/bukti/<sumber>-<tanggal>.png|pdf`.
2. Kirim ke Claude Code: "Izin <sumber> sudah ada di docs/lisensi/bukti/<berkas>. Ubah status <sumber> menjadi granted di audio_sources.dart dan qari_katalog.json, isi ref yang masih null dari API sumbernya, jalankan tes, commit tersendiri."
