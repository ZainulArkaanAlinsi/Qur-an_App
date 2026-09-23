# Revisi v2 — Tahap 0: audit, baseline, dan rencana

Tanggal: 23 September 2026 · branch `revisi-v2` dari `main` (`cebc758`) · versi `1.4.0+9`

Semua angka di dokumen ini berasal dari perintah yang benar-benar dijalankan atau
dari pembacaan berkas per baris. Yang belum diuji ditulis sebagai belum diuji.

## 1. Baseline sebelum menyentuh apa pun

| Perintah | Hasil |
|---|---|
| `flutter pub get` | sukses (60 paket punya versi lebih baru yang tidak kompatibel dengan constraint) |
| `dart analyze lib test` | **No issues found** |
| `flutter test` | **252 lulus**, 0 gagal (40 berkas tes) |
| `graphify update .` | sukses; `graphify-out/` ada, jadi asumsi di prompt ("belum ada") tidak berlaku |

Kalau nanti ada yang gagal, itu regresi dari revisi ini, bukan warisan.

## 2. Verifikasi temuan audit di prompt

Diverifikasi sendiri terhadap kode, bukan diterima mentah.

| # | Klaim di prompt | Verdik | Bukti |
|---|---|---|---|
| 1 | Belajar & Tajwid campur Material mentah dan SacredTokens | **SEBAGIAN** | `learn_screen.dart` tidak memakai SacredTokens **sama sekali** (impornya hanya material + glass_surface) — jadi bukan campuran, tapi seluruhnya Material. `tajweed_lessons_screen.dart` memang campuran (SacredTokens di `:25,100,133,181,227`; Scaffold/AppBar/ListTile mentah di `:26,182,292`). `practice_screen.dart` juga 100 % Material dan memakai `fontFamily: 'Amiri'` hardcode di `:335` |
| 2 | `assets/learn/tajweed_lessons.json` kosong | **BENAR** | 159 byte, `"lessons": []`, `source` semua kosong → `isReady` false → layar menampilkan "Materi tajwid belum dimuat" |
| 3 | Kartu "Belajar Membaca Al-Qur'an" masih "Belum tersedia" | **BENAR** | `learn_screen.dart:88-94` + `Chip(Text('Belum tersedia'))` `:137-140` |
| 4 | Daftar Juz 'Amma dobel antara Belajar dan Hafalan | **SALAH** | Belajar menampilkan 78–114 tetap (`learn_screen.dart:15-16,57-58`); Hafalan menampilkan hanya surah yang sudah ditandai, dari 114 surah (`memorization_screen.dart:18,152-157`). Yang dipakai bersama adalah widget `MemorizationTile`, satu berkas — bukan duplikasi daftar |
| 5 | Belajar & Hafalan hanya dari tab Progres | **BENAR** | Satu-satunya rujukan: `progress_screen.dart:159` dan `:170`. Pintasan Beranda hanya Surah/Bookmark/Khatam |
| 6a | Repeat 3×/5×/10× tidak pernah berhenti | **BENAR** | `playRange` selalu `AudioRepeat.range` (`quran_audio_service.dart:204-207`) → `LoopMode.all` (`:326-330`); `setRepeat` menolak `range` di `:258`. Nilai 3/5/10 tidak pernah dipakai sebagai pencacah di mana pun |
| 6b | Opsi 1× memutar sampai akhir surah | **BENAR** | Keluar dari rentang memuat `AudioQueue.from(q.surah, ayah)` **tanpa** `toAyah` (`:262-269`) → sampai ayat terakhir surah. Tombolnya sendiri tertulis "Putar ayat $from–$to" (`practice_screen.dart:240`), jadi labelnya berbohong |
| 7 | Status hafalan hanya per surah, tanpa murajaah, tanpa sync | **BENAR** | `hafalan_status_{surah}` berisi nama enum saja (`shared_preferences_service.dart:288,300-302`). `firebase_sync.dart:189` hanya menyinkronkan `sessions` dan `bookmarks` |
| 8 | Judul "Pengaturan" dobel | **BENAR** | `app_shell.dart:177` dan `settings_screen.dart:74-77`, dua `LargeTitle` aktif |
| 9 | Warna chip Pengaturan hardcode | **BENAR** | `settings_screen.dart:25-30`, 5 konstanta top-level di luar tema → tidak ikut berubah di mode gelap |
| 10 | Baris sumber murottal hardcode Alafasy | **BENAR** | `settings_screen.dart:243-252`, seluruh grupnya `const` sehingga mustahil membaca qari terpilih. Bitrate "128 kbps" juga tetap walau mode hemat kuota memakai 64 |
| 11 | Pembaruan terpecah dua grup | **BENAR** | "Pembaruan aplikasi" (`:257`) dan "Tentang aplikasi" (`:263`) |
| 12 | Tidak ada pilihan mode baca / terjemahan / tajwid / salat | **BENAR** | Grup yang ada hanya: akun, Tampilan, Bacaan (3 slider), Kebiasaan & audio, Sumber & lisensi, Pembaruan, Tentang, Debug |
| 13 | Beranda ±23 warna hardcode | **BENAR, tepat 23** | Baris 317, 525, 535, 547, 578, 581, 592, 593, 597, 629, 709, 771, 1135, 1237-1240, 1252, 1257, 1269, 1272, 1288, 1294 |
| 14 | `_SoftCard`/`_CircleButton` duplikat | **BENAR** | `_CircleButton` (`home_screen.dart:280-331`) hampir identik dengan `SacredCircleButton` (`sacred_controls.dart:413-468`); kartu lembut ada **tiga** implementasi: `home_screen.dart:755`, `progress_screen.dart:190`, `settings_screen.dart:1032` |
| 15 | "Ayat hari ini" acak | **SEBAGIAN** | Bukan acak — deterministik dari tanggal (`home_screen.dart:71-74`), stabil sepanjang hari. Tapi **tanpa kurasi**: seluruh 6.236 ayat berpeluang muncul, jadi risiko ayat lepas konteks tetap nyata. Bonus cacat: `seed % 114` dan `seed % ayahCount` dari seed yang sama membuat surah maju berurutan tiap hari dan bias ke ayat-ayat awal |
| 16 | Beranda tanpa pintu ke Belajar/Hafalan | **BENAR** | `home_screen.dart:139-184`, pintasan hanya 3 |
| 17 | Qari hanya Al Quran Cloud, model tanpa provider/lisensi | **SEBAGIAN** | Sumber tunggal: **BENAR** (`reciter_repository.dart:17-18`). Model `Reciter` hanya 4 field (`identifier`, `name`, `englishName`, `bitrate?`): **BENAR**. Jumlah "±15": **tidak bisa dipastikan dari kode** — daftarnya dinamis dari API, tanpa filter klien sama sekali (termasuk edisi audio terjemahan dan riwayat non-Hafs yang seharusnya disaring) |
| 18 | Mushaf 604 halaman hanya prototipe debug | **BENAR** | Satu-satunya pintu: `settings_screen.dart:265` di balik `if (kDebugMode)`. Di rilis cabangnya di-tree-shake |
| 19 | `TajweedMarkupParser` tidak dipakai di rilis | **BENAR** | Pemanggilnya hanya dua layar debug, satu skrip `tool/`, dan dua berkas tes |
| 20 | Palet tajwid bukan standar Kemenag | **BENAR** | `tajweed_palette.dart`, satu preset `draft-preview-1` berstatus draft. String "Kemenag"/"LPMQ" **tidak ada sama sekali** di `lib/` |
| 21 | ADR melarang menempel markup QF ke teks Tanzil | **BENAR** | `docs/SDD.md:29-40` (ADR-2): hanya 1.256/6.236 ayat identik byte-per-byte |
| 22 | Terjemahan hanya Indonesia | **BENAR** | `translation_repository.dart:14`, satu aset, tanpa pemilihan bahasa |
| 23 | `IslamicNewsScreen` & `SearchScreen` kode mati | **BENAR** | Nol rujukan di luar berkasnya sendiri. `search_screen.dart:16` bahkan masih `Text('Search Quran')` |

