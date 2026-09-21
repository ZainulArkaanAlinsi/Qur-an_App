# Qur’an App — Panduan Perombakan dan Prompt Codex

Untuk Zainul Arkaan • 20 September 2026

## 0. Status dan cara memakai panduan

Ini spesifikasi implementasi dan tutorial, bukan klaim aplikasi sudah selesai. ZIP desain berhasil dibaca: 17 pasang code.html/screen.png, Sacred Serenity DESIGN.md, dan project_foundation_roadmap.md. Dashboard enhanced dan reader premium diperiksa secara visual. Repository GitHub belum bisa diakses: terminal menolak koneksi dengan HTTP 403. Kode Flutter lama belum diaudit, diubah, atau diuji. Tidak ada perubahan/push ke GitHub.

Jalankan implementasi melalui Codex di laptop yang memiliki repo. Simpan dokumen ini sebagai docs/QURAN_APP_GUIDE_DAN_PROMPT_CODEX.md di repo. Ekstrak ZIP desain, lalu gunakan prompt pada bagian terakhir. Jangan membuat proyek Flutter baru menimpa proyek lama.

Urutan: audit → pulihkan baseline → dataset → reader → audio → streak → sinkronisasi → fitur tambahan → QA → rilis. Setiap tahap harus punya bukti pengujian sebelum tahap berikutnya.

## 1. Tujuan produk dan batas versi pertama

Tujuan: Qur’an reader berbahasa Indonesia, nyaman, bisa membaca offline, memiliki murottal dan kebiasaan membaca harian. Prioritas kebenaran konten di atas dekorasi.

V1 wajib: daftar surah/juz, reader Arab/terjemahan, lanjut baca, pencarian, bookmark, ukuran font, light/dark, audio, pengulangan ayat, target 5/10 menit, streak, statistik lokal, pengaturan sumber. Akun dan cloud sync dapat mengikuti setelah versi lokal stabil. Tidak wajib login untuk membaca.

V1.1: rencana khatam, koleksi bookmark, tafsir bersumber, pengingat lokal, audio offline setelah izin penggunaan diperiksa, repeat rentang, jadwal salat dan kiblat.

V2 opsional: taman istiqamah, latihan hafalan, audio kata jika tersedia. Community/social ditunda: roadmap ZIP sendiri menyebut forum di luar V1. Jangan mengisi aplikasi dengan forum palsu, profil contoh, atau angka statistik statis.

Streak bukan ukuran pahala atau kepastian seseorang membaca. Timer hanya perkiraan aktivitas. Tidak perlu kamera, mikrofon, atau pelacakan mata untuk membuktikan bacaan.

## 2. Audit desain ZIP dan keputusan UI

Tema dipertahankan: Sacred Serenity, emerald + ivory + emas. HTML adalah referensi visual, bukan aplikasi produksi dan bukan sumber ayat. Implementasikan komponen Flutter native, bukan seluruh aplikasi dalam WebView.

| Referensi ZIP | Keputusan implementasi |
|---|---|
| splash_screen | Splash singkat, tidak menahan navigasi untuk animasi |
| home_dashboard_1, home_dashboard_2, enhanced_home_dashboard | Gabungkan menjadi satu Home; lanjut baca dan target harian di atas |
| surah_list | Daftar surah dan tab juz; loading/error/search kosong |
| reading_screen, premium_reading_experience | Satu reader responsif dengan mode fokus |
| reading_settings | Ukuran teks, terjemahan, tema, qari |
| bookmarks_collections | Bookmark lokal, koleksi tahap berikutnya |
| advanced_search | Cari nama surah/nomor ayat/terjemahan; sumber hasil jelas |
| khatim_progress | Ubah label Indonesia menjadi Progres Khatam |
| profile_insights, refined_profile_insights | Gabungkan menjadi Progres; profil dan privasi di Pengaturan |
| prayer_schedule, qibla_finder | Utilitas V1.1, izin lokasi opsional |
| community_hub, enhanced_community_hub | Tidak ditampilkan di V1 |

