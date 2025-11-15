import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quran_app_2025/core/config.dart' as core_config;
import 'package:quran_app_2025/models/surahs.dart';
import 'package:quran_app_2025/screens/surah_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const String routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Surahs>> data;
  final Color _primaryColor = const Color(0xFF2E7D32);
  final Color _secondaryColor = const Color(0xFF1B5E20);
  final Color _accentColor = const Color(0xFFE8F5E9);
  final Color _goldColor = const Color(0xFFD4AF37);

  // Data lengkap 114 surah untuk fallback
  final List<Surahs> _fallbackSurahs = [
    Surahs(
      number: 1,
      surahName: "Al-Fatihah",
      surahNameArabic: "الفاتحة",
      surahNameTranslation: "The Opening",
      revelationPlace: "Mecca",
      totalAyah: 7,
    ),
    Surahs(
      number: 2,
      surahName: "Al-Baqarah",
      surahNameArabic: "البقرة",
      surahNameTranslation: "The Cow",
      revelationPlace: "Medina",
      totalAyah: 286,
    ),
    Surahs(
      number: 3,
      surahName: "Ali 'Imran",
      surahNameArabic: "آل عمران",
      surahNameTranslation: "Family of Imran",
      revelationPlace: "Medina",
      totalAyah: 200,
    ),
    Surahs(
      number: 4,
      surahName: "An-Nisa",
      surahNameArabic: "النساء",
      surahNameTranslation: "The Women",
      revelationPlace: "Medina",
      totalAyah: 176,
    ),
    Surahs(
      number: 5,
      surahName: "Al-Ma'idah",
      surahNameArabic: "المائدة",
      surahNameTranslation: "The Table Spread",
      revelationPlace: "Medina",
      totalAyah: 120,
    ),
    Surahs(
      number: 6,
      surahName: "Al-An'am",
      surahNameArabic: "الأنعام",
      surahNameTranslation: "The Cattle",
      revelationPlace: "Mecca",
      totalAyah: 165,
    ),
    Surahs(
      number: 7,
      surahName: "Al-A'raf",
      surahNameArabic: "الأعراف",
      surahNameTranslation: "The Heights",
      revelationPlace: "Mecca",
      totalAyah: 206,
    ),
    Surahs(
      number: 8,
      surahName: "Al-Anfal",
      surahNameArabic: "الأنفال",
      surahNameTranslation: "The Spoils of War",
      revelationPlace: "Medina",
      totalAyah: 75,
    ),
    Surahs(
      number: 9,
      surahName: "At-Tawbah",
      surahNameArabic: "التوبة",
      surahNameTranslation: "The Repentance",
      revelationPlace: "Medina",
      totalAyah: 129,
    ),
    Surahs(
      number: 10,
      surahName: "Yunus",
      surahNameArabic: "يونس",
      surahNameTranslation: "Jonah",
      revelationPlace: "Mecca",
      totalAyah: 109,
    ),
    Surahs(
      number: 11,
      surahName: "Hud",
      surahNameArabic: "هود",
      surahNameTranslation: "Hud",
      revelationPlace: "Mecca",
      totalAyah: 123,
    ),
    Surahs(
      number: 12,
      surahName: "Yusuf",
      surahNameArabic: "يوسف",
      surahNameTranslation: "Joseph",
      revelationPlace: "Mecca",
      totalAyah: 111,
    ),
    Surahs(
      number: 13,
      surahName: "Ar-Ra'd",
      surahNameArabic: "الرعد",
      surahNameTranslation: "The Thunder",
      revelationPlace: "Medina",
      totalAyah: 43,
    ),
    Surahs(
      number: 14,
      surahName: "Ibrahim",
      surahNameArabic: "إبراهيم",
      surahNameTranslation: "Abraham",
      revelationPlace: "Mecca",
      totalAyah: 52,
    ),
    Surahs(
      number: 15,
      surahName: "Al-Hijr",
      surahNameArabic: "الحجر",
      surahNameTranslation: "The Rocky Tract",
      revelationPlace: "Mecca",
      totalAyah: 99,
    ),
    Surahs(
      number: 16,
      surahName: "An-Nahl",
      surahNameArabic: "النحل",
      surahNameTranslation: "The Bee",
      revelationPlace: "Mecca",
      totalAyah: 128,
    ),
    Surahs(
      number: 17,
      surahName: "Al-Isra",
      surahNameArabic: "الإسراء",
      surahNameTranslation: "The Night Journey",
      revelationPlace: "Mecca",
      totalAyah: 111,
    ),
    Surahs(
      number: 18,
      surahName: "Al-Kahf",
      surahNameArabic: "الكهف",
      surahNameTranslation: "The Cave",
      revelationPlace: "Mecca",
      totalAyah: 110,
    ),
    Surahs(
      number: 19,
      surahName: "Maryam",
      surahNameArabic: "مريم",
      surahNameTranslation: "Mary",
      revelationPlace: "Mecca",
      totalAyah: 98,
    ),
    Surahs(
      number: 20,
      surahName: "Taha",
      surahNameArabic: "طه",
      surahNameTranslation: "Ta-Ha",
      revelationPlace: "Mecca",
      totalAyah: 135,
    ),
    Surahs(
      number: 21,
      surahName: "Al-Anbiya",
      surahNameArabic: "الأنبياء",
      surahNameTranslation: "The Prophets",
      revelationPlace: "Mecca",
      totalAyah: 112,
    ),
    Surahs(
      number: 22,
      surahName: "Al-Hajj",
      surahNameArabic: "الحج",
      surahNameTranslation: "The Pilgrimage",
      revelationPlace: "Medina",
      totalAyah: 78,
    ),
    Surahs(
      number: 23,
      surahName: "Al-Mu'minun",
      surahNameArabic: "المؤمنون",
      surahNameTranslation: "The Believers",
      revelationPlace: "Mecca",
      totalAyah: 118,
    ),
    Surahs(
      number: 24,
      surahName: "An-Nur",
      surahNameArabic: "النور",
      surahNameTranslation: "The Light",
      revelationPlace: "Medina",
      totalAyah: 64,
    ),
    Surahs(
      number: 25,
      surahName: "Al-Furqan",
      surahNameArabic: "الفرقان",
      surahNameTranslation: "The Criterion",
      revelationPlace: "Mecca",
      totalAyah: 77,
    ),
    Surahs(
      number: 26,
      surahName: "Ash-Shu'ara",
      surahNameArabic: "الشعراء",
      surahNameTranslation: "The Poets",
      revelationPlace: "Mecca",
      totalAyah: 227,
    ),
    Surahs(
      number: 27,
      surahName: "An-Naml",
      surahNameArabic: "النمل",
      surahNameTranslation: "The Ant",
      revelationPlace: "Mecca",
      totalAyah: 93,
    ),
    Surahs(
      number: 28,
      surahName: "Al-Qasas",
      surahNameArabic: "القصص",
      surahNameTranslation: "The Stories",
      revelationPlace: "Mecca",
      totalAyah: 88,
    ),
    Surahs(
      number: 29,
      surahName: "Al-Ankabut",
      surahNameArabic: "العنكبوت",
      surahNameTranslation: "The Spider",
      revelationPlace: "Mecca",
      totalAyah: 69,
    ),
    Surahs(
      number: 30,
      surahName: "Ar-Rum",
      surahNameArabic: "الروم",
      surahNameTranslation: "The Romans",
      revelationPlace: "Mecca",
      totalAyah: 60,
    ),
    Surahs(
      number: 31,
      surahName: "Luqman",
      surahNameArabic: "لقمان",
      surahNameTranslation: "Luqman",
      revelationPlace: "Mecca",
      totalAyah: 34,
    ),
    Surahs(
      number: 32,
      surahName: "As-Sajdah",
      surahNameArabic: "السجدة",
      surahNameTranslation: "The Prostration",
      revelationPlace: "Mecca",
      totalAyah: 30,
    ),
    Surahs(
      number: 33,
      surahName: "Al-Ahzab",
      surahNameArabic: "الأحزاب",
      surahNameTranslation: "The Combined Forces",
      revelationPlace: "Medina",
      totalAyah: 73,
    ),
    Surahs(
      number: 34,
      surahName: "Saba",
      surahNameArabic: "سبإ",
      surahNameTranslation: "Sheba",
      revelationPlace: "Mecca",
      totalAyah: 54,
    ),
    Surahs(
      number: 35,
      surahName: "Fatir",
      surahNameArabic: "فاطر",
      surahNameTranslation: "Originator",
      revelationPlace: "Mecca",
      totalAyah: 45,
    ),
    Surahs(
      number: 36,
      surahName: "Yasin",
      surahNameArabic: "يس",
      surahNameTranslation: "Ya Sin",
      revelationPlace: "Mecca",
      totalAyah: 83,
    ),
    Surahs(
      number: 37,
      surahName: "As-Saffat",
      surahNameArabic: "الصافات",
      surahNameTranslation: "Those who set the Ranks",
      revelationPlace: "Mecca",
      totalAyah: 182,
    ),
    Surahs(
      number: 38,
      surahName: "Sad",
      surahNameArabic: "ص",
      surahNameTranslation: "The Letter Saad",
      revelationPlace: "Mecca",
      totalAyah: 88,
    ),
    Surahs(
      number: 39,
      surahName: "Az-Zumar",
      surahNameArabic: "الزمر",
      surahNameTranslation: "The Troops",
      revelationPlace: "Mecca",
      totalAyah: 75,
    ),
    Surahs(
      number: 40,
      surahName: "Ghafir",
      surahNameArabic: "غافر",
      surahNameTranslation: "The Forgiver",
      revelationPlace: "Mecca",
      totalAyah: 85,
    ),
    Surahs(
      number: 41,
      surahName: "Fussilat",
      surahNameArabic: "فصلت",
      surahNameTranslation: "Explained in Detail",
      revelationPlace: "Mecca",
      totalAyah: 54,
    ),
    Surahs(
      number: 42,
      surahName: "Ash-Shura",
      surahNameArabic: "الشورى",
      surahNameTranslation: "The Consultation",
      revelationPlace: "Mecca",
      totalAyah: 53,
    ),
    Surahs(
      number: 43,
      surahName: "Az-Zukhruf",
      surahNameArabic: "الزخرف",
      surahNameTranslation: "The Ornaments of Gold",
      revelationPlace: "Mecca",
      totalAyah: 89,
    ),
    Surahs(
      number: 44,
      surahName: "Ad-Dukhan",
      surahNameArabic: "الدخان",
      surahNameTranslation: "The Smoke",
      revelationPlace: "Mecca",
      totalAyah: 59,
    ),
    Surahs(
      number: 45,
      surahName: "Al-Jathiyah",
      surahNameArabic: "الجاثية",
      surahNameTranslation: "The Crouching",
      revelationPlace: "Mecca",
      totalAyah: 37,
    ),
    Surahs(
      number: 46,
      surahName: "Al-Ahqaf",
      surahNameArabic: "الأحقاف",
      surahNameTranslation: "The Wind-Curved Sandhills",
      revelationPlace: "Mecca",
      totalAyah: 35,
    ),
    Surahs(
      number: 47,
      surahName: "Muhammad",
      surahNameArabic: "محمد",
      surahNameTranslation: "Muhammad",
      revelationPlace: "Medina",
      totalAyah: 38,
    ),
    Surahs(
      number: 48,
      surahName: "Al-Fath",
      surahNameArabic: "الفتح",
      surahNameTranslation: "The Victory",
      revelationPlace: "Medina",
      totalAyah: 29,
    ),
    Surahs(
      number: 49,
      surahName: "Al-Hujurat",
      surahNameArabic: "الحجرات",
      surahNameTranslation: "The Rooms",
      revelationPlace: "Medina",
      totalAyah: 18,
    ),
    Surahs(
      number: 50,
      surahName: "Qaf",
      surahNameArabic: "ق",
      surahNameTranslation: "The Letter Qaf",
      revelationPlace: "Mecca",
      totalAyah: 45,
    ),
    Surahs(
      number: 51,
      surahName: "Adh-Dhariyat",
      surahNameArabic: "الذاريات",
      surahNameTranslation: "The Winnowing Winds",
      revelationPlace: "Mecca",
      totalAyah: 60,
    ),
    Surahs(
      number: 52,
      surahName: "At-Tur",
      surahNameArabic: "الطور",
      surahNameTranslation: "The Mount",
      revelationPlace: "Mecca",
      totalAyah: 49,
    ),
    Surahs(
      number: 53,
      surahName: "An-Najm",
      surahNameArabic: "النجم",
      surahNameTranslation: "The Star",
      revelationPlace: "Mecca",
      totalAyah: 62,
    ),
    Surahs(
      number: 54,
      surahName: "Al-Qamar",
      surahNameArabic: "القمر",
      surahNameTranslation: "The Moon",
      revelationPlace: "Mecca",
      totalAyah: 55,
    ),
    Surahs(
      number: 55,
      surahName: "Ar-Rahman",
      surahNameArabic: "الرحمن",
      surahNameTranslation: "The Beneficent",
      revelationPlace: "Medina",
      totalAyah: 78,
    ),
    Surahs(
      number: 56,
      surahName: "Al-Waqi'ah",
      surahNameArabic: "الواقعة",
      surahNameTranslation: "The Inevitable",
      revelationPlace: "Mecca",
      totalAyah: 96,
    ),
    Surahs(
      number: 57,
      surahName: "Al-Hadid",
      surahNameArabic: "الحديد",
      surahNameTranslation: "The Iron",
      revelationPlace: "Medina",
      totalAyah: 29,
    ),
    Surahs(
      number: 58,
      surahName: "Al-Mujadila",
      surahNameArabic: "المجادلة",
      surahNameTranslation: "The Pleading Woman",
      revelationPlace: "Medina",
      totalAyah: 22,
    ),
    Surahs(
      number: 59,
      surahName: "Al-Hashr",
      surahNameArabic: "الحشر",
      surahNameTranslation: "The Exile",
      revelationPlace: "Medina",
      totalAyah: 24,
    ),
    Surahs(
      number: 60,
      surahName: "Al-Mumtahanah",
      surahNameArabic: "الممتحنة",
      surahNameTranslation: "She that is to be examined",
      revelationPlace: "Medina",
      totalAyah: 13,
    ),
    Surahs(
      number: 61,
      surahName: "As-Saff",
      surahNameArabic: "الصف",
      surahNameTranslation: "The Ranks",
      revelationPlace: "Medina",
      totalAyah: 14,
    ),
    Surahs(
      number: 62,
      surahName: "Al-Jumu'ah",
      surahNameArabic: "الجمعة",
      surahNameTranslation: "The Congregation, Friday",
      revelationPlace: "Medina",
      totalAyah: 11,
    ),
    Surahs(
      number: 63,
      surahName: "Al-Munafiqun",
      surahNameArabic: "المنافقون",
      surahNameTranslation: "The Hypocrites",
      revelationPlace: "Medina",
      totalAyah: 11,
    ),
    Surahs(
      number: 64,
      surahName: "At-Taghabun",
      surahNameArabic: "التغابن",
      surahNameTranslation: "The Mutual Disillusion",
      revelationPlace: "Medina",
      totalAyah: 18,
    ),
    Surahs(
      number: 65,
      surahName: "At-Talaq",
      surahNameArabic: "الطلاق",
      surahNameTranslation: "The Divorce",
      revelationPlace: "Medina",
      totalAyah: 12,
    ),
    Surahs(
      number: 66,
      surahName: "At-Tahrim",
      surahNameArabic: "التحريم",
      surahNameTranslation: "The Prohibition",
      revelationPlace: "Medina",
      totalAyah: 12,
    ),
    Surahs(
      number: 67,
      surahName: "Al-Mulk",
      surahNameArabic: "الملك",
      surahNameTranslation: "The Sovereignty",
      revelationPlace: "Mecca",
      totalAyah: 30,
    ),
    Surahs(
      number: 68,
      surahName: "Al-Qalam",
      surahNameArabic: "القلم",
      surahNameTranslation: "The Pen",
      revelationPlace: "Mecca",
      totalAyah: 52,
    ),
    Surahs(
      number: 69,
      surahName: "Al-Haqqah",
      surahNameArabic: "الحاقة",
      surahNameTranslation: "The Reality",
      revelationPlace: "Mecca",
      totalAyah: 52,
    ),
    Surahs(
      number: 70,
      surahName: "Al-Ma'arij",
      surahNameArabic: "المعارج",
      surahNameTranslation: "The Ascending Stairways",
      revelationPlace: "Mecca",
      totalAyah: 44,
    ),
    Surahs(
      number: 71,
      surahName: "Nuh",
      surahNameArabic: "نوح",
      surahNameTranslation: "Noah",
      revelationPlace: "Mecca",
      totalAyah: 28,
    ),
    Surahs(
      number: 72,
      surahName: "Al-Jinn",
      surahNameArabic: "الجن",
      surahNameTranslation: "The Jinn",
      revelationPlace: "Mecca",
      totalAyah: 28,
    ),
    Surahs(
      number: 73,
      surahName: "Al-Muzzammil",
      surahNameArabic: "المزمل",
      surahNameTranslation: "The Enshrouded One",
      revelationPlace: "Mecca",
      totalAyah: 20,
    ),
    Surahs(
      number: 74,
      surahName: "Al-Muddathir",
      surahNameArabic: "المدثر",
      surahNameTranslation: "The Cloaked One",
      revelationPlace: "Mecca",
      totalAyah: 56,
    ),
    Surahs(
      number: 75,
      surahName: "Al-Qiyamah",
      surahNameArabic: "القيامة",
      surahNameTranslation: "The Resurrection",
      revelationPlace: "Mecca",
      totalAyah: 40,
    ),
    Surahs(
      number: 76,
      surahName: "Al-Insan",
      surahNameArabic: "الإنسان",
      surahNameTranslation: "The Man",
      revelationPlace: "Medina",
      totalAyah: 31,
    ),
    Surahs(
      number: 77,
      surahName: "Al-Mursalat",
      surahNameArabic: "المرسلات",
      surahNameTranslation: "The Emissaries",
      revelationPlace: "Mecca",
      totalAyah: 50,
    ),
    Surahs(
      number: 78,
      surahName: "An-Naba",
      surahNameArabic: "النبأ",
      surahNameTranslation: "The Tidings",
      revelationPlace: "Mecca",
      totalAyah: 40,
    ),
    Surahs(
      number: 79,
      surahName: "An-Nazi'at",
      surahNameArabic: "النازعات",
      surahNameTranslation: "Those who drag forth",
      revelationPlace: "Mecca",
      totalAyah: 46,
    ),
    Surahs(
      number: 80,
      surahName: "Abasa",
      surahNameArabic: "عبس",
      surahNameTranslation: "He frowned",
      revelationPlace: "Mecca",
      totalAyah: 42,
    ),
    Surahs(
      number: 81,
      surahName: "At-Takwir",
      surahNameArabic: "التكوير",
      surahNameTranslation: "The Overthrowing",
      revelationPlace: "Mecca",
      totalAyah: 29,
    ),
    Surahs(
      number: 82,
      surahName: "Al-Infitar",
      surahNameArabic: "الإنفطار",
      surahNameTranslation: "The Cleaving",
      revelationPlace: "Mecca",
      totalAyah: 19,
    ),
    Surahs(
      number: 83,
      surahName: "Al-Mutaffifin",
      surahNameArabic: "المطففين",
      surahNameTranslation: "The Defrauding",
      revelationPlace: "Mecca",
      totalAyah: 36,
    ),
    Surahs(
      number: 84,
      surahName: "Al-Inshiqaq",
      surahNameArabic: "الإنشقاق",
      surahNameTranslation: "The Sundering",
      revelationPlace: "Mecca",
      totalAyah: 25,
    ),
    Surahs(
      number: 85,
      surahName: "Al-Buruj",
      surahNameArabic: "البروج",
      surahNameTranslation: "The Mansions of the Stars",
      revelationPlace: "Mecca",
      totalAyah: 22,
    ),
    Surahs(
      number: 86,
      surahName: "At-Tariq",
      surahNameArabic: "الطارق",
      surahNameTranslation: "The Morning Star",
      revelationPlace: "Mecca",
      totalAyah: 17,
    ),
    Surahs(
      number: 87,
      surahName: "Al-A'la",
      surahNameArabic: "الأعلى",
      surahNameTranslation: "The Most High",
      revelationPlace: "Mecca",
      totalAyah: 19,
    ),
    Surahs(
      number: 88,
      surahName: "Al-Ghashiyah",
      surahNameArabic: "الغاشية",
      surahNameTranslation: "The Overwhelming",
      revelationPlace: "Mecca",
      totalAyah: 26,
    ),
    Surahs(
      number: 89,
      surahName: "Al-Fajr",
      surahNameArabic: "الفجر",
      surahNameTranslation: "The Dawn",
      revelationPlace: "Mecca",
      totalAyah: 30,
    ),
    Surahs(
      number: 90,
      surahName: "Al-Balad",
      surahNameArabic: "البلد",
      surahNameTranslation: "The City",
      revelationPlace: "Mecca",
      totalAyah: 20,
    ),
    Surahs(
      number: 91,
      surahName: "Ash-Shams",
      surahNameArabic: "الشمس",
      surahNameTranslation: "The Sun",
      revelationPlace: "Mecca",
      totalAyah: 15,
    ),
    Surahs(
      number: 92,
      surahName: "Al-Layl",
      surahNameArabic: "الليل",
      surahNameTranslation: "The Night",
      revelationPlace: "Mecca",
      totalAyah: 21,
    ),
    Surahs(
      number: 93,
      surahName: "Ad-Duha",
      surahNameArabic: "الضحى",
      surahNameTranslation: "The Morning Hours",
      revelationPlace: "Mecca",
      totalAyah: 11,
    ),
    Surahs(
      number: 94,
      surahName: "Ash-Sharh",
      surahNameArabic: "الشرح",
      surahNameTranslation: "The Relief",
      revelationPlace: "Mecca",
      totalAyah: 8,
    ),
    Surahs(
      number: 95,
      surahName: "At-Tin",
      surahNameArabic: "التين",
      surahNameTranslation: "The Fig",
      revelationPlace: "Mecca",
      totalAyah: 8,
    ),
    Surahs(
      number: 96,
      surahName: "Al-Alaq",
      surahNameArabic: "العلق",
      surahNameTranslation: "The Clot",
      revelationPlace: "Mecca",
      totalAyah: 19,
    ),
    Surahs(
      number: 97,
      surahName: "Al-Qadr",
      surahNameArabic: "القدر",
      surahNameTranslation: "The Power",
      revelationPlace: "Mecca",
      totalAyah: 5,
    ),
    Surahs(
      number: 98,
      surahName: "Al-Bayyinah",
      surahNameArabic: "البينة",
      surahNameTranslation: "The Clear Proof",
      revelationPlace: "Medina",
      totalAyah: 8,
    ),
    Surahs(
      number: 99,
      surahName: "Az-Zalzalah",
      surahNameArabic: "الزلزلة",
      surahNameTranslation: "The Earthquake",
      revelationPlace: "Medina",
      totalAyah: 8,
    ),
    Surahs(
      number: 100,
      surahName: "Al-Adiyat",
      surahNameArabic: "العاديات",
      surahNameTranslation: "The Courser",
      revelationPlace: "Mecca",
      totalAyah: 11,
    ),
    Surahs(
      number: 101,
      surahName: "Al-Qari'ah",
      surahNameArabic: "القارعة",
      surahNameTranslation: "The Calamity",
      revelationPlace: "Mecca",
      totalAyah: 11,
    ),
    Surahs(
      number: 102,
      surahName: "At-Takathur",
      surahNameArabic: "التكاثر",
      surahNameTranslation: "The Rivalry in world increase",
      revelationPlace: "Mecca",
      totalAyah: 8,
    ),
    Surahs(
      number: 103,
      surahName: "Al-Asr",
      surahNameArabic: "العصر",
      surahNameTranslation: "The Declining Day",
      revelationPlace: "Mecca",
      totalAyah: 3,
    ),
    Surahs(
      number: 104,
      surahName: "Al-Humazah",
      surahNameArabic: "الهمزة",
      surahNameTranslation: "The Traducer",
      revelationPlace: "Mecca",
      totalAyah: 9,
    ),
    Surahs(
      number: 105,
      surahName: "Al-Fil",
      surahNameArabic: "الفيل",
      surahNameTranslation: "The Elephant",
      revelationPlace: "Mecca",
      totalAyah: 5,
    ),
    Surahs(
      number: 106,
      surahName: "Quraysh",
      surahNameArabic: "قريش",
      surahNameTranslation: "Quraysh",
      revelationPlace: "Mecca",
      totalAyah: 4,
    ),
    Surahs(
      number: 107,
      surahName: "Al-Ma'un",
      surahNameArabic: "الماعون",
      surahNameTranslation: "The Small kindnesses",
      revelationPlace: "Mecca",
      totalAyah: 7,
    ),
    Surahs(
      number: 108,
      surahName: "Al-Kawthar",
      surahNameArabic: "الكوثر",
      surahNameTranslation: "The Abundance",
      revelationPlace: "Mecca",
      totalAyah: 3,
    ),
    Surahs(
      number: 109,
      surahName: "Al-Kafirun",
      surahNameArabic: "الكافرون",
      surahNameTranslation: "The Disbelievers",
      revelationPlace: "Mecca",
      totalAyah: 6,
    ),
    Surahs(
      number: 110,
      surahName: "An-Nasr",
      surahNameArabic: "النصر",
      surahNameTranslation: "The Divine Support",
      revelationPlace: "Medina",
      totalAyah: 3,
    ),
    Surahs(
      number: 111,
      surahName: "Al-Masad",
      surahNameArabic: "المسد",
      surahNameTranslation: "The Palm Fiber",
      revelationPlace: "Mecca",
      totalAyah: 5,
    ),
    Surahs(
      number: 112,
      surahName: "Al-Ikhlas",
      surahNameArabic: "الإخلاص",
      surahNameTranslation: "The Sincerity",
      revelationPlace: "Mecca",
      totalAyah: 4,
    ),
    Surahs(
      number: 113,
      surahName: "Al-Falaq",
      surahNameArabic: "الفلق",
      surahNameTranslation: "The Daybreak",
      revelationPlace: "Mecca",
      totalAyah: 5,
    ),
    Surahs(
      number: 114,
      surahName: "An-Nas",
      surahNameArabic: "الناس",
      surahNameTranslation: "The Mankind",
      revelationPlace: "Mecca",
      totalAyah: 6,
    ),
  ];

  Future<List<Surahs>> _fetchChapters() async {
    for (final endpoint in core_config.Config.apiEndpoints) {
      try {
        print('Mencoba mengambil data dari: $endpoint/surahs');
        final response = await http
            .get(Uri.parse('$endpoint/surahs'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
          final List<dynamic> dataList = jsonResponse['data'] ?? [];
          if (dataList.isNotEmpty) {
            print('Berhasil mengambil ${dataList.length} surah dari $endpoint');
            return dataList.map((e) => Surahs.fromJson(e)).toList();
          }
        } else {
          print('Gagal dengan status code: ${response.statusCode}');
        }
      } catch (e) {
        print('Error dari $endpoint: $e');
        continue;
      }
    }

    // Jika semua API gagal, gunakan fallback data lengkap 114 surah
    print('Menggunakan data fallback lengkap 114 surah');
    return _fallbackSurahs;
  }

  @override
  void initState() {
    super.initState();
    data = _fetchChapters();
  }

  Future<void> _refreshData() async {
    setState(() {
      data = _fetchChapters();
    });
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      floating: true,
      pinned: true,
      snap: false,
      expandedHeight: 120.0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Al-Qur\'an Kareem',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryColor, _secondaryColor],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            Navigator.pushNamed(context, '/search');
          },
          icon: const Icon(Icons.search),
          tooltip: 'Search',
        ),
        IconButton(
          onPressed: () {
            Navigator.pushNamed(context, '/settings');
          },
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, _secondaryColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('114', 'Surah', Icons.book),
          _buildStatItem('6236', 'Ayat', Icons.format_quote),
          _buildStatItem('30', 'Juz', Icons.library_books),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildActionCard(
              'Last Read',
              Icons.bookmark,
              _primaryColor,
              () {
                Navigator.pushNamed(context, '/surah_details', arguments: 1);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionCard(
              'Bookmarks',
              Icons.bookmarks,
              _goldColor,
              () {
                Navigator.pushNamed(context, '/bookmarks');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSurahTile(Surahs surah, int index, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () {
          print('Navigating to surah: ${surah.number} - ${surah.surahName}');
          Navigator.of(
            context,
          ).pushNamed(SurahDetailsScreen.routeName, arguments: surah.number);
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_accentColor, _accentColor.withOpacity(0.7)],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${surah.number}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          surah.surahName ?? 'Unknown',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${surah.revelationPlace ?? 'Unknown'} • ${surah.totalAyah ?? 0} Ayat',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              surah.surahNameArabic ?? '...',
              style: const TextStyle(
                fontFamily: 'Amiri',
                fontSize: 20,
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: _primaryColor,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsCard(),
                    const SizedBox(height: 16),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Daftar Surah (114)',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              FutureBuilder<List<Surahs>>(
                future: data,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: _primaryColor),
                              const SizedBox(height: 16),
                              Text(
                                'Memuat data surah...',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Gagal memuat data\nMenggunakan data offline',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _refreshData,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(child: Text('Tidak ada data surah.')),
                    );
                  }

                  final surahs = snapshot.data!;
                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final surah = surahs[index];
                      return _buildSurahTile(surah, index, theme);
                    }, childCount: surahs.length),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
