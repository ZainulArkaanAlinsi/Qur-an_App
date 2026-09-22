# BFF Quran Foundation

Proxy kecil supaya `client_id`/`client_secret` Quran Foundation **tidak pernah
masuk aplikasi Flutter**. Dokumentasi provider menyatakan alur client
credentials tidak boleh dipakai aplikasi mobile, dan Developer Terms meminta
secret hanya hidup di server.

Status: kerangka Fase 0. Belum dipakai aplikasi dan belum di-deploy.

## Jalankan lokal

```bash
cd bff
npm install
cp .env.example .env    # isi QF_CLIENT_ID dan QF_CLIENT_SECRET
npm run dev             # http://localhost:8787/v1/health
npm test
npm run typecheck
```

Kredensial didapat dari <https://dev-console.quran.foundation/projects>.
Proyek baru mulai di **prelive**, yang datanya hanya Al-Fatihah dan Al-Baqarah;
dataset penuh perlu persetujuan akses produksi.

## Endpoint

| Endpoint | Isi |
|---|---|
| `GET /v1/health` | Status dan nama lingkungan |
| `GET /v1/chapters` | 114 surah (nama Arab/Latin, jumlah ayat, rentang halaman) |
| `GET /v1/recitations` | Daftar qari dinamis |
| `GET /v1/mushaf/v2/pages/:page` | Kata satu halaman QCF V2 (1–604) |
| `GET /v1/chapters/:chapter/tajweed` | Markup `text_uthmani_tajweed` per surah |

Respons memakai bentuk milik aplikasi (mis. `verseKey`, `glyph`), bukan
salinan mentah payload provider.

Endpoint halaman menutupi satu keanehan provider: `verses/by_page/{n}` memilih
ayat menurut halaman **QCF V1**, sedangkan `page_number`/`line_number` tiap
kata mengikuti mushaf yang diminta. Server mengambil halaman tetangga lalu
menyaring kata milik halaman yang benar.

## Aturan yang ditegakkan kode

- **Secret hanya dari environment.** Server menolak start bila kredensial
  kosong, dan pesan error hanya menyebut nama variabel.
- **Token:** Basic auth, `grant_type=client_credentials`, scope `content`,
  umur 3600 detik. Token dipakai ulang, diperbarui 30 detik sebelum
  kedaluwarsa, satu permintaan token untuk panggilan serentak, dan `401`
  dicoba ulang **satu kali** saja.
- **Cache maksimal 1 minggu.** Developer Terms melarang menyimpan konten lebih
  lama kecuali lewat Content Sync, jadi `CACHE_TTL_*` divalidasi dengan batas
  604.800 detik. Cache hanya di memori dan hilang saat proses berhenti.
- **Rate limit per klien.** Angka resmi provider tidak dipublikasikan, jadi
  `RATE_LIMIT_PER_MINUTE` adalah batas milik kita sendiri.
- **Timeout dan error aman.** Panggilan yang menggantung dibatalkan (504);
  pesan provider tidak diteruskan apa adanya.
- **Log tanpa identitas.** Hanya metode, rute, status, dan durasi.

## Belum dikerjakan

- Deploy (kandidat: Cloud Run atau Render) dan secret manager.
- Klien Dart di aplikasi; saat ini layar debug masih memanggil api.quran.com
  langsung.
- Audio, terjemahan, tafsir, dan Content Sync.
- Cache bersama antar-instance (sekarang per proses).

Sumber ketentuan: <https://api-docs.quran.foundation/docs/quickstart/>,
<https://api-docs.quran.foundation/legal/developer-terms/>.
