# DATA — data, aturan, dan logika MyQuran

Dokumen ini menjelaskan **dari mana angka di layar berasal dan aturan apa yang menentukannya**. Mulai v6 (2 Oktober 2026), bagian Beranda dan Murottal ditulis lengkap. Data lain dirangkum di §7. Kalau kode dan dokumen ini berbeda, jangan menebak: tanyakan pemilik, lalu perbarui dokumen ini atau kodenya.

Prinsip umum:
- Semua data pengguna disimpan di HP (`SharedPreferences`, berkas di `<documents>`). Cloud (Firestore) hanya bila pengguna masuk, dan hanya yang tercantum di `docs/CLOUD_SYNC.md`.
- Teks ayat dan terjemahan **dibaca dari aset berlisensi**, tidak pernah dibentuk ulang, dirapikan, atau diambil dari mockup.
- Logika keputusan (mis. langkah berikutnya) ditulis sebagai **fungsi murni** di `domain/`, tanpa `BuildContext`, tanpa `DateTime.now()` di dalamnya (waktu dioper sebagai parameter), supaya bisa dites.

---

## 1. HomeSnapshot (Beranda)

Berkas: `lib/features/home/domain/home_snapshot.dart`. Dibangun oleh `HomeController` (`lib/features/home/application/home_controller.dart`, `ChangeNotifier`) dari layanan yang **sudah ada**. Tidak ada layanan baru.

| Field | Tipe | Sumber (kode yang sudah ada) |
| --- | --- | --- |
| `now` | `DateTime` | dioper dari luar (tes memakai jam palsu, seperti `HomeScreen.now`) |
| `lastRead` | `LastRead?` (`surah`, `ayah`, `started`) | `SharedPreferencesService.getLastReadSurah()` + `getLastReadVerse()` |
| `reading` | `ReadingProgress` | `ReadingProgressService.read(now:)` → `todaySeconds`, `targetSeconds`, `currentStreak`, `recentDays` |
| `session` | `DailySession?` | `SessionStore.app?.day(ReadingProgressService.localDate(now))` |
| `sessionAvailable` | `bool` | kurikulum punya ≥ 1 pelajaran `published` (atau draf bila `showDraftLessons`) |
| `memorizedCount` | `int` | `SharedPreferencesService.allAyahMemorization().length` |
| `murajaahDue` | `List<AyahMemorization>` | `dueForReview(all, now)` |
| `murajaahDoneToday` | `int` | **baru**: kunci `murajaah.selesai.<yyyy-mm-dd>` (§4) |
| `startPoint` | `StartPoint` | `StartPoint.saved ?? StartPoint.initial` |
| `nextLesson` | `LessonRef?` | `curriculum.nextAfter(done, includeDrafts: showDraftLessons)` (judul untuk "Sesi besok") |
| `prayer` | `PrayerDay?` + status | `PrayerService.fetch(city, country)`; status `ok / belumDiatur / luring / memuat` |
| `nowPlaying` | `AudioQueue?` + `playingVerse` | `QuranAudioService.instance.queue`, `.playingVerse` |

Hitung ulang snapshot ketika: Beranda tampil lagi (kembali dari layar lain), `sessionRevision` berubah, `QuranAudioService.queue`/`playingVerse` berubah, pull-to-refresh, dan **tanggal lokal berganti** (timer ke 00:00:05 berikutnya).

---

## 2. NextStepEngine — "Langkah berikutnya"

Berkas: `lib/features/home/domain/next_step.dart`.

```dart
enum NextStepKind { resumeSession, startSession, murajaah, reading }

class NextStep {
  final NextStepKind kind;
  final String title;      // judul kartu
  final String subtitle;   // satu kalimat alasan/keadaan
  final String cta;        // teks tombol
  final String? badge;     // pill kanan atas: "±10 mnt", "10 ayat", "Hal. 296"
  final int? sessionStep;  // 0..4, hanya untuk sesi
}

class NextStepResult {
  final NextStep primary;
  final List<NextStepAlt> alternatives; // maks 2
}

NextStepResult decideNextStep(HomeSnapshot s);
```

