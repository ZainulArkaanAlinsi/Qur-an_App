# Liquid Glass MyQuran: spesifikasi v4

Dokumen ini jadi acuan tunggal untuk efek kaca di MyQuran. Isinya: di mana kaca boleh dipakai, lapisan penyusunnya, angka tokennya, gerakannya, aturan warna untuk terang, gelap, sepia, dan kontras tinggi, serta batas kinerjanya. Semua angka di sini bisa diperiksa lewat `tool/glass_audit.sh`, tes kontras, golden test, dan tes kinerja. Jadi "sudah cukup liquid atau belum" tidak ditentukan dari perasaan.

Dokumen ini melanjutkan DESIGN v2/v3 dan tidak menggantinya. Kalau ada yang bertentangan soal kaca, dokumen ini yang dipakai.

## 1. Empat prinsip

1. **Kaca hanya untuk bagian yang mengambang.** Tab bar, nav pembaca, mini player, tombol bulat mengambang, dan kepala sheet boleh berkaca. Isi yang dibaca tidak berkaca: ayat, terjemahan, daftar surah, kartu materi, dan daftar penanda.
2. **Ayat selalu di atas permukaan padat.** Teks Arab dan terjemahan tidak pernah diletakkan di atas blur. Warnanya tidak diubah selain oleh palet tajwid.
3. **Kesan liquid datang dari cahaya dan gerak.** Yang membuat kaca terasa hidup adalah tepi yang menangkap cahaya, kilau melengkung, warna di belakang yang ikut terbawa, dan indikator yang mengalir. Membuatnya makin bening justru merusak keterbacaan.
4. **Ringan dulu, baru cantik.** Kalau HP tidak kuat, tampilan kaca turun ke tingkat ringan atau padat secara otomatis. Tata letak tidak berubah.

## 2. Boleh dan tidak boleh

| Tempat | Kaca? | Catatan |
| --- | --- | --- |
| Tab bar mengambang | Ya (utama) | Tanpa scrim padat di belakangnya. Isi halaman harus terlihat lewat kaca. |
| Nav atas pembaca | Ya | Sembunyi saat gulir ke bawah, muncul saat gulir ke atas. |
| Bar bawah mushaf / kontrol pembaca | Ya | Maksimal 2 kaca terlihat bersamaan di pembaca. |
| Mini player murottal | Ya | Ikut token, tidak lagi memakai hijau atau putih mentah. |
| Tombol bulat mengambang (kembali, Aa, putar di atas hero) | Ya, versi kecil | Diameter 40–44. |
| Kepala bottom sheet (grabber + judul) | Ya | Isi sheet tetap padat (`surf`). |
| Dialog, menu popup | Opsional, tingkat ringan | Hanya kalau tidak menambah kaca ke-4 di layar. |
| Kartu ayat, daftar surah, daftar penanda, kartu materi, kuis | **Tidak** | Pakai permukaan tonal `surf`/`surf2` + `cardShadows`. |
| Apa pun di dalam `ListView`/`SliverList` builder | **Tidak pernah** | Setiap item akan menjadi satu blur, dan itu berat saat digulir. |

## 3. Anatomi: enam lapis

Urutan dari bawah ke atas. Semuanya ada di satu komponen, `LiquidGlass` (`lib/app/glass/liquid_glass.dart`). Layar tidak boleh menyusun lapisan ini sendiri.

| # | Lapis | Isi | Kenapa |
| --- | --- | --- | --- |
| L0 | Bayangan | `tokens.floatShadows`, di luar klip | Bayangan di dalam `ClipRRect` ikut terpotong. Itu yang terjadi sekarang di `GlassSurface` bawaan. |
| L1 | Backdrop | `BackdropFilter.grouped` dengan `ImageFilter.compose(outer: vibrancy, inner: blur)` | Blur membuat isi di belakang jadi lembut. Vibrancy menjaga warnanya tetap hidup sekaligus menekan rentang terang-gelapnya, supaya teks di atas kaca tetap terbaca. |
| L2 | Tint | `glassTint` dengan alfa per palet (§4) | Memberi warna dasar kaca. Alfanya rendah karena kontras sudah dijaga L1. |
| L3 | Kilau | Gradien linear atas → bawah, putih ke transparan | Memberi kesan permukaan melengkung. |
| L4 | Tepi | Garis 1 px bergradien: terang di kiri-atas, redup di kanan-bawah (`CustomPainter`, di dalam `RepaintBoundary`) | Tepi yang menangkap cahaya adalah ciri utama liquid glass. |
| L5 | Sorot dalam | Garis 1 px di tepi atas bagian dalam, putih tipis | Membuat kaca terasa tebal, tidak seperti stiker. |

