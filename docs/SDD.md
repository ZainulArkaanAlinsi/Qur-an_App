# SDD — Desain sistem

Status: draf Fase 0 · 22 September 2026

## 1. Kondisi sekarang

- Flutter 3.44.8 / Dart ≥ 3.9.2. `flutter analyze`: tanpa isu. `flutter test`:
  87 lulus (baseline 22 September 2026, sebelum spike tajwid).
- Struktur datar: `lib/app`, `lib/data`, `lib/models`, `lib/screens`,
  `lib/services`, `lib/widgets`.
- State: `ChangeNotifier` + `InheritedNotifier` (`AppScope`) dan service
  statis; persistensi `shared_preferences`; tanpa router package.
- Audio: `just_audio` + `audio_service` 0.18.19 (foreground `mediaPlayback`).
- Cloud: Firebase Auth (Google) + Firestore, opsional, outbox idempoten
  (`docs/CLOUD_SYNC.md`).
- Konten: Tanzil Uthmani 1.0.2 + terjemahan `id.indonesian` dibundel verbatim
  dengan checksum (`docs/DATASET_ATTRIBUTION.md`).

## 2. Keputusan arsitektur (ADR ringkas)

**ADR-1: Tidak migrasi massal state management/router/DB.** Master prompt
menyarankan Riverpod, `go_router`, `drift`, tetapi juga melarang migrasi tanpa
alasan dan persetujuan. Kode yang ada konsisten dan teruji. Modul baru ditulis
*feature-first* di `lib/features/<fitur>/{domain,data,presentation}` dengan
logika murni (tanpa Flutter) di `domain`/`data` agar mudah diuji. `drift`
diusulkan baru ketika data offline besar (halaman mushaf, word timing, tafsir)
masuk di Fase 1 — keputusan saat itu, bukan sekarang.

**ADR-2: Satu edisi per tampilan, tidak ada join lintas edisi.** Spike
22 September 2026: dari 6.236 ayat, hanya **1.256** yang teks polos Quran
Foundation `text_uthmani_tajweed` identik byte-per-byte dengan Tanzil Uthmani
yang dibundel (2.024 bila tatweel diabaikan). Maka rentang warna tajwid
**tidak boleh** ditempel ke teks Tanzil. Mode Card dengan tajwid menampilkan
teks milik edisi tajwid itu sendiri dan melabelinya. Bahkan `text_uthmani`
milik Quran Foundation hanya identik pada 2.026/6.236 ayat dengan teks tajwid
tanpa tag: bedanya encoding Unicode (ZWNJ vs spasi sebelum tanda waqaf,
sukun vs small high rounded zero, alif wavy hamza vs superscript alef, dll.),
bukan sekadar spasi. Karena itu teks cadangan untuk ayat bermarkup rusak
selalu ditampilkan dengan **label edisinya** (`fallbackEditionLabel`). Bookmark disimpan sebagai
`verse_key` (+ `editionId` untuk posisi halaman) agar tetap valid lintas edisi.

**ADR-3: Parser tajwid whitelist dan gagal-tertutup.** Lihat §4.

**ADR-4: Secret hanya di BFF.** `client_id`/`client_secret` Quran Foundation
dan token LPMQ tidak pernah masuk APK. Flutter memanggil BFF milik sendiri.

## 3. Model edisi

```
MushafEdition { editionId, name, provider, riwayah ('hafs'), rasm,
  totalPages, pageDirection ('rtl'), pageMapVersion, glyphVersion,
  license, attribution, manifestSha256 }
MushafPageAsset { editionId, page, fontAsset, sha256 }   // terikat 1 edisi
QuranWord { editionId, verseKey, position, page, line, glyph|text }
```

Aturan: kata dikelompokkan berdasarkan `page_number` + `line_number` dari edisi
yang sama; baris boleh melintasi batas ayat.

## 4. Pipeline tajwid (spike Fase 0, sudah ada)

- `lib/features/tajweed/domain/tajweed_rule.dart`: whitelist 17 class provider
  → `TajweedRule` + nama Indonesia (status **draft**, perlu review guru).
- `lib/features/tajweed/data/tajweed_markup_parser.dart`: parser ketat.
  Menerima hanya `<tajweed class=…>` (whitelist) dan `<span class=end>`.
  Menghasilkan `text` (tanpa normalisasi/trim), `segments` (offset UTF-16,
  mendukung nesting), `runs` (tanpa tumpang tindih, hukum terdalam menang),
  `ruleCounts` untuk chip, `rejectedClasses`.
- Markup rusak → `FormatException`. UI wajib menampilkan teks polos edisi yang
  sama **tanpa warna**, dan melaporkan `verse_key`. Jangan pernah "membetulkan"
  markup.
- Temuan nyata: ayat **32:3** pada dump provider memiliki `</tajweed>` tanpa
  pembuka; strip tag naif akan menyisakan karakter `>` di tengah ayat. Parser
  menolaknya (regresi di `test/tajweed_parser_test.dart`).
- Audit dataset penuh: `dart run tool/tajweed_audit.dart <dump.json>`.
- Widget kartu: `lib/features/tajweed/presentation/tajweed_verse_panel.dart`
  (`TajweedVersePanel`): TextSpan per run (warna saja, font sama agar shaping
  Arab tidak putus), ketuk segmen → sorot rentang + sheet nama hukum, chip
  "Nama ×n", legend, toggle tajwid, fallback teks polos edisi yang sama bila
  markup rusak. Palet `TajweedPalette.draftPreview` (draft) dengan kontras
  ≥ 4:1 di tema terang/gelap. Belum dipasang di Reader: menunggu keputusan
  edisi dan sumber data (BFF).
- Pratinjau debug: Pengaturan > Debug > Pratinjau tajwid
  (`debug_tajweed_preview_screen.dart`), hanya saat `kDebugMode`; data
  langsung dari api.quran.com per surah, divalidasi jumlah/kunci ayat terhadap
  manifest, ayat bermarkup rusak dicantumkan di banner.

## 5. Mushaf (rencana Fase 1)

- QCF V2 (biasa) dan QCF V4 (tajwid): font per halaman, glyph per kata.
  Kanvas aspect ratio tetap, `FittedBox`/`InteractiveViewer` untuk zoom; tidak
  ada reflow. Kontrol hanya overlay di luar area glyph.
- Dua halaman: landscape hanya selama mode aktif
  (`SystemChrome.setPreferredOrientations`, dipulihkan di `dispose`). Ganjil
  kanan, genap berikutnya kiri; sisi kosong netral bila tidak berpasangan.
- Font mushaf tidak dapat diganti bebas; pilihan hanya *Mushaf Biasa* /
  *Mushaf Tajwid*.

## 6. BFF (rencana)

Service Node.js ringan atau Next.js route handler (disarankan: Firebase
Functions/Cloud Run agar satu project dengan Firebase yang ada — perlu plan
Blaze). Endpoint: `/v1/resources/recitations`, `/v1/verses/by_page/:n`,
`/v1/verses/tajweed/:chapter`, `/v1/audio/...`. Wajib: rate limit, cache sesuai
terms, timeout, retry terbatas, validasi schema, log tanpa isi catatan pribadi.

## 7. Offline

Paket terpisah (teks, terjemahan, tafsir, font halaman, audio) dengan ukuran
ditampilkan, resume, checksum. Data bundel hanya yang lisensinya mengizinkan.
Jika sumber gagal: pakai cache terverifikasi terakhir; tidak pernah diam-diam
mengganti teks dari provider lain.
