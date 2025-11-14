class Config {
  // Multiple API options for fallback
  static const List<String> apiEndpoints = [
    'https://api.quran.gading.dev',
    'https://quran-api.santrikoding.com/api',
    'https://equran.id/api',
  ];

  static String get baseApiUrl => apiEndpoints[0];

  // Audio API
  static const String audioBaseUrl = 'https://api.quran.com/api/v4/recitations';
}
