# 19-beranda — Beranda v6

**Gambar acuan:** `V6-Beranda.png` · gelap `V6-Beranda-Gelap.png` · saat murottal diputar `V6-Beranda-Diputar.png` · halaman penuh `V6-Beranda-Penuh.png` · status kartu `V6-Komponen.png`
**HTML acuan:** `../html/V6-Beranda*.html`
**Kode:** `lib/screens/home_screen.dart` (dirombak), `lib/features/home/` (baru)
**Data & logika:** `docs/DATA.md §1–§4`

## Tujuan
Dalam 3 detik pengguna tahu: salat berikutnya kapan, dan **satu hal** yang sebaiknya dikerjakan sekarang.

## Tata letak (atas → bawah, 390 dp)

1. **Header** (tetap seperti v2): tanggal Masehi 13/800 + Hijriah 13/500 `sec`; kanan tombol Cari & Bookmark (`SacredCircleButton` 40).
2. **Sapaan**: "Assalamu'alaikum," 15/600 `sec` + nama EB Garamond 34. Belum login: "Sahabat Qur'an".
3. **PrayerHorizon** (§3).
4. **NextStepCard** (§4).
5. Label bagian **HARI INI** + tautan kanan "Progres" (→ `ProgressScreen`).
6. **TodayCard** (§5).
7. Ruang bawah = tinggi dock saat ini + 16 (`AppDock.reservedHeightOf(context)`), supaya isi terakhir tidak tertutup baik saat dock 64 maupun 128.

Pull-to-refresh tetap: memuat ulang jadwal salat dan menghitung ulang `HomeSnapshot`.

## 3. PrayerHorizon

- Kartu radius 22, latar gradien `surf` (45%) → `skyHorizon`, garis tepi `hairline`.
- Baris atas: "Berikutnya" 13/600 `sec` + "Dzuhur 11:42" 15/800; kanan pill `primarySoft` "1 j 7 m lagi" (diperbarui tiap menit).
- `Lintasan` 5 titik berjarak sama (bukan proporsional jam; jarak sama lebih mudah dibaca). Titik "sekarang" (12, `ink`, halo `surf` 3) diletakkan **proporsional di antara dua salat** yang mengapitnya: `(now − prev) / (next − prev)`.
- Label di bawah tiap titik: nama 11/700 `ink` + jam 11/600 `sec`; salat berikutnya: nama `ink` 800, jam `goldText` 800. (`tertiary` tidak dipakai untuk teks; kontrasnya < 4.5.)
- Setelah Isya: titik sekarang di ujung kanan, salat berikutnya "Subuh besok" (jam dari data besok bila ada; kalau belum ada, tulis "Subuh" tanpa jam).
- Ketuk → `PrayerScreen`.
- **Status lain:**
  - Kota belum diatur: satu baris "Atur kota untuk jadwal salat" + chevron → pengaturan kota.
  - Luring tanpa cache: "Jadwal salat belum dimuat · Coba lagi". Tidak menampilkan jam contoh.
  - Memuat: kerangka (skeleton) setinggi kartu, tanpa spinner.

## 4. NextStepCard

Isi ditentukan `NextStepEngine` (`docs/DATA.md §2`). Satu kartu hijau, radius 28, padding 18, pola bintang 7% (dihilangkan di kontras tinggi).

| Bagian | Isi |
| --- | --- |
| Eyebrow | "LANGKAH BERIKUTNYA" `goldLine` + pill kanan (durasi/jumlah/halaman dari `NextStep.badge`) |
| Judul | `NextStep.title` EB Garamond 31 `onHero`, maks 2 baris |
| Subjudul | `NextStep.subtitle` 14 `onHeroSec`, maks 2 baris |
| Progres | Hanya untuk sesi: `Lintasan` 5 langkah dengan label Ulang · Materi · Temukan · Tirukan · Selesai (sama dengan `SessionStep.shortLabel`; keputusan 2026-10-02) |
| CTA | Tombol `goldButton` tinggi 52, ikon putar + `NextStep.cta` |
| Pilihan lain | Maks 2 baris di dalam kartu (latar putih 7%, pemisah putih 10%): ikon 32×38 + eyebrow + teks 14/700 + chevron. Tinggi baris ≥ 56. |

- Ikon pilihan "Baca" = mihrab kecil berisi nama surah Arab (dari `SuraNamesRepository`). Saat surah itu sedang diputar, ikonnya menjadi ikon equalizer dan eyebrow "DIPUTAR"; ketuk membuka pemutar penuh, **bukan** tombol jeda kedua.
- Ketuk CTA → `NextStep.action`; ketuk pilihan lain → aksi pilihan tsb. Setelah kembali, snapshot dihitung ulang.
- Teks di pilihan lain boleh dielipsis (satu baris, `Expanded`) karena isinya data; eyebrow tidak boleh terpotong.

## 5. TodayCard

- Kartu `surf` radius 24, padding 16.
- Kiri: `ConcentricRings` 108 (luar → dalam): Baca (`primaryText`), Sesi (`gold`), Murajaah (`teal`). Track `surf2`.
- Kanan: tiga baris legenda (titik 10 + label 14/700 + angka 800 tabular, satuan 12/600 `sec`).
  - Baris Sesi disembunyikan bila tidak ada materi terbit (`sessionAvailable == false`).
  - Baris Murajaah disembunyikan bila pengguna belum pernah menghafal; cincinnya ikut hilang.
- **Kalimat bantu** (kotak `bg` radius 14) — hanya satu, dari `TodaySummary.hint` (`docs/DATA.md §3`):
  - Semua nol dan istiqamah 0: "Hari pertama. Lima menit membaca sudah cukup untuk mulai."
  - Semua target tercapai: "Semua target hari ini tercapai. Alhamdulillah."
  - Selain itu: tidak ada kalimat (kartu lebih pendek).
- Bawah (dipisah garis): ikon api `goldText` + "N hari" 14/800, lalu 7 titik pekan (S S R K J S M) — sudah tercapai `gold`, hari ini lingkaran putus-putus `gold`, belum `surf2`. Huruf hari 10.5/700 `sec`, hari ini `ink`.
- Ketuk kartu → `ProgressScreen`.

## Status yang wajib ada golden-nya

`baru` (hari pertama), `sesi berjalan`, `murajaah jatuh tempo + titik mulai hafalan`, `semua selesai`, `murottal diputar`, `luring tanpa jadwal salat`, `kota belum diatur`. Masing-masing terang + gelap, ditambah `baru` di sepia, kontras tinggi, dan teks 2.0.

## Selesai jika

- Golden 390×844 cocok dengan acuan (selisih hanya data nyata), terang, gelap, sepia, kontras tinggi, teks 2.0.
- Tidak ada lagi tiga tombol "Lanjutkan" di satu layar. Paling banyak satu CTA penuh.
- Tes `NextStepEngine` & `TodaySummary` lulus (`docs/DATA.md §6`).
- Ganti tanggal saat aplikasi terbuka (melewati 00:00) → snapshot dihitung ulang tanpa restart.
- `flutter analyze` bersih, semua tes lama lulus.
