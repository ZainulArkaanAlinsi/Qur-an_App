# Prompt Claude Code — rilis Play + v6

## Cara pakai

1. Ekstrak paket ke **akar repo** (folder `docs/` dan `tool/` akan bergabung dengan yang ada; tidak ada berkas kode yang ditimpa).
2. Buka Claude Code di repo. Kirim prompt **satu per satu sesuai urutan**. Setiap prompt dimulai dengan rencana; baca rencananya, setujui, baru Claude Code menulis kode.
3. Selesai satu prompt → cek hasil (gambar golden, tes) → baru prompt berikutnya. Kalau ada yang tidak cocok, bilang di sesi yang sama; jangan lompat.
4. Satu sesi = satu prompt. Kalau sesi sudah panjang, `/clear` lalu lanjut prompt berikutnya (CLAUDE.md membuat konteksnya tetap terbaca).

Urutan & perkiraan:

| # | Prompt | Hasil | Bisa paralel dengan closed testing? |
| --- | --- | --- | --- |
| 0 | Persiapan dokumen | CLAUDE.md, PRD, DATA, decisions terpasang | ya |
| 1 | Rilis 1.10.1 untuk Play | AAB siap tes tertutup | **kerjakan duluan** |
| 2 | Liquid glass: fondasi | `LiquidGlass`, token, tier | ya |
| 3 | Dock | tab + sedang diputar | ya |
| 4 | Beranda: logika | NextStepEngine dkk + tes | ya |
| 5 | Beranda: tampilan | layar 19 + golden | ya |
| 6 | Murottal | layar 20 + golden | ya |
| 7 | Waktu salat | layar 22 | ya |
| 8 | Qari | layar 23 | ya |
| 9 | Kontras, kinerja, gambar Play, 1.11.0 | PR rilis v6 | ya |

---

## Prompt 0 — Persiapan dokumen (tanpa kode aplikasi)

```
Baca CLAUDE.md, lalu docs/PRD.md, docs/DATA.md, docs/decisions.md,
docs/design/v6/DESIGN.md beserta screens/19–23, dan
docs/design/v4-liquid-glass/LIQUID_GLASS.md. Lihat semua PNG di
docs/design/v6/screens/ (pakai Read untuk membuka gambar).

1. Buat branch docs/v6 dari main terbaru.
2. PRD lama: git show main:docs/PRD.md > docs/arsip/PRD-2026-09-22.md
   (PRD baru dari paket sudah menimpa docs/PRD.md; pastikan isinya yang baru).
3. Tambahkan ke CLAUDE.md, tanpa mengubah aturan lain:
   a. Di "Sumber kebenaran", setelah butir 2, tambahkan:
      "2b. docs/design/v6/DESIGN.md + screens/19–23 — Beranda, dock, Murottal,
       pengaturan salat, qari. Menang atas v2 untuk layar-layar itu.
       docs/design/v4-liquid-glass/LIQUID_GLASS.md — efek kaca."
   b. Bagian baru "Dokumen produk" berisi tiga baris impor:
      @docs/PRD.md
      @docs/DATA.md
      @docs/decisions.md
   c. Bagian baru "Cara kerja fitur" (ringkas):
      - Satu fitur per sesi. Mulai dengan rencana; tunggu persetujuan pemilik.
      - Kebutuhan berubah → perbarui PRD/DATA/decisions dulu, baru kode.
      - Kriteria "Selesai jika" di screens/NN-*.md dan PRD §4 adalah checklist
        laporan akhir; tulis tiap butir: lulus/gagal + bukti (berkas:baris,
        nama tes, nama golden).
      - Logika keputusan = fungsi murni di domain/, waktu dioper sebagai
        parameter, dites tabel.
4. Jalankan flutter analyze, flutter test, dan bash tool/glass_audit.sh.
   Catat hasilnya (jangan perbaiki apa pun dulu).
5. Laporkan ke saya: daftar hal di PRD/DATA yang tidak cocok dengan kode
   sekarang (nama fungsi, kunci, alur). Jangan menebak; sebut berkas:baris.
6. Commit "Dokumen v6: PRD, DATA, decisions, desain v6, glass v4". Buka PR ke
   main. Jangan merge.
```

