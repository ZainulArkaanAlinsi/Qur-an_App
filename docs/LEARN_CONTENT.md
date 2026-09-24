# Menulis materi Belajar (`assets/learn/curriculum.json`)

Materi ditulis dan ditinjau manusia (`docs/RELIGIOUS_CONTENT_GOVERNANCE.md`).
Aplikasi hanya menampilkan isi berkas ini; ia tidak menambah kalimat, ciri
huruf, atau contoh ayat sendiri.

## Status

- `"review": "draft"` hanya tampil di build debug dengan label DRAF. Di rilis,
  tahapnya terlihat di jalur Belajar tetapi terkunci dengan keterangan
  "Materi sedang ditinjau".
- `"review": "published"` tampil di rilis dan bisa dibuka.

## Blok isi dan halaman

Di layar Pelajaran, **setiap blok `text` membuka halaman baru**. Blok `tip`,
`letters`, `example`, dan `audio` ikut halaman `text` sebelumnya. Semua blok
`quiz` dikumpulkan menjadi satu bagian *Latihan* di akhir. Jadi pelajaran
dengan 2 blok `text` dan beberapa soal punya 3 bagian ("1/3", "2/3", "3/3").

| Jenis | Isi | Catatan |
| --- | --- | --- |
| `text` | `text`, `heading` (opsional) | 2–3 kalimat. `heading` menjadi judul halaman (mis. "Huruf yang mirip"); tanpa `heading` judulnya nama tahap. `**kata**` ditebalkan. |
| `tip` | `text` | Kotak hijau lembut. |
| `letters` | `items`: `[{letter, name, note}]` | Kartu huruf besar, maksimal 3 sejajar. Contoh: `{"letter": "ب", "name": "Ba", "note": "1 titik di bawah"}`. Ciri huruf wajib diperiksa. |
| `example` | `surah`, `ayah`, `note` | Teks ayat diambil dari dataset Tanzil, tidak diketik. |
| `audio` | `label`, `asset` | Rekaman manusia berizin. Selama `asset` kosong, tampil "Audio contoh sedang disiapkan". Tanpa TTS. |
| `quiz` | `id`, `question`, `options`, `answer`, `explanation` | `id` tetap selamanya. Bila semua pilihan berupa huruf Arab (≤ 4), pilihan tampil besar sejajar. `explanation` muncul setelah dijawab ("Benar — …" / "Belum tepat — …"). |

Contoh satu halaman:

```json
{ "type": "text", "heading": "Huruf yang mirip",
  "text": "Bentuk dasarnya sama. Yang membedakan hanya **jumlah dan letak titiknya**." },
{ "type": "letters", "items": [
  { "letter": "ب", "name": "Ba", "note": "1 titik di bawah" },
  { "letter": "ت", "name": "Ta", "note": "2 titik di atas" },
  { "letter": "ث", "name": "Tsa", "note": "3 titik di atas" } ] },
{ "type": "audio", "label": "Bunyi ba, ta, tsa", "asset": null }
```
