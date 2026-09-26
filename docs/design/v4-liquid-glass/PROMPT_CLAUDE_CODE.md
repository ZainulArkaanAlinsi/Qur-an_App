# Prompt Claude Code: liquid glass v4

Cara pakai: salin isi paket ini ke akar repo (`docs/design/v4-liquid-glass/` dan `tool/glass_audit.sh`), buka Claude Code di repo, lalu kirim prompt satu per satu sesuai urutan. Tunggu satu prompt selesai dan periksa hasilnya sebelum mengirim prompt berikutnya. Prompt 6 bisa dipakai kapan saja untuk mengecek ulang.

---

## Prompt 0 — Persiapan dan audit (belum mengubah kode aplikasi)

```
Baca dulu: CLAUDE.md, docs/design/v4-liquid-glass/LIQUID_GLASS.md,
docs/design/v4-liquid-glass/AUDIT_RUBRIK.md, docs/design/v3/DESIGN.md.

1. Buat branch fitur/liquid-glass-v4 dari main terbaru.
2. Jalankan `flutter --version`, lalu catat versi Flutter/Dart dan apakah SDK ini
   punya: BackdropGroup, BackdropFilter.grouped (dengan parameter enabled),
   ImageFilter.compose, ClipRSuperellipse. Cek langsung di sumber SDK, jangan
   menebak. Kalau ada yang tidak tersedia, tulis alternatifnya di bagian
   "Catatan SDK" pada HASIL_AUDIT.md (mis. tanpa BackdropGroup: batasi 2 kaca
   terlihat dan pakai BackdropFilter biasa hanya di dalam lib/app/glass/).
3. Jalankan `bash tool/glass_audit.sh` dan simpan keluarannya.
4. Nilai repo dengan AUDIT_RUBRIK.md (G1–G10). Setiap nilai wajib punya bukti
   berkas:baris. Bandingkan dengan "Audit awal" di rubrik; kalau ada yang
   berbeda, jelaskan kenapa.
5. Tulis hasilnya ke docs/design/v4-liquid-glass/HASIL_AUDIT.md.
6. Tambahkan ke CLAUDE.md bagian "Liquid glass v4" berisi aturan di bawah ini
   (ringkas, tanpa mengubah aturan lain):
   - Efek kaca hanya lewat LiquidGlass di lib/app/glass/. Layar tidak boleh
     memanggil BackdropFilter sendiri.
   - Kaca hanya untuk chrome mengambang (LIQUID_GLASS.md §2). Tidak pernah
     di item daftar dan tidak pernah di belakang teks ayat.
   - Teks ayat dan terjemahan tidak diubah, tanpa efek; warna tajwid ≥ 4.5:1
     di semua permukaan ayat.
   - Setiap perubahan kaca: glass_audit.sh 0 GAGAL, flutter analyze bersih,
     flutter test lulus, golden diperbarui dan dilihat.
7. Commit: "Audit liquid glass v4 + aturan CLAUDE.md". Jangan push ke main.

Jangan mengubah kode di lib/ pada langkah ini.
```

---

## Prompt 1 — Fondasi: token, komponen LiquidGlass, tingkat kualitas