### Rumus vibrancy (L1)

Warna backdrop dijenuhkan dulu (saturasi `s`), lalu rentang terangnya ditekan ke arah warna tema: mendekati terang untuk tema terang, mendekati gelap untuk tema gelap. `keep` adalah seberapa banyak backdrop asli yang tersisa.

```dart
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';

/// Matriks 4x5 untuk ColorFilter.matrix. Kolom translasi dalam skala 0..255.
List<double> glassVibrancyMatrix({
  required double saturation, // s
  required double keep,       // k
  required Color toward,      // warna tujuan penekanan
}) {
  const lr = .2126, lg = .7152, lb = .0722; // bobot luminans Rec.709
  final s = saturation;
  final sat = [
    [lr * (1 - s) + s, lg * (1 - s), lb * (1 - s)],
    [lr * (1 - s), lg * (1 - s) + s, lb * (1 - s)],
    [lr * (1 - s), lg * (1 - s), lb * (1 - s) + s],
  ];
  final t = [toward.r * 255, toward.g * 255, toward.b * 255];
  return [
    for (var i = 0; i < 3; i++) ...[
      for (var j = 0; j < 3; j++) keep * sat[i][j],
      0,
      (1 - keep) * t[i],
    ],
    0, 0, 0, 1, 0,
  ];
}

ui.ImageFilter glassFilter(GlassSpec spec) => ui.ImageFilter.compose(
  outer: ui.ColorFilter.matrix(glassVibrancyMatrix(
    saturation: spec.saturation,
    keep: spec.keep,
    toward: spec.toward,
  )),
  inner: ui.ImageFilter.blur(
    sigmaX: spec.sigma,
    sigmaY: spec.sigma,
    tileMode: TileMode.mirror,
  ),
);
```

`ColorFilter` di `dart:ui` mengimplementasikan `ImageFilter`, jadi bisa dipakai di `compose`. Tetap cek dengan golden test di SDK yang terpasang. Kalau hasilnya tidak sesuai (misalnya skala offset berbeda), perbaiki di satu fungsi ini saja.

## 4. Token

Tambahkan sebagai `GlassTokens extends ThemeExtension<GlassTokens>` (sudah dengan `lerp`) atau sebagai field baru di `SacredTokens`. Token lama `glass`/`glassBorder` diganti.

### Angka tingkat **penuh**

| Token | Terang | Sepia | Gelap | Kontras tinggi |
| --- | --- | --- | --- | --- |
| `sigma` bar / tombol kecil | 18 / 12 | 18 / 12 | 18 / 12 | 0 (padat) |
| `sigma` kepala sheet | 22 | 22 | 22 | 0 |
| `saturation` | 1.7 | 1.5 | 1.7 | — |
| `keep` | .20 | .20 | .30 | — |
| `toward` | `#FFFFFF` | `#F9F2E2` | `#000000` | — |
| `glassTint` | `surf` @ 38% | `surf` @ 42% | `surf` @ 42% | `surf` @ 100% |
| `rimStart` → `rimEnd` | putih 70% → 15% | putih 60% → 12% | putih 24% → 5% | `outline` 100%, 1.5 px |
| `sheen` (atas → 55%) | putih 18% → 0 | putih 14% → 0 | putih 7% → 0 | tidak ada |
| `innerHighlight` | putih 50% | putih 40% | putih 18% | tidak ada |
| bayangan | `floatShadows` | `floatShadows` | `floatShadows` | `floatShadows` |

### Tingkat kualitas

