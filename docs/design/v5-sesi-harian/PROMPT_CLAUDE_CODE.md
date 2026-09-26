# Prompt Claude Code: Sesi hari ini

Salin `docs/design/v5-sesi-harian/` ke repo. Kirim prompt ke Claude Code berurutan, dan cek hasil tiap prompt sebelum lanjut. Kalau pengerjaan liquid glass v4 belum selesai, kerjakan ini di branch sendiri supaya tidak bentrok.

---

## Prompt 1: Fondasi dan pemilih ayat

```
Baca CLAUDE.md, docs/design/v5-sesi-harian/SESI_HARIAN.md,
docs/RELIGIOUS_CONTENT_GOVERNANCE.md, dan docs/LEARN_CONTENT.md.

Buat branch fitur/sesi-harian dari main terbaru. Semua batasan di §0
SESI_HARIAN.md wajib diikuti: tanpa paket baru, tanpa server, aplikasi
tidak menilai bacaan, teks ayat tidak diubah, materi draf terkunci di rilis.

1. lib/features/session/domain/
   - session_plan.dart
     - SessionStep: warmup, newMaterial, findInVerse, listenRepeat, done.
     - DailySession: tanggal, lessonId, langkah terakhir, ayat terpilih,
       selesai.
     - Fungsi murni buildPlan(...) yang menyusun sesi dari kurikulum, riwayat
       kuis, langkah pelajaran, dan riwayat ayat.
   - verse_picker.dart: pemilih ayat sesuai §2.
     - Cocokkan huruf persis per code point.
     - Tanda: tanwin U+064B–U+064D, tasydid U+0651, sukun U+0652.
     - Ayat pendek ≤ 8 kata dari Al-Fatihah + surah 78–114, tanpa basmalah
       pembuka.
     - Indeks kata harus sama dengan tanzilWords() dari
       lib/features/mushaf/domain/mushaf_text.dart.
   - warmup_picker.dart: 3–5 soal ulang. Yang pernah salah didahulukan,
     lalu yang paling lama tidak dijawab. Hanya dari pelajaran yang sudah
     dibuka dan (di rilis) berstatus published.
2. lib/features/session/data/session_store.dart
   - Kunci SharedPreferences sesuai §5.
   - Rekaman di <documents>/rekaman_sesi/, dengan pembersihan otomatis
     > 30 hari kecuali disematkan.
3. Tes unit:
   - verse_picker: untuk setiap 28 huruf ada ≥ 3 ayat, dan semua kata yang
     disorot memuat hurufnya. Sama untuk tanwin, tasydid, dan sukun.
     Indeks sama dengan tanzilWords. Tidak ada ayat > 8 kata.
   - buildPlan: pelajaran aktif, pelajaran tanpa contoh (tahap 1–2), semua
     contoh sudah terpakai, materi draf di rilis (tidak boleh muncul), dan
     hari berganti di tengah sesi.
4. flutter analyze + flutter test. Commit: "Sesi harian: rencana, pemilih
   ayat, penyimpanan".
```

---

## Prompt 2: Layar sesi 5 langkah

```
Ikuti SESI_HARIAN.md §1 dan §4.

1. lib/features/session/presentation/session_screen.dart
   - Satu layar penuh dengan penunjuk 5 langkah (pakai ulang gaya _Stepper
     dari practice_screen.dart, jadikan widget bersama kalau perlu), tombol
     tutup, dan tanpa tab bar.
   - Pemanasan: pakai logika quiz_session.dart yang sudah ada.
   - Materi baru: tampilkan blok pelajaran aktif mulai getLessonStep sampai
     kuis berikutnya, dengan widget blok dari lesson_screen.dart. Pisahkan
     widget blok ke berkas bersama bila perlu, tanpa mengubah tampilannya
     di lesson_screen.
   - Temukan di ayat: ayat dengan kata tersorot dan tajwid yang bisa
     diketuk. Pertanyaan "Ketuk kata yang …", dicek dari indeks kata.
   - Dengar & tirukan: tombol Qari (QuranAudioService untuk satu ayat, ulang
     3×, kecepatan 0.75/1), tombol Rekam (record, sama seperti
     _RecordRow di practice_screen), tombol Suaraku, dan tombol
     "Bergantian" (Qari → Suaraku → Qari, maks 3 putaran). Bar amplitudo
     dari onAmplitudeChanged. Tulis kalimat: "Aplikasi tidak menilai
     bacaanmu. Minta guru menyimak bila bisa."
   - Offline tanpa audio terunduh: langkah ini menjadi "Rekam saja".
   - Selesai: "Sudah mirip" / "Masih beda", ringkasan, dan saran besok.
   - Setiap langkah bisa dilewati kecuali Selesai. Keluar di tengah sesi
     menyimpan langkahnya.
   - Pastikan audio sesi tidak merusak antrean murottal yang sedang
     berjalan. Hentikan antrean dengan sopan dan pulihkan mini player
     setelah sesi.
2. Izin mikrofon diminta hanya saat pertama kali menekan Rekam, dengan
   penjelasan satu kalimat. Kalau ditolak, sesi tetap bisa selesai.
3. Semua warna dari SacredTokens. Aksesibilitas: Semantics per tombol,
   target sentuh ≥ 44, teks 2× tidak terpotong, dan kurangi gerak dihormati.
4. Tes widget alur lengkap: lewati langkah, keluar lalu lanjut, izin mikrofon
   ditolak, dan offline. Golden layar tiap langkah dalam terang, gelap,
   sepia, dan teks 2×. Buka PNG golden dan pastikan teks Arab tidak
   terpotong.
5. Commit: "Sesi harian: layar 5 langkah".
```

---

## Prompt 3: Beranda, istiqamah, pengingat

```
Ikuti SESI_HARIAN.md §4 dan §5.

1. Kartu "Sesi hari ini" di home_screen.dart:
   - Paling atas untuk titik mulai nol/tajwid; di bawah kartu Lanjutkan
     membaca untuk titik mulai hafalan.
   - Isi kartu: 5 titik langkah dan tombol Mulai/Lanjutkan. Setelah
     selesai, kartu menjadi "Selesai hari ini ✓ · besok: <judul>".
2. Istiqamah: sesi selesai dihitung sebagai hari istiqamah. Tambah aturan
   di StreakCalculator tanpa mengubah aturan lama. Semua tes lama harus tetap
   lulus, dan tambahkan tes baru.
3. Sinkron cloud (kalau masuk): hanya tanggal sesi selesai. Rekaman dan
   nilai diri tidak pernah dikirim. Tambahkan tes yang memastikannya.
4. Pengingat "Sesi hari ini" di Saya → Pengingat, lewat reminder_service.dart.
5. Blok bunyi huruf (asset null) tetap bertuliskan "Rekaman sedang
   disiapkan". Jangan diisi TTS atau suara sintetis.
6. flutter analyze + flutter test + golden. Kalau glass_audit.sh sudah ada di
   repo, jalankan juga dan pastikan tidak ada GAGAL baru.
7. Perbarui README (bagian Fitur → Belajar) dan docs/PROGRESS.md.
8. Buka PR fitur/sesi-harian ke main dengan ringkasan, golden yang berubah,
   dan hasil uji manual di HP bila ada. Jangan merge dan jangan membuat
   rilis.
```

---

## Yang berlaku di semua prompt

- Jangan mengubah `assets/quran/**`, terjemahan, isi `curriculum.json`, atau status draf.
- Tidak menambah paket pub dan tidak menambah layanan jaringan baru.
- Aplikasi tidak memberi skor bacaan otomatis dalam bentuk apa pun.
- Rekaman tetap di HP.
