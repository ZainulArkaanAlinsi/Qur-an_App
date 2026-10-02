# 23-qari — Pilihan qari v6.1 (banyak, bisa difilter, adem)

Menggantikan `23-qari.md` di paket v6.
**Gambar acuan:** `V6-Qari.png` (build rilis, filter Adem) · `V6-Qari-Debug-Gelap.png` (build debug, semua sumber)
**Data:** `docs/design/v6/data/qari_katalog.json` → dipindah ke `assets/audio/qari_katalog.json`
**Kode:** `lib/data/audio_sources.dart` (baru), `lib/data/qari_catalog.dart` (baru), `lib/data/reciter_repository.dart`, `lib/data/audio_repository.dart`, `lib/screens/reciter_picker.dart`, `lib/models/reciter.dart`, `bff/`

## Tujuan

Banyak qari, mudah dipilih menurut **suasana** (adem, merdu, untuk hafalan, imam Haramain, populer), bisa didengar contohnya sebelum dipilih, dan tetap aman secara hak cipta.

## Angka (per 2 Oktober 2026)

| | Jumlah |
| --- | --- |
| Qari di katalog | 35 |
| Tampil di **rilis sekarang** (sumber Islamic Network, status granted) | 17 |
| + bila Quran Foundation disetujui (lewat `bff/`) | +8 baru (a.l. **Yasser Al-Dosari, Saad Al-Ghamdi, Al-Minshawi, Bandar Baleela, Husary Muallim**) |
| + bila equran.id mengizinkan | +3 baru (**Abdullah Al-Juhany**, Ibrahim Al-Dossari, Abdul Muhsin Al-Qasim; Yasser juga ada di sini) |
| + bila QUL / MP3Quran mengizinkan | +4 baru (Nasser Al-Qatami, Khalid Al-Jalil, Idris Abkar, Muhammad Al-Luhaidan) |
| + izin langsung qari | Muzammil Hasballah, Salim Bahanan |
| Belum ada sumber berizin | Islam Sobhi |

## Aturan izin (tidak bisa ditawar)

- Qari tampil di **build rilis** hanya bila minimal satu sumbernya berstatus `granted` di `audio_sources.dart`. Status diubah **hanya** setelah bukti izin disimpan di `docs/lisensi/bukti/` dan dalam commit tersendiri yang menyebut buktinya.
- Build debug menampilkan semua qari, yang belum berizin diberi lencana **MENUNGGU IZIN** (agar pemilik bisa menguji alur).
- Audio tidak pernah diambil dari YouTube, TikTok, Instagram, Google Drive, atau situs yang tidak menyatakan izin, sepopuler apa pun qarinya.
- Tag suasana adalah **kurasi**, bukan fakta tentang qari. Tidak ada kalimat yang merendahkan qari mana pun; tidak ada peringkat "terbaik".

## Katalog (`qari_katalog.json`)

```json
{
  "diperbarui": "2026-10-02",
  "suasana": { "tenang": "Tenang & adem", "merdu": "Merdu", "hafalan": "...", "belajar": "...", "imam_dua_masjid": "Haramain ...", "populer": "Populer sekarang" },
  "populer": ["yasser", "alafasy", "muzammil", ...],        // urutan bagian "Populer sekarang"
  "sumber": { "islamic_network": { "status": "granted", ... }, ... },
  "qari": [ { "id": "maher", "nama": "...", "gaya": "murattal", "suasana": ["imam_dua_masjid", "tenang"],
             "negara": "...", "sumber": [ { "sumber": "islamic_network", "ref": "ar.mahermuaiqly", "perAyat": true } ] } ]
}
```