Temuan visual nyata: premium reader menunjukkan kotak pengganti glyph dan teks keluar sisi kanan. Dashboard enhanced memperlihatkan gambar/konten samar menumpuk di kartu dan jadwal terpotong. Jangan menyalin cacat ini.

DESIGN.md menyebut Meiryo sebagai contoh font Arab; jangan mengikuti saran itu. Pilih font Qur’an yang lisensinya sesuai, mendukung karakter dataset dan tanda waqaf. Font Unicode tidak dapat dipertukarkan sembarang dengan font glyph berbasis halaman. Jangan mengambil ayat contoh HTML sebagai konten resmi.

Token awal dari file: primary #003527, primaryContainer #064E3B, surface #FCF9F8, text #1B1C1C, gold #FED65B. Emas bukan warna teks kecil di ivory karena kontras perlu diuji. Latin: Plus Jakarta Sans; heading EB Garamond opsional dengan lisensi diperiksa. Font Arab dibundel agar tersedia offline.

Spacing 8/12/16/24/40, margin mobile 20, radius kartu 16. Jangan fixed-height untuk ayat. Gunakan RTL pada teks Arab dan LTR untuk terjemahan Indonesia. Uji skala font 200%, landscape, layar sempit, SafeArea, navigation bar, dan mini-player. Harakat tidak boleh terpotong.

Navigasi V1: Beranda, Qur’an, Progres, Pengaturan. Bookmark dapat diakses dari Beranda/Qur’an. Reader tidak memerlukan seluruh bottom navigation; sediakan back, nama surah, pengaturan dan mini-player.

Home: lanjut membaca → target hari ini → streak → akses surah/bookmark → rencana khatam. Jadwal salat bukan elemen dominan pada aplikasi baca Qur’an. Kutipan harian harus berasal dari dataset terverifikasi dan menyertakan referensi.

## 3. Persiapan Windows dan baseline repo

Buka PowerShell. Repo sudah ada, jadi jangan clone lagi ke folder tersebut.

```powershell
Set-Location 'C:\Users\USER\github-repos\Qur-an_App'
git status --short
git remote -v
git branch --show-current
flutter --version
dart --version
flutter doctor -v
flutter devices
```

Periksa AGENTS.md jika ada. Catat perubahan pengguna; jangan reset, clean, stash, overwrite, atau commit semuanya secara otomatis. Buat backup/checkpoint yang disepakati. Buat branch baru dengan nama yang belum dipakai:

```powershell
git switch -c redesign/sacred-serenity
flutter pub get
flutter analyze
flutter test
```

Jika belum ada tests, catat sebagai kekurangan, bukan hasil lulus. Simpan error baseline agar tidak tertukar dengan regresi baru. Jalankan `flutter run -d <device-id>` menggunakan ID dari flutter devices; placeholder harus diganti.

Hanya bila folder repo benar-benar belum ada, jalankan dari folder induk: `git clone https://github.com/ZainulArkaanAlinsi/Qur-an_App.git`. Jika akses ditolak, berhenti dan minta akses/ZIP source; jangan berusaha melewati pembatasan.

Audit pubspec.yaml, lockfile, lib/, assets/, android/, tests, route, controllers/providers, model API, audio lifecycle, storage, izin Android, Firebase config dan dependency lama. Pertahankan state management yang sudah dipakai kecuali ada bukti masalah. Tidak perlu migrasi GetX ke Riverpod hanya demi tren. Pin dependency kompatibel; jangan upgrade major semuanya sekaligus.

Deliverable audit: docs/AUDIT.md berisi file nyata, fitur bekerja/rusak, risiko, baseline test, dan urutan refactor. Jangan mengarang nama class atau path sebelum membaca repo.

## 4. Arsitektur yang disarankan