```
Ikuti LIQUID_GLASS.md §3, §4, §7 persis. Angka di sana sudah dihitung;
jangan mengganti angka tanpa menuliskan alasan dan hasil tes kontrasnya.

1. lib/app/glass/glass_tokens.dart
   - GlassTokens extends ThemeExtension<GlassTokens> dengan field: sigmaBar,
     sigmaSmall, sigmaSheet, saturation, keep, toward, tint, rimStart,
     rimEnd, rimWidth, sheenTop, innerHighlight. Beserta copyWith dan lerp.
   - Nilai untuk light, sepia, dark, highContrastLight, highContrastDark
     sesuai tabel §4. Pasang di SacredTheme.themeFor lewat extensions,
     berdampingan dengan SacredTokens.
   - Token lama glass/glassBorder di SacredTokens: hapus pemakaiannya dan
     tandai @Deprecated.
2. lib/app/glass/glass_tier.dart
   - enum GlassTier { full, lite, solid } dan enum GlassPreference { auto,
     full, lite, off }.
   - GlassScope (InheritedNotifier) yang menentukan tier efektif dari:
     preferensi pengguna, palet kontras tinggi,
     MediaQuery.highContrastOf, MediaQuery.disableAnimationsOf (paling
     tinggi lite), dan tier hasil pengawas frame (Prompt 4, sediakan
     setter-nya sekarang).
   - Preferensi disimpan di SharedPreferencesService (kunci
     glass_preference), bawaannya auto.
3. lib/app/glass/liquid_glass.dart: widget LiquidGlass dengan enam lapis
   §3 dalam satu komponen.
   - Parameter: child, borderRadius, size (bar/small/sheet), padding,
     interactive (untuk kilau yang bergeser).
   - L0 bayangan di luar klip. L1 BackdropFilter.grouped dengan
     glassFilter() dari rumus §3 dan enabled: tier != solid. L2 tint.
     L3 kilau. L4 tepi lewat CustomPainter di RepaintBoundary. L5 sorot
     dalam.
   - Tier lite/solid mengikuti tabel §4. Bentuk dan ukuran tidak berubah
     antar-tier.
   - Tanpa Opacity/ShaderMask. Tanpa ripple Material.
4. Pasang BackdropGroup di AppShell dan di setiap rute yang punya kaca
   (ReaderScreen, mushaf, sheet murottal bila perlu).
5. lib/app/glass_surface.dart: ubah GlassSurface menjadi pembungkus tipis
   yang meneruskan ke LiquidGlass supaya pemanggil lama tidak rusak.
   Tandai @Deprecated. Pemakaian di item daftar ditangani di Prompt 2.
6. test/glass_contrast_test.dart
   - Luminans relatif WCAG dari sRGB.
   - Komposit: latar → saturasi → penekanan keep/toward → tint alfa.
   - Latar uji dan ambang sesuai §5, untuk semua palet × tier full/lite.
   - Tes ini harus gagal kalau alfa tint diturunkan di bawah angka §4.
7. Jalankan flutter analyze, flutter test, dan bash tool/glass_audit.sh.
   Target langkah ini: A1, A2, B1, B4, C1, C2 lulus.
8. Commit: "LiquidGlass: token, tingkat kualitas, tes kontras".
```

---

## Prompt 2 — Permukaan: tab bar, nav pembaca, mini player, tombol, sheet

```
Ikuti LIQUID_GLASS.md §2 dan §6.

1. FloatingTabBar (lib/app/widgets/sacred_controls.dart)
   - Hapus scrim padat [tokens.bg, tokens.bg, ...] di belakang tab bar.
     Kalau perlu pemisah dari isi, pakai gradien sangat tipis yang hanya
     menaikkan alfa di 20 px terbawah (maks 40%), bukan latar penuh.
   - Pastikan tiap halaman punya padding bawah supaya isi terakhir tidak
     tertutup, tapi isi yang sedang digulir tetap terlihat lewat kaca.
   - Ganti Container aktif dengan satu "lensa" yang meluncur: pegas massa 1,
     kekakuan 420, redaman 32; regangan scaleX maks 1.12; tekan 0.94 dalam
     90 ms; geser jari di tab bar menggerakkan lensa, lalu menempel ke tab
     terdekat; HapticFeedback.selectionClick saat pindah tab.
   - Tanpa InkWell/ripple. Semantics tab tetap seperti sekarang.
   - Kurangi gerak: crossfade 150 ms tanpa regangan.
2. Nav pembaca (_ReaderNav di reader_screen.dart): LiquidGlass ukuran bar.
   Sembunyi saat gulir turun > 24 px, muncul saat gulir naik, 220 ms dengan
   Cubic(0.22, 1, 0.36, 1). Jangan menggeser posisi ayat saat nav
   muncul/hilang (nav menumpang di atas isi).
3. Mini player (lib/widgets/audio_mini_player.dart): pakai LiquidGlass dan
   token. Semua SacredTheme.primary/primaryContainer/gold dan
   Colors.white/black diganti token yang cocok di keempat palet. Tombol
   putar tetap CTA berwarna pekat supaya mudah ditemukan.
4. Tombol bulat mengambang di atas hero dan pembaca: LiquidGlass ukuran small.
5. Kepala bottom sheet (murottal, mode baca, aturan tajwid): kepala +
   grabber berkaca, isi tetap tokens.surf/bg. Buat satu helper
   showGlassSheet(), jangan menyalin di tiap sheet.
6. Penanda (bookmark_screen.dart): item daftar kembali ke kartu padat
   (tokens.surf + cardShadows). Keadaan kosong boleh tetap memakai kartu padat.
7. Hitung ulang jumlah kaca yang terlihat bersamaan di tiap layar. Maksimal
   3, di pembaca maksimal 2. Tulis tabelnya di HASIL_AUDIT.md.
8. Jalankan flutter analyze, flutter test, dan glass_audit.sh.
   Target langkah ini: A3, B2, B3 lulus.
9. Commit per bagian (tab bar, pembaca, mini player, sheet, penanda).
```

