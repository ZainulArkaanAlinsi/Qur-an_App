# Qur'an App

Reader Qur'an offline dengan jadwal salat, kalender Hijriah, pengingat ibadah, dan berita Islam.

## Konfigurasi berita Islam

Jadwal salat dan kalender Hijriah memakai AlAdhan. Berita memakai GNews melalui backend proxy supaya API key tidak masuk ke APK. Konfigurasikan URL endpoint backend yang mengembalikan format respons `articles` GNews saat build:

```powershell
flutter run --dart-define=ISLAMIC_NEWS_API_URL=https://api.example.com/islamic-news
```

Backend harus menyimpan kunci GNews, meminta artikel dengan kueri Islam/Muslim/Ramadhan, `lang=id`, dan `country=id`, lalu meneruskan hanya respons yang diperlukan aplikasi.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
