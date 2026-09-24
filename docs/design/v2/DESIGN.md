# DESIGN.md — Sacred Serenity v2

Melanjutkan `docs/design/ios-redesign/DESIGN_SPEC.md` (token v1 tetap berlaku). File ini menambah aturan v2 dan pola yang dipakai di `screens/`.

## 1. Token (sudah ada di `SacredTokens`)

| Token | Terang | Gelap |
|---|---|---|
| bg | #F4F1EA | #08110E |
| surf | #FCF9F8 | #111C18 |
| surf2 | #EAE6DC | #1A2823 |
| ink / sec | #1B1C1C / #5F625D | #ECEFEA / #9DA79F |
| primary / primaryText / primarySoft | #003527 / #00513B / #E0ECE5 | #8FD7B8 / #9ADDBF / rgba(143,215,184,.13) |
| gold / goldText / goldSoft | #C9A13B / #7A5A0E / #FBF0CC | #FED65B / #F4D679 / rgba(254,214,91,.12) |
| cta / ctaInk | #003527 / #FFFFFF | #FED65B / #1F1A05 |
| art (kartu hero) / artInk | #064E3B / #FED65B | #0B3D2F / #FED65B |

Font: Plus Jakarta Sans (UI), EB Garamond 500 (judul besar, nama surah), Amiri Quran (ayat).

## 2. Token baru v2

**Kertas mushaf** (`MushafPaper`):

| | Gading | Sepia | Malam |
|---|---|---|---|
| halaman | #FBF6E8 | #F4ECD8 | #0F1714 |
| latar di luar halaman | #F3EEDF | #EFE5CC | #08110E |
| tinta | #1B1C1C | #3E3222 | #E9ECE6 |
| bingkai tebal | #064E3B | #5B4630 | #0B3D2F |
| garis emas | #B8912E | #A7822C | #C9A13B |
| pita surah (isi / teks) | #EAF1EC / #003527 | #EFE3C4 / #3E3222 | #16261F / #F4D679 |

**Warna tajwid** (`TajweedPaletteKemenag`) — kelompok warna mengikuti Pedoman Tajwid Sistem Warna LPMQ Kemenag 2011 (cek ulang pemetaannya ke PDF), kecerahan disetel per kertas:

| Kelompok | Hukum (id aturan) | Gading | Malam |
|---|---|---|---|
| merah | idgham bilaghunnah, mutajanisain, mutaqaribain | #C62828 | #FF7B7B |
| magenta | idgham bighunnah, ghunnah, idgham mimi, mad lazim | #B0177E | #F58AD0 |
| cyan | iqlab, mad wajib muttashil | #00739E | #5CC8F2 |
| hijau | ikhfa', ikhfa' syafawi, mad jaiz munfashil, mad 'aridh | #1B7D3A | #6FD890 |
| biru | qalqalah | #2437B8 | #9AA8FF |
| abu | huruf tidak dibaca (lam syamsiyah, hamzah washal, silent) | #8A8A8A | #7F8A84 |

Mad thabi'i tidak diwarnai. Warna diberikan ke **huruf + harakatnya** (satu klaster), bukan ke latar. Tes otomatis: tiap warna ≥ 3:1 terhadap kertasnya. Pastikan pergantian warna di tengah kata tidak memutus sambungan huruf Arab (uji di perangkat; kalau terputus, sisipkan ZWJ U+200D di batas run — cara ini dipakai di mockup HTML).

## 3. Tata letak

- Lebar acuan 390 dp. Margin layar 16 (kartu) / 20 (judul). Jarak antarkartu 12; antargrup 18.
- Header layar utama: `LargeTitle` EB Garamond 42 + subjudul 14. Layar turunan: tautan balik "‹ Nama" (primaryText 17) di atas LargeTitle.
- Tab bar: kapsul kaca 64 tinggi, 12 dari kiri/kanan, 24 dari bawah; 5 tab sama lebar, ikon 22 + label 11. Tab aktif = kapsul primarySoft. Scrim gradien bg setinggi 140 di belakangnya.
- Baris list (`SettingsRow`/`ListRow`): tinggi min 56; `[leading 32–44] 12 [Expanded(title 16/700 + subtitle 13/500, 1 baris elipsis)] 10 [trailing intrinsik]`, pemisah 0.5 px mulai dari tepi kiri teks.
- Pill status: tinggi 24, padding 4×10, radius 10, teks 12/800, satu baris.
- Tombol utama: tinggi 48–54, radius penuh. Tombol ikon: 40–48 bulat.
- Tidak ada label yang terpotong di 390 dp. Pilihan saat sempit: ikon saja, label lebih pendek, atau pindah baris — tidak dengan elipsis di tombol.

## 4. Komponen baru

| Komponen | Pakai di | Catatan |
|---|---|---|
| `FloatingTabBar5` | shell | ganti tab bar 5+1 lama |
| `TodayList` | Beranda | InsetGrouped: Lanjutkan belajar (cincin progres), Murajaah hari ini (pill jumlah ayat) |
| `PrayerStrip` | Beranda | tinggi 54, gradien langit sesuai periode, teks tidak boleh terpotong |
| `MushafPageView` | Mushaf 1/2 halaman | bingkai ganda (hijau tebal + garis emas), rosette di 4 sudut, tab juz di tepi kanan, pita surah bersudut runcing, medali nomor halaman |
| `ReadingModeSheet` | Pembaca | 3 kartu mode + toggle tajwid + legenda + kertas |
| `TajweedLegend` | layar & sheet | per kelompok, contoh kata berwarna dari dataset |
| `VerseCard` | Kartu ayat | rosette, aksi, Arab bertajwid, terjemahan berlabel kode bahasa (ID/EN), baris unduh bahasa kedua |
| `LearningPath` | Belajar | node 44 bulat (selesai = emas + centang, sekarang = CTA, belum = garis), garis penghubung 2 px, kartu tahap aktif dengan progres & tombol Lanjutkan |
| `LessonScaffold` | Pelajaran | tombol tutup, bar progres, eyebrow tahap, judul serif, blok konten, kartu latihan, CTA bawah |
| `MemorizationStepper` | Sesi hafalan | 5 langkah: Dengar, Baca, Tutup, Uji, Sambung |
| `HiddenWordMask` | Sesi hafalan | kotak surf2 radius 10 selebar kata |
| `SelfRatingBar` | Sesi hafalan | Salah / Ragu / Lancar |
| `ReciterRow` | Qari | inisial bulat 42, nama 1 baris, subjudul nama Arab + gaya + bitrate + sumber, tombol dengar, centang |
