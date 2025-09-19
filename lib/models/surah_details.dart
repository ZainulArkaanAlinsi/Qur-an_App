// To parse this JSON data, do
//
//     final surahDetails = surahDetailsFromJson(jsonString);

import 'dart:convert';

SurahDetails surahDetailsFromJson(String str) =>
    SurahDetails.fromJson(json.decode(str));

String surahDetailsToJson(SurahDetails data) => json.encode(data.toJson());

class SurahDetails {
  String? surahName;
  String? surahNameArabic;
  String? surahNameArabicLong;
  String? surahNameTranslation;
  String? revelationPlace;
  int? totalAyah;
  int? surahNo;
  Map<String, Audio>? audio;
  List<String>? english;
  List<String>? arabic1;
  List<String>? arabic2;
  List<String>? bengali;
  List<String>? urdu;
  List<String>? uzbek;

  SurahDetails({
    this.surahName,
    this.surahNameArabic,
    this.surahNameArabicLong,
    this.surahNameTranslation,
    this.revelationPlace,
    this.totalAyah,
    this.surahNo,
    this.audio,
    this.english,
    this.arabic1,
    this.arabic2,
    this.bengali,
    this.urdu,
    this.uzbek,
  });

  factory SurahDetails.fromJson(Map<String, dynamic> json) => SurahDetails(
    surahName: json["surahName"],
    surahNameArabic: json["surahNameArabic"],
    surahNameArabicLong: json["surahNameArabicLong"],
    surahNameTranslation: json["surahNameTranslation"],
    revelationPlace: json["revelationPlace"],
    totalAyah: json["totalAyah"],
    surahNo: json["surahNo"],
    audio: Map.from(
      json["audio"]!,
    ).map((k, v) => MapEntry<String, Audio>(k, Audio.fromJson(v))),
    english: json["english"] == null
        ? []
        : List<String>.from(json["english"]!.map((x) => x)),
    arabic1: json["arabic1"] == null
        ? []
        : List<String>.from(json["arabic1"]!.map((x) => x)),
    arabic2: json["arabic2"] == null
        ? []
        : List<String>.from(json["arabic2"]!.map((x) => x)),
    bengali: json["bengali"] == null
        ? []
        : List<String>.from(json["bengali"]!.map((x) => x)),
    urdu: json["urdu"] == null
        ? []
        : List<String>.from(json["urdu"]!.map((x) => x)),
    uzbek: json["uzbek"] == null
        ? []
        : List<String>.from(json["uzbek"]!.map((x) => x)),
  );

  get name => null;

  Map<String, dynamic> toJson() => {
    "surahName": surahName,
    "surahNameArabic": surahNameArabic,
    "surahNameArabicLong": surahNameArabicLong,
    "surahNameTranslation": surahNameTranslation,
    "revelationPlace": revelationPlace,
    "totalAyah": totalAyah,
    "surahNo": surahNo,
    "audio": Map.from(
      audio!,
    ).map((k, v) => MapEntry<String, dynamic>(k, v.toJson())),
    "english": english == null
        ? []
        : List<dynamic>.from(english!.map((x) => x)),
    "arabic1": arabic1 == null
        ? []
        : List<dynamic>.from(arabic1!.map((x) => x)),
    "arabic2": arabic2 == null
        ? []
        : List<dynamic>.from(arabic2!.map((x) => x)),
    "bengali": bengali == null
        ? []
        : List<dynamic>.from(bengali!.map((x) => x)),
    "urdu": urdu == null ? [] : List<dynamic>.from(urdu!.map((x) => x)),
    "uzbek": uzbek == null ? [] : List<dynamic>.from(uzbek!.map((x) => x)),
  };
}

class Audio {
  String? reciter;
  String? url;
  String? originalUrl;

  Audio({this.reciter, this.url, this.originalUrl});

  factory Audio.fromJson(Map<String, dynamic> json) => Audio(
    reciter: json["reciter"],
    url: json["url"],
    originalUrl: json["originalUrl"],
  );

  Map<String, dynamic> toJson() => {
    "reciter": reciter,
    "url": url,
    "originalUrl": originalUrl,
  };
}
