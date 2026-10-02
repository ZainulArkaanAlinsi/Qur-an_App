# 23-qari — Pilihan qari v6 (lebih banyak, lebih mudah dipilih)

**Kode:** `lib/screens/reciter_picker.dart`, `lib/data/reciter_repository.dart`, `lib/data/audio_repository.dart`, `lib/models/reciter.dart`
**Dibuka dari:** chip qari di Murottal (`20-murottal.md`), Saya → Pengaturan → Qari.

## Kondisi sekarang

- Daftar qari per ayat diambil dari `api.alquran.cloud/v1/edition?format=audio&type=versebyverse` (audio di `cdn.islamic.network`). Per 2 Oktober 2026 daftar itu memuat **17 qari berbahasa Arab** (a.l. Alafasy, As-Sudais, Ash-Shuraym, Maher Al-Muaiqly, Hudhaify, Husary + Mujawwad, Abdul Basit/Abdul Samad, Ahmed Al-Ajamy, Abu Bakr Ash-Shaatree, Hani Rifai, Abdullah Basfar, Ibrahim Akhdar, Muhammad Ayyoub, Muhammad Jibreel, Ayman Sowaid, Parhizgar). Banyak yang belum terlihat karena daftarnya polos dan panjang.
- equran.id (6 qari, termasuk **Yasser Al-Dosari** dan Abdullah Al-Juhany) dan MP3Quran baru dipakai sebagai cadangan dan **menunggu izin** (`docs/lisensi/`).

## Aturan izin (tidak bisa ditawar)

Rekaman bacaan punya hak cipta qari/penerbitnya. **Qari hanya tampil di build rilis bila sumbernya berizin** (status `granted` di registri, bukti di `docs/lisensi/bukti/`). Qari yang menunggu izin hanya tampil di build debug dengan lencana "MENUNGGU IZIN". Tidak mengambil audio dari YouTube, TikTok, Instagram, atau situs yang tidak mencantumkan izin, berapa pun populernya.

## Registri sumber audio (baru)

`lib/data/audio_sources.dart`:

```dart
enum LicenseStatus { granted, pending }

class AudioSourceInfo {
  final String id;                 // 'islamic_network', 'equran', 'mp3quran', 'qul', 'langsung_qari'
  final String name;
  final LicenseStatus status;      // diubah HANYA setelah bukti izin disimpan
  final String evidencePath;       // docs/lisensi/bukti/...
  final bool perAyah;              // false = per surah saja (tidak bisa ulang ayat)
}
```

- `ReciterRepository` menggabungkan daftar dari semua sumber `granted` (+ `pending` bila `kDebugMode`).
- Qari dari sumber per surah (tidak `perAyah`) tetap bisa diputar penuh, tapi tombol Ulang ayat/Rentang dan Sesi harian memakai qari per ayat bawaan; tampilkan keterangan "Qari ini hanya per surah".
- Tes: di mode rilis tidak ada `Reciter` dari sumber `pending`.

## Tampilan pemilih (lembar penuh)

1. Pencarian di atas (nama Latin & Arab).
2. **Dipilih** (1 baris, qari aktif, centang).
3. **Populer di Indonesia** — urutan terkurasi dari daftar berizin (bukan "viral" dari internet): Alafasy, As-Sudais, Maher Al-Muaiqly, Abdul Basit, Husary, Ash-Shuraym, Hudhaify, Ahmed Al-Ajamy, Minshawi (bila ada). Urutan disimpan di kode sebagai daftar identifier; yang tidak ada di sumber dilewati.
4. **Semua qari** A–Z.
5. Tiap baris: avatar inisial, nama Latin + nama Arab (sec), gaya (Murattal/Mujawwad/Muallim), tombol **dengar contoh** (`playPreview`, Al-Fatihah:1) dan status unduhan ("Tersimpan 3 surah").
6. Debug saja: bagian **Menunggu izin** dengan lencana.

## Qari populer yang diminta pemilik tapi belum berizin

Kandidat dari permintaan pemilik ("yang viral, suaranya bagus"): Yasser Al-Dosari, Abdullah Al-Juhany, Nasser Al-Qatami, Idris Abkar, Islam Sobhi, Muzammil Hasballah, Salim Bahanan. Langkahnya bukan kode, tapi izin:

| Qari | Jalur izin yang mungkin |
| --- | --- |
| Yasser Al-Dosari, Abdullah Al-Juhany | equran.id (sudah ada di `AudioRepository.equranQari`) → tunggu balasan izin equran.id |
| Nasser Al-Qatami, Idris Abkar, Islam Sobhi | MP3Quran (permintaan izin sudah disiapkan) atau QUL/Tarteel (#768) |
| Muzammil Hasballah, Salim Bahanan | Langsung ke qari/manajemennya lewat kanal resmi mereka. Zainul yang mengirim. |

Claude Code **tidak** menambahkan URL audio untuk qari ini sampai pemilik menyimpan bukti izin dan mengubah status di `audio_sources.dart` dalam commit tersendiri.

## Selesai jika

- Golden pemilih: terang/gelap, teks 2.0, pencarian kosong.
- Tes: registri menyaring `pending` di rilis; urutan Populer stabil; qari per surah menonaktifkan Ulang ayat dengan keterangan.