| Tingkat | Kapan | Yang berubah |
| --- | --- | --- |
| **penuh** | Bawaan | Semua lapis, angka di atas |
| **ringan** | Pengawas frame menurunkan, "Kurangi gerak" aktif, atau dipilih pengguna | `sigma` 10 (tombol kecil 8), alfa tint +10 poin, animasi kilau mati. Tepi dan vibrancy tetap. |
| **padat** | Palet atau sistem kontras tinggi, "Efek kaca: Mati", atau pengawas menurunkan lagi | `BackdropFilter.grouped(enabled: false)` supaya pohon layer tetap stabil, tint 100% `surf`, tepi tetap ada. Bentuk dan ukuran sama persis. |

Pilihan pengguna ada di **Saya → Tampilan → Efek kaca**: Otomatis (bawaan) / Penuh / Ringan / Mati. Flutter tidak menyediakan sinyal "Kurangi transparansi" dari iOS, jadi pilihan ini yang menggantikannya.

## 5. Warna dan keterbacaan

### Teks di atas kaca

Ukur **kasus terburuk**: kaca di atas latar polos putih, hitam, hijau hero `#064E3B`, emas `#C9A13B`, merah `#B0533A`, biru `#2F5FE0`, teal langit `#0B3F48`, `bg` terang, dan `bg` gelap. Blur hanya meratakan warna, jadi latar polos adalah kasus terburuk. Targetnya:

| Teks | Minimum |
| --- | --- |
| `ink` (label utama, nama surah) | 7 : 1 |
| `sec` (keterangan, label tab tidak aktif) | 4.5 : 1 |
| `primaryText` (tab aktif, tautan) | 4.5 : 1 |

Hasil perhitungan (saturasi 1.7, sepia 1.5; model latar polos):

| | Alfa tint | Backdrop terlihat | ink terburuk | sec terburuk | primaryText terburuk |
| --- | --- | --- | --- | --- | --- |
| **Sekarang**, terang (tint 76%, tanpa vibrancy) | 76% | 24% | 9.15 | **3.32 ✗** | 5.02 |
| **Sekarang**, gelap | 76% | 24% | 6.56 ✗ | **3.07 ✗** | 4.88 |
| **Sekarang**, sepia | 76% | 24% | 6.39 ✗ | **3.25 ✗** | 4.80 |
| **v4 penuh**, terang (k .20) | 38% | 12.4% | 12.6 | 4.57 | 6.92 |
| **v4 penuh**, sepia (k .20) | 42% | 11.6% | 8.94 | 4.54 | 6.72 |
| **v4 penuh**, gelap (k .30) | 42% | 17.4% | 9.98 | 4.67 | 7.43 |
| **v4 ringan**, terang / sepia / gelap | 48 / 52 / 52% | 10–14% | ≥ 9.3 | ≥ 4.77 | ≥ 7.05 |

Dengan kata lain, kaca sekarang lebih pekat tapi teks keterangannya malah kurang terbaca. Kaca v4 lebih bening di tint dan warna di belakangnya lebih hidup, tapi teksnya lebih jelas. Angka ini wajib dikunci di `test/glass_contrast_test.dart` (§8).

### Ayat dan tajwid

- Teks Arab: `ink` di atas `surf`. Sekarang 16.3 (terang), 15.05 (gelap), 11.38 (sepia), jadi aman. Pertahankan minimal 7 : 1 di semua palet dan di latar ayat aktif.
- Tema gelap: latar tidak hitam murni (`#08110E`) dan tinta tidak putih murni (`#ECEFEA`) supaya huruf tidak berpendar. Jangan diubah ke hitam/putih penuh kecuali di palet kontras tinggi.
- Tidak boleh ada `Shadow` teks, glow, gradien, atau `ShaderMask` di teks Arab.
- **Warna tajwid minimal 4.5 : 1 di setiap permukaan ayat**: `surf`, ayat aktif (`primarySoft`), ayat bertanda (`goldSoft`), dan `surf`/`bg` sepia, di terang dan gelap. Hasil cek sekarang:

| Permukaan | Warna terlemah | Rasio |
| --- | --- | --- |
| terang `surf` | abu hamzah wasl / lam syamsiyah / huruf tidak dibaca `#7A7A7A` | 4.10 |
| terang ayat aktif `primarySoft` | abu yang sama | **3.54** |
| terang `goldSoft` | abu yang sama | **3.77** |
| sepia `bg` | abu yang sama | **3.65** |
| gelap ayat aktif | mad wajib `#7F8CFF` | 4.45 |
| gelap `goldSoft` | mad wajib | 4.41 |

  Perbaiki warna palet (bukan hukumnya) sampai semua baris ≥ 4.5, lalu perluas `test/tajweed_widget_test.dart` supaya memeriksa semua permukaan di atas, bukan hanya kartu terang/gelap. Abu-abu boleh tetap terlihat lebih redup daripada `ink` karena memang huruf yang tidak dibaca, tapi tidak boleh di bawah 4.5.
- Latar ayat aktif memakai `AnimatedContainer` warna saja. Tidak boleh memakai blur atau kaca.

## 6. Gerak

| Elemen | Perilaku | Angka |
| --- | --- | --- |
| Indikator tab ("lensa") | Satu kapsul yang **meluncur** di antara tab, tidak berganti-ganti `Container` | Pegas: massa 1, kekakuan 420, redaman 32 (sekitar 350 ms, lewatan ≤ 4%) |
| Regangan lensa | Saat meluncur, kapsul memanjang searah gerak lalu kembali | `scaleX` = 1 + 0.12 × kecepatan ternormalisasi, maks 1.12. `scaleY` = 1 − setengahnya. |
| Tekan tab | Lensa mengecil lalu memantul | 0.94 dalam 90 ms, lepas dengan pegas yang sama |
| Geser di tab bar | Lensa mengikuti jari, lalu menempel ke tab terdekat saat dilepas | Haptik `selectionClick` saat pindah tab |
| Kilau (L3) | Bergeser sedikit mengikuti posisi lensa | Pergeseran maksimal 8% lebar. Hanya berubah saat ada interaksi, bukan tiap frame. |
| Nav pembaca | Sembunyi saat gulir turun > 24 px, muncul saat gulir naik | 220 ms, `Cubic(0.22, 1, 0.36, 1)` (kurva v3) |
| Mini player | Muncul dari bawah, menempel di atas tab bar | 280 ms, kurva yang sama |
| Sheet | Kepala kaca ikut ditarik, grabber meregang sedikit saat ditarik | Mengikuti `DraggableScrollableSheet` |
| **Kurangi gerak** | Tidak ada regangan, pantulan, atau kilau bergerak. Pindah tab = crossfade 150 ms. | `MediaQuery.disableAnimationsOf(context)` |

Di atas kaca, jangan pakai ripple Material (`InkWell` bawaan). Pakai `splashFactory: NoSplash.splashFactory` atau `GestureDetector` + efek tekan di atas. Ripple bundar di atas kaca adalah salah satu sebab tampilan sekarang terasa kaku.

## 7. Kinerja

### Aturan

1. Semua blur memakai `BackdropFilter.grouped` di bawah satu `BackdropGroup` per rute (`AppShell`, `ReaderScreen`, dan rute lain yang punya kaca).
2. Maksimal **3 kaca terlihat** bersamaan di layar mana pun. Pembaca maksimal 2.
3. Kaca selalu terbatas oleh `ClipRRect` (atau `ClipRSuperellipse` bila tersedia di SDK). Tidak ada blur layar penuh.
4. Tidak ada `Opacity`, `ShaderMask`, atau `ColorFiltered` yang membungkus kaca, karena ketiganya memaksa `saveLayer`. Untuk memudarkan, pakai `FadeTransition` atau alfa warna.
5. Lapis tepi (L4) memakai `CustomPainter` dengan `shouldRepaint` yang ketat di dalam `RepaintBoundary`. Lensa tab juga dibungkus `RepaintBoundary` sendiri supaya animasinya tidak menggambar ulang ikon.
6. Animasi memakai `AnimationController`/`SpringSimulation` + `AnimatedBuilder` dengan `child` yang di-cache, bukan `setState` di widget besar.
7. Tidak memakai paket kaca pihak ketiga secara bawaan (lihat §9).

### Pengawas frame (turun tingkat otomatis)