Ringkasan: **19 benar, 3 sebagian, 1 salah.**

## 3. Temuan tambahan yang tidak ada di prompt

### 3.1 Tata letak mushaf di foto: terkonfirmasi Madinah 604 halaman

`RISET_SUMBER.md` menulis "tampaknya mengikuti Mushaf Madinah KFGQPC" dan minta
diverifikasi. Sudah diverifikasi dengan data yang sudah ada di repo:

```
<page index="272" sura="16" aya="43" />
<page index="273" sura="16" aya="55" />   ← halaman di foto
<page index="274" sura="16" aya="65" />
```

Halaman 273 memuat An-Nahl 55–64. Header di foto: **"16. An-Nahl 55 - 64"**.
Cocok persis. Jadi target layout benar Mushaf Madinah 604 halaman, dan
`assets/quran/raw/quran-data.xml` sudah memuat batas halamannya.

**Tapi** yang ada baru batas *halaman*; data *baris* (15 baris, rentang kata per
baris, baris rata tengah) belum ada dan sekarang selalu diambil dari jaringan.
`page_repository.dart:15-16` menyatakannya sendiri: "bukan untuk menyusun tata
letak halaman mushaf". Itulah yang perlu diambil dari QUL di Tahap 1.

### 3.2 Foto sampul bertentangan dengan spesifikasi §C

