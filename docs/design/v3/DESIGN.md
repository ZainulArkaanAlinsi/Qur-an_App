# DESIGN v3 — Logo, splash, onboarding, materi nun sukun

Tambahan untuk `docs/design/v2/DESIGN.md`. Token, komponen, dan aturan v2 tetap berlaku. Dokumen ini hanya berisi hal baru.

Gambar acuan ada di `docs/design/v3/screens/*.png` dan HTML-nya di `docs/design/v3/html/`.

## 1. Nama & identitas

- **Nama tampilan aplikasi:** `MyQuran`. Build debug: `MyQuran Debug`.
- **Judul di Play Store:** jangan cuma "MyQuran", karena sudah ada banyak aplikasi dengan nama itu. Contoh judul (maksimal 30 karakter): `MyQuran: Baca, Tajwid, Hafalan`.
- **Package id:** tidak diubah di tahap ini. Mengganti package id berarti aplikasi baru di Play Store, jadi harus ada izin pemilik dulu.

## 2. Logo — dipakai utuh, tidak digambar ulang

| Berkas | Isi | Dipakai di |
| --- | --- | --- |
| `assets/brand/logo_utama.png` | Logo utama: tulisan Arab + buku + "MyQuran", latar transparan, tulisan Arab dirapikan dengan Amiri | Splash animasi (terang), onboarding hal. 1, halaman Tentang, grafis Play Store |
| `assets/brand/logo_utama_gelap.png` | Sama, tetapi tulisan "MyQuran" berwarna krem `#F1E9D6` | Semua tempat di atas, versi mode gelap |
| `assets/brand/logo_utama_asli.png` / `_gelap` | Versi asli dengan tulisan Arab bawaan gambar | Arsip saja, **jangan dipakai** (bentuk hurufnya kurang tepat) |
| `assets/brand/logo_sekunder.png` | Ikon kotak-bulat hijau tanpa tulisan | Header kecil, kartu bagikan, halaman "Sumber & Lisensi", tempat santai |
| `assets/icons/icon.png` | Ikon penuh 1024, tanpa transparansi | iOS, Play Store (512), web |
| `assets/icons/icon_foreground.png` | Buku + tunas di latar transparan, sudah dalam zona aman 66/108 | Android adaptive icon (latar `#0D5843`) |
| `assets/icons/icon_monochrome.png` | Siluet putih | Android 13+ themed icon, ikon notifikasi kecil |
| `assets/icons/splash_icon.png` | Logo sekunder 600 px di kanvas 768 | Splash native Android ≤ 11 & iOS |
| `assets/icons/splash_android12.png` | Buku + tunas di kanvas 1152, masuk lingkaran 768 | Splash native Android 12+ |

Aturan:

- **Logo selalu utuh.** Jangan dipotong, diregangkan, diputar, diberi efek, atau diganti warnanya. Jangan menggambar ulang logo dengan widget. Pakai `Image.asset`.
- **Jarak aman** di sekeliling logo sama dengan tinggi huruf "M".
- **Ukuran minimum:** logo utama 120 dp lebar, ikon 24 dp.
- **Mode terang/gelap:** pilih berkas lewat `SacredTokens.isDark`, bukan lewat `ColorFilter`.
- **Muat lebih awal:** panggil `precacheImage` untuk logo utama sebelum splash animasi mulai, supaya tidak berkedip.

Token baru (tambahkan ke `SacredTokens`, grup `brand`; bukan untuk warna teks UI):

| Token | Nilai |
| --- | --- |
| `brandIcon` | `#0D5843` |
| `brandCover` | `#265A43` |
| `brandGold` | `#BD9B62` |

## 3. Ikon aplikasi — `pubspec.yaml`

```yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  remove_alpha_ios: true
  image_path: "assets/icons/icon.png"
  min_sdk_android: 21
  adaptive_icon_background: "#0D5843"
  adaptive_icon_foreground: "assets/icons/icon_foreground.png"
  adaptive_icon_monochrome: "assets/icons/icon_monochrome.png"
  web:
    generate: true
    image_path: "assets/icons/icon.png"
    background_color: "#0D5843"
    theme_color: "#0D5843"
```

Jalankan `dart run flutter_launcher_icons`.

## 4. Splash

### 4a. Splash bawaan sistem (`flutter_native_splash`)

Tampil sebentar sebelum Flutter siap. Isinya hanya logo sekunder di atas warna latar aplikasi.