Flutter presentation → controller/state → repository → datasource lokal/remote. Pisahkan model respons API dari domain Ayah agar pergantian provider tidak mengubah semua UI.

- Local database: SQLite melalui library yang kompatibel dengan repo; Drift kandidat jika belum ada solusi.
- Qur’an content: read-only, versioned, terpisah dari user database.
- Local user data: bookmark, last-read, preferences, sessions dan outbox.
- Audio: evaluasi just_audio + audio_service dengan versi kompatibel dan konfigurasi platform resmi.
- Backend opsional: TypeScript Cloud Functions atau server lain yang disetujui, sebagai proxy Content API dan sync validation.
- Auth/sync: Firebase Auth dan Firestore bila dipilih setelah kebutuhan biaya dipahami.

Struktur target konseptual: app/theme, core/database, core/network, core/audio, features/quran, features/search, features/bookmarks, features/reading_sessions, features/streak, features/progress, features/settings. Sesuaikan dengan struktur nyata; migrasikan satu fitur sekali jalan.

Jangan mewajibkan seluruh dataset Qur’an disalin ke Firestore per pengguna. Jangan menambahkan custom JWT jika sudah menggunakan Firebase ID token. Jangan menjanjikan end-to-end encryption untuk catatan tanpa implementasi key management; catatan privat harus memiliki akses owner-only, dan klaim enkripsi dijelaskan secara tepat.

## 5. Data Qur’an dan sumber resmi

Calon teks Arab offline: Tanzil Uthmani. Simpan salinan sumber verbatim, versi, URL, tanggal pengambilan, checksum dan atribusi. Periksa hak terjemahan secara terpisah; lisensi teks Arab tidak otomatis berlaku untuk terjemahan, font atau audio.

Tanzil mensyaratkan teks tidak diubah dan atribusi sumber disertakan: https://tanzil.net/docs/Text_License

Calon metadata, tafsir dan audio: Quran Foundation. Credential Content API berada di backend, bukan Flutter assets atau dart-define yang dibundel. Dokumentasi: https://api-docs.quran.foundation/docs/sdk/javascript/audio/

Audio per surah dan per ayat memakai keluarga ID resource berbeda. Timing kata/ayat opsional; bila tidak tersedia, nonaktifkan highlight tersinkronisasi, jangan mengarang timestamp. Periksa developer terms sebelum menyimpan/mendistribusikan audio offline. Jangan menjanjikan semua qari atau seluruh audio bebas dibundel.

Langkah ingestion:

1. Pilih satu edisi/script/konvensi penomoran; dokumentasikan baseline.
2. Ambil dataset dari sumber resmi beserta atribusi, bukan HTML desain atau AI.
3. Simpan raw file immutable dan SHA-256. Checksum mendeteksi perubahan setelah baseline, bukan bukti kebenaran agama.
4. Parse deterministik ke database read-only. Jangan trim/normalize teks Arab kanonis secara destruktif.
5. Gunakan verseKey `surah:ayah`; nomor dan jumlah ayat divalidasi terhadap manifest edisi.
6. Periksa seluruh pagination respons API agar surah panjang tidak terpotong.
7. Pisahkan basmalah tampilan dari identitas ayat sesuai sumber. Uji Al-Fatihah, At-Taubah, serta basmalah dalam An-Naml 27:30; jangan menghapus basmalah dengan regex global.
8. Normalisasi hanya salinan indeks pencarian, tidak isi tampilan.
9. Update dataset melalui staging, diff, review dan rollback ke versi terakhir valid; jangan overwrite konten valid dengan respons parsial.
10. Minta reviewer kompeten memeriksa tampilan, harakat, nomor dan pasangan audio sebelum rilis.