---

## Prompt 1 — Rilis 1.10.1 untuk Google Play (kecil, kerjakan duluan)

```
Tujuan: AAB yang aman dikirim ke closed testing Play Console hari ini.
Ikuti docs/PRD.md R1–R4 dan docs/PLAY_STORE_RELEASE.md. Branch: rilis/1.10.1.
Rencana dulu, tunggu persetujuan.

1. Perbaikan UI kecil yang melanggar PRD R4 (tanpa redesain):
   - lib/screens/murottal_screen.dart: hapus kalimat "Waktu mendengar belum
     dicatat terpisah dari streak membaca." dan chip Unduh yang non-aktif.
     Kalau mudah, sambungkan Unduh ke AudioDownloadService.download yang
     sama dengan daftar surah (status: Unduh / persen / Tersimpan ✓);
     kalau tidak, sembunyikan chip-nya saja.
   - Cari teks internal lain di UI: grep "belum dicatat|TODO|debug|sementara"
     di lib/ pada string yang tampil. Laporkan dulu, ubah setelah saya setujui.
2. Kebijakan privasi vs kode: baca hosting/public/privacy.html dan tabel
   Data safety di docs/PLAY_STORE_RELEASE.md, lalu cocokkan dengan kode
   (Firebase Auth, Firestore, AlAdhan dengan nama kota, audio
   cdn.islamic.network, unduhan terjemahan, berita bila ada). Tulis tabel
   selisih. Perbaiki dokumen supaya sesuai kode, bukan sebaliknya.
3. Hapus akun: pastikan alur Saya → Hapus akun & data cloud berjalan, dan
   ada halaman web permintaan hapus (mis. hosting/public/hapus-akun.html
   berisi langkah di aplikasi + email zainaril13@gmail.com). Tambahkan URL-nya
   ke PLAY_STORE_RELEASE.md bagian Data safety.
4. Build:
   - versi 1.10.1+21 di pubspec.yaml.
   - flutter build appbundle --release; laporkan ukuran, targetSdk, minSdk,
     dan daftar izin di manifest gabungan (aapt2/bundletool bila ada).
   - Cek dukungan 16 KB page size untuk library native di AAB (bundletool
     atau zipalign -c -P 16 -v 4 pada APK hasil bundletool). Laporkan.
5. Perbarui dokumen rilis:
   - docs/PLAY_STORE_RELEASE.md: versi 1.10.1 (21); tambah bagian
     "Verifikasi developer Android": karena APK juga dibagikan lewat GitHub,
     daftarkan package com.zainularkaan.quran di Play Console → Verifikasi
     developer Android (penegakan di Indonesia mulai 30 September 2026;
     sumber developer.android.com/developer-verification). Tambah langkah
     closed testing 12 penguji × 14 hari berturut-turut.
   - docs/RELEASE_CHECKLIST.md: bagian "Distribusi APK langsung (dipilih
     22 September 2026)" bertentangan dengan rilis Play; tandai sebagai
     riwayat dan rujuk PLAY_STORE_RELEASE.md.
   - Catatan rilis "Yang baru" 1.10.1 (Indonesia + Inggris), maks 500 karakter.
6. flutter analyze, flutter test. Commit, PR ke main. Jangan merge, jangan
   upload apa pun ke Play Console (itu dikerjakan pemilik).
```

---

## Prompt 2 — Liquid glass: fondasi

```
Kerjakan docs/design/v4-liquid-glass/PROMPT_CLAUDE_CODE.md Prompt 0 lalu
Prompt 1 (audit + LiquidGlass + token + tier + tes kontras) di branch
fitur/v6. Lewati langkah yang sudah dikerjakan di Prompt 0 v6 (CLAUDE.md).
Target: glass_audit.sh A1, A2, B1, B4, C1, C2 lulus.
Tambahan v6: token baru di docs/design/v6/DESIGN.md §3 (teal, tealSoft,
heroA/heroB, onHero/onHeroSec, goldLine, goldButton/onGoldButton,
skyHorizon) ditambahkan ke SacredTokens untuk 5 palet + lerp, dengan tes
kontras yang tercantum di §3.
Commit terpisah: "LiquidGlass v4" dan "Token v6".
```

