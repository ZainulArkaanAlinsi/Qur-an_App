# Prompt Claude Code — Revisi v2

## Cara pakai

1. Salin folder `revisi-v2` ini ke `docs/revisi-v2/` di repo `Qur-an_App`. Isinya:
   - `SPESIFIKASI_REVISI_V2.md` — apa yang dibangun.
   - `RISET_SUMBER.md` — sumber data, buku tajwid, lisensi.
   - File prompt ini.
2. Foto referensi sudah ada di folder `referensi/`.
3. Buka terminal di root repo, jalankan `claude`, tekan Shift+Tab sampai **plan mode**, lalu tempel **Prompt utama**.
4. Kerjakan satu tahap per sesi. Setelah dicek di HP, tempel **Prompt lanjutan**.

---

## Prompt utama

```text
Kamu engineer Flutter senior di proyek Qur'an App (repo ini, versi 1.4.0). Tugasmu
revisi v2. Tujuannya: orang yang belum bisa membaca Al-Qur'an sama sekali bisa belajar
di aplikasi ini sampai lancar & bertajwid, lalu menghafal. Semuanya dengan UI rapi
bergaya iOS dan konten yang akurat. Rombak proyek yang ada; jangan buat proyek baru.

WAJIB DIBACA dulu, urut:
1. CLAUDE.md. Folder graphify-out/ belum ada; kalau perintah graphify tersedia,
   jalankan `graphify update .` dulu. Kalau tidak tersedia, baca kode langsung dan
   catat itu.
2. QURAN_APP_GUIDE_DAN_PROMPT_CODEX.md, docs/RELIGIOUS_CONTENT_GOVERNANCE.md,
   docs/PRD.md, docs/ROADMAP.md, docs/DATA_SOURCES_AND_LICENSES.md.
3. docs/design/ios-redesign/DESIGN_SPEC.md (token & komponen: SacredTokens, SacredText,
   MihrabClipper, InsetGroupedList, dll).
4. docs/revisi-v2/SPESIFIKASI_REVISI_V2.md dan docs/revisi-v2/RISET_SUMBER.md.
5. Foto di docs/revisi-v2/referensi/ sebagai gambaran nuansa mushaf cetak berwarna.

TEMUAN AUDIT (verifikasi sendiri sebelum dipakai):
- Belajar: lib/screens/learn_screen.dart & tajweed_lessons_screen.dart campur Material
  mentah dan SacredTokens. assets/learn/tajweed_lessons.json kosong (0 pelajaran).
  Kartu "Belajar Membaca Al-Qur'an" masih "Belum tersedia". Daftar Juz 'Amma dobel
  dengan Hafalan. Belajar & Hafalan hanya bisa dicapai dari tab Progres.
- Hafalan: memorization_screen.dart, memorization_tile.dart, practice_screen.dart.
  Status hanya per surah (SharedPreferences hafalan_status_{surah}), tanpa jadwal
  murajaah, tanpa sync. BUG: di PracticeScreen repeat 3×/5×/10× memakai LoopMode.all
  sehingga tidak pernah berhenti; 1× memutar sampai akhir surah, bukan akhir rentang.
- Pengaturan: judul "Pengaturan" tampil dua kali (app_shell _SettingsTab + SettingsScreen).
  Warna chip hardcode. Baris sumber murottal hardcode Alafasy. Pembaruan terpecah
  di dua grup. Pilihan mode baca/terjemahan/tajwid/salat belum ada.
- Beranda: home_screen.dart ±23 warna hardcode, _SoftCard/_CircleButton duplikat.
  "Ayat hari ini" diambil acak (bisa keluar dari konteks). Tidak ada pintu ke
  Belajar/Hafalan.
- Qari: hanya Al Quran Cloud (±15 qari, per ayat). Model Reciter belum punya
  provider/lisensi.
- Mushaf 604 halaman + layout 1 halaman/2 halaman landscape sudah ada tapi hanya
  prototipe debug (lib/features/mushaf/*). Font V4 COLRv1 belum bisa dirender Flutter
  (flutter/flutter#134897).
- Tajwid: parser QF (TajweedMarkupParser) belum dipakai di release; palet sekarang
  bukan standar Kemenag. ADR repo melarang menempel markup QF ke teks Tanzil.
- Terjemahan: hanya Indonesia (Tanzil/Kemenag 2010).
- Kode mati: IslamicNewsScreen, SearchScreen stub.

ATURAN KONTEN (tidak boleh dilanggar):
- Teks Al-Qur'an & terjemahan hanya dari dataset berlisensi, verbatim, dengan
  atribusi & versi. Tidak diketik ulang, tidak dari AI, tidak dari gambar.
- Tidak ada doa, fadhilah, wirid, atau amalan tanpa dalil shahih. Tidak ada konten
  amalan khas golongan/ormas mana pun. Hadits (bila ada) wajib takhrij & derajat
  shahih/hasan. Materi tajwid mengikuti riwayat Hafs 'an 'Ashim (thariq Syathibiyyah),
  rujukan Tuhfatul Athfal & Al-Jazariyyah.
- Materi belajar ditulis ulang dengan bahasa sederhana berdasarkan sumber di
  RISET_SUMBER.md, mencantumkan sumber, status draf → minimal 2 reviewer → terbit.
  Rilis hanya menampilkan yang terbit; debug menampilkan draf berlabel.
- Tanpa TTS/AI untuk bacaan, tanpa penilaian bacaan otomatis.
- Setiap data/font/audio baru: cek lisensinya, catat di DATA_SOURCES_AND_LICENSES.md
  & DATASET_ATTRIBUTION.md, simpan checksum. Kalau lisensi tidak jelas, JANGAN
  dipakai di rilis; laporkan ke saya.
- Jangan hapus fitur tanpa izin. Jangan push/deploy/aktifkan layanan berbayar.

TAHAPAN (satu tahap, lalu berhenti dan laporkan):

Tahap 0: Audit & rencana. Buat branch revisi-v2. Jalankan flutter pub get, analyze,
test (catat baseline). Perbarui docs/PROGRESS.md yang sudah basi (masih menyebut
5 tab/v1.2.1). Usulkan struktur navigasi: 4 tab + Cari, atau 5 tab dengan "Belajar".
Sertakan kelebihan/kekurangan, lalu TANYA saya. Petakan tiap poin spesifikasi ke
file yang akan diubah.

Tahap 1: Spike mushaf persis cetakan (layout 1 & 2).
- Ambil layout QUL KFGQPC V2 (cek lisensi) sebagai DB offline read-only + checksum.
- Uji dua jalur warna tajwid (SPESIFIKASI §A):
  (a) konversi font V4 COLRv1 → COLRv0 + palet CPAL Kemenag;
  (b) font Unicode KFGQPC Hafs + span per huruf dari cpfair/quran-tajweed (CC BY 4.0).
  Cocokkan dulu teks cpfair dengan assets/quran/raw/tanzil_uthmani_v1.0.2.txt.
- Buat tes perbandingan kata pertama/terakhir tiap baris untuk halaman 1, 2, 3, 50,
  187, 273, 379, 582, 604.
- Laporkan hasil, screenshot, dan rekomendasi. Tunggu keputusan saya.

Tahap 2: Mode baca produksi.
- Mushaf 1 halaman: hiasan berwarna orisinal (bingkai, pita surah, penanda
  juz/hizb, medali nomor halaman, tab juz di tepi), 3 kertas (gading, sepia, malam).
- Mushaf 2 halaman landscape (ganjil kanan, genap kiri, geser kanan → kiri).
- Keduanya tanpa terjemahan.
- Kartu per ayat: terjemahan multi-bahasa dari QuranEnc (unduh per bahasa, atribusi
  + versi, maksimal 2 terjemahan sekaligus).
- Warna tajwid per huruf+harakat mengikuti Pedoman Tajwid Sistem Warna LPMQ (baca
  PDF-nya untuk pemetaan pasti). Nilai warna disetel per kertas agar kontras ≥ 3:1 dan
  tidak pernah sama dengan latar; tes kontras otomatis. Ada legenda, toggle, dan opsi
  buta warna. Tap huruf berwarna → sheet nama hukum + tautan ke pelajaran.
- Pengalih mode di Pembaca & Pengaturan; posisi baca tersinkron antar mode.

Tahap 3: Qari. Model Reciter baru (SPESIFIKASI §E). Sumber: Al Quran Cloud + EveryAyah,
plus Quran Foundation via BFF bila kredensial ada. Hanya riwayat Hafs; buang edisi
audio terjemahan. Verifikasi URL (HEAD 1:1 & 114:6) sebelum tampil. Kelompokkan
murattal/mujawwad/muallim, sediakan pencarian & tombol dengar contoh. Unduhan tetap
jalan per qari. Sorot per kata hanya untuk qari yang punya data timing.

Tahap 4: Belajar dari nol (SPESIFIKASI §B). Desain ulang Belajar memakai komponen
sacred: peta jalur 16 tahap, kartu pelajaran, layar pelajaran berblok, latihan
dengar-pilih, kuis, progres. Perluas skema JSON pelajaran + validasi. Isi semua
pelajaran sebagai DRAF (bahasa sederhana, rujukan jelas, contoh ayat via rujukan).
Tandai draf dengan jelas. Audio contoh: state "sedang disiapkan" sampai ada rekaman
berizin. Tambahkan "Lanjutkan belajar" di Beranda.

Tahap 5: Hafalan (SPESIFIKASI §D). Jelaskan di layar tujuan ziyadah/murajaah/tasmi'.
Rencana harian, sesi ziyadah terpandu, murajaah terjadwal yang bisa dijelaskan,
status per ayat, rekam suara opsional lokal. Perbaiki bug repeat. Masukkan ke sync
cloud + tes rules Firestore.

Tahap 6: Beranda & Pengaturan (SPESIFIKASI §E). Beranda dengan urutan baru, ayat
pilihan terkurasi (daftar JSON berstatus review), nol warna hardcode. Pengaturan
disusun ulang 9 grup, bug judul dobel diperbaiki, sumber & lisensi dinamis.
Hapus/arsipkan kode mati setelah saya setujui.

Tahap 7: QA. Terang/gelap/sepia/kontras tinggi, font 200%, layar 320 dp, landscape,
TalkBack, offline, audio gagal, izin lokasi ditolak. flutter analyze & test bersih.
Tambah tes untuk memorization, learn, repeat count, kontras warna tajwid, dan layout
mushaf.

SETIAP AKHIR TAHAP laporkan:
- Yang selesai.
- File yang berubah.
- Perintah + hasil test (jangan tulis lulus kalau belum dijalankan).
- Screenshot layar terang & gelap.
- Yang belum diuji di HP nyata.
- Keputusan/izin yang saya perlukan.
Perbarui docs/PROGRESS.md.

Mulai dari Tahap 0.
```

