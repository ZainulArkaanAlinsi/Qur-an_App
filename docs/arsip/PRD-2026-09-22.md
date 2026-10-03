# PRD — Ruang Tilawah → Quran Learning Super App

Status: draf Fase 0 · 22 September 2026 · pemilik: Zainul Arkaan

## 1. Ringkasan

Ruang Tilawah (v1.1.2, rilis APK gratis di GitHub Releases) dikembangkan menjadi
pusat **membaca, mendengar, memahami, belajar tajwid, belajar membaca, dan
menghafal** Al-Qur'an untuk pengguna Indonesia, anak-anak sampai dewasa.
Aplikasi dikembangkan dari kode yang sudah ada, bukan dibangun ulang.

Urutan prioritas: **integritas teks Al-Qur'an** → kemudahan membaca → sumber
ilmu yang dapat diverifikasi → offline → privasi → performa.

## 2. Pengguna

| Persona | Kebutuhan utama |
|---|---|
| Pembaca dewasa | Lanjut baca cepat, mushaf halaman, murottal, target harian |
| Pelajar tajwid | Warna tajwid bersumber, chip hukum per ayat, materi terstruktur |
| Anak (didampingi orang tua) | Sesi 5–10 menit, audio guru, reward tanpa dark pattern |
| Penghafal | Blok hafalan, repeat rentang, murajaah terjadwal |
| Guru/TPQ (fase 4) | Kelas, tugas, progres santri |

## 3. Yang sudah ada (v1.1.2)

Reader card per ayat (Tanzil Uthmani + Amiri, terjemahan Tanzil `id.indonesian`
2010), murottal Alafasy per ayat dengan antrean/repeat/background, bookmark +
koleksi, lanjut baca, pencarian, tab Juz, target menit + streak lembut, rencana
khatam, jadwal salat, kiblat, berita Islam, pengingat, sync cloud opsional
(Google + Firestore). Navigasi: Beranda, Qur'an, Progres, Pengaturan.

## 4. Lingkup per fase

Detail dan kriteria lulus ada di `docs/ROADMAP.md`.

- **Fase 0**: dokumen, keputusan edisi/sumber, spike parser tajwid ✅, spike
  font QCF V2/V4, prototipe tiga layout, akses API resmi.
- **Fase 1 (MVP pembaca)**: tiga mode baca (Card Belajar, Mushaf 1 halaman,
  Mushaf 2 halaman), banyak qari, setting font/tema, download teks & audio.
- **Fase 2 (belajar)**: Akademi Tajwid, tajwid interaktif per ayat, kurikulum
  *Belajar Membaca Al-Qur'an* orisinal, mode anak/dewasa, hub Juz Amma.
- **Fase 3 (hafalan)**: target, blok, repeat, spaced repetition, rekam lokal.
- **Fase 4 (pemahaman & institusi)**: tafsir terkurasi, tema ayat, dashboard
  guru, admin editorial.

## 5. Navigasi target

Lima tab: **Beranda, Baca, Belajar, Hafalan, Profil**. Dengar, Juz Amma,
Tajwid, Belajar Membaca, Tafsir, Pencarian menjadi shortcut.

**Keputusan yang perlu disetujui pemilik:** fitur yang sudah ada dan tidak
disebut di master prompt, yaitu jadwal salat, kiblat, berita Islam, dan
rencana khatam. Usulan: jadwal salat dan kiblat menjadi shortcut di Beranda,
Progres + Rencana khatam masuk ke Profil, dan berita tetap sebagai shortcut
(atau dihapus). Tab tidak diubah sebelum ada persetujuan.

## 6. Non-goal

- AI generatif untuk tafsir, tema ayat, asbabun nuzul, fatwa, deteksi tajwid,
  atau skor bacaan otomatis.
- Menyalin halaman/nama produk Iqro tanpa izin tertulis.
- Forum/komunitas, iklan di layar Al-Qur'an, paywall untuk ayat.
- Klaim "sama persis dengan mushaf cetak" sebelum verifikasi visual + izin aset.

## 7. Model bisnis

Membaca, terjemahan dasar, dan tajwid dasar tetap gratis. Catatan: terjemahan
yang dibundel saat ini berlisensi **non-komersial** (Tanzil). Monetisasi apa pun
(fitur institusi, sync keluarga, dll.) mewajibkan izin terjemahan terlebih dulu
— lihat `docs/DATA_SOURCES_AND_LICENSES.md`.

## 8. Metrik keberhasilan (lokal, tanpa tracker)

Crash-free session, waktu buka reader < 1 detik offline, 0 laporan teks salah,
persentase ayat tajwid yang tampil berwarna vs fallback polos.
