# MyQuran v6 — "Tenang & Terarah"

Status: diminta pemilik · 2 Oktober 2026. Gambar acuan = target visual; angka di gambar adalah contoh.

| Layar | Spesifikasi |
| --- | --- |
| Beranda | `screens/19-beranda.md` |
| Pemutar murottal | `screens/20-murottal.md` |
| Dock (tab bar + sedang diputar) | `screens/21-dock.md` |
| Lokasi & cara hitung waktu salat | `screens/22-pengaturan-salat.md` |
| Pilihan qari | `screens/23-qari.md` |

Berlaku **bersama** `docs/design/v2/DESIGN.md`, `docs/design/v3/DESIGN.md`, dan `docs/design/v4-liquid-glass/LIQUID_GLASS.md`. Kalau bertentangan, dokumen ini menang untuk layar-layar di atas; untuk layar lain v2/v3 tetap berlaku.

Gambar acuan: `screens/V6-*.png` (papan gabungan: `screens/V6-Papan.png`). HTML sumber gambar: `html/`.

## 0. Masalah yang diselesaikan

Dari tangkapan layar 1.10.0 (2 Oktober 2026):

| # | Masalah | Akibat bagi pengguna |
| --- | --- | --- |
| M1 | Beranda punya tiga ajakan "Lanjutkan" (Sesi hari ini, Lanjutkan membaca, Lanjutkan belajar) dengan bobot sama | Bingung harus mulai dari mana; tidak ada yang terasa penting |
| M2 | Target baca dan Istiqamah tampil "0" besar di hari pertama | Terasa menghakimi, bukan mengajak |
| M3 | Jadwal salat ada di paling bawah, tertutup tab bar | Informasi yang paling terikat waktu justru paling sulit dilihat |
| M4 | Mini player menumpuk di atas tab bar sebagai kartu hijau kedua, menutupi isi, dan tombolnya dobel dengan tombol jeda di kartu bacaan | Dua kontrol untuk satu audio; layar terasa penuh |
| M5 | Layar Murottal: 45% layar untuk sampul statis, ayat yang sedang dibaca **tidak tampil** | Tidak bisa mengikuti bacaan qari, padahal itu kebutuhan utama |
| M6 | Bar kemajuan per ayat (0:01 / −0:05) | Angka berubah tiap 5 detik, tidak memberi gambaran posisi di surah |
| M7 | Tombol "Unduh" non-aktif dengan alasan tersembunyi; catatan developer "Waktu mendengar belum dicatat…" tampil ke pengguna | Tombol mati dan teks internal merusak kepercayaan |
| M8 | Lensa tab aktif menempel ke tepi kapsul; tab bar dan scrim padat (lihat audit v4) | Terlihat kaku, tidak "liquid glass" |

## 1. Prinsip

1. **Satu langkah berikutnya.** Setiap kali Beranda dibuka, satu aksi utama dipilih oleh `NextStepEngine` (`docs/DATA.md §2`). Aksi lain tetap terjangkau, tapi tampil lebih kecil.
2. **Hari mengikuti salat.** Waktu ditampilkan sebagai lintasan lima waktu salat di bagian atas, bukan strip di bawah.
3. **Ayat selalu terlihat saat didengar.** Murottal menampilkan teks ayat yang sedang dibaca (Tanzil, verbatim) dengan terjemahan.
4. **Satu permukaan kaca di bawah.** Tab bar dan mini player menjadi satu dock. Kaca hanya untuk chrome (aturan v4).
5. **Mengajak, bukan menghakimi.** Angka nol diganti kalimat ajakan; capaian penuh dirayakan secukupnya.
6. **Tidak ada tombol mati.** Tombol yang belum bisa bekerja disembunyikan, bukan dinonaktifkan dengan alasan tersembunyi.

## 2. Bahasa visual: "Lintasan"

Satu komponen garis-dan-titik dipakai untuk semua yang bersifat urutan, supaya aplikasi terasa satu sistem:

| Pemakaian | Titik | Garis | Titik aktif |
| --- | --- | --- | --- |
| Horizon salat (Beranda) | 5 waktu salat | sudah lewat = `primaryText`, belum = `surf2` | salat berikutnya: cincin `gold` 16 + halo `goldSoft` 4 |
| Langkah sesi (kartu Langkah berikutnya) | 5 langkah | putih 18% di atas hijau | langkah sekarang: cincin `goldLine` |
| Segmen ayat (Murottal, dock) | 1 segmen per ayat dalam antrean | selesai = `primaryText`, belum = `surf2` | ayat sekarang terisi `gold` sesuai posisi audio |
| Pekan istiqamah | 7 hari | — | hari ini: lingkaran putus-putus `gold` |

