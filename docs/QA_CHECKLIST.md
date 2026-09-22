# QA checklist

Centang per rilis/fase. Otomatis = ada tes/skrip; Manual = butuh manusia.

## Definition of Done per fase

- [ ] Fitur jalan di perangkat Android nyata dan emulator
- [ ] `flutter analyze` tanpa error, `flutter test` lulus
- [ ] Tidak ada teks Al-Qur'an yang diubah
- [ ] Tidak ada secret di source, APK, atau log (`grep` artefak build)
- [ ] Sumber & lisensi tercatat di docs dan menu Konten & sumber
- [ ] Layout Arab tidak overflow (font 200%, layar sempit, landscape)
- [ ] State offline/error/loading tersedia
- [ ] Aksesibilitas dasar: semantic label ikon, target sentuh ≥ 48dp
- [ ] Konten agama berstatus approved + reviewer
- [ ] README dan docs diperbarui

## Integritas Al-Qur'an

- [x] Otomatis: 114 surah, 6.236 ayat, jumlah ayat per surah
      (`test/quran_catalog_test.dart`, `test/translation_test.dart`)
- [ ] Otomatis: SHA-256 aset `assets/quran/raw/*` = nilai di
      `DATASET_ATTRIBUTION.md` (saat ini hanya tercatat, belum diuji)
- [ ] Otomatis: basmalah — Al-Fatihah ayat 1, surah lain di header, At-Taubah
      tanpa basmalah, tidak ganda
- [ ] Otomatis: golden test ayat dengan banyak harakat, waqaf, sajdah, ligatur
- [ ] Manual: sampling awal/tengah/akhir setiap surah oleh reviewer
- [x] Tidak ada normalisasi Unicode di pipeline tajwid (tes identik byte)

## Tajwid

- [x] Otomatis: teks polos parser = markup tanpa tag (fixture)
- [x] Otomatis: runs menutup teks tanpa celah; nesting ditangani
- [x] Otomatis: class asing ditolak, markup rusak → FormatException
- [x] Otomatis: audit 6.236 ayat (`tool/tajweed_audit.dart`) — 32:3 ditolak
- [x] Otomatis: widget test TextSpan tajwid, sorot segmen, chip, legend,
      toggle, fallback polos (`test/tajweed_widget_test.dart`)
- [x] Otomatis: kontras palet ≥ 4:1 terhadap permukaan kartu terang/gelap
- [ ] Manual: render di perangkat — sambungan huruf di batas warna (sudah
      dicek sekali di render host dengan Amiri, 22 September 2026)
- [ ] Manual: legend, kontras, buta warna; warna hafalan tidak mengenai glyph
- [ ] Manual: seluruh kategori diperiksa guru tajwid

## Layout mushaf

- [ ] Otomatis: 604 halaman tanpa overflow/missing glyph/baris terpotong
- [ ] Golden: halaman 1, 2, pembuka surah, sajdah, 604
- [ ] Pasangan dua halaman: ganjil kanan, genap kiri; sisi kosong netral
- [ ] Rotasi masuk/keluar mode landscape dipulihkan
- [ ] Visual regression vs render resmi edisi yang sama
- [ ] Manual: sampling tiap juz + tiap halaman pembuka surah

## Font

- [ ] Setiap font Arab lulus dataset uji (waqaf, mad, hamzah, lafaz Allah,
      sajdah, nomor ayat); font gagal tidak ditawarkan
- [ ] Fallback tidak mengubah teks/arah; QCF hanya dengan halaman yang sesuai

## Audio

- [ ] URL kedaluwarsa, koneksi putus, resume, seek, repeat, background,
      ganti qari
- [ ] Highlight kata mati bila timing tidak tersedia
- [ ] Resource dihapus provider → pesan aman + opsi qari lain

## Umum

- [ ] Integration: baca → audio → bookmark → offline → restart
- [ ] Privasi: mikrofon hanya setelah izin eksplisit; rekaman lokal default