- Daftarkan `SchedulerBinding.instance.addTimingsCallback` hanya saat mode "Otomatis" dan ada kaca terlihat.
- Jendela 120 frame. Anggarannya `1000 / refreshRate` ms, dengan refresh rate dari `View.of(context).display.refreshRate`.
- Kalau lebih dari 8% frame dalam **dua jendela berturut-turut** melewati anggaran (`totalSpan`), turunkan tingkat: penuh → ringan → padat. Simpan ke `SharedPreferences` (`glass_tier_auto`).
- Tingkat tidak dinaikkan lagi di sesi yang sama. Setelah versi aplikasi berubah, reset satu kali.
- Callback cukup menghitung angka, tanpa `setState` per frame dan tanpa log di rilis.

### Anggaran (mode profile, HP asli, bukan emulator)

Skenario A: gulir pembaca Al-Baqarah selama 15 detik dengan tajwid aktif. Skenario B: ganti tab 20 kali. Skenario C: buka/tutup sheet murottal 10 kali.

| Ukuran | 60 Hz | 90/120 Hz |
| --- | --- | --- |
| Build p90 | ≤ 6 ms | ≤ 4 ms |
| Raster p90 | ≤ 10 ms | ≤ 7 ms |
| Frame terlewat | ≤ 1% | ≤ 2% |
| Selisih raster p90 tingkat penuh vs padat | ≤ 2 ms | ≤ 1.5 ms |
| Kenaikan memori setelah 3 menit | ≤ 15 MB | ≤ 15 MB |

Ukur dengan `integration_test` + `IntegrationTestWidgetsFlutterBinding.watchPerformance` dan catat ringkasannya (`90th_percentile_frame_rasterizer_time_millis`, `missed_frame_rasterizer_budget_count`, dan seterusnya) ke `docs/design/v4-liquid-glass/HASIL_KINERJA.md` beserta model HP dan refresh rate-nya. Uji di HP paling lemah yang tersedia. Android lama tanpa Vulkan adalah kasus terberat, dan di sana pengawas harus terbukti menurunkan tingkat.

## 8. Pengujian wajib

1. `bash tool/glass_audit.sh` harus berakhir dengan **0 GAGAL**.
2. `test/glass_contrast_test.dart`: rumus sRGB → luminans relatif WCAG, komposit `vibrancy(latar) → tint`, untuk semua palet × tingkat × latar di §5. Ambang di §5.
3. `test/tajweed_widget_test.dart` diperluas ke semua permukaan ayat di §5.
4. Golden: `FloatingTabBar`, nav pembaca, mini player, dan kepala sheet × {terang, gelap, sepia, kontras tinggi} × {penuh, padat}, di atas latar uji bergaris warna (hero hijau + teks + gambar), supaya efek kaca terlihat di golden. Bila perlu, pakai `testWidgets` dengan `debugDisableShadows = false`.
5. `integration_test/glass_perf_test.dart`: skenario A, B, C di §7.
6. `flutter analyze` bersih, dan seluruh tes lama tetap lulus (termasuk `curriculum_test.dart` dan tes tajwid).

## 9. Lisensi dan aset

- Implementasi sendiri dengan API Flutter. Tidak perlu paket baru.
- Jangan memakai aset Apple (SF Symbols, font SF, gambar material iOS) dan jangan menyalin kode dari proyek tanpa lisensi. Yang diikuti adalah konsep visualnya, bukan asetnya. Ikon tetap `SacredIcons`.
- `liquid_glass_widgets` (MIT, butuh Flutter ≥ 3.41) dan `liquid_glass_renderer` (MIT, eksperimental, khusus Impeller, oleh pembuatnya disebut belum siap produksi) **tidak dipakai secara bawaan**. Kalau suatu saat mau dicoba untuk lensa tab saja, lakukan di branch terpisah dengan syarat:
  1. Lolos anggaran §7 di HP terlemah.
  2. Berkas lisensi MIT dan `THIRD_PARTY_NOTICES` didaftarkan ke `LicenseRegistry`.
  3. Tingkat ringan/padat tetap memakai `LiquidGlass` sendiri.
  4. Pemilik menyetujui.