---

## Prompt lanjutan

```text
Baca docs/PROGRESS.md dan git diff terakhir. Lanjutkan tahap berikutnya di
docs/revisi-v2/PROMPT_REVISI_V2.md tanpa mengulang yang sudah selesai. Patuhi
SPESIFIKASI_REVISI_V2.md dan aturan konten. Jalankan analyze & test, sertakan
screenshot terang/gelap, perbarui PROGRESS.md, lalu berhenti dan laporkan.
```

## Prompt kalau layout mushaf belum persis

```text
Bandingkan halaman <NOMOR> di mode Mushaf dengan mushaf cetak Madinah 15 baris.
Untuk tiap baris, cek kata pertama & terakhir, rata tengah atau penuh, posisi judul
surah & basmalah. Buat daftar selisih, cari penyebabnya di data layout atau renderer
(jangan menambal manual per halaman), perbaiki, lalu tambahkan halaman itu ke tes
perbandingan.
```

## Prompt untuk merapikan bahasa materi tajwid

```text
Ambil pelajaran <ID> di assets/learn/. Tulis ulang penjelasannya agar mudah dipahami
anak SD sampai orang tua. Kalimat pendek, satu konsep per blok, istilah Arab diberi
arti. Isi hukum jangan diubah dan rujukan jangan dihapus. Status tetap "draf".
Tampilkan sebelum & sesudah untuk saya kirim ke reviewer.
```