```yaml
flutter_native_splash:
  color: "#F4F1EA"
  image: assets/icons/splash_icon.png
  color_dark: "#08110E"
  image_dark: assets/icons/splash_icon.png
  android_12:
    image: assets/icons/splash_android12.png
    icon_background_color: "#0D5843"
    color: "#F4F1EA"
    image_dark: assets/icons/splash_android12.png
    icon_background_color_dark: "#0D5843"
    color_dark: "#08110E"
  android: true
  ios: true
  web: true
```

- Hapus baris `branding` lama, karena berkas `branding.png` tidak ada.
- Jalankan `dart run flutter_native_splash:create`.

### 4b. Splash animasi (layar Flutter pertama)

Acuan: `screens/V3-Splash.png` dan `V3-Splash-Gelap.png`.

**Tata letak (390×844):**

- **Latar:** `bg`, ditambah pola geometri emas dengan opasitas 6%, memudar ke tepi.
- **Glow:** diameter 380, pusat di y=372.
- **Bintang 8 sudut:** outline 300 dp, opasitas 35%, warna `gold`.
- **Logo utama:** lebar 250 dp, pusat di y=372.
- **Tagline:** `BACA · BELAJAR · HAFAL`, 12/800, tracking 0.14em, warna `goldText`, 54 dp dari bawah.

**Lini waktu.** Kurva `Cubic(0.22, 1, 0.36, 1)`, disebut **EASE**.

| Waktu | Elemen | Gerak |
| --- | --- | --- |
| 0–260 ms | Logo sekunder 160 dp (menyambung dari splash native) | opasitas 1→0, skala 1→0.92 |
| 0–900 ms | Glow | skala 0.55→1, opasitas 0→1 |
| 0–1100 ms | Bintang | rotasi −30°→0°, skala 0.9→1, opasitas 0→0.35 |
| 120–940 ms | Logo utama | skala 0.86→1, geser Y 10→0, opasitas 0→1 |
| 715–1300 ms | Tagline | opasitas 0→1, geser Y 6→0 |

**Keluar dari splash:**

- Tunggu inisialisasi aplikasi selesai.
- Durasi splash **minimal 1400 ms**, **maksimal 2500 ms**. Kalau inisialisasi belum selesai di batas maksimal, lanjut saja; data dimuat di layar berikutnya.
- Transisi keluar: *fade-through* 320 ms, ke Onboarding untuk pengguna baru atau ke Beranda.
- **Kurangi gerak** (`MediaQuery.disableAnimationsOf`): tanpa skala dan rotasi, hanya fade 200 ms.
- Semua animasi pakai `AnimationController` + `CurvedAnimation` bawaan Flutter. Tanpa Lottie, Rive, atau video.

## 5. Onboarding

Acuan:

- **Statis:** `screens/V3-Onb1..4.png` dan `-Gelap`.
- **Gerak:** `screens/gerak_1_ke_2_50.png` (geser 50%) dan `gerak_2_ke_3_30.png` (geser 30%).
- **Prototipe yang bisa digeser:** kanvas desain, halaman "Logo, splash & onboarding". Tekan Play lalu geser.

### 5a. Kapan tampil

- Hanya pada pembukaan pertama. Simpan `onboarding.selesai.v1 = true` di `SharedPreferences` setelah tombol **Mulai** ditekan.
- **Lewati** di halaman 1–3 melompat ke **halaman 4**, bukan langsung keluar, karena pilihan titik mulai dibutuhkan.
- Tombol kembali Android di halaman 2–4 mundur satu halaman. Di halaman 1, tombol ini menutup aplikasi.

### 5b. Isi halaman

Teks ditulis persis seperti ini.

| # | Judul (EB Garamond 500, 33/38) | Subjudul (15/23, `sec`) | Ilustrasi |
| --- | --- | --- | --- |
| 1 | Selamat datang di *MyQuran* ("MyQuran" miring) | Membaca, belajar, dan menghafal Al-Qur'an dalam satu aplikasi yang tenang. Tetap bisa dibuka tanpa internet. | Logo utama 236 dp di atas glow + bintang 316 dp |
| 2 | Baca seperti mushaf aslinya | Pilih 1 halaman, 2 halaman, atau kartu per ayat dengan terjemahan. Warna tajwid menempel langsung di hurufnya. | 3 kartu (lihat bawah) + chip "1 halaman · 2 halaman · Kartu" |
| 3 | Belajar dari nol, lalu menghafal | Jalur bertahap dari mengenal huruf sampai tajwid, lalu hafalan dengan ziyadah dan murajaah yang terjadwal. | Kartu jalur belajar + kartu hafalan |
| 4 | Mulai dari mana? (36/40, rata kiri, eyebrow "LANGKAH TERAKHIR") | Supaya materi pertama pas dengan kemampuanmu sekarang. | 3 kartu pilihan (radio) |