Implementasi: `lib/app/widgets/lintasan.dart` → `Lintasan({required int count, required double progress, int? current, List<String>? labels, LintasanStyle style})` dengan `LintasanStyle.onSurface | onHero`. Satu `CustomPainter`, dibungkus `RepaintBoundary`, tanpa animasi per frame kecuali segmen aktif (lihat §6).

## 3. Token tambahan

Ditambahkan ke `SacredTokens` (semua palet, dengan `lerp`). Token lama tidak dihapus.

| Token | Terang | Sepia | Gelap | Kontras tinggi (terang/gelap) | Dipakai |
| --- | --- | --- | --- | --- | --- |
| `teal` | `#1F6F78` | `#1F6F78` | `#7CCFD6` | `#00474F` / `#A6E6EC` | cincin & titik Murajaah |
| `tealSoft` | `#DCEEEF` | `#DCEEEF` | `#7CCFD6` @14% | `#DCEEEF` / `#A6E6EC` @20% | latar ikon murajaah |
| `heroA` → `heroB` | `#0D5843` → `#063B2D` | sama | `#0F4A39` → `#082A20` | `#00301F` padat | kartu Langkah berikutnya |
| `onHero` / `onHeroSec` | `#FBF7EC` / 78% | sama | `#F3F1E8` / 74% | `#FFFFFF` / 100% | teks di kartu hijau |
| `goldLine` | `#E2C36A` | `#E2C36A` | `#D6B04A` | `#FFE27A` | eyebrow & garis mihrab di hijau |
| `goldButton` / `onGoldButton` | `#F4CF5D` / `#1F1A08` | sama | sama | `#FFE27A` / `#000000` | CTA utama di kartu hijau |
| `skyHorizon` | `#E3EEF2` | `#EFE6CF` | `#132733` | — (padat `surf`) | ujung gradien kartu horizon |

Kontras yang wajib dites (tambah ke `test/contrast_test.dart` atau berkas setara):
- `teal` di `surf` ≥ 3:1 (elemen grafis) di semua palet; teks memakai `ink`, bukan `teal`.
- `onHero` di `heroB` ≥ 7:1; `onHeroSec` di `heroA` ≥ 4.5:1; `goldLine` di `heroA` ≥ 4.5:1 (eyebrow 11/800 dihitung teks kecil). Nilai di tabel sudah dihitung: onHero/heroB 11.7 (terang) · 13.6 (gelap); onHeroSec/heroA 5.5 · 5.7; goldLine/heroA 4.9 · 4.9; onGoldButton/goldButton 11.5; teal/surf 5.6 · 5.3 (sepia) · 9.8.
- `onGoldButton` di `goldButton` ≥ 7:1.

## 4. Tipografi & jarak (khusus layar v6)

| Peran | Gaya |
| --- | --- |
| Nama pengguna | EB Garamond 34/500, tinggi baris 1.08 |
| Judul kartu Langkah berikutnya | EB Garamond 31/500 (≥ 1.6× teks: 26) |
| Eyebrow | Plus Jakarta 11/800, spasi huruf 1.4, kapital |
| Isi | Plus Jakarta 14/500–700 |
| Angka | Plus Jakarta 800 dengan `FontFeature.tabularFigures()` |
| Ayat aktif (Murottal) | `SacredText.quran` 29, line-height 2.15 |
| Ayat lain (Murottal) | `SacredText.quran` 25, warna `sec` |

- Gutter layar v6: **20** (layar lain tetap 16 sampai dimigrasikan).
- Jarak antarbagian: 14 (antar-kartu atas), 22 (sebelum label bagian).
- Radius: kartu besar 28, kartu biasa 22–24, pill 999, dock 32.

## 5. Komponen baru

