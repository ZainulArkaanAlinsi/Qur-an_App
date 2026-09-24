import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_palette.dart';

/// Rujukan contoh kata: surah, ayat, dan urutan kata (mulai 1) di teks
/// Tanzil. Tanda waqaf tidak dihitung sebagai kata; `last` = kata terakhir.
@immutable
class TajweedExample {
  const TajweedExample(this.surah, this.ayah, this.first, [this.count = 1])
    : last = false;
  const TajweedExample.lastWord(this.surah, this.ayah)
    : first = 0,
      count = 1,
      last = true;

  final int surah;
  final int ayah;
  final int first;
  final int count;
  final bool last;

  String get reference => 'QS $surah:$ayah';
}

/// Kelompok legenda dan contoh tiap hukum. Contoh dipilih sebagai draf dan
/// menunggu pemeriksaan guru tajwid (docs/RELIGIOUS_CONTENT_GOVERNANCE.md);
/// teksnya selalu diambil dari dataset, tidak diketik.
const tajweedLegendGroups = <(String, List<(TajweedRule, TajweedExample)>)>[
  (
    'Hukum huruf',
    [
      (TajweedRule.idghamBilaghunnah, TajweedExample(2, 5, 4, 2)),
      (TajweedRule.idghamBighunnah, TajweedExample(2, 8, 3, 2)),
      (TajweedRule.iqlab, TajweedExample(2, 27, 5, 2)),
      (TajweedRule.ikhfaHaqiqi, TajweedExample(114, 4, 1, 2)),
      (TajweedRule.ikhfaSyafawi, TajweedExample(105, 4, 1, 2)),
      (TajweedRule.idghamMimi, TajweedExample(106, 4, 2, 2)),
      (TajweedRule.ghunnah, TajweedExample(114, 1, 8)),
      (TajweedRule.qalqalah, TajweedExample(113, 1, 8)),
    ],
  ),
  (
    'Hukum panjang',
    [
      (TajweedRule.madThabii, TajweedExample(1, 4, 1)),
      (TajweedRule.madWajib, TajweedExample(110, 1, 6)),
      (TajweedRule.madJaiz, TajweedExample(2, 4, 3, 2)),
      (TajweedRule.madLazim, TajweedExample.lastWord(1, 7)),
    ],
  ),
  (
    'Lainnya',
    [
      (TajweedRule.hamzahWasl, TajweedExample(1, 2, 1)),
      (TajweedRule.lamSyamsiyah, TajweedExample(1, 6, 2)),
      (TajweedRule.silent, TajweedExample(2, 5, 1)),
      (TajweedRule.idghamMutajanisain, TajweedExample(2, 256, 5, 2)),
      (TajweedRule.idghamMutaqaribain, TajweedExample(77, 20, 1, 2)),
    ],
  ),
];

final _pauseMark = RegExp('^[ۖ-ۭ]+\$');

/// Kata contoh dari [verse] persis seperti di dataset (tanpa normalisasi),
/// atau null bila rujukannya tidak ada.
String? tajweedExampleText(String verse, TajweedExample example) {
  final words = [
    for (final word in verse.split(' '))
      if (word.isNotEmpty && !_pauseMark.hasMatch(word)) word,
  ];
  if (words.isEmpty) return null;
  if (example.last) return words.last;
  final start = example.first - 1;
  final end = start + example.count;
  if (start < 0 || end > words.length) return null;
  return words.sublist(start, end).join(' ');
}

/// Warna tajwid (docs/design/v2/screens/07-legenda-tajwid.md): arti setiap
/// warna, dengan contoh kata dari teks Tanzil beserta rujukan ayatnya.
class TajweedLegendScreen extends StatefulWidget {
  const TajweedLegendScreen({
    super.key,
    this.backLabel = 'Mushaf',
    this.palette = TajweedPalette.draftPreview,
    this.verses,
  });

  final String backLabel;

  /// Palet yang sama dengan yang dipakai saat mewarnai ayat.
  final TajweedPalette palette;

  /// Hanya untuk tes: sumber teks ayat.
  @visibleForTesting
  final Future<String> Function(int surah, int ayah)? verses;

  @override
  State<TajweedLegendScreen> createState() => _TajweedLegendScreenState();
}

class _TajweedLegendScreenState extends State<TajweedLegendScreen> {
  late final Future<Map<TajweedRule, String>> _examples = _load();

  Future<Map<TajweedRule, String>> _load() async {
    final read =
        widget.verses ??
        (surah, ayah) async => (await QuranTextRepository.instance
            .versesForSurah(surah))[ayah - 1];
    final result = <TajweedRule, String>{};
    for (final (_, rows) in tajweedLegendGroups) {
      for (final (rule, example) in rows) {
        try {
          final text = tajweedExampleText(
            await read(example.surah, example.ayah),
            example,
          );
          if (text != null) result[rule] = text;
        } on Object {
          // Contoh yang gagal dimuat dilewati; warnanya tetap dijelaskan.
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<Map<TajweedRule, String>>(
          future: _examples,
          builder: (context, snapshot) {
            final examples = snapshot.data ?? const {};
            return ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                ScreenHeader(
                  title: 'Warna tajwid',
                  backLabel: widget.backLabel,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: Text(
                    'Yang diwarnai huruf beserta harakatnya, bukan latarnya. '
                    'Warnanya sama dengan pewarnaan ayat di aplikasi dan '
                    'dipilih agar tetap kontras di mode terang maupun gelap.',
                    style: SacredText.body.copyWith(color: tokens.sec),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.goldSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Nama hukum dan contoh kata masih draf, menunggu '
                      'pemeriksaan guru tajwid. Contoh diambil utuh dari teks '
                      'Tanzil; seluruh kata contoh diberi warna hukumnya.',
                      style: SacredText.infoBox.copyWith(color: tokens.ink),
                    ),
                  ),
                ),
                for (final (label, rows) in tajweedLegendGroups)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: GroupedList(
                      label: label,
                      children: [
                        for (final (rule, example) in rows)
                          _LegendRow(
                            name: rule.nameId,
                            reference: example.reference,
                            color: widget.palette.colorFor(rule, brightness),
                            example: examples[rule],
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.name,
    required this.reference,
    required this.color,
    required this.example,
  });

  final String name;
  final String reference;
  final Color color;
  final String? example;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: name,
      subtitle: example == null ? null : 'Contoh $reference',
      semanticsLabel: example == null ? name : '$name, contoh $reference',
      leading: ExcludeSemantics(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
      trailing: example == null
          ? null
          : ExcludeSemantics(
              child: Text(
                example!,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: SacredText.quran,
                  fontSize: 24,
                  height: 2,
                  color: color,
                ),
              ),
            ),
    );
  }
}