**Detail ilustrasi:**

- **Halaman 2:**
  - Kartu tengah menampilkan **QS 2:5 dari dataset Tanzil** dan terjemahan dari dataset yang sudah dibundel, verbatim. Warna tajwid diambil dari sumber tajwid yang aktif di aplikasi; kalau belum ada yang aktif, tampilkan tanpa warna. Jangan menulis warna secara manual.
  - Kartu samping berupa garis abstrak, bukan teks Arab palsu.
  - Kartu kiri diputar −9°, kartu kanan +8°.
- **Halaman 3:**
  - Judul tahap diambil dari `curriculum.json`: Huruf hijaiyah, Harakat, Tanwin, Nun sukun & tanwin.
  - Chip hukum memakai warna tajwid dari palet `gading` / `malam`.
  - Kartu hafalan adalah **ilustrasi dengan nilai contoh tetap**. Bungkus dengan `ExcludeSemantics` dan beri label "Ilustrasi".
- **Halaman 4:** pilihan yang tersedia.

| Pilihan | Keterangan | Nilai `belajar.titikMulai` | Setelah Mulai |
| --- | --- | --- | --- |
| Belum bisa membaca huruf Arab | Mulai dari tahap 1: huruf hijaiyah | `nol` | Buka tab Belajar di tahap 1 |
| Sudah bisa, ingin lancar tajwid | Mulai dari tahap 10: nun sukun & tanwin | `tajwid` | Buka tab Belajar, gulir ke tahap 10. Kalau tahap itu masih draf di rilis, tampilkan kartu "Materi sedang ditinjau" dan arahkan "Lanjutkan" ke tahap terbit pertama yang belum selesai |
| Ingin fokus menghafal | Buka Hafalan dengan target harian | `hafalan` | Buka tab Hafalan |

- Pilihan awal: nomor 2.
- Bisa diubah lagi di **Saya → Belajar**.

**Kerangka tetap semua halaman:**

- **Lewati:** teks 15/700 `priText`, kanan atas (top 50, target 44 dp). Disembunyikan di halaman 4.
- **Titik halaman:** di y=716, tinggi 7. Titik aktif lebar 22, titik lain 7, jarak 7.
- **CTA:** pill 56 dp, 20 dp dari tepi, 34 dp dari bawah, warna `cta` / `ctaInk`. Label "Lanjut", di halaman 4 "Mulai".

**Latar tiap halaman:** glow radial lembut. Terang:

1. Emas `rgba(233,196,106,.34)`
2. Mint `rgba(169,214,190,.42)`
3. Pasir `rgba(240,214,160,.40)`
4. Mint `.34`

Gelap memakai warna yang sama dengan opasitas 0.10–0.13. Pola geometri emas 7% hanya di 520 dp teratas.

### 5c. Gerak geser (inti permintaan)

Implementasi: `PageView` + `PageController`. Lapisan dibaca dari `controller.page` lewat `AnimatedBuilder`. Tanpa paket pihak ketiga.

Untuk halaman `k`, hitung posisinya:

- `x = (k − page) × lebarLayar`
- `t = min(1, |x| / lebarLayar)`

| Lapisan | Transform (di dalam halaman yang ikut bergeser `x`) | Opasitas |
| --- | --- | --- |
| Ilustrasi | geser X `−0.45·x` (bergerak lebih lambat, terasa ada kedalaman), skala `1 − 0.10·t` | `1 − 0.9·t` |
| Judul | geser X `+0.10·x` | `1 − 1.7·t` |
| Subjudul | geser X `+0.22·x` (bergerak paling cepat, muncul bertingkat) | `1 − 2.0·t` |
| Glow latar (tidak ikut bergeser) | — | `1 − t` |
| Titik ke-k | lebar `7 + 15·(1−t)` | `0.22 + 0.78·(1−t)` |
| Label CTA | `AnimatedSwitcher` 200 ms saat halaman terdekat berganti | — |

Semua nilai dijepit (*clamp*) di 0..1.

**Fisika & tombol:**

- **Fisika:** `PageScrollPhysics(parent: BouncingScrollPhysics())` di kedua platform, supaya terasa seperti iPhone.
- **Pindah halaman saat dilepas:** kalau geseran lebih dari 20% lebar layar, atau kecepatan lebih dari 450 dp/s.
- **Tombol Lanjut, titik, dan Lewati:** `animateToPage` 560 ms, kurva **EASE**.
- **Haptik:**
  - `HapticFeedback.selectionClick()` setiap halaman berhenti.
  - `lightImpact()` saat memilih opsi di halaman 4.
