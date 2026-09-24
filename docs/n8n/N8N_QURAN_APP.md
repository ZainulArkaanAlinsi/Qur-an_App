# Sistem n8n untuk Qur'an App

Tujuannya: semua keinginan dan keluhan pengguna tertampung, tersusun rapi, dan sampai ke kamu dalam bentuk yang bisa langsung dikerjakan. Materi keagamaan juga tetap melewati review ustadz sebelum terbit.

## 1. Gambaran sistem

```
Pengguna ──(tombol "Kirim masukan" di tab Saya)──┐
Pengguna ──(link formulir di Play Store/IG)──────┤
                                                 ▼
                         [1] Masukan pengguna (n8n)
                         rapikan → klasifikasi → prioritas
                         ├─► Google Sheet "Masukan" (semua masukan)
                         └─► bug/konten ─► Issue GitHub ─► Telegram tim

Ustadz reviewer ──(formulir review)──► [2] Review materi (n8n)
                         simpan → hitung → ≥2 setuju & 0 perbaikan?
                         ├─ ya  ─► Issue GitHub "Terbitkan materi …"
                         └─ tidak ─► Telegram penulis: catatan perbaikan

Setiap Senin 08.00 ──► [3] Rangkuman mingguan (n8n)
                         kategori terbanyak, layar tersering, P1 terbuka,
                         permintaan fitur terbaru ─► Telegram
```

Klasifikasi memakai **aturan kata kunci**, bukan AI. Alasannya: gratis, hasilnya bisa dijelaskan, dan tidak ada teks keagamaan yang dibuat mesin. Kalau nanti mau pakai AI, pakai hanya untuk mengelompokkan masukan, jangan untuk menjawab soal agama.

## 2. Siapkan Google Sheet

Buat satu spreadsheet berisi 2 tab. Tulis header di baris 1 persis seperti di bawah.

**Tab `Masukan`:**

```
id | diterima | sumber | kategori | prioritas | pesan | layar | rujukan_ayat | versi_app | perangkat | kontak | status
```

- `status` diisi manual: `baru` → `dikerjakan` → `selesai`.
- `kategori` bisa berisi `bug`, `konten`, `audio`, `belajar`, `hafalan`, `tampilan`, `permintaan`, atau `lainnya`.
- `prioritas`:
  - **P1:** kesalahan konten (ayat, harakat), crash, atau data hilang.
  - **P2:** bug lainnya.
  - **P3:** sisanya.

**Tab `Review`:**

```
waktu | materi | reviewer | sanad | keputusan | catatan
```

## 3. Pasang di n8n

1. Buka n8n (Cloud atau self-host), lalu pilih **Workflows → Import from file**. Impor ketiga file JSON:
   - `1-masukan-pengguna.json`
   - `2-review-materi.json`
   - `3-rangkuman-mingguan.json`
2. Buat kredensial:
   - **Google Sheets OAuth2.**
   - **GitHub (Access Token):** fine-grained token, hanya repo `Qur-an_App`, izin Issues read & write.
   - **Telegram Bot:** buat lewat @BotFather, lalu ambil chat ID grup tim.
3. Di setiap node, ganti placeholder dengan nilai milikmu:
   - `GANTI_DENGAN_URL_GOOGLE_SHEET` → URL spreadsheet-mu.
   - `GANTI_DENGAN_CHAT_ID` → chat ID Telegram.
4. Buat label di repo GitHub: `masukan-pengguna`, `bug`, `konten`, `siap-terbit`.
5. Aktifkan ketiga workflow. Salin **Production URL**:
   - dari node *Masukan dari aplikasi* (webhook), untuk dipasang di aplikasi;
   - dari node *Formulir masukan*, untuk dibagikan ke pengguna;
   - dari node *Formulir review*, khusus untuk reviewer.
6. Uji dulu dengan "Test workflow" sebelum diaktifkan.

Catatan: JSON ini disusun untuk n8n versi 1.x dan logika node Code-nya sudah aku uji. Tapi aku belum mengimpornya ke instance n8n sungguhan. Kalau ada node yang menampilkan peringatan parameter setelah diimpor, buka node itu dan pilih ulang field-nya.

## 4. Sambungkan ke aplikasi

Tambahkan baris **"Kirim masukan"** di tab Saya. Isinya: pilihan jenis, kolom pesan, dan centang "Boleh dihubungi lewat email". Layar yang sedang dibuka, versi aplikasi, dan model perangkat diisi otomatis. Contoh prompt untuk Claude Code:

```text
Tambahkan fitur "Kirim masukan" di tab Saya sesuai docs/n8n/N8N_QURAN_APP.md §4.
Kirim POST JSON ke URL webhook dari --dart-define=FEEDBACK_WEBHOOK_URL, dengan field:
jenis, pesan, layar, rujukan_ayat, versi_app, perangkat, boleh_dihubungi, email.
Email hanya dikirim bila boleh_dihubungi = true. Jangan kirim data akun, token, atau
riwayat baca. Kalau offline, simpan antrean lokal lalu kirim ulang saat online.
Tampilkan konfirmasi "Jazakallahu khairan" setelah terkirim. Gunakan komponen
SacredTokens & InsetGroupedList. Tambah widget test.
```

Contoh body yang diterima webhook:

```json
{
  "jenis": "Kesalahan konten (ayat/terjemahan/tajwid)",
  "pesan": "Warna tajwid di 2:255 kata ke-3 terpotong",
  "layar": "Mushaf",
  "rujukan_ayat": "2:255",
  "versi_app": "1.6.1",
  "perangkat": "Redmi Note 12 · Android 14",
  "boleh_dihubungi": false
}
```

## 5. Privasi & aturan

- **Data yang dikirim:** hanya yang diisi pengguna, plus info teknis (layar, versi, perangkat).
- **Email:** hanya disimpan kalau pengguna mengizinkan, dan tidak pernah ikut masuk ke issue GitHub (repo bisa publik).
- **Kebijakan privasi & Data Safety Play Store:** sebutkan bahwa masukan dikirim ke layanan n8n dan Google Sheets milikmu.
- **Materi keagamaan tetap mengikuti `docs/RELIGIOUS_CONTENT_GOVERNANCE.md`:**
  - Workflow 2 hanya **membuat tugas** "siap terbit".
  - Yang mengubah status materi tetap kamu, lewat PR.
- **Tidak ada balasan otomatis ke pengguna** untuk pertanyaan agama.

## 6. Pengembangan berikutnya (opsional)

- **Ulasan Play Store:** tarik ulasan baru lewat Google Play Developer API (endpoint `reviews`) setiap hari, masukkan ke sheet yang sama dengan `sumber = playstore`, lalu buat draf balasan untuk kamu setujui manual.
- **Laporan konten di dalam mushaf:** tekan lama sebuah ayat → "Laporkan", maka `rujukan_ayat` terisi otomatis. Laporan ini selalu P1.
- **Voting fitur:** tampilkan 3 permintaan teratas dari rangkuman mingguan di aplikasi, lalu biarkan pengguna memilih.