Terjemahan Indonesia harus punya nama penerjemah/penerbit/resource ID/versi yang benar-benar ditemukan. Jangan memberi label Kemenag pada sumber yang tidak diverifikasi. AI tidak menulis ulang ayat, terjemahan resmi, tafsir, atau warna tajwid. Tajwid hanya dari dataset beranotasi tervalidasi dan renderer yang sesuai.

Model minimal: Surah(id,nameArabic,nameLatin,verseCount); Ayah(verseKey,surahId,ayahNumber,arabicText,editionId); Translation(verseKey,resourceId,text,version); AudioResource(provider,kind,resourceId,verseKey,url,timing); Bookmark(id,verseKey,createdAt,updatedAt,deletedAt); LastRead(verseKey,scrollOffset,updatedAt).

## 6. Aturan streak final

Default target 5 menit, pilihan 10/15/30. Memenuhi target menambah SATU hari, bukan jumlah menit. Sesi boleh dicicil. Membuka app tanpa membaca tidak cukup. V1 mengikuti permintaan pengguna: streak membaca; mendengarkan dicatat terpisah, tidak otomatis menambah reading streak.

Sesi: idle → running → paused → completed/saved. Timer monotonik, bukan selisih jam HP mentah. Reader visible dan foreground diperlukan; pause pada app background, layar terkunci atau pengguna menekan pause. Jangan memaksa scroll terus-menerus: orang bisa lama membaca satu ayat. Gunakan jeda tidak aktif yang konservatif dengan konfirmasi 'Masih membaca?' dan jelaskan bahwa ini estimasi, bukan verifikasi pasti.

Tanggal memakai zona waktu IANA yang tersimpan. Hari berganti pada 00:00 zona pengguna, bukan UTC. Pecah sesi lintas tengah malam menjadi dua hari. Perubahan zona/target berlaku mulai hari berikutnya, tidak mengubah riwayat. Snapshot target harian.

Algoritme: setelah agregasi harian, jika durasi >= targetSeconds, qualifying=true. Recompute rentetan tanggal qualifying. Jika hari ini belum qualifying tetapi kemarin qualifying, tampilkan rentetan sampai kemarin sebagai pending hari ini. Jika kemarin terlewat, current=0 sampai hari ini memenuhi target, lalu menjadi 1. Longest dan riwayat tidak hilang. Tidak ada freeze otomatis di V1.

Contoh target 5 menit: Senin 7 → 1; Selasa 11 → 2; Rabu 3 pada siang hari → 2 pending; Rabu berakhir tanpa tambahan → putus; Kamis belum membaca → 0; Kamis mencapai 5 → 1. Ini memperbaiki ambiguitas contoh sebelumnya.

Session: UUID, deviceId pseudonim, startedAtUtc, endedAtUtc, monotonicActiveSeconds, timezoneSnapshot, localDate, mode, lastVerseKey, syncStatus. DailyProgress: date, targetSeconds, qualifiedSeconds, completed. Stats turunan: current, longest, totalMinutes.

Sync idempotent berdasarkan sessionId; kirim delta/session, jangan increment streak langsung dari client. Gabungkan interval tumpang-tindih dari dua device agar menit tidak dobel. Simpan raw sessions dan deduplikasi dalam transaksi server. Client tidak boleh menulis authoritative stats. Guest boleh menghitung lokal; server tidak dapat membuktikan ketulusan membaca atau waktu offline secara sempurna. Status offline provisional sampai rekonsiliasi; sesi offline valid yang terlambat harus dapat memulihkan riwayat melalui recompute. Jam server + deteksi anomali mengurangi manipulasi, bukan membuatnya mustahil.

Test wajib: 299/300 detik; 2+3 menit; reopen berkali-kali; dua sesi terkirim ulang; tengah malam; gap sehari; leap day; perubahan timezone; target diubah; dua perangkat; app kill; jam dimajukan/mundur; sinkronisasi terlambat; pause/resume. Fake clock agar tests deterministik.

## 7. Audio, offline dan error handling

