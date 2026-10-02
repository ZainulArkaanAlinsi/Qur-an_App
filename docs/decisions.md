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