### 2.1 Kandidat

| Kandidat | Ada bila | Judul | Subjudul | CTA | Badge |
| --- | --- | --- | --- | --- | --- |
| `resumeSession` | `session != null && !completed && step > warmup` **atau** ada langkah yang sudah dikerjakan/dilewati | "Lanjutkan sesi" | "Langkah {n} dari 5 · {step.title}" | "Lanjutkan" | "±{sisa} mnt" (2 mnt per langkah tersisa) |
| `startSession` | `sessionAvailable && (session == null \|\| (!completed && belum ada langkah dikerjakan))` | "Sesi hari ini" | "Langkah 1 dari 5 · Pemanasan, ulang {k} soal" (k dari rencana; kalau belum tahu: "Ulang, materi baru, ayat, tirukan qari") | "Mulai sesi" | "±10 mnt" |
| `murajaah` | `murajaahDue.isNotEmpty` | "Murajaah {ringkasan}" — ringkasan sama dengan `_dueSummary` lama, mis. "An-Naba' 1–10" | "{n} ayat jatuh tempo" + " · {h} hari terlewat" bila `dueOn` terlama < hari ini | "Mulai murajaah" | "{n} ayat" |
| `reading` | selalu | `lastRead == null` → "Mulai membaca"; selain itu "{Surah} · ayat {a}" | sisa target: "{m} mnt lagi ke target hari ini"; target tercapai: "Target hari ini tercapai"; plus "Sesi selesai ✓" bila sesi hari ini selesai | `lastRead == null` → "Buka Al-Fatihah"; selain itu "Lanjut membaca" | "Hal. {page}" bila halaman diketahui |

### 2.2 Urutan memilih kandidat utama (berhenti di aturan pertama yang cocok)

1. `resumeSession` ada → **resumeSession**. (Pekerjaan yang setengah jalan selalu didahulukan.)
2. `startPoint == hafalan` dan `murajaah` ada → **murajaah**.
3. `startSession` ada → **startSession**.
4. `murajaah` ada → **murajaah**.
5. → **reading**.

Tidak ada aturan berdasarkan jam (pagi/malam) atau acak. Hasil harus sama untuk snapshot yang sama.

### 2.3 Pilihan lain (maks 2, urutan tetap)

Dari kandidat yang tersisa, ambil sesuai urutan `[reading, murajaah, startSession/resumeSession]`, lalu bila masih kurang dari 2:
- `nowPlaying != null` dan utama bukan `reading` → "DENGAR · Murottal {surah} ayat {a}" (buka pemutar).
- Sesi hari ini sudah selesai dan `nextLesson != null` → "SESI BESOK · {judul pelajaran}" (buka tab Belajar, tidak memulai sesi baru).

Eyebrow pilihan lain: BACA / MURAJAAH / SESI HARI INI / DENGAR / SESI BESOK. Saat surah bacaan terakhir sedang diputar, eyebrow BACA menjadi **DIPUTAR** dan aksinya membuka pemutar.

### 2.4 Aksi

| Kind | Aksi |
| --- | --- |
| resumeSession / startSession | `SessionScreen(now:)` (layar yang sudah ada) |
| murajaah | tab Hafalan → layar murajaah dengan antrean `murajaahDue` |
| reading | `ReaderScreen(surah, initialVerse)`; `lastRead == null` → Al-Fatihah ayat 1 |

---

## 3. TodaySummary — kartu "Hari ini"

Berkas: `lib/features/home/domain/today_summary.dart`.