Bangun satu audio controller/service dengan queue, bukan player untuk tiap kartu. Mulai dengan playback per ayat: play/pause/next/previous, repeat satu ayat, lalu repeat rentang. Saat qari berubah, cancel request lama agar hasil lama tidak menimpa state baru. Audio harus cocok verseKey dan resource yang dipilih.

Background audio berbeda dari reading timer: audio boleh tetap berjalan saat layar mati, tetapi reading timer berhenti. Handle audio focus, panggilan masuk, headphone dilepas, buffering, error URL dan retry. Next/previous serta highlight harus mengikuti actual player state, bukan timer perkiraan.

Unduhan hanya setelah izin resource jelas. Tampilkan ukuran, progress, pembatalan, retry, hapus, storage limit. Unduh ke temporary file lalu atomic rename setelah validasi; jangan menandai file setengah jadi sebagai siap. Offline text wajib tetap bisa dibaca saat API gagal. Bila audio belum diunduh tampilkan pesan jelas, bukan loading tanpa akhir.

## 8. Backend, keamanan dan biaya

Tahap lokal dulu bisa dikerjakan tanpa cloud. Jangan klaim seluruh proyek gratis selamanya: backend, bandwidth audio, quota API, akun store dan layanan cloud dapat berbiaya. Cek paket/billing saat setup dan minta persetujuan sebelum mengaktifkan layanan berbayar/deploy.

Jika memakai Firebase: buat proyek development terpisah setelah izin pengguna; register applicationId nyata; konfigurasi FlutterFire sesuai dokumentasi saat itu; simpan credential server di secret manager. Konfigurasi Firebase client bukan pengganti security rules. Service account/private key tidak masuk git atau aplikasi.

Contoh jalur Firestore valid: users/{uid}/sessions/{sessionId}, users/{uid}/dailyProgress/{date}, users/{uid}/stats/reading, users/{uid}/bookmarks/{bookmarkId}. Hindari contoh lama users/{uid}/reading_stats sebagai dokumen karena jumlah segmennya tidak tepat.

Rules: pengguna hanya akses data sendiri, validasi field/ukuran/jenis, tolak write client ke stats authoritative. Uji rules dengan emulator: user A tidak dapat membaca/mengubah data B. Endpoint verifikasi ID token, rate limit dan payload bounds. App attestation dapat membantu abuse prevention tetapi bukan otorisasi tunggal.

Guest-to-account migration memerlukan idempotent import dan conflict handling. Bookmark gunakan ID stabil dan tombstone untuk delete; jangan resurrect bookmark saat sync lama datang. Sediakan delete account + data, termasuk proses pembersihan yang dapat diulang. Jangan log catatan pribadi/token/ayat aktivitas pengguna di analytics tanpa kebutuhan dan persetujuan.

## 9. Implementasi bertahap dan gerbang lulus

| Tahap | Yang dibangun | Bukti selesai |
|---|---|---|
| 0 Audit | Baca source, dependency, baseline, branch aman | AUDIT.md + log perintah |
| 1 Baseline | Perbaiki build/runtime lama tanpa redesign besar | App lama berjalan pada perangkat |
| 2 Konten | Import, manifest, font, database | Seluruh keys/count/hash tests lulus |
| 3 Reader | Theme, surah/juz, reader, bookmark, last read | Offline + RTL + skala 200% lulus |
| 4 Audio | Proxy bila diperlukan, queue dan interruptions | Pasangan verse/audio benar di perangkat |
| 5 Streak | Sessions, target, kalender dan statistik | Edge-case tests deterministik |
| 6 Sync | Akun opsional, outbox, security rules | Dua perangkat + isolation tests |
| 7 Pelengkap | Khatam, reminder, tafsir; utilitas opsional | Tidak ada tombol dummy yang terlihat |
| 8 Release | QA konten, aksesibilitas, signing, privacy | Checklist disetujui sebelum distribusi |