Sampul di `referensi/sampul-tajwid-warna.png` berbunyi **"Dengan Tajwid Blok
Warna"** — mewarnai **latar/blok** di belakang huruf (lihat juga blok-blok warna
pada foto halaman 273). Spesifikasi §C justru mewajibkan standar LPMQ yang
mewarnai **huruf beserta harakatnya, bukan latar**. Dua gaya ini berbeda hasil
akhirnya. Perlu keputusan — lihat §6.

### 3.3 Dokumen repo sendiri sudah basi dan saling bertentangan soal navigasi

- `docs/PROGRESS.md:100-103` menulis aplikasi memakai **5 tab** (Beranda, Baca,
  Belajar, Hafalan, Profil).
- `docs/ROADMAP.md:47` menandai **[x] "Navigasi lima tab"** sebagai selesai.
- `docs/PRD.md:49` menetapkan target **5 tab** dan menegaskan "Tab tidak diubah
  sebelum ada persetujuan".
- `QURAN_APP_GUIDE_DAN_PROMPT_CODEX.md:51` menetapkan **4 tab**.
- Kode sekarang (`app_shell.dart:19-40`): **4 tab** + tombol Cari bulat.

Artinya redesign iOS memangkas 5 tab jadi 4 tanpa keputusan tertulis, dan tab
Belajar serta Hafalan kehilangan tempatnya — persis kondisi yang dilarang PRD.
Ini bukan sekadar dokumen basi; ini keputusan yang belum pernah diambil.

### 3.4 Tidak ada font mushaf yang dibundel

`pubspec.yaml:87-105` hanya mendeklarasikan AmiriQuran, Amiri, PlusJakartaSans,
EBGaramond. Font QCF diunduh runtime dari CDN Quran Foundation. Untuk mode
mushaf di **rilis**, font harus dibundel atau di-cache, dan itu terikat syarat:
punya akun Developer Console aktif + mencantumkan kredit Quran Foundation
(`docs/DATA_SOURCES_AND_LICENSES.md:46-51`).

### 3.5 Ejaan id hukum tajwid tidak standar dan wajib dipakai persis

