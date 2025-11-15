class Config {
  // Multiple API options for fallback
  static const List<String> apiEndpoints = [
    'https://api.quran.gading.dev',
    'https://quran-api.santrikoding.com/api',
    'https://equran.id/api',
    'https://api.alquran.cloud/v1',
  ];

  static String get baseApiUrl => apiEndpoints[0];

  // Audio API dengan berbagai sumber untuk reliability
  static const List<String> audioEndpoints = [
    'https://cdn.islamic.network/quran/audio/128/ar.alafasy',
    'https://everyayah.com/data/Alafasy_128kbps',
    'https://server8.mp3quran.net/afs',
  ];

  // Method untuk mendapatkan audio URL dengan fallback
  static String getAudioUrl(int surahNumber) {
    // Coba berbagai sumber audio
    final sources = [
      'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$surahNumber.mp3',
      'https://everyayah.com/data/Alafasy_128kbps/$surahNumber.mp3',
      'https://server8.mp3quran.net/afs/$surahNumber.mp3',
      'https://download.quranicaudio.com/quran/mishaari_raashid_al_3afaasee/$surahNumber.mp3',
    ];

    return sources[0]; // Gunakan sumber pertama
  }
}