- **Kurangi gerak:** tanpa parallax dan skala; hanya fade silang antarhalaman.

### 5d. Aksesibilitas

- Setiap halaman diberi `Semantics(label: 'Halaman 2 dari 4')`.
- Titik halaman adalah tombol dengan label.
- Opsi di halaman 4 memakai `Semantics(selected: …, inMutuallyExclusiveGroup: true)`.
- **Text scale 2.0:**
  - Ilustrasi mengecil (`FittedBox`, maksimal 45% tinggi layar).
  - Area teks bisa di-scroll.
  - Tidak ada overflow. Label CTA dan Lewati tidak boleh terpotong.
- **Kontras:** subjudul `sec` di atas glow harus ≥ 4.5:1 di kedua tema. Hasil cek mockup ada di `LISENSI_ASET.md` §5.

## 6. Materi Belajar — tahap 6–16 (tajwid lengkap)

Isinya ada di `assets/learn/curriculum.json`, tahap 6–16, semuanya berstatus **draft**:

- 99 halaman penjelasan;
- 214 contoh ayat;
- 118 soal.

Naskah yang mudah dibaca untuk peninjau ada di `docs/content/tajwid/NN-*.md`, dengan `README.md` sebagai daftar isinya.

Acuan layar: `screens/V3-Materi.png`, `V3-Materi-Gelap.png`, dan `V3-Materi-Mutlak.png`. Layar Pelajaran yang sudah ada dipakai lagi, dengan tambahan berikut.

1. **Field baru `words` pada blok `example`** (opsional):
   - Bentuknya `"words": [dari, sampai]`, indeks kata **1-based**. Hitungannya **sama persis dengan `tanzilWords()`** di `lib/features/mushaf/domain/mushaf_text.dart`: basmalah awal ayat 1 dibuang lewat `basmalahPrefix`, dan tanda waqaf atau sajdah ikut kata sebelumnya.
   - Sudah dicek: jumlah kata versi ini sama dengan `tanzilWords` di 6.236 ayat.
   - Parser lama mengabaikan field ini, jadi JSON tetap terbaca sebelum kode diperbarui.
   - Tambahkan `List<int>? words` ke `LessonExample`. Tolak nilainya bila di luar jangkauan kata ayat, dengan `FormatException` seperti validasi lain.
2. **Kartu `example` dengan `words`:**
   - Kata-kata dalam rentang itu diberi latar `goldSoft`, radius 6, dan garis bawah `goldText` 2 dp.
   - Kata lain tetap normal. Warna tajwid huruf tetap tampil di atas sorotan.
   - Tampilkan juga baris kecil di atas ayat: kata yang disorot saja (Amiri Quran 26), agar mata langsung menemukannya.
3. **Tiga contoh atau lebih berurutan di satu halaman** (misalnya 15 contoh ikhfa, satu per huruf):
   - Tampilkan sebagai **daftar ringkas**. Tiap baris berisi kata yang disorot saja, chip huruf penentu (diambil dari `note`, huruf Arab dalam kurung), dan "QS nama · ayat".
   - Ketuk baris untuk membuka kartu ayat lengkap (bottom sheet).
   - Daftar ini **tidak boleh overflow** di text scale 2.0.
4. **Blok `letters`:**
   - 1–4 huruf: satu baris. Amiri 42, tinggi glyph 82, nama 14/800 di bawahnya. Kartu tidak boleh menimpa ekor huruf ي / م.
   - 5–15 huruf: grid 5 kolom, Amiri 32.
   - Kartu tanpa `note` tidak menampilkan baris ketiga.
5. **Blok `text` dengan `heading`** menjadi judul halaman. Beberapa halaman ringkasan berisi 5–6 kalimat; biarkan area teks bisa di-scroll.
6. **Lencana DRAF** (build debug saja) di pojok kanan atas, memakai `goldSoft` / `goldText`.
7. **Status:** semua tahap 6–16 tetap `draft`. Jangan dinaikkan tanpa 2 peninjau (docs/RELIGIOUS_CONTENT_GOVERNANCE.md). `test/curriculum_test.dart` harus lulus **tanpa diubah**.

## 7. Lisensi

Semua aset & paket gratis dan aman lisensinya. Rinciannya ada di `docs/design/v3/LISENSI_ASET.md`. Jangan menambah paket animasi, font, atau ilustrasi berbayar tanpa izin pemilik.
