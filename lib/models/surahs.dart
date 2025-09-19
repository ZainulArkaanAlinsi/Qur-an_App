class Surahs {
  String? surahName;
  String? surahNameArabic;
  String? surahNameTranslation;
  String? surahArabicLong;
  String? revelationPlace;
  int? totalAyah;

  Surahs({
    this.surahName,
    this.surahNameArabic,
    this.surahNameTranslation,
    this.surahArabicLong,
    this.revelationPlace,
    this.totalAyah,
  });

  Surahs.fromJson(Map<String, dynamic> json) {
    surahName = json['surahName'];
    surahNameArabic = json['surahNameArabic'];
    surahArabicLong = json['surahArabicLong'];
    surahNameTranslation = json['surahNameTranslation'];
    revelationPlace = json['revelationPlace'];
    totalAyah = json['totalAyah'];
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['surahName'] = surahName;
    data['surahNameArabic'] = surahNameArabic;
    data['surahArabicLong'] = surahArabicLong;
    data['surahNameTranslation'] = surahNameTranslation;
    data['revelationPlace'] = revelationPlace;
    data['totalAyah'] = totalAyah;
    return data;
  }
}