---

## Prompt 3 — Dock (tab bar + sedang diputar)

```
Ikuti docs/design/v6/screens/21-dock.md dan v4 LIQUID_GLASS.md §2, §6.
Branch fitur/v6. Rencana dulu.

1. lib/app/widgets/lintasan.dart (DESIGN v6 §2) — dipakai juga nanti.
2. NowPlayingRow + AyahSegmentTrack mini.
3. AppDock: satu LiquidGlass, tabs dengan lensa meluncur (v4 §6), baris
   sedang diputar dengan AnimatedSize, gestur & semantics sesuai tabel.
4. AppShell memakai AppDock; hapus scrim padat; ganti semua padding bawah
   tetap (FloatingTabBar.reservedHeight, bottom: 120) dengan
   AppDock.reservedHeightOf(context).
5. ReaderScreen memakai NowPlayingRow yang sama (maks 2 kaca di pembaca).
6. FloatingTabBar & AudioMiniPlayer: tandai @Deprecated, hapus setelah tidak
   ada pemanggil (grep).
7. Tes & golden sesuai "Selesai jika". Buka PNG golden dan bandingkan dengan
   V6-Beranda.png, V6-Beranda-Diputar.png, V6-Komponen.png (baris Dock).
   Tulis daftar selisih, perbaiki, ulangi.
Commit "Dock v6".
```

---

## Prompt 4 — Beranda: logika dulu (tanpa UI)

```
Ikuti docs/DATA.md §1–§4 dan §6. Branch fitur/v6. Rencana dulu.

1. lib/features/home/domain/: home_snapshot.dart, next_step.dart
   (decideNextStep), today_summary.dart, prayer_horizon.dart (buildHorizon).
   Semua fungsi murni; DateTime dioper.
2. Kunci baru murajaah.selesai.<tanggal>: cari titik pencatatan hasil
   murajaah yang sudah ada, tambahkan penghitung, bersihkan kunci > 14 hari.
3. lib/features/home/application/home_controller.dart: membangun snapshot
   dari layanan yang ada; hitung ulang sesuai DATA §1 (termasuk ganti hari).
4. Tes tabel di test/home/ persis sesuai DATA §6. Semua kasus harus ada.
5. Tes bahwa kunci baru tidak ikut sinkron cloud.
flutter analyze + flutter test. Commit "Beranda v6: logika + tes".
Belum mengubah home_screen.dart.
```

---

## Prompt 5 — Beranda: tampilan

```
Ikuti docs/design/v6/screens/19-beranda.md. Lihat V6-Beranda*.png dan
V6-Komponen.png. Branch fitur/v6. Rencana dulu.

1. PrayerHorizon, NextStepCard, TodayCard, ConcentricRings di
   lib/features/home/presentation/, memakai HomeController dari Prompt 4.
2. home_screen.dart dirombak sesuai tata letak; hapus _PrayerStrip,
   _TodayList, _TargetAndStreak, _HeroCard setelah tidak dipakai.
   SessionTodayCard pindah ke tab Belajar (bagian atas).
3. Semua status di "Status yang wajib ada golden-nya". Ikuti loop verifikasi
   visual CLAUDE.md: golden → buka PNG → bandingkan dengan acuan → daftar
   selisih → perbaiki. Ulangi di teks 2.0.
4. Laporan akhir: checklist "Selesai jika" dengan bukti + pasangan gambar
   (acuan vs hasil).
Commit "Beranda v6".
```

---

## Prompt 6 — Murottal

```
Ikuti docs/design/v6/screens/20-murottal.md dan DATA §5.2–§5.3. Lihat
V6-Murottal*.png. Branch fitur/v6. Rencana dulu.

1. PlayerViewModel (lib/features/murottal/application/) + tes.
2. AyahFollowList (ScrollablePositionedList, ayat dari loader yang sama
   dengan ReaderScreen — cari, jangan buat parser baru), AyahSegmentTrack,
   panel kontrol, tombol sesuai tabel §5, menu ⋯, Teks|Sampul.
3. Unduh lewat AudioDownloadService yang sudah ada.
4. Hapus teks internal & tombol mati.
5. Tes widget + golden sesuai "Selesai jika". Buka PNG golden: pastikan
   harakat ayat tidak terpotong dan tidak ada Opacity/ShaderMask di atas ayat.
Commit "Murottal v6".
```

