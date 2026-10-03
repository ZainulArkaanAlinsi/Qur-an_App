# 20-murottal — Pemutar murottal v6 ("ikuti bacaan")

**Gambar acuan:** `V6-Murottal.png` · gelap `V6-Murottal-Gelap.png`
**HTML acuan:** `../html/V6-Murottal*.html`
**Kode:** `lib/screens/murottal_screen.dart` (dirombak), komponen baru di `lib/features/murottal/presentation/`
**Data & logika:** `docs/DATA.md §5`

## Tujuan
Mendengar sambil **mengikuti ayat yang sedang dibaca**, lalu mengatur ulang/kecepatan/timer/unduhan tanpa mencari-cari.

## Tata letak

1. **Bar atas**: kiri tombol tutup (chevron bawah, 40); tengah eyebrow "MUROTTAL · PER AYAT" 10.5/800 `sec` + nama surah 17/800; kanan tombol ⋯ (40) berisi menu: Buka di pembaca · Tampilkan/sembunyikan terjemahan · Hentikan murottal.
2. **Baris pilihan**: kiri chip qari (avatar inisial 28 `primary` + nama qari 13/800 + chevron) → `ReciterPicker`. Kanan `SegmentedPill` **Teks | Sampul** (disimpan di preferensi `murottal.tampilan`, bawaan Teks).
3. **Isi** (mengisi sisa layar, digulir di belakang panel):
   - **Teks** → `AyahFollowList` (§3).
   - **Sampul** → mihrab v2 (`_Plate` lama) diperkecil ke lebar 62% layar, nama surah Arab di dalamnya, dan **satu ayat aktif** di bawahnya (Arab + terjemahan, tanpa daftar).
4. **Panel kontrol** (padat `surf`, radius atas 30, bayangan ke atas; **bukan kaca**, karena teks ayat lewat di belakangnya):
   - Baris label: "Ayat 5 dari 7" 13/800 + kanan posisi/durasi ayat "0:01 / 0:06" tabular `sec`.
   - `AyahSegmentTrack` (§4).
   - Transport: Ulang (46, label kecil) · Sebelumnya (52) · **Putar/Jeda 78** (`primary`, ikon `surf`) · Berikutnya (52) · Kecepatan (46, label "1×").
   - Tiga pill sama lebar (tinggi 44): **Timer** · **Unduh** · **Rentang**.
   - Ruang bawah = inset gestur sistem.

Yang **dihapus**: kalimat "Waktu mendengar belum dicatat terpisah dari streak membaca." dan tombol Unduh yang non-aktif.

## 3. AyahFollowList

- Sumber teks: loader yang sama dengan `ReaderScreen` (Tanzil Uthmani + terjemahan aktif dari aset/unduhan). **Tidak** memuat dari jaringan; cari dulu nama loader-nya di kode, jangan membuat parser baru.
- Isi daftar = ayat dalam antrean (`AudioQueue.firstAyah..lastAyah`). Bila antrean > 300 ayat, daftar tetap lazy (`ScrollablePositionedList.builder`).
- Item tidak aktif: tanpa latar, nomor dalam lingkaran garis `tertiary` 26, Arab 25 `sec`, terjemahan 13.5 `sec`. **Jangan** pakai `tertiary` untuk teks: kontrasnya hanya 2.4 (terang) · 2.7 (sepia) terhadap `bg`. Ayat aktif dibedakan lewat kartu, ukuran, dan warna `ink`, bukan dengan meredupkan ayat lain.
- Item aktif: kartu `surf` radius 22, garis `primarySoft` 1.5, label kecil "DIPUTAR" + ikon equalizer `primaryText`, nomor dalam lingkaran `gold`/`goldSoft`, Arab 29 `ink`, terjemahan 14 `ink`.
- Mengikuti audio: saat `playingVerse` berubah, gulir ke item itu (posisi 30% dari atas). Kalau pengguna menggulir sendiri, auto-gulir berhenti 6 detik dan muncul pill "Kembali ke ayat yang diputar" di atas panel; ketuk → gulir & lanjut mengikuti.
- Ketuk item → lompat & putar dari ayat itu (masih dalam antrean). Tahan → menu: Bookmark · Buka di pembaca.
- Teks Arab: `SacredText.quran`, RTL, tanpa tinggi tetap, tanpa efek/opacity, tidak pernah di-clip (aturan CLAUDE.md). Terjemahan disembunyikan bila preferensi "tampilkan terjemahan" mati.