Whitelist di `tajweed_rule.dart:9-25` memakai ejaan provider:
`qalaqah` (bukan qalqalah), `ikhafa` (bukan ikhfa), `laam_shamsiyah` (dobel-a),
`idgham_mutajanisayn`/`idgham_mutaqaribayn` (akhiran `-ayn`). Saat mengisi
`assets/learn/*.json` nanti, ejaan ini harus ditulis persis atau seluruh berkas
ditolak (parser fail-closed: satu entri rusak membatalkan semuanya).

## 4. Pemetaan spesifikasi → berkas

| Spesifikasi | Berkas yang akan disentuh | Status sekarang |
|---|---|---|
| §A1 Mushaf 1 halaman | `lib/features/mushaf/**` (naikkan dari debug ke rilis), `mushaf_page_canvas.dart`, aset layout baris **baru**, `pubspec.yaml` (font) | prototipe debug, data dari jaringan |
| §A2 Mushaf 2 halaman | `debug_reader_prototype_screen.dart` → layar rilis baru | ada, `_minSpreadPageWidth = 230` sudah jalan |
| §A3 Kartu per ayat multi-bahasa | `lib/data/translation_repository.dart`, model terjemahan baru, `reader_screen.dart` | 1 bahasa, hardcode 1 aset |
| §B Belajar 16 tahap | `learn_screen.dart` (rombak), `tajweed_lessons_screen.dart`, `tajweed_lesson_repository.dart` (perluas skema), `assets/learn/**` | 0 pelajaran, UI Material mentah |
| §C Warna tajwid LPMQ | `tajweed_palette.dart`, `tajweed_rule.dart`, tes kontras baru | palet draft, bukan Kemenag |
| §D Hafalan | `memorization_screen.dart`, `practice_screen.dart`, `quran_audio_service.dart` (bug repeat), `shared_preferences_service.dart` (skema per ayat), `firebase_sync.dart` + rules | per surah, 2 bug repeat, tanpa sync |
| §E Beranda | `home_screen.dart` (23 warna hardcode, 2 widget duplikat, ayat tanpa kurasi), aset ayat pilihan **baru** | — |
| §E Pengaturan | `settings_screen.dart`, `app_shell.dart:177` (judul dobel) | 8 grup, target 9 grup |
| §E Qari | `lib/models/reciter.dart`, `lib/data/reciter_repository.dart` | 4 field, 1 penyedia, tanpa filter |
| Kode mati | `islamic_news_screen.dart`, `search_screen.dart` | menunggu izin hapus |

## 5. Urutan kerja yang diusulkan

Tahap 1 (mushaf) adalah yang paling berisiko dan paling bergantung lisensi, jadi
saya usul **menyisipkan satu tahap** yang tidak terhalang apa pun:

1. **Tahap 0.5 — perbaikan yang tidak butuh keputusan apa pun**: bug repeat
   3×/5×/10×, judul Pengaturan dobel, warna chip hardcode, baris murottal
   hardcode Alafasy, 23 warna hardcode di Beranda, kartu lembut triplikat.
   Semuanya murni bug/kerapian, tidak menambah konten agama, bisa langsung.
2. Tahap 1 (spike mushaf) setelah lisensi QUL & font dipastikan.
3. Sisanya mengikuti urutan di prompt.

## 6. Keputusan yang saya perlukan sebelum lanjut

1. **Struktur navigasi** — lihat §3.3; dokumen repo saling bertentangan.
2. **Gaya warna tajwid** — LPMQ (mewarnai huruf, sesuai spesifikasi §C) atau blok
   warna (sesuai foto sampul)? Lihat §3.2.
3. **Izin menghapus kode mati** `islamic_news_screen.dart` dan `search_screen.dart`.
4. **Akun Quran Foundation Developer Console** — perlu untuk membundel font QCF
   di rilis. Sudah ada atau belum?