---

## Prompt 7 — Waktu salat: lokasi & cara hitung

```
Ikuti docs/design/v6/screens/22-pengaturan-salat.md. Branch fitur/v6.
Rencana dulu.

1. Buka aladhan.com/calculation-methods dan dokumentasi endpoint timings
   (koordinat, method, school, tune). Tulis ID metode yang dipakai beserta
   sumbernya di komentar kode. Jangan dari ingatan.
2. PrayerService: dukung koordinat (dibulatkan 2 desimal), method, school,
   tune; kunci cache memuat semua setelan. Pengguna lama tetap mode kota.
3. Lembar "Waktu salat" + baris di Saya → Pengaturan + pintu dari Beranda.
4. Pengingat salat dijadwalkan ulang setelah simpan (pakai logika ganti kota
   yang ada).
5. Perbarui hosting/public/privacy.html dan Data safety di
   docs/PLAY_STORE_RELEASE.md pada commit yang sama.
6. Tes & golden sesuai "Selesai jika".
Commit "Waktu salat: lokasi otomatis, metode, Asar, koreksi".
```

---

## Prompt 8 — Qari

```
Ikuti docs/design/v6/screens/23-qari.md. Branch fitur/v6. Rencana dulu.

1. lib/data/audio_sources.dart (registri granted/pending). Status awal:
   islamic_network = granted (dipakai sejak awal; izin tertulis masih
   diminta — catat di docs/lisensi), equran/mp3quran/qul = pending.
2. ReciterRepository menyaring pending di rilis; debug menampilkan dengan
   lencana.
3. Pemilih qari v6: cari, Dipilih, Populer di Indonesia (urutan di 23-qari.md,
   lewati yang tidak tersedia), Semua A–Z, dengar contoh, status unduhan.
4. JANGAN menambah URL audio untuk qari yang belum berizin (Yasser
   Al-Dosari, Nasser Al-Qatami, Idris Abkar, Islam Sobhi, Muzammil
   Hasballah, Salim Bahanan, dll.).
5. Tes & golden. Commit "Qari v6 + registri izin sumber audio".
```

---

## Prompt 9 — Kontras, kinerja, gambar Play, 1.11.0

```
1. Kerjakan v4 PROMPT_CLAUDE_CODE.md Prompt 3 (warna & golden kaca),
   Prompt 4 (pengawas frame + pengaturan Efek kaca + tes kinerja), lalu
   Prompt 5 (putaran nilai-perbaiki). Jangan mengarang angka kinerja; kalau
   tidak ada HP tersambung tulis "BELUM DIUKUR DI HP".
2. Jalankan ulang tool/store/store_assets_test.dart untuk 7 bahasa dengan
   UI v6. Pastikan listing hanya menyebut fitur yang ada di rilis (lokasi
   otomatis salat & tampilan ikuti ayat boleh disebut; qari pending tidak).
3. Versi 1.11.0+22, catatan rilis "Yang baru" ID + EN.
4. Laporan akhir: tabel PRD §4 (V1–V7) lulus/gagal + bukti, nilai rubrik
   glass sebelum → sesudah, daftar golden yang berubah.
5. PR fitur/v6 → main. Jangan merge, jangan upload ke Play.
```

---

## Berlaku di semua prompt

- Jangan mengubah `assets/quran/**`, terjemahan, `curriculum.json`, data atau arti tajwid, status draf.
- Tidak ada paket pub baru tanpa izin. Tidak ada layanan berbayar.
- Logo hanya lewat `Image.asset`, utuh.
- Tidak ada skor bacaan otomatis; rekaman tetap di HP.
- Jangan push ke main, merge, membuat rilis, atau mengunggah ke Play Console.