| Komponen | Berkas | Ringkas |
| --- | --- | --- |
| `Lintasan` | `lib/app/widgets/lintasan.dart` | §2 |
| `PrayerHorizon` | `lib/features/home/presentation/prayer_horizon.dart` | Kartu salat di atas Beranda (`screens/19-beranda.md §3`) |
| `NextStepCard` | `lib/features/home/presentation/next_step_card.dart` | Kartu hijau dari `NextStep` (§4 layar 19) |
| `TodayCard` | `lib/features/home/presentation/today_card.dart` | Tiga cincin + legenda + pekan istiqamah |
| `ConcentricRings` | `lib/app/widgets/concentric_rings.dart` | 1–3 cincin, stroke 10, jarak 4, ujung bulat |
| `AppDock` | `lib/app/widgets/app_dock.dart` | Menggantikan `FloatingTabBar` + `AudioMiniPlayer` di `AppShell` (`screens/21-dock.md`) |
| `NowPlayingRow` | `lib/features/murottal/presentation/now_playing_row.dart` | Baris "sedang diputar"; dipakai dock dan pembaca |
| `AyahFollowList` | `lib/features/murottal/presentation/ayah_follow_list.dart` | Daftar ayat yang mengikuti audio (`screens/20-murottal.md §3`) |
| `AyahSegmentTrack` | `lib/features/murottal/presentation/ayah_segment_track.dart` | `Lintasan` versi segmen, bisa diketuk & digeser |

Komponen lama yang **dihapus dari Beranda**: `_PrayerStrip` (pindah jadi `PrayerHorizon`), `_TodayList` (isinya masuk ke pilihan lain di `NextStepCard`), `_TargetAndStreak` (jadi `TodayCard`), `_HeroCard` (bacaan terakhir menjadi salah satu keluaran `NextStepCard`). `SessionTodayCard` tetap dipakai di tab Belajar, tidak lagi di Beranda.

## 6. Gerak

Semua dengan API bawaan Flutter. `MediaQuery.disableAnimationsOf` → semua jadi crossfade 150 ms atau langsung.

| Elemen | Gerak |
| --- | --- |
| Dock memanjang saat audio mulai | Tinggi 64 → 128, pegas (massa 1, kekakuan 380, redaman 30), baris "sedang diputar" fade + geser 8 px |
| Lensa tab | Sesuai v4 §6 (pegas 420/32, regang scaleX ≤ 1.12) |
| Ganti langkah berikutnya | `AnimatedSwitcher` 260 ms, isi lama geser kiri 12 px + fade |
| Cincin Hari ini | Isi bertambah 600 ms `Curves.easeOutCubic` saat Beranda tampil; tidak berulang ketika setState lain |
| Segmen ayat aktif | Mengisi mengikuti `positionStream`, dibatasi 10 Hz (bukan per frame) |
| Daftar ayat Murottal | `scrollable_positioned_list` `scrollTo` 380 ms `Curves.easeInOutCubic` ke posisi 30% dari atas |
| Titik "sekarang" di horizon | Bergeser tiap menit (Timer.periodic 60 dtk), bukan animasi terus-menerus |

## 7. Aksesibilitas (wajib)

- Target sentuh ≥ 44, termasuk segmen ayat (area sentuh setinggi 32 walau garisnya 7).
- `Semantics`:
  - Horizon: "Salat berikutnya Dzuhur pukul 11.42, 1 jam 7 menit lagi".
  - Langkah berikutnya: label = judul + subjudul; tombol = teks CTA.
  - Cincin: "Baca 0 dari 5 menit, Sesi 0 dari 5 langkah, Murajaah 0 dari 1 ayat".
  - Dock "sedang diputar": `customSemanticsActions` **Hentikan murottal** dan **Buka pemutar** (pengganti gestur geser).
  - Segmen ayat: `Slider`-semantics dengan nilai "Ayat 5 dari 7".
- Skala teks 2.0: horizon menjadi daftar vertikal 5 baris; pilihan lain di kartu hijau tetap satu kolom; cincin pindah ke atas legenda. Tidak ada teks terpotong (aturan CLAUDE.md).
- Kontras tinggi: tanpa gradien hijau (padat `heroA`), tanpa pola bintang, dock tier padat.

## 8. Yang tidak berubah

- Logo, ikon aplikasi, splash, onboarding (v3).
- Urutan 5 tab: Beranda, Qur'an, Belajar, Hafalan, Saya.
- Teks ayat & terjemahan: verbatim dari Tanzil, tanpa efek, tanpa kaca di atasnya.
- Palet tajwid.
- Tidak ada paket baru. `scrollable_positioned_list`, `just_audio`, `audio_service` sudah ada.
