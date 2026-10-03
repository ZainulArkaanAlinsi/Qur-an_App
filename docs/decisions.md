# Catatan keputusan

Satu baris per keputusan: tanggal · keputusan · alasan · rujukan. Keputusan di sini **tidak dibahas ulang** kecuali pemilik membukanya lagi; kalau berubah, tambah baris baru yang menyebut baris lama, jangan menghapus.

| Tanggal | Keputusan | Alasan | Rujukan |
| --- | --- | --- | --- |
| 2026-09-22 | State management tetap `ChangeNotifier`/`InheritedNotifier`, tanpa paket | Sudah cukup, tidak menambah dependensi | `CLAUDE.md` (Larangan) |
| 2026-09-22 | Teks Tanzil Uthmani 1.0.2 + terjemahan `id.indonesian` 2010 dibundel; verbatim | Lisensi jelas, luring | `docs/DATA_SOURCES_AND_LICENSES.md` |
| 2026-09-22 | Aplikasi tetap non-komersial (tanpa iklan/IAP/langganan) | Lisensi terjemahan Tanzil/Kemenag non-komersial | `docs/PLAY_STORE_RELEASE.md §5` |
| 2026-09-22 | EveryAyah tidak dipakai | Lisensi tidak jelas | `lib/data/audio_repository.dart` |
| 2026-09-25 | Nama tampilan MyQuran; package `com.zainularkaan.quran` tetap | Merek baru tanpa memutus pembaruan | `docs/design/v3/DESIGN.md` |
| 2026-09-25 | Mode mushaf dikunci di rilis | Menunggu izin KFGQPC & QUL | `docs/lisensi/` |
| 2026-09-25 | Materi tahap 6–16 dikunci di rilis | Wajib 2 peninjau bersanad | `docs/RELIGIOUS_CONTENT_GOVERNANCE.md` |
| 2026-09-25 | Aplikasi tidak pernah menilai bacaan secara otomatis | Kebijakan konten agama | `docs/RELIGIOUS_CONTENT_GOVERNANCE.md` |
| 2026-09-30 | Sesi hari ini: gratis, tanpa server, tanpa paket baru; rekaman hanya di HP | Permintaan pemilik | `docs/design/v5-sesi-harian/SESI_HARIAN.md` |
| 2026-10-02 | Rilis Play pertama memakai 1.10.x apa adanya ke **closed testing**; v6 menyusul sebagai update | Akun pribadi baru wajib 12 penguji × 14 hari berturut-turut sebelum Production; menunggu UI baru hanya menunda jam itu | `docs/PRD.md §3` |
| 2026-10-02 | Beranda memakai satu "Langkah berikutnya" dari `NextStepEngine` deterministik (tanpa aturan jam, tanpa acak) | Tiga tombol "Lanjutkan" membingungkan; aturan tetap mudah dites & dijelaskan | `docs/DATA.md §2` |
| 2026-10-02 | Tab bar + mini player menjadi satu dock kaca | Mengurangi kaca terlihat & tumpukan kartu; satu kontrol per audio | `docs/design/v6/screens/21-dock.md` |
| 2026-10-02 | Murottal menampilkan teks ayat yang sedang diputar; panel kontrol padat (bukan kaca) | Kebutuhan utama mendengar = mengikuti ayat; kaca dilarang di belakang teks ayat | `20-murottal.md`, v4 §2 |
| 2026-10-02 | Urutan tab tidak diubah (Beranda, Qur'an, Belajar, Hafalan, Saya) | Aturan CLAUDE.md; perubahan tanpa manfaat jelas | `CLAUDE.md` |
| 2026-10-02 | Waktu salat bisa otomatis dari lokasi; koordinat dibulatkan 2 desimal sebelum dikirim ke AlAdhan; Kemenag RI tetap bawaan | Permintaan pemilik; privasi | `22-pengaturan-salat.md` |
| 2026-10-02 | Qari baru (termasuk yang populer/viral) hanya dari sumber berizin; registri `granted/pending` | Hak cipta rekaman; risiko penghapusan dari Play | `23-qari.md` |
| 2026-10-02 | Tidak ada paket pub baru untuk v6 | Semua kebutuhan dipenuhi paket yang ada | `docs/design/v6/DESIGN.md §8` |
| 2026-10-02 | Aksi "Murajaah" di Beranda membuka tab Hafalan, tanpa layar antrean murajaah baru | Keputusan pemilik; layar latihan per surah sudah ada | `docs/DATA.md §2.4` |
| 2026-10-02 | Label langkah sesi di Lintasan memakai label kode: Ulang · Materi · Temukan · Tirukan · Selesai | Keputusan pemilik; satu sumber label dengan layar Sesi | `lib/features/session/domain/session_plan.dart`, `19-beranda.md §4` |
| 2026-10-03 | `rilis/1.10.1` digabung ke `fitur/v6` sebelum Murottal v6 | Rilis itu sudah mengubah tombol Unduh Murottal; menghindari dua versi & konflik saat v6 masuk `main` | PR #38, commit 70fa7a7 |
| 2026-10-03 | Ulang ×N (tahan tombol Ulang) berlaku untuk antrean yang sedang dimuat, mulai dari ayat sekarang | Keputusan pemilik; antrean tidak menyusut jadi satu ayat sehingga daftar ayat tetap tampil | `docs/DATA.md §5.2` |
| 2026-10-03 | Galat dan luring di Murottal memakai satu banner; tanpa deteksi konektivitas | Keputusan pemilik; tidak ada paket baru untuk v6 | `docs/DATA.md §5.2` |
| 2026-10-03 | Koordinat waktu salat dibulatkan ke kisi 0,025° (≈ 2,8 km), bukan 2 desimal (menggantikan sebagian baris 2026-10-02 "koordinat dibulatkan 2 desimal") | Play: *approximate location* = area ≥ 3 km²; 2 desimal (≈ 1,2 km²) termasuk lokasi presisi. Keputusan pemilik; efek ke jadwal < 5 detik | `docs/DATA.md §8`, support.google.com/googleplay/android-developer/answer/10787469 |
| 2026-10-03 | Pengguna yang belum memilih kota tetap memakai Jakarta (ditandai "(bawaan)" di layar Salat) | Keputusan pemilik; jadwal langsung tampil, pengguna bisa mengganti lewat lembar Waktu salat | `docs/DATA.md §8` |
| 2026-10-03 | Lembar Waktu salat hanya menyimpan setelan bila jadwalnya berhasil dimuat | Mencegah kota salah ketik / setelan yang tidak bisa dihitung tersimpan diam-diam | `prayer_settings_sheet.dart` |
| 2026-10-02 | Katalog qari terkurasi (35) + registri izin; rilis hanya sumber granted. | Hak cipta rekaman; qari populer hanya dari sumber berizin | `assets/audio/qari_katalog.json`, `lib/data/audio_sources.dart`, `23-qari.md` |
| 2026-10-02 | Quran Foundation diakses lewat bff/ di Cloudflare Workers (gratis); secret tidak di aplikasi; audio QF tanpa unduhan (batas 7 hari). | Developer Terms QF; tanpa biaya | `23-qari.md` §Sumber Quran Foundation |
| 2026-10-03 | Cadangan equran.id & MP3Quran (status pending) hanya aktif di build debug; rilis hanya Islamic Network | Keputusan pemilik; konsisten dengan registri izin. Bila CDN utama gagal, banner galat Murottal tampil | `quran_audio_service.dart`, `audio_sources.dart` |
| 2026-10-03 | Kunci app signing Play adalah kunci buatan Google (`ED:D3:…`). `ruang-tilawah-release.jks` menjadi kunci upload. Ini menggantikan saran "pakai kunci lama lewat PEPK" (PRD Q1) | Terjadi saat unggahan Internal testing pertama dan tidak bisa diganti dengan cara biasa. APK GitHub tidak bisa diperbarui langsung ke versi Play | `docs/PLAY_STORE_RELEASE.md §2` |
| 2026-10-03 | Setiap kunci penandatangan baru wajib didaftarkan di Firebase (sidik jari) **dan** di pembatasan API key Android (Google Cloud) | Tanpa pembatasan API key, Firebase Auth gagal `unknown` (`403 API_KEY_ANDROID_APP_BLOCKED`) walau Google Sign-In berhasil | `docs/PLAY_STORE_RELEASE.md §2` |
| 2026-10-03 | Pesan kartu akun (gagal masuk, hapus akun) ditulis di dalam kartu, bukan SnackBar | Kartu ada di lembar bawah; SnackBar tertutup lembar dan pengguna tidak melihat alasan gagal | `settings_screen.dart` `_SyncCard`, `test/account_sheet_message_test.dart` |
