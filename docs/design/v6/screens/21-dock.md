# 21-dock — Tab bar + "sedang diputar" dalam satu dock

**Gambar acuan:** `V6-Beranda.png` (diam), `V6-Beranda-Diputar.png` (diputar), `V6-Komponen.png` baris "Dock" (tiga status)
**Kode:** `lib/app/widgets/app_dock.dart` (baru), `lib/app/app_shell.dart`, `lib/features/murottal/presentation/now_playing_row.dart` (baru). `FloatingTabBar` dan `AudioMiniPlayer` dipensiunkan setelah semua pemanggil pindah.
**Bergantung pada:** `LiquidGlass` dari `docs/design/v4-liquid-glass/LIQUID_GLASS.md` (ukuran `bar`).

## Struktur

```
AppDock (satu LiquidGlass, radius 32, margin kiri/kanan 12, bawah max(24, inset gestur))
├─ [AnimatedSize] NowPlayingRow   ← hanya bila queue != null
│    ├─ mihrab mini 34×42 berisi nomor ayat (goldLine)
│    ├─ judul "Al-Fatihah · Ayat 3" 14/800 (elipsis) + sub "Hudhaify · per ayat" 12/600 sec
│    ├─ Putar/Jeda 42 (lingkaran primary, ikon surf)
│    └─ Berikutnya 42
│    └─ AyahSegmentTrack mini (tinggi 3, celah 3; > 40 ayat = bar kontinu) + garis pemisah hairline
└─ Tabs (tinggi 64, padding 4): Beranda · Qur'an · Belajar · Hafalan · Saya
```

- **Satu** permukaan kaca untuk keduanya. Tidak ada kartu hijau terpisah di atas tab bar.
- Scrim padat lama (`[bg, bg, bg→0]` setinggi 140) **dihapus** (v4 B2). Isi yang digulir terlihat samar di balik dock.
- Teks sub baris sedang diputar mengikuti status: "Hudhaify · per ayat" · "Ulang ayat · 2/3" · "Rentang 1–20 · 2/3" · "Memuat…" · "Sumber cadangan".

## Tab

- Ikon 22 (`SacredIcons`), label 11/600; aktif: label 800 `primaryText`, ikon stroke tebal, **lensa** `LiquidGlass` kecil (tint `primarySoft` 92%) dengan inset 4 dari tepi dock di semua sisi — lensa tidak boleh menyentuh/keluar dari tepi kapsul (bug 1.10.0).
- Lensa meluncur dengan pegas v4; geser jari di dock menggerakkan lensa lalu menempel ke tab terdekat; `HapticFeedback.selectionClick` saat tab berganti.
- Tanpa `InkWell`/ripple. Umpan balik tekan: skala 0.94 selama 90 ms.
- Label tidak pernah dielipsis; skala teks dock dibatasi 1.3 (seperti sekarang).

## Gestur di baris sedang diputar

| Gestur | Aksi |
| --- | --- |
| Ketuk baris | Buka `MurottalScreen` (transisi: mihrab mini → `Hero` ke sampul/ayat aktif) |
| Geser ke atas (> 40 px atau kecepatan > 600) | Buka `MurottalScreen` |
| Geser ke bawah (> 40 px) | `stop()`; dock kembali 64; `SnackBar` "Murottal dihentikan" + **Urungkan** (pakai `resumePoint()`/`restore()`) selama 4 detik |
| Ketuk Putar/Jeda, Berikutnya | Langsung ke `QuranAudioService` |

Pengganti gestur untuk pembaca layar: `customSemanticsActions` "Buka pemutar" dan "Hentikan murottal".

## Tinggi yang harus disisakan layar

`AppDock.reservedHeightOf(context)` = tinggi dock saat ini (64 atau 64 + 62 + 9) + jarak bawah + 16. Semua halaman tab memakai nilai ini untuk padding bawah daftar (ganti konstanta `FloatingTabBar.reservedHeight` dan `padding: bottom: 120`). Nilai ini dibungkus `ValueListenable` supaya halaman ikut bergeser saat dock memanjang.

## Di layar lain

- **Pembaca (`ReaderScreen`)**: tidak memakai dock tab. Pakai `NowPlayingRow` yang sama di atas nav pembaca (satu `LiquidGlass`, maks 2 kaca terlihat di pembaca — aturan v4).
- **Layar penuh lain** (Sesi, Pelajaran, Murottal): dock disembunyikan.

## Selesai jika

- Golden dock: diam × 5 tab aktif (terang), diputar (terang, gelap, sepia, kontras tinggi = padat), rentang panjang, teks 1.3.
- Tes widget: queue null → tinggi 64; queue ada → baris muncul; geser bawah memanggil `stop` dan Urungkan memanggil `restore`; reservedHeight berubah saat memanjang.
- `glass_audit.sh`: tidak ada GAGAL baru; jumlah kaca terlihat di Beranda ≤ 3 (dock + lensa + tidak ada yang lain).