Setiap tahap memperbarui docs/PROGRESS.md: selesai, diuji, belum diuji, blocker, langkah lanjut. Dokumen ini bukan perkiraan tanggal: durasi ditentukan setelah audit nyata.

Rencana khatam memakai unit edisi yang jelas, misalnya ayat atau halaman; jangan menganggap seluruh ayat sama lama. Halaman hanya jika mapping mushaf terverifikasi. Catat completion pengguna, jangan otomatis menyatakan seluruh ayat yang dilewati scroll telah dibaca.

Reminder opt-in, waktu lokal dan quiet hours. Salat/kiblat V1.1: pilih kota manual jika izin lokasi ditolak; tampilkan metode kalkulasi, tanggal, timezone dan kalibrasi kompas. Arah kiblat tidak boleh angka statis dari mockup. Tidak perlu akses lokasi background untuk pembaca Qur’an.

## 10. Menjalankan dan memeriksa hasil

Sesudah perubahan, dari root repo:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter devices
```

Gunakan `dart format lib` bila folder test belum ada; lalu tambahkan tests yang diperlukan. Jalankan `flutter run -d <device-id>` dengan ID yang nyata. Jika integration tests sudah dibuat, jalankan `flutter test integration_test -d <device-id>`. Jangan menulis 'passed' bila command belum dijalankan.

Test manual: first launch airplane mode; Al-Fatihah; surah panjang; At-Taubah; An-Naml 27:30; resume ayat panjang; 200% font; dark mode; screen reader; player interruption; storage penuh; jaringan putus; audio tidak tersedia; logout; uninstall/reinstall sesuai kebijakan backup; reader saat low-memory. Simpan screenshot dan catat perangkat, OS, commit, dataset version.

Uji performa pada profile/release, bukan menyimpulkan dari debug. Sasaran transisi/audio dalam roadmap ZIP adalah target, bukan jaminan: audio buffer dipengaruhi jaringan. Ukur cold/warm start, reader scroll dan loading pada perangkat target.

## 11. APK, AAB dan rilis

Setelah QA lokal:

```powershell
flutter build apk --debug
```

APK debug untuk uji internal, bukan bukti production-ready. Umumnya berada di build/app/outputs/flutter-apk/app-debug.apk; konfirmasi file hasil command.

Untuk rilis: tentukan applicationId, version/build number, icon, nama, permissions minimal; buat signing key sendiri dan backup aman. Jangan kirim password ke chat, commit keystore atau key.properties. Ikuti panduan signing resmi: https://docs.flutter.dev/deployment/android

```powershell
flutter build appbundle --release
```

Konfigurasi release signing harus selesai lebih dulu. Output umumnya build/app/outputs/bundle/release/app-release.aab. AAB untuk store bukan APK instal langsung. Lakukan internal/closed testing, lengkapi privacy policy, atribusi dataset/font/audio, data safety sesuai implementasi nyata, review konten manusia, lalu pengguna menyetujui publikasi. Syarat store saat rilis harus diperiksa ulang. iOS membutuhkan lingkungan macOS/Xcode dan proses signing Apple; tidak dianggap selesai karena Android berhasil.

Jangan auto-publish atau push tanpa instruksi pengguna. Rollback aplikasi dan dataset perlu disiapkan. Pantau crash secara minim data, tangani laporan konten melalui review dan release terkontrol.

## 12. Troubleshooting singkat

| Gejala | Pemeriksaan pertama |
|---|---|
| Huruf kotak/harakat terpotong | Cakupan glyph font, pasangan dataset-font, line height dan clipping |
| Surah hanya beberapa ayat | Pagination dan manifest jumlah ayat |
| Audio ayat salah | verseKey dan keluarga recitation ID, request race |
| Audio gagal saat layar mati | Konfigurasi service/background platform dan audio focus |
| Bookmark hilang setelah update | Database migration dan backup; jangan drop tabel |
| Streak dobel | Session idempotency dan interval overlap |
| Streak putus saat offline | Outbox dan recompute sesudah sync |
| Build Gradle/JDK gagal | Flutter doctor, kompatibilitas Gradle/AGP/JDK nyata; jangan upgrade acak |
| API 401/403/429 | Credential backend, izin resource, expiry/token dan rate limit; jangan bypass |

## 13. Prompt master untuk Codex lokal

Salin seluruh blok berikut setelah dokumen ini tersimpan di docs/. Prompt ini meminta implementasi bertahap, bukan sekadar membuat rencana.

```text
Kamu bekerja sebagai engineer Flutter pada proyek Qur’an App milik saya.
PERBAIKI DAN ROMBAK PROYEK YANG ADA; jangan membuat app baru menimpa repo.

