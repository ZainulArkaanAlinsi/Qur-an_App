# Permintaan kejelasan lisensi — QUL mushaf layout

Naskah untuk menanyakan lisensi data tata letak mushaf di qul.tarteel.ai.
Latar belakangnya ada di `TAHAP_1_LISENSI.md` §1.

## Ke mana dikirim

QUL **tidak mempublikasikan alamat email**. Kanal yang ditunjuk FAQ-nya sendiri:

> "If you don't find what you're looking for, please open a new issue on our
> GitHub repository"

1. **Utama — GitHub issue** (paling mungkin dijawab, dan jawabannya jadi rujukan
   publik yang bisa dikutip nanti):
   <https://github.com/TarteelAI/quranic-universal-library/issues/new>
2. **Cadangan — live chat** di <https://support.tarteel.ai/en/> (ada kotak chat
   di sudut halaman). Tempel naskah yang sama.

Jangan menebak alamat email. Kalau nanti ada yang membalas dari alamat tertentu,
catat alamat itu di tabel paling bawah.

## Judul

```
Licence for the mushaf layout resources (KFGQPC V1 / V2) — bundling in a free offline app
```

## Isi

```
Assalamu'alaikum,

Thank you for QUL — having the mushaf layout data gathered in one place is a
real service to everyone building Qur'an apps.

I am an independent developer working on Ruang Tilawah, a free Android app for
Indonesian users. It has no ads, no paywall and nothing for sale; it is handed
out as an APK through public GitHub releases. I would like to use QUL's mushaf
layout data so the app can show pages the way the printed mushaf lays them out,
and I want to get the permissions right before shipping anything.

What I would like to use:

  - KFGQPC V1 layout (1405H print) — /resources/mushaf-layout/15
  - KFGQPC V2 layout (1421H print) — /resources/mushaf-layout/10

How I would use it: download the SQLite file once, bundle it inside the app as
read-only data, and use the page and line records to render pages offline. I
would not re-publish the database as a downloadable dataset of its own, and I
would not sell it or charge for access to it.

My question comes from the FAQ, which says:

  "The resources available on QUL vary in their copyright status. Some are in
   the public domain, while others may be subject to specific licenses. We
   recommend reviewing the licensing information provided by each resource's
   author before use."

I have gone through the resource pages for both layouts above and could not find
any licensing information on them — there is no licence field, and none of the
mushaf-layout pages appear to carry one. I understand the MIT licence in the
repository covers the QUL software itself rather than the data.

So, concretely:

  1. Is there a licence or permission statement for these two layout resources
     that I have missed? If so, where can I read it?
  2. If there is none published, may these layout databases be bundled inside an
     application that is distributed free of charge, as described above?
  3. What attribution would you like displayed? I am happy to credit both
     QUL/Tarteel and the King Fahd Glorious Quran Printing Complex wherever you
     think is appropriate, and to link back to qul.tarteel.ai.
  4. Since the layouts originate with KFGQPC, is this something I should be
     asking them directly instead? If so, is there a contact you would suggest?

If there are conditions attached, I would rather hear them and follow them than
guess. If the answer is that the data should not be bundled, that is a clear
answer too and I will look elsewhere — I would simply rather not ship something
I do not have permission for.

Jazakumullahu khayran for your time and for the work you have put into QUL.

Wassalamu'alaikum,

Zainul Arkaan
Ruang Tilawah — https://github.com/ZainulArkaanAlinsi/Qur-an_App
```

## Catatan saat mengirim

- Tulis di **satu** issue saja; jangan dipecah per resource.
- Jangan menyertakan tangkapan layar yang memuat isi datanya.
- Simpan tautan issue-nya di tabel ini setelah dibuat, dan tempel jawabannya
  begitu ada — itu nanti jadi bukti izin yang dikutip di
  `docs/DATA_SOURCES_AND_LICENSES.md`.

| Dikirim | Kanal | Tautan | Jawaban |
|---|---|---|---|
| (isi tanggalnya) | GitHub issue | | |
