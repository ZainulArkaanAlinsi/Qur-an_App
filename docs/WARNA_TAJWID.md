# Warna tajwid (palet draf)

Revisi 1.9.1, 25 September 2026. Palet ini tetap **draf** sampai diperiksa guru tajwid.
Yang berubah hanya **nilai warna**: hukum, data tajwid (cpfair/quran-tajweed), dan
teks ayat tidak berubah.

## Kenapa diubah

Beberapa warna terlalu samar di latar ayat. Terendah adalah abu hamzah washal / lam
syamsiyah / huruf tidak dibaca: **3.54 : 1** di ayat yang sedang diputar. Targetnya:
setiap warna tajwid **≥ 4.5 : 1** di semua permukaan ayat, yaitu kartu, latar, ayat aktif
(sedang diputar), dan ayat bertanda, di palet hijau, sepia, dan kontras tinggi, terang dan
gelap. Target ini diperiksa otomatis oleh `test/tajweed_widget_test.dart`.

Aturan saat mengubah warna:

- Abu tetap lebih redup daripada tinta, karena memang menandai huruf yang tidak dibaca.
- Tiga warna mad tetap satu keluarga biru dengan urutan terang-gelap yang sama.
- Pasangan hukum yang mudah tertukar (ΔE2000 < 15) tidak boleh menjadi lebih mirip.
  Pasangan lain tetap ≥ 15.

Latar ayat aktif/bertanda di palet **kontras tinggi** disamakan dengan palet hijau. Latar
lama yang lebih pekat justru membuat warna tajwid di sana paling samar (abu 3.35).

Kontras dihitung sebagai rasio WCAG dari luminans relatif sRGB, di permukaan terburuk.
Jarak warna memakai CIEDE2000. Warna yang berubah ditandai ✱.

#### Terang

| Hukum | Lama | Baru | Kontras terburuk lama → baru | ΔE lama→baru |
| --- | --- | --- | --- | --- |
| hamzah washal / lam syamsiyah / tidak dibaca ✱ | `#7A7A7A` | `#676767` | 3.54 → **4.66** | 7.5 |
| mad thabi'i ✱ | `#2F5FE0` | `#0B5FE0` | 4.51 → **4.64** | 1.9 |
| mad jaiz | `#3340D0` | `#3340D0` | 6.21 → **6.21** | 0.0 |
| mad wajib | `#0A1596` | `#0A1596` | 11.09 → **11.09** | 0.0 |
| mad lazim | `#5A0F8C` | `#5A0F8C` | 9.19 → **9.19** | 0.0 |
| qalqalah | `#C8000A` | `#C8000A` | 5.00 → **5.00** | 0.0 |
| ikhfa haqiqi | `#8A009C` | `#8A009C` | 6.76 → **6.76** | 0.0 |
| ikhfa syafawi | `#B0009A` | `#B0009A` | 5.22 → **5.22** | 0.0 |
| idgham bighunnah ✱ | `#127A60` | `#00765F` | 4.35 → **4.60** | 1.8 |
| idgham bilaghunnah ✱ | `#1F7A12` | `#1D7810` | 4.49 → **4.62** | 0.7 |
| idgham mimi ✱ | `#3C8A00` | `#587000` | 3.58 → **4.63** | 11.2 |
| idgham mutajanisain / mutaqaribain ✱ | `#6E6E6E` | `#565656` | 4.20 → **6.05** | 8.9 |
| iqlab ✱ | `#0078B8` | `#017095` | 3.95 → **4.61** | 7.6 |
| ghunnah ✱ | `#C25400` | `#A05300` | 3.79 → **4.64** | 8.1 |

Pasangan yang mudah tertukar (ΔE2000 < 15), lama → baru:

| Pasangan | ΔE lama | ΔE baru |
| --- | --- | --- |
| hamzah washal / lam syamsiyah / tidak dibaca – idgham mutajanisain / mutaqaribain | 4.77 | 6.19 |
| idgham bilaghunnah – idgham mimi | 7.03 | 10.50 |
| ikhfa haqiqi – ikhfa syafawi | 8.14 | 8.14 |
| mad lazim – ikhfa haqiqi | 8.68 | 8.68 |
| mad wajib – mad lazim | 9.67 | 9.67 |
| mad thabi'i – mad jaiz | 9.75 | 10.43 |
| mad jaiz – mad wajib | 13.03 | 13.03 |
| mad thabi'i – iqlab | 13.09 | 14.44 |

Jarak terkecil antarhukum: 4.77 → 6.19. Semua pasangan lain ≥ 15 (terkecil baru 15.04).

#### Gelap

| Hukum | Lama | Baru | Kontras terburuk lama → baru | ΔE lama→baru |
| --- | --- | --- | --- | --- |
| hamzah washal / lam syamsiyah / tidak dibaca | `#9A9A9A` | `#9A9A9A` | 4.63 → **4.63** | 0.0 |
| mad thabi'i | `#8FA8FF` | `#8FA8FF` | 5.72 → **5.72** | 0.0 |
| mad jaiz | `#A0A8FF` | `#A0A8FF` | 5.92 → **5.92** | 0.0 |
| mad wajib ✱ | `#7F8CFF` | `#5A97FD` | 4.41 → **4.52** | 8.5 |
| mad lazim | `#C69BFF` | `#C69BFF` | 5.92 → **5.92** | 0.0 |
| qalqalah | `#FF7A7A` | `#FF7A7A` | 5.16 → **5.16** | 0.0 |
| ikhfa haqiqi | `#D98BFF` | `#D98BFF` | 5.64 → **5.64** | 0.0 |
| ikhfa syafawi | `#FF8AE6` | `#FF8AE6` | 6.23 → **6.23** | 0.0 |
| idgham bighunnah | `#52D6B0` | `#52D6B0` | 7.21 → **7.21** | 0.0 |
| idgham bilaghunnah | `#7DDB6E` | `#7DDB6E` | 7.59 → **7.59** | 0.0 |
| idgham mimi ✱ | `#8FE05A` | `#B5D943` | 8.06 → **8.05** | 8.0 |
| idgham mutajanisain / mutaqaribain | `#A8A8A8` | `#A8A8A8` | 5.48 → **5.48** | 0.0 |
| iqlab | `#5CCBFF` | `#5CCBFF` | 7.10 → **7.10** | 0.0 |
| ghunnah | `#FFA25C` | `#FFA25C` | 6.57 → **6.57** | 0.0 |

Pasangan yang mudah tertukar (ΔE2000 < 15), lama → baru:

| Pasangan | ΔE lama | ΔE baru |
| --- | --- | --- |
| mad thabi'i – mad jaiz | 3.88 | 3.88 |
| hamzah washal / lam syamsiyah / tidak dibaca – idgham mutajanisain / mutaqaribain | 4.26 | 4.26 |
| idgham bilaghunnah – idgham mimi | 4.49 | 11.78 |
| mad lazim – ikhfa haqiqi | 5.65 | 5.65 |
| mad thabi'i – mad wajib | 7.86 | 8.35 |
| mad jaiz – mad wajib | 8.53 | 11.87 |
| ikhfa haqiqi – ikhfa syafawi | 9.62 | 9.62 |
| mad jaiz – mad lazim | 10.60 | 10.60 |
| mad lazim – ikhfa syafawi | 13.57 | 13.57 |
| mad wajib – mad lazim | 14.09 | 21.51 |
| mad thabi'i – mad lazim | 14.47 | 14.47 |

Jarak terkecil antarhukum: 3.88 → 3.88. Semua pasangan lain ≥ 15 (terkecil baru 15.57).