Repo lokal: C:\Users\USER\github-repos\Qur-an_App
Remote referensi: https://github.com/ZainulArkaanAlinsi/Qur-an_App.git
Referensi desain: C:\Users\USER\Downloads\stitch_al_quran_comprehensive_companion
Spesifikasi: docs/QURAN_APP_GUIDE_DAN_PROMPT_CODEX.md

Mulai dengan membaca AGENTS.md jika ada, spesifikasi tersebut, git status,
pubspec.yaml/lockfile, source lib, assets, android, tests dan konfigurasi.
Temukan DESIGN.md dan project_foundation_roadmap.md secara rekursif di folder
desain karena ZIP punya nested folder dengan nama sama. Jika path tidak ada,
laporkan path yang dicari dan minta lokasi yang benar; jangan mengarang isinya.

Audit codebase nyata. Buat docs/AUDIT.md, baseline analyze/test/run, dan rencana
tahap kecil. Pertahankan perubahan saya dan fitur yang bekerja. Jangan reset,
clean, hapus massal, push, deploy, menambah billing, atau menyimpan secret.
Jangan upgrade major semua dependency atau mengganti state management tanpa
alasan yang dibuktikan dari repo. Jika perubahan saya bertabrakan, tanyakan.

Setelah audit, lanjutkan implementasi tahap lokal aman pertama dalam turn ini;
jangan berhenti pada daftar rencana jika masih bisa bekerja. Prioritas: build
baseline, integritas data, reader, audio, streak, lalu sync. Jalankan tests
di setiap tahap. Jika ada blocker eksternal, dokumentasikan dan kerjakan
bagian independen yang aman. Jangan mengatasi penolakan izin dengan bypass.

UI mengikuti Sacred Serenity: #003527, #064E3B, #FCF9F8, aksen #FED65B.
Implementasi Flutter native, responsif, light/dark, bahasa Indonesia.
Perbaiki overflow, glyph kotak, harakat clipping dan gambar saling menimpa.
Home memprioritaskan lanjut baca dan target harian. Navigasi V1: Beranda,
Qur’an, Progres, Pengaturan. Community ditunda; jangan tampilkan tombol dummy.
Semua state loading/error/empty/offline harus jelas, tanpa spinner tak berujung.

Teks ayat bukan dari HTML mockup, AI, atau ketikan manual. Gunakan dataset
resmi berlisensi sesuai, simpan atribusi/versi/hash, validasi 114 surah dan
manifest ayat edisi terpilih, verseKey unik, pagination, basmalah dan RTL.
Hash bukan bukti kebenaran konten; tetap sediakan review manusia sebelum rilis.
Jangan mengubah Arab kanonis, menerjemahkan ayat dengan AI, atau mengarang tajwid.
Normalisasi hanya search index. Resource translation/audio harus teridentifikasi.

Quran Foundation credential hanya di backend. Verifikasi kontrak API terbaru
sebelum integrasi; jangan mengarang endpoint/resource ID. Audio ayat dan surah
memiliki katalog ID berbeda. Highlight hanya dengan timing valid. Download
audio hanya setelah hak offline diperiksa. Jika akses belum tersedia, tampilkan
state unavailable yang jujur; jangan mengklaim mock sebagai integrasi selesai.