| Cincin | Nilai | Rumus | Tampil bila |
| --- | --- | --- | --- |
| Baca | menit | `todaySeconds ~/ 60` dari `targetSeconds ~/ 60`; isi = `min(1, todaySeconds / targetSeconds)` | selalu |
| Sesi | langkah | langkah selesai + dilewati (`completed` → 5); isi = langkah / 5 | `sessionAvailable` |
| Murajaah | ayat | `done = murajaahDoneToday`, `total = done + murajaahDue.length`; isi = `done / total` (0 bila total 0 → cincin penuh **tidak** ditampilkan, tulis "Tidak ada jadwal") | `memorizedCount > 0` |

`hint`:
- `todaySeconds == 0 && sesi 0 && done 0 && currentStreak == 0` → "Hari pertama. Lima menit membaca sudah cukup untuk mulai."
- semua cincin yang tampil penuh → "Semua target hari ini tercapai. Alhamdulillah."
- selain itu → `null`.

Pekan: 7 hari dari `ReadingProgress.recentDays` (aturan istiqamah tidak diubah; sesi selesai sudah dihitung oleh aturan v5).

Kalimat di layar tidak boleh menyebut keutamaan/pahala tertentu (aturan konten).

---

## 4. Penyimpanan baru (lokal)

| Kunci | Isi | Ditulis oleh |
| --- | --- | --- |
| `murajaah.selesai.<yyyy-mm-dd>` | `int` jumlah ayat yang ditandai sudah dimurajaah pada tanggal itu | titik yang sama dengan pencatatan hasil murajaah di layar Hafalan (cari pemanggil yang memperbarui `AyahMemorization.dueOn`). Hapus kunci yang lebih tua dari 14 hari saat menulis. |
| `murottal.tampilan` | `"teks"` / `"sampul"` | `MurottalScreen` |
| `murottal.terjemahan` | `bool` (bawaan `true`) | menu ⋯ Murottal |

Tidak ada yang ikut sinkron cloud. Tambahkan tes bahwa `firebase_sync.dart`/`cloud_sync_service.dart` tidak membaca kunci-kunci ini.

---

## 5. Murottal

### 5.1 PrayerHorizon (dipakai Beranda)

`lib/features/home/domain/prayer_horizon.dart`:

```dart
class HorizonModel {
  final List<HorizonNode> nodes;   // 5: Subuh, Dzuhur, Ashar, Maghrib, Isya (label Indonesia)
  final int nextIndex;             // 0..4, atau 0 dengan isTomorrow = true setelah Isya
  final bool isTomorrow;
  final double nowPosition;        // 0..1 di sepanjang lintasan (titik berjarak sama)
  final Duration untilNext;
}
HorizonModel? buildHorizon(PrayerDay day, DateTime now);
```

- Label & jam dari `PrayerDay.timeFor(label)` / `nextLabelAt(now)` (sudah ada). Imsak/Terbit tidak masuk lintasan.
- `nowPosition = (i + (now − t[i]) / (t[i+1] − t[i])) / 4` untuk `t[i] ≤ now < t[i+1]`; sebelum Subuh = 0; setelah Isya = 1.
- Teks hitung mundur: `< 1 jam` → "{m} m lagi"; selainnya "{j} j {m} m lagi".
- Zona waktu: pakai `day.timezone` seperti `_PrayerStrip` lama (jangan pakai zona HP bila kota diatur ke zona lain).

### 5.2 Status pemutar (sudah ada di `QuranAudioService`, tidak diubah)

`queue`, `playingVerse`, `isPlaying`, `buffering`, `repeat`, `speed`, `sleepAt`, `rangePass`, `rangeTarget`, `error`, `sourceNote`, `positionStream`, `durationStream`, `resumePoint()`, `restore()`.

Turunan untuk UI (`lib/features/murottal/application/player_view_model.dart`):

