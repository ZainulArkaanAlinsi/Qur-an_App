# Pernyataan pemilik: data tata letak mushaf (KFGQPC / QUL)

Tanggal: 15 November 2026
Dicatat oleh: asisten pengembangan, atas pernyataan pemilik (Zainul Arkaan) dalam sesi kerja.

## Isi pernyataan

Pemilik menyatakan bahwa izin untuk memakai data tata letak mushaf (KFGQPC dan
QUL) sudah ia peroleh, dan bahwa ia memegang kredensial Quran Foundation serta
akan men-deploy server perantara (BFF) sendiri.

## Yang ini BUKAN

- Bukan salinan izin tertulis dari KFGQPC, QUL, atau Quran Foundation. Tidak ada
  surat, e-mail, atau tangkapan layar yang tersimpan di repositori.
- Bukan bukti bahwa akses produksi Quran Foundation sudah disetujui. Lingkungan
  prelive hanya memuat Al-Fatihah dan Al-Baqarah.

## Akibat di kode

- Mode mushaf 1/2 halaman **tetap mati bawaan**. Ia hidup hanya pada build yang
  diberi `BFF_BASE_URL` (APK GitHub: `MYQURAN_BFF_URL` untuk
  `tool/build_release.ps1`).
- Tidak ada dataset tata letak yang dibundel di APK; halaman diambil lewat BFF.
- Kredit tata letak mushaf tampil di Sumber & Lisensi hanya pada build yang
  memakai BFF.

## Yang masih perlu pemilik sebelum rilis publik

1. Simpan salinan izin KFGQPC/QUL (surat atau e-mail) di folder ini, lalu
   ubah baris "QUL / KFGQPC" di `docs/lisensi/STATUS_HAK_CIPTA.md` ke tertulis.
2. Deploy BFF dan isi `QF_CLIENT_ID`, `QF_CLIENT_SECRET` hanya di server.
3. Ajukan dan tunggu persetujuan akses produksi Quran Foundation.