Streak mengikuti bagian 6 spesifikasi: target 5/10/15/30 menit, maksimal satu
increment per hari, timer aktivitas perkiraan, pause background/lock, mendengar
terpisah, timezone IANA, split midnight, target snapshot, reset sesudah hari
terlewat, longest tetap. Tidak ada freeze di V1. Gunakan fake clock tests untuk
batas durasi, gap, timezone, duplikasi, offline dan multi-device. Jangan mengklaim
anti-curang sempurna. Outbox idempotent dan recompute saat sync; client tidak
menulis stats authoritative. Reading tetap berjalan tanpa login/internet.

Sediakan dataset/source attribution, README setup Windows, .env.example tanpa
secret jika diperlukan, tests unit/widget/integration, migrations, serta
docs/PROGRESS.md dan docs/RELEASE_CHECKLIST.md. Untuk security rules uji isolasi
antar akun dan larangan manipulasi stats. Jangan klaim E2EE jika tidak dibuat.

Definition of done setiap tahap: code terhubung ke app, bukan halaman contoh;
analyze/test dijalankan dan hasilnya dilaporkan; reader tak terpotong pada 200%
font; data lama tidak hilang; state error bisa dipulihkan. Perubahan runtime
harus diuji di emulator/perangkat bila tersedia. Jika tidak tersedia, sebutkan
belum diuji, jangan mengklaim aplikasi siap produksi.

Akhiri tiap turn dengan: fitur selesai, file berubah, perintah dan hasil test,
yang belum diverifikasi, blocker/keputusan pengguna, dan tahap selanjutnya.
Jangan publikasi atau push tanpa permintaan saya. Mulai audit repo sekarang.
```

## 14. Prompt lanjut setelah satu tahap

```text
Baca docs/PROGRESS.md dan git diff terbaru. Lanjutkan tahap berikutnya dari
QURAN_APP_GUIDE_DAN_PROMPT_CODEX.md tanpa mengulang pekerjaan yang sudah lulus.
Periksa bahwa perubahan saya tetap aman. Implementasikan, jalankan pengujian,
perbarui progress dan laporkan bukti; jangan berhenti hanya pada penjelasan.
Jika tahap bergantung credential/biaya/izin yang belum ada, laporkan blocker
dan lanjut hanya bagian independen yang aman.
```

## 15. Checklist penerimaan akhir

- [ ] Repo lama diaudit, perubahan pengguna dipertahankan.
- [ ] Tidak ada ayat produksi dari mockup atau AI.
- [ ] Manifest, atribusi, dataset hash dan font terverifikasi.
- [ ] Semua surah bisa dibaca offline; Arab/harakat tidak terpotong.
- [ ] Terjemahan dan audio terhubung verseKey yang tepat.
- [ ] Last read/bookmark bertahan setelah restart/update.
- [ ] Streak lolos kasus durasi/tanggal/offline/duplikasi.
- [ ] Audio dan reading timer memiliki lifecycle berbeda yang benar.
- [ ] Rules/auth dan migrasi user data diuji bila cloud aktif.
- [ ] Semua tombol terlihat punya fungsi nyata atau disabled dengan alasan.
- [ ] Reviewer konten menyetujui hasil render dan sampel playback.
- [ ] Analyze/test/build dan tes perangkat tercatat, bukan diasumsikan.
- [ ] Signing, privacy, lisensi, store requirements dan rollback siap.
- [ ] Pengguna menyetujui publikasi; tidak ada biaya/deploy otomatis.

Referensi diperiksa 20 September 2026. Kontrak API, dependency, biaya dan syarat
store perlu diverifikasi lagi saat implementasi/rilis. Dokumen ini adalah
pegangan kerja; readiness ditentukan oleh bukti pengujian, bukan panjang prompt.