---

## Prompt 3 — Warna terang/gelap/sepia/kontras tinggi dan keterbacaan ayat

```
Ikuti LIQUID_GLASS.md §5. JANGAN mengubah teks ayat, terjemahan, data
tajwid, atau arti hukum tajwid. Yang boleh diubah hanya nilai warna.

1. Palet tajwid (lib/features/tajweed/presentation/tajweed_palette.dart):
   - Naikkan kontras warna yang lemah sampai ≥ 4.5:1 terhadap SEMUA
     permukaan ayat: surf, primarySoft (ayat aktif), goldSoft (ayat
     bertanda), surf dan bg sepia, di terang dan gelap. Yang sudah diketahui
     lemah: abu #7A7A7A (3.54–4.10) dan mad wajib gelap #7F8CFF (4.41–4.45).
   - Pertahankan hubungan antarwarna: abu tetap terlihat lebih redup
     daripada tinta; tiga warna mad tetap satu keluarga biru dengan urutan
     gelap-terang yang sama; tidak ada dua hukum yang warnanya jadi lebih
     mirip daripada sekarang (hitung ΔE2000 sebelum/sesudah dan tulis
     tabelnya).
   - Status palet tetap draft.
2. Perluas test/tajweed_widget_test.dart ke semua permukaan di atas.
3. Periksa semua teks di atas kaca dan ayat di keempat palet:
   - Tidak ada lagi warna mentah di chrome.
   - goldText dipakai untuk teks emas di latar terang.
   - Kontras tinggi selalu memakai tier solid.
4. Golden test (test/goldens/glass/): FloatingTabBar, nav pembaca, mini
   player, dan kepala sheet × {terang, gelap, sepia, kontras tinggi} ×
   {full, solid}, di atas latar uji yang berisi kartu hero hijau, teks, dan
   garis warna. Buat golden, lalu BUKA PNG-nya dan periksa tiga hal:
   a. Tepi kaca menangkap cahaya di terang dan gelap.
   b. Warna di belakang terlihat samar lewat kaca pada tier full.
   c. Label tab tidak aktif tetap jelas.
   Tulis pengamatan per PNG di HASIL_AUDIT.md. Kalau a/b/c gagal, perbaiki
   token dalam batas tes kontras, lalu ulangi.
5. Golden pembaca: satu halaman Al-Fatihah dan Al-Baqarah 1–5 dengan tajwid
   aktif, di terang/gelap/sepia, termasuk satu ayat aktif. Periksa bahwa
   tidak ada huruf yang tertutup nav dan tidak ada efek di teks Arab.
6. Commit: "Warna kaca & tajwid: kontras semua palet + golden".
```

---

## Prompt 4 — Kinerja: pengawas frame, pengaturan, tes kinerja

