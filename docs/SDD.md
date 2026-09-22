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

## 6. BFF (kerangka sudah ada)

`bff/` — Node 20 + TypeScript + Hono (lihat `bff/README.md`). Belum dipakai
aplikasi dan belum di-deploy.

- Endpoint: `/v1/health`, `/v1/chapters`, `/v1/recitations`,
  `/v1/mushaf/v2/pages/:page`, `/v1/chapters/:chapter/tajweed`. Respons memakai
  bentuk milik aplikasi, bukan salinan mentah payload provider.
- Auth (diverifikasi dari dokumentasi provider, 23 September 2026): Basic auth
  ke `https://{prelive-,}oauth2.quran.foundation/oauth2/token`,
  `grant_type=client_credentials`, scope `content`; setiap panggilan membawa
  `x-auth-token` + `x-client-id`; base URL `.../content/api/v4`. Token 3600
  detik tanpa refresh token, diperbarui 30 detik sebelum kedaluwarsa, satu
  permintaan token untuk panggilan serentak, `401` dicoba ulang satu kali.
  Dokumentasi provider menyatakan aplikasi mobile **tidak boleh** memakai alur
  ini — itulah alasan BFF ada.
- Developer Terms: konten tidak boleh disimpan > 1 minggu kecuali via Content
  Sync, jadi `CACHE_TTL_*` divalidasi maksimal 604.800 detik. Font/aset mushaf
  boleh di-cache/dibundel bila akun Developer Console aktif dan kredit Quran
  Foundation ditampilkan.
- Batas rate limit resmi tidak dipublikasikan; `RATE_LIMIT_PER_MINUTE` adalah
  batas milik kita sendiri.
- Lingkungan prelive hanya memuat surah 1–2; dataset penuh perlu persetujuan
  akses produksi.
- Deploy dan secret manager belum dipilih (kandidat: Cloud Run atau Render).

## 7. Offline

Paket terpisah (teks, terjemahan, tafsir, font halaman, audio) dengan ukuran
ditampilkan, resume, checksum. Data bundel hanya yang lisensinya mengizinkan.
Jika sumber gagal: pakai cache terverifikasi terakhir; tidak pernah diam-diam
mengganti teks dari provider lain.
