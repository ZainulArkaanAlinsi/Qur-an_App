class Surahs {
  String? surahName;
  String? surahNameArabic;
  String? surahNameTranslation;
  String? revelationPlace;
  int? totalAyah;
  int? number;

  Surahs({
    this.surahName,
    this.surahNameArabic,
    this.surahNameTranslation,
    this.revelationPlace,
    this.totalAyah,
    this.number,
  });

  factory Surahs.fromJson(Map<String, dynamic> json) {
    return Surahs(
      surahName:
          json['name']?['transliteration']?['en'] ??
          json['englishName'] ??
          'Unknown',
      surahNameArabic: json['name']?['short'] ?? json['name'] ?? '...',
      surahNameTranslation:
          json['name']?['translation']?['en'] ??
          json['englishNameTranslation'] ??
          'Unknown',
      revelationPlace: _getRevelationPlace(json),
      totalAyah: json['numberOfVerses'] ?? json['numberOfAyahs'] ?? 0,
      number: json['number'] ?? 0,
    );
  }

  static String _getRevelationPlace(Map<String, dynamic> json) {
    final revelation = json['revelation'];
    if (revelation is Map) {
      return revelation['en'] == 'Meccan' ? 'Mecca' : 'Medina';
    }
    return json['revelationType'] == 'Meccan' ? 'Mecca' : 'Medina';
  }

  Map<String, dynamic> toJson() {
    return {
      'surahName': surahName,
      'surahNameArabic': surahNameArabic,
      'surahNameTranslation': surahNameTranslation,
      'revelationPlace': revelationPlace,
      'totalAyah': totalAyah,
      'number': number,
    };
  }
}