```
Ikuti LIQUID_GLASS.md §7.

1. lib/app/glass/glass_governor.dart
   - Aktif hanya saat preferensi auto dan ada kaca terlihat.
   - SchedulerBinding.instance.addTimingsCallback, jendela 120 frame,
     anggaran 1000/refreshRate ms (View.of(context).display.refreshRate).
   - Lebih dari 8% frame melewati anggaran di dua jendela berturut-turut
     menurunkan tier: full → lite → solid, lalu disimpan (glass_tier_auto).
   - Tidak naik lagi di sesi yang sama; di-reset sekali saat versi aplikasi
     berubah. Tanpa setState per frame, tanpa log di rilis.
2. Pengaturan: Saya → Tampilan → "Efek kaca": Otomatis / Penuh / Ringan /
   Mati, dengan pratinjau kecil (pakai lib/app/widgets/theme_preview.dart
   bila cocok) dan keterangan satu baris: "Otomatis menurunkan efek bila HP
   terasa berat."
3. integration_test/glass_perf_test.dart + test_driver/perf_driver.dart
   (integration_test dari SDK Flutter; jangan tambah paket lain):
   - A: gulir pembaca Al-Baqarah 15 detik dengan tajwid aktif.
   - B: ganti tab 20 kali.
   - C: buka/tutup sheet murottal 10 kali.
   - Masing-masing dijalankan dengan tier full dan solid lewat preferensi.
   - Pakai binding.watchPerformance dan simpan ringkasannya.
4. Kalau ada HP tersambung (flutter devices), jalankan dalam mode profile:
   flutter drive --profile --driver=test_driver/perf_driver.dart \
     --target=integration_test/glass_perf_test.dart
   Catat model HP, versi Android/iOS, refresh rate, dan tabel anggaran §7
   (lulus/gagal) di docs/design/v4-liquid-glass/HASIL_KINERJA.md.
   Kalau tidak ada HP, tulis "BELUM DIUKUR DI HP" dan beri tahu saya
   perintahnya. Jangan mengarang angka, dan emulator tidak dihitung.
5. Kalau anggaran gagal: cari penyebabnya di timeline DevTools (raster
   thread, saveLayer, jumlah BackdropFilter), perbaiki, lalu ukur ulang.
   Menurunkan sigma di bawah tier lite bukan perbaikan.
6. glass_audit.sh harus 0 GAGAL. Commit: "Pengawas frame + pengaturan efek
   kaca + tes kinerja".
```

---

## Prompt 5 — Putaran nilai-perbaiki sampai lulus

```
Nilai ulang dengan AUDIT_RUBRIK.md.
- Jalankan glass_audit.sh, flutter analyze, flutter test (termasuk golden),
  lalu buka golden-nya.
- Kalau total < 18, ada nilai 0, atau G6/G7/G8 belum 2: perbaiki kriteria
  dengan nilai terendah, lalu nilai ulang. Maksimal 3 putaran.
- Setiap putaran ditulis di HASIL_AUDIT.md: nilai per kriteria + bukti +
  apa yang diubah.
Setelah lulus (atau setelah 3 putaran), buat PR dari fitur/liquid-glass-v4
ke main. Di deskripsi PR cantumkan:
- Nilai rubrik sebelum → sesudah.
- Tabel kontras.
- Tabel kinerja (atau "belum diukur di HP").
- Daftar golden yang berubah.
Jangan merge dan jangan membuat rilis.
```

---

## Prompt 6 — Cek cepat (bisa dipakai kapan saja)

```
Cek liquid glass tanpa mengubah kode: jalankan bash tool/glass_audit.sh,
nilai G1–G10 dari AUDIT_RUBRIK.md dengan bukti berkas:baris, lalu sebutkan
3 hal paling kurang dan perbaikan yang paling kecil untuk masing-masing.
Tulis singkat di chat; jangan membuat berkas.
```

---

## Yang berlaku di semua prompt

- Jangan mengubah `assets/quran/**`, terjemahan, `assets/learn/curriculum.json`, atau logika dan arti hukum tajwid. Status materi draf tetap draf.
- Jangan menambah paket pub baru tanpa bertanya. `integration_test` dan `flutter_test` dari SDK boleh dipakai.
- Jangan push ke main, merge, atau membuat rilis. Kerjakan di branch dan PR.
- Jangan menyebut target kinerja lulus tanpa angka dari HP asli.
- Logo tetap utuh lewat `Image.asset` (aturan v3).
