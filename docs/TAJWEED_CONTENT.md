# Cara mengisi materi tajwid

Materi tajwid di aplikasi ini **ditulis manusia**. Aplikasi hanya menampilkan
apa yang ada di `assets/learn/tajweed_lessons.json`. Tidak ada satu kalimat pun
yang dibuat otomatis, sesuai aturan di `docs/RELIGIOUS_CONTENT_GOVERNANCE.md`.

Selama berkas itu kosong, layar Belajar menampilkan keadaan sebenarnya: materi
belum ada. Itu disengaja — lebih baik kosong daripada salah.

## Yang perlu disiapkan

Untuk tiap hukum tajwid yang mau dimuat:

- **title** — nama hukum sebagaimana kamu ingin ditampilkan
- **summary** — satu kalimat pendek, muncul di daftar
- **detail** — penjelasan lengkap, muncul saat dibuka
- **examples** — daftar contoh, masing-masing berisi nomor `surah`, nomor
  `ayah`, dan `note` (keterangan singkat, mis. bagian mana yang dimaksud)

**Teks ayat tidak perlu kamu tulis.** Cukup nomor surah dan ayatnya; aplikasi
mengambil teks Arabnya dari dataset Tanzil yang sudah dibundel. Ini menjaga
ayat tetap verbatim dan menghilangkan risiko salah ketik.

## Sumber dan peninjau wajib diisi

Bagian `source` harus terisi, khususnya `title` (judul buku/sumber) dan
`reviewedBy` (nama orang yang memeriksa). Kalau kosong, aplikasi tetap tidak
menampilkan materinya walau `lessons` sudah ada isinya. Ini penjaga, bukan
formalitas: pembaca berhak tahu materi itu dari mana dan siapa yang memeriksa.

## Nilai `rule` yang dikenali

Harus persis salah satu dari daftar ini. Nilai lain ditolak saat dimuat,
supaya materi dan pewarnaan ayat merujuk hukum yang sama:

| `rule` | Hukum |
| --- | --- |
| `ham_wasl` | Hamzah Washal |
| `laam_shamsiyah` | Lam Syamsiyah |
| `slnt` | Huruf tidak dibaca |
| `madda_normal` | Mad Thabi'i |
| `madda_permissible` | Mad Jaiz |
| `madda_obligatory` | Mad Wajib |
| `madda_necessary` | Mad Lazim |
| `qalaqah` | Qalqalah |
| `ikhafa` | Ikhfa Haqiqi |
| `ikhafa_shafawi` | Ikhfa Syafawi |
| `idgham_ghunnah` | Idgham Bighunnah |
| `idgham_wo_ghunnah` | Idgham Bilaghunnah |
| `idgham_shafawi` | Idgham Mimi |
| `idgham_mutajanisayn` | Idgham Mutajanisain |
| `idgham_mutaqaribayn` | Idgham Mutaqaribain |
| `iqlab` | Iqlab |
| `ghunnah` | Ghunnah |

Nama Indonesia pada kolom kanan berstatus draft dan ikut perlu ditinjau.
Tidak semua hukum harus diisi sekaligus; isi yang sudah siap saja.

## Bentuk berkasnya

```json
{
  "version": 1,
  "source": {
    "title": "Judul buku atau sumber",
    "author": "Nama penulis",
    "url": "Pranala bila ada",
    "reviewedBy": "Nama peninjau",
    "reviewedOn": "2026-09-23"
  },
  "lessons": [
    {
      "rule": "idgham_ghunnah",
      "title": "Judul yang tampil",
      "summary": "Satu kalimat untuk daftar.",
      "detail": "Penjelasan lengkap.",
      "examples": [
        { "surah": 2, "ayah": 5, "note": "Keterangan singkat" }
      ]
    }
  ]
}
```

Tanggal memakai format `YYYY-MM-DD`.

## Memeriksa hasil isian

```
flutter test test/tajweed_lesson_test.dart
```

Pemuatnya gagal-tertutup: satu entri rusak membatalkan seluruh materi, bukan
menampilkannya separuh. Yang ditolak antara lain nilai `rule` di luar daftar,
hukum yang ditulis dua kali, bagian `title`/`summary`/`detail` yang kosong, dan
nomor ayat yang melebihi jumlah ayat surahnya.