- `ref: null` = identifier belum diketahui. Claude Code mencarinya dari API sumber (cocokkan nama), **bukan menebak**, lalu menulis hasilnya ke JSON dengan komentar sumber di PR.
- Nama Arab qari tidak ditulis di JSON. Ambil dari API sumber (alquran.cloud memberi `name` Arab); kalau tidak ada, tampilkan nama Latin saja.
- "Populer sekarang" = daftar kurasi pemilik yang diperbarui tiap rilis (tanggal `diperbarui` tampil kecil di bawah judul bagian). Tidak ada pelacakan pengguna untuk menghitung tren.
- Status sumber di JSON hanya informasi; **sumber kebenaran status adalah `audio_sources.dart`** (kode, ikut ditinjau di PR). Tes memastikan keduanya konsisten.

## Tampilan (lembar penuh)

1. Bar atas: tutup + "Pilih qari".
2. Cari (nama Latin; juga nama Arab bila tersedia).
3. Chip filter, satu baris bisa digeser: **Semua · Adem · Populer · Hafalan · Merdu · Haramain**. Chip terakhir dipakai disimpan (`qari.filter`).
4. **Dipilih**: qari aktif dengan centang.
5. Daftar sesuai filter, judul bagian "ADEM · 8 QARI". Filter Semua dibagi: **Populer sekarang** (urutan dari `populer`, hanya yang tampil) lalu **Semua A–Z**.
6. Baris (tinggi ≥ 64): avatar inisial (lingkaran `primarySoft`, dipilih = `primary`), nama 14.5/800 (elipsis), sub "Murattal · Arab Saudi" + **satu** tag suasana (`goldSoft`/`goldText`), tombol dengar contoh 40 (`playPreview`, Al-Fatihah:1; ketuk lagi = berhenti; hanya satu contoh berbunyi).
7. Ketuk baris = pilih → simpan → antrean yang sedang diputar dimuat ulang dengan qari baru di ayat yang sama.
8. Qari dengan sumber **per surah saja** (tanpa per ayat): sub menyebut "per surah"; saat dipilih, tombol Ulang ayat & Rentang di Murottal menampilkan keterangan "Qari ini per surah. Ulang ayat memakai {qari per ayat bawaan}." Sesi harian selalu memakai qari per ayat.
9. Status unduhan per qari ("Tersimpan 3 surah") tetap ada di Saya → Unduhan, tidak di baris ini (baris jadi terlalu padat).

## Sumber Quran Foundation (paling cepat untuk Yasser Al-Dosari dkk.)

- Lewat `bff/` yang sudah ada (secret tidak pernah masuk aplikasi). Tambah endpoint `GET /v1/recitations/:id/chapters/:chapter/audio` yang mengembalikan URL audio per ayat (+ durasi bila ada).
- Deploy gratis: **Cloudflare Workers** (Hono berjalan native; paket gratis cukup untuk aplikasi kecil). Render/Cloud Run disebut README lama; pilih yang tanpa biaya dan tanpa kartu kredit wajib. Pemilik yang membuat akun dan mengisi secret.
- Developer Terms: konten (termasuk daftar URL) **tidak boleh disimpan > 7 hari**. Maka untuk qari dari sumber ini: streaming boleh; tombol **Unduh** disembunyikan, atau unduhan otomatis dihapus setelah 7 hari dengan keterangan jelas. Pilih yang pertama untuk rilis awal.
- Proyek baru di Developer Console mulai **prelive** (hanya Al-Fatihah & Al-Baqarah). Status `granted` baru setelah akses produksi disetujui.

## Selesai jika

- Golden `V6-Qari` (rilis) dan `V6-Qari-Debug-Gelap` cocok; teks 2.0 tanpa label terpotong.
- Tes: (a) mode rilis tidak pernah menampilkan qari tanpa sumber granted; (b) status di JSON = status di `audio_sources.dart`; (c) filter & urutan Populer stabil; (d) `ref: null` tidak pernah dipakai untuk membentuk URL; (e) qari per surah memberi keterangan di Murottal; (f) qari Quran Foundation tidak menampilkan Unduh.
- `bff/`: tes endpoint audio, secret hanya dari environment, cache ≤ 7 hari.
