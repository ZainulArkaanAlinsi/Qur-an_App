# PRD — MyQuran: rilis Google Play + v6

Status: aktif · 2 Oktober 2026 · pemilik: Zainul Arkaan
PRD lama (Fase 0, 22 September 2026) dipindah ke `docs/arsip/PRD-2026-09-22.md`.

## 1. Masalah

Orang Indonesia yang ingin dekat dengan Al-Qur'an biasanya memakai beberapa aplikasi sekaligus: satu untuk membaca, satu untuk murottal, satu untuk jadwal salat, dan belajar tajwid di tempat lain. Kebanyakan aplikasi itu penuh iklan, menampilkan banyak tombol yang sama pentingnya, dan tidak membantu membangun kebiasaan harian.

MyQuran menjawabnya dengan satu aplikasi gratis tanpa iklan yang **memberi tahu satu langkah berikutnya** setiap hari, dengan teks Al-Qur'an yang dijaga verbatim.

## 2. Pengguna

| Persona | Titik mulai onboarding | Yang paling dibutuhkan |
| --- | --- | --- |
| Pemula (belum bisa membaca huruf Arab) | `nol` | Sesi 10 menit yang jelas urutannya, bunyi huruf, tidak dihakimi |
| Pembaca yang ingin lancar tajwid | `tajwid` | Warna tajwid, materi bertahap, murottal per ayat untuk ditirukan |
| Penghafal | `hafalan` | Murajaah terjadwal, ulang ayat/rentang, rekam suara sendiri |
| Semua | — | Lanjut baca cepat, jadwal salat akurat untuk lokasinya, tanpa iklan |

## 3. Lingkup

### Masuk rilis Play pertama (1.10.x, sekarang)
Fitur 1.10.0 apa adanya: baca (kartu ayat + tajwid), terjemahan, murottal per ayat, sesi hari ini (v5), belajar tahap 1–5, hafalan & murajaah, salat & kiblat, pengingat, sinkron opsional.

### Masuk update selama closed testing (1.11 = v6)
Beranda v6, dock, Murottal v6, pengaturan waktu salat, pemilih qari v6, liquid glass v4.

### Tidak masuk (dikunci sampai ada izin/peninjau)
Mode mushaf 1/2 halaman (izin KFGQPC + QUL), materi tajwid tahap 6–16 (2 peninjau bersanad), qari dari sumber yang belum berizin, rekaman bunyi huruf (menunggu guru).

### Bukan tujuan
Iklan, langganan, pembelian dalam aplikasi; skor bacaan otomatis/AI; tafsir buatan AI; forum; fadhilah/amalan tanpa dalil shahih.

## 4. Fitur & kriteria selesai

Prioritas: **Must** = wajib sebelum minta akses Production · **Should** = di 1.11 bila sempat · **Could** = nanti.

| # | Fitur | Prio | Kriteria selesai (semua harus benar) |
| --- | --- | --- | --- |
| R1 | Build Play siap tes tertutup | Must | `flutter build appbundle --release` sukses dengan kunci upload; targetSdk 36; lolos cek 16 KB page size di App bundle explorer; tidak ada izin `REQUEST_INSTALL_PACKAGES` di AAB |
| R2 | Kebijakan privasi & Data safety sesuai kode | Must | Setiap pengumpulan data di kode (Firebase Auth, Firestore, AlAdhan, audio) tercantum; tidak ada klaim yang tidak ada di kode; URL hidup |
| R3 | Hapus akun di aplikasi + web | Must | Saya → kartu profil → Hapus akun & data cloud bekerja; ada URL web untuk permintaan hapus (Play mewajibkan untuk app yang punya login) |
| R4 | Tidak ada tombol mati / teks internal | Must | Tidak ada tombol non-aktif tanpa alasan terlihat; tidak ada kalimat developer di UI (cek: "belum dicatat", "TODO", "debug") |
| V1 | Beranda v6 | Must (1.11) | `docs/design/v6/screens/19-beranda.md` "Selesai jika" + tes `NextStepEngine` |
| V2 | Dock (tab + sedang diputar) | Must (1.11) | `21-dock.md` "Selesai jika" |
| V3 | Murottal ikuti bacaan | Must (1.11) | `20-murottal.md` "Selesai jika" |
| V4 | Liquid glass v4 | Must (1.11) | `docs/design/v4-liquid-glass/AUDIT_RUBRIK.md` ≥ 18/20, G6–G8 = 2 (G8 boleh 1 bila belum diukur di HP, ditulis jujur) |
| V5 | Pengaturan waktu salat (lokasi otomatis, metode, Asar, koreksi menit) | Should | `22-pengaturan-salat.md` "Selesai jika" + privasi diperbarui |
| V6 | Pemilih qari v6 + registri izin sumber | Should | `23-qari.md` "Selesai jika"; qari `pending` tidak pernah muncul di rilis |
| V7 | Gambar Play Store dibuat ulang dari UI v6 | Should | `tool/store/store_assets_test.dart` dijalankan ulang; 7 bahasa; hanya fitur yang ada di rilis |
| C1 | Qari populer tambahan (Yasser Al-Dosari, dll.) | Could | Setelah bukti izin disimpan (`23-qari.md`) |
| C2 | Gutter 20 & Lintasan di semua layar | Could | Migrasi layar per layar dengan golden |

## 5. Alur utama

1. **Hari pertama pemula**: buka → onboarding pilih `nol` → Beranda: horizon salat, kartu "Sesi hari ini" → Mulai sesi → 5 langkah → selesai → Beranda: kartu berubah ke bacaan/murajaah, cincin Sesi penuh, istiqamah 1 hari.
2. **Penghafal pagi hari**: buka → kartu utama "Murajaah An-Naba' 1–10" → Mulai → kembali → kartu berubah ke sesi/bacaan.
3. **Dengar sambil mengikuti**: Beranda → pilihan "Baca Al-Fatihah" → ikon dengar di pembaca → dock memanjang → ketuk dock → Murottal: ayat aktif tersorot dan bergulir sendiri → atur ulang 3× → geser dock ke bawah untuk berhenti → Urungkan.
4. **Pindah kota**: Salat → Ganti → Otomatis → Pakai lokasi sekarang → jadwal & pengingat diperbarui.

## 6. Metrik (lokal, tanpa pelacak)

Crash-free (Play Console vitals), waktu buka pembaca < 1 dtk luring, 0 laporan teks ayat salah, rating Play ≥ 4.5 dari penguji tertutup.

## 7. Pertanyaan terbuka

| # | Pertanyaan | Pemilik jawaban |
| --- | --- | --- |
| Q1 | ~~Kunci penandatanganan: pakai kunci rilis yang ada atau kunci Google?~~ Terjawab 3 Oktober 2026: kunci Google (lihat `docs/decisions.md`) | Zainul, saat membuat app di Play Console |
| Q2 | Kategori Play: Education atau Books & Reference? | Zainul |
| Q3 | Siapa 12+ penguji tertutup (email Google mereka)? | Zainul |
| Q4 | APK GitHub tetap dirilis? Bila ya, daftarkan package di Play Console → Verifikasi developer Android (penegakan di Indonesia sejak 30 Sep 2026) | Zainul |
| Q5 | Urutan qari "Populer di Indonesia" disetujui? | Zainul |