| Nilai | Rumus |
| --- | --- |
| `index` | `ayah(playingVerse) − queue.firstAyah` |
| `total` | `queue.length` |
| `label` | "Ayat {ayah} dari {lastAyah}" bila antrean mulai dari ayat 1; selain itu "Ayat {ayah} · {index+1} dari {total}" |
| `segmentMode` | `total ≤ 40` → segmen, selain itu kontinu |
| `fill` | `(index + pos/dur) / total` (kontinu) atau `pos/dur` untuk segmen aktif |
| `downloadState` | `AudioDownloadService.isComplete(reciter, surah)` → `tersimpan`; sedang `download(...)` → `mengunduh(p)`; selain itu `belum` |
| `subtitle` dock | lihat `screens/21-dock.md` |

Posisi di-*throttle* ke 10 Hz sebelum masuk widget.

### 5.3 Aturan audio yang tidak boleh rusak

- Memutar dari Beranda/Murottal tidak menghapus resume point murottal yang lebih lama tanpa alasan (perilaku `toggle` sekarang dipertahankan).
- Sesi harian (v5) menghentikan antrean murottal dengan sopan dan memulihkannya setelah sesi; dock harus menampilkan keadaan yang dipulihkan.
- Unduhan memakai `AudioDownloadService` yang sama dengan daftar surah. Jangan membuat pengunduh kedua.

---

## 6. Tes yang wajib ada

| Berkas | Isi minimal |
| --- | --- |
| `test/home/next_step_test.dart` | Tabel kasus: pengguna baru (tanpa lastRead, sesi tersedia) → startSession; sesi di langkah 3 → resumeSession walau murajaah jatuh tempo; titik mulai hafalan + murajaah → murajaah; sesi selesai + murajaah 0 → reading dengan subjudul "Sesi selesai ✓"; tidak ada materi terbit → tidak pernah sesi; murajaah terlewat 2 hari → subjudul memuat "2 hari terlewat"; alternatif tidak pernah > 2 dan tidak pernah mengulang utama; deterministik (panggil 2× hasil sama). |
| `test/home/today_summary_test.dart` | hint hari pertama; semua penuh; sesi disembunyikan bila tidak tersedia; murajaah disembunyikan bila belum menghafal; target 0 detik tidak membagi nol. |
| `test/home/prayer_horizon_test.dart` | sebelum Subuh, tepat di jam salat, di antara Ashar–Maghrib, setelah Isya (isTomorrow), zona waktu kota ≠ zona HP, data tidak lengkap → `null`. |
| `test/murottal/player_view_model_test.dart` | label ayat untuk antrean penuh & rentang; segmen ↔ kontinu di batas 40/41; fill tidak > 1. |
| Golden | lihat `screens/19`, `20`, `21`. |

---

## 7. Data lain (ringkas, sudah ada sebelum v6)

| Domain | Kunci/berkas utama | Dokumen |
| --- | --- | --- |
| Teks & terjemahan | `assets/quran/raw/*` (Tanzil Uthmani 1.0.2, `id.indonesian` 2010-06-04) | `docs/DATA_SOURCES_AND_LICENSES.md` |
| Tajwid | `tajweed_cpfair_tanzil_v1.0.2.json`, palet di `tajweed_palette.dart` | `docs/TAJWEED_CONTENT.md`, `docs/WARNA_TAJWID.md` |
| Kurikulum | `assets/learn/curriculum.json` (draf terkunci di rilis) | `docs/LEARN_CONTENT.md`, `docs/RELIGIOUS_CONTENT_GOVERNANCE.md` |
| Sesi harian | `sesi.hari.<tanggal>`, `sesi.riwayatAyat`, `sesi.nilaiDiri`, `<documents>/rekaman_sesi/` | `docs/design/v5-sesi-harian/SESI_HARIAN.md §5` |
| Istiqamah & target | `StreakCalculator`, `ReadingProgressService` | `QURAN_APP_GUIDE_DAN_PROMPT_CODEX.md` |
| Hafalan | `AyahMemorization` (`surah`, `ayah`, `interval`, `dueOn`) | `lib/features/hafalan/domain/murajaah_schedule.dart` |
| Sinkron cloud | Firestore (hanya bila masuk) | `docs/CLOUD_SYNC.md`, `firestore.rules` |