## 4. AyahSegmentTrack

- Antrean ≤ 40 ayat: satu segmen per ayat, celah 4, tinggi 7, radius 4. Selesai `primaryText`, belum `surf2`, aktif terisi `gold` sesuai `position/duration` (+ halo `goldSoft` 3).
- Antrean > 40 ayat: satu bar kontinu, isi = `(indeks + posisi/durasi) / panjang`.
- Ketuk segmen → lompat ke ayat itu. Geser horizontal → pilih ayat (haptic `selectionClick` per ayat), audio pindah saat jari diangkat.
- Pembaruan posisi dibatasi 10 Hz.

## 5. Tombol

| Tombol | Ketuk | Tahan | Status tampil |
| --- | --- | --- | --- |
| Ulang | Siklus: Mati → Ulang ayat → Ulang rentang (bila ada rentang) | Lembar jumlah ulang: 1×, 3×, 5×, 7×, ∞ (pakai `RangePlan`) | Aktif: latar `goldSoft`, ikon `goldText`, lencana angka (mis. "3") |
| Sebelumnya / Berikutnya | `previous()` / `next()` | — | Non-aktif (bukan disembunyikan) di ujung antrean, dengan semantics "Ayat pertama/terakhir" |
| Putar/Jeda | `togglePlayPause()` | — | Buffering: cincin progres tipis di tepi tombol |
| Kecepatan | Siklus 0.75 → 1 → 1.25 → 1.5 | — | Teks "0.75×" dst |
| Timer | Lembar: 5/10/15/30/45/60 mnt, Matikan (pakai `setSleepTimer`) | — | Aktif: "Berhenti 10:52" |
| Unduh | `AudioDownloadService.download(reciter, surah)` | — | "Unduh" → "45%" (bisa diketuk untuk batal) → "Tersimpan ✓" (ketuk = tawarkan hapus). Ukuran dari `estimateSize` tampil di lembar konfirmasi, bukan di pill |
| Rentang | Lembar: dari ayat · sampai ayat · jumlah ulang → `playRange(...)` | — | "1–7" sesuai antrean |

## Status

- **Tidak ada yang diputar**: ilustrasi mihrab kecil + "Murottal sedang tidak diputar" + tombol "Putar {surah terakhir dibaca} dari ayat {n}".
- **Error**: banner di atas panel (latar `goldSoft`, teks `ink`): "Murottal belum dapat diputar. Periksa koneksi atau unduh surah ini." + "Coba lagi". Tombol putar tetap bisa ditekan.
- **Luring & belum diunduh**: banner yang sama dengan "Unduh saat online".
- **Sumber cadangan** (`sourceNote` tidak null): teks kecil di bawah label ayat, mis. "Diputar dari sumber cadangan".

## Selesai jika

- Golden: Teks & Sampul × terang/gelap/sepia, teks 2.0, status error, tidak diputar.
- Tes widget: ayat aktif mengikuti `playingVerse`; ketuk segmen memanggil lompat ke indeks yang benar; gulir manual menghentikan auto-gulir dan pill "Kembali" muncul; Unduh memanggil `AudioDownloadService` dan statusnya berubah.
- Teks Arab di golden dibuka dan dicek: tidak ada harakat terpotong di atas/bawah.
- Tidak ada widget `Opacity` atau `ShaderMask` di atas teks ayat.
