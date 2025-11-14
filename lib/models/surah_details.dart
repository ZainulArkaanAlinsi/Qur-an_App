import 'dart:convert';

SurahDetails surahDetailsFromJson(String str) =>
    SurahDetails.fromJson(json.decode(str));

String surahDetailsToJson(SurahDetails data) => json.encode(data.toJson());

class SurahDetails {
  String? surahName;
  String? surahNameArabic;
  String? surahNameTranslation;
  String? revelationPlace;
  int? totalAyah;
  int? surahNo;
  List<String>? english;
  List<String>? arabic;

  SurahDetails({
    this.surahName,
    this.surahNameArabic,
    this.surahNameTranslation,
    this.revelationPlace,
    this.totalAyah,
    this.surahNo,
    this.english,
    this.arabic,
  });

  factory SurahDetails.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;

    List<String> englishVerses = [];
    List<String> arabicVerses = [];

    if (data['verses'] != null) {
      final verses = data['verses'] as List;
      englishVerses = verses.map<String>((verse) {
        return verse['text']?['transliteration']?['en'] ??
            verse['translation']?['en'] ??
            verse['text'] ??
            '';
      }).toList();

      arabicVerses = verses.map<String>((verse) {
        return verse['text']?['arab'] ?? verse['text'] ?? '';
      }).toList();
    }

    return SurahDetails(
      surahName:
          data['name']?['transliteration']?['en'] ??
          data['englishName'] ??
          'Unknown',
      surahNameArabic: data['name']?['short'] ?? data['name'] ?? '...',
      surahNameTranslation:
          data['name']?['translation']?['en'] ??
          data['englishNameTranslation'] ??
          'Unknown',
      revelationPlace: _getRevelationPlace(data),
      totalAyah: data['numberOfVerses'] ?? data['numberOfAyahs'] ?? 0,
      surahNo: data['number'] ?? 0,
      english: englishVerses,
      arabic: arabicVerses,
    );
  }

  static String _getRevelationPlace(Map<String, dynamic> data) {
    final revelation = data['revelation'];
    if (revelation is Map) {
      return revelation['en'] == 'Meccan' ? 'Mecca' : 'Medina';
    }
    return data['revelationType'] == 'Meccan' ? 'Mecca' : 'Medina';
  }

  Map<String, dynamic> toJson() => {
    "surahName": surahName,
    "surahNameArabic": surahNameArabic,
    "surahNameTranslation": surahNameTranslation,
    "revelationPlace": revelationPlace,
    "totalAyah": totalAyah,
    "surahNo": surahNo,
    "english": english ?? [],
    "arabic": arabic ?? [],
  };
}
