# Cara pakai paket v3 dengan Claude Code

Isi paket: logo MyQuran, ikon aplikasi, splash, onboarding yang bisa digeser, dan materi hukum nun sukun & tanwin.

## Pasang

1. Ekstrak ZIP di **root repo**. Isinya:

   ```
   CLAUDE.md                          ← sudah digabung dengan yang lama (+ bagian v3)
   assets/brand/*.png                 ← logo utama (terang/gelap), logo sekunder
   assets/icons/*.png                 ← ikon launcher, adaptif, monokrom, splash
   assets/learn/curriculum.json       ← materi tajwid tahap 6–16 (draft)
   docs/design/v3/                    ← DESIGN.md, screens/15–18 + PNG, html/, LISENSI_ASET.md
   docs/content/tajwid/*.md               ← naskah tahap 6–16 untuk ustadz peninjau
   ```

2. Commit: `docs: paket desain v3 (logo, splash, onboarding, materi tajwid 6–16)`.
3. Jalankan `claude` di root repo, lalu kirim prompt di bawah **satu per satu**. Tunggu satu selesai sebelum mengirim yang berikutnya.

## Prompt 0 — rencana (tanpa kode)

```text
Baca CLAUDE.md, docs/design/v3/DESIGN.md, docs/design/v3/LISENSI_ASET.md, dan
docs/design/v3/screens/15-*.md sampai 18-*.md. Buka juga semua PNG di
docs/design/v3/screens/. Jangan menulis kode dulu. Buat rencana:
1) perubahan pubspec (ikon, splash, aset brand, nama aplikasi MyQuran),
2) struktur lib/features/onboarding/ (splash animasi, onboarding, preferensi),
3) perubahan layar Pelajaran untuk blok letters >3 huruf & lencana DRAF,
4) daftar golden test yang akan dibuat.
Sebutkan file yang akan diubah. Tunggu persetujuan saya.
```

## Prompt 1 — ikon, nama, splash bawaan

```text
Kerjakan docs/design/v3/screens/15-logo-ikon.md.
- Ganti blok flutter_launcher_icons & flutter_native_splash di pubspec.yaml persis
  seperti DESIGN.md §3 dan §4a. Tambahkan assets/brand/ ke daftar aset.
- Nama tampilan: Android appLabel "MyQuran" (debug "MyQuran Debug"), iOS
  CFBundleDisplayName "MyQuran". Package id JANGAN diubah.
- Jalankan dart run flutter_launcher_icons dan dart run flutter_native_splash:create.
- Tambahkan token brandIcon/brandCover/brandGold ke SacredTokens.
- Daftarkan keempat berkas OFL di assets/fonts lewat LicenseRegistry.
- Logo hanya lewat Image.asset, utuh. Jangan digambar ulang atau dipotong.
Laporkan berkas yang dibuat generator, lalu jalankan flutter analyze.
```

## Prompt 2 — splash animasi

```text
Kerjakan docs/design/v3/screens/16-splash.md mengikuti DESIGN.md §4b persis
(lini waktu, kurva Cubic(0.22,1,0.36,1), min 1400 ms / maks 2500 ms, mode kurangi gerak).
Hanya pakai AnimationController bawaan Flutter. precacheImage logo sebelum mulai.
Buat golden frame akhir terang & gelap, buka PNG-nya, bandingkan dengan
docs/design/v3/screens/V3-Splash*.png, lalu tulis tabel selisih dan perbaiki.
```

## Prompt 3 — onboarding yang bisa digeser

```text
Kerjakan docs/design/v3/screens/17-onboarding.md.
- PageView + PageController + AnimatedBuilder. Rumus parallax, opasitas, lebar
  titik, ambang geser, kurva, dan haptik PERSIS DESIGN.md §5c.
- Teks persis DESIGN.md §5b. Ayat & terjemahan halaman 2 diambil dari dataset yang
  sudah dibundel (QS 2:5), tidak diketik.
- Simpan onboarding.selesai.v1 dan belajar.titikMulai; arahkan ke tab sesuai tabel.
- Golden: halaman 1–4 terang & gelap + 2 frame tengah geser (page 0.5 dan 1.3).
  Buka setiap PNG, bandingkan dengan acuan dan gerak_*.png, perbaiki selisihnya.
- Uji text scale 2.0: tidak boleh ada overflow.
```

## Prompt 4 — materi tajwid tahap 6–16

```text
Kerjakan docs/design/v3/screens/18-materi-nun-sukun.md dan DESIGN.md v3 §6.
curriculum.json sudah berisi materi tahap 6–16. JANGAN mengubah teks, contoh, soal,
atau status draft.
- Tambah field opsional `words` [dari, sampai] ke LessonExample. Validasi indeks
  dengan tanzilWords() + basmalahPrefix (lib/features/mushaf/domain/mushaf_text.dart).
- Sorot kata pada kartu contoh. Kalau ≥3 contoh berurutan, tampilkan sebagai daftar ringkas
  yang bisa diketuk.
- Blok letters: 1–4 huruf satu baris; 5–15 huruf grid 5 kolom.
- Golden V3-Materi (terang/gelap), V3-Materi-Mutlak, dan daftar ringkas 15 contoh ikhfa
  (text scale 1.0 & 2.0).
- Tambah test: semua `words` di curriculum.json valid terhadap teks Tanzil.
- test/curriculum_test.dart harus lulus TANPA diubah.
```

## Prompt 5 — pemeriksaan akhir

```text
Jalankan dart format lib test, flutter analyze, flutter test. Buka ulang semua golden
v3 dan tempel pasangan acuan↔hasil. Cek manual di emulator: ikon (bulat & squircle),
themed icon Android 13, splash terang/gelap tanpa kedip putih, geser onboarding
maju/mundur, tombol kembali. Daftarkan sisa masalah. Jangan push.
```

## Kalau hasilnya meleset

```text
<layar> belum sama dengan acuan. Buka test/golden/goldens/<file>.png dan
docs/design/v3/screens/<acuan>.png. Ukur selisihnya: posisi y, ukuran font, jarak,
radius, opasitas glow, dan kecepatan parallax. Perbaiki satu per satu sesuai
DESIGN.md v3. Jangan mengubah desain sendiri.
```

## Materi tajwid: langkah sebelum terbit

1. Kirim berkas `docs/content/tajwid/NN-*.md` (satu per tahap) ke 2 guru tajwid bersanad.
2. Kalau keduanya setuju (bisa lewat workflow n8n "Review materi"), barulah minta Claude Code mengubah `"review": "published"` dan mengisi nama peninjau di `provenance`. Tes "tahap hukum tajwid belum diterbitkan" di `test/curriculum_test.dart` juga perlu disesuaikan saat itu, atas izinmu.
