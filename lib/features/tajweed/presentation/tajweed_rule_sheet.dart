import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass/glass_sheet.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_explanations.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_markup_parser.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_palette.dart';

/// Kata-kata di [verse] (offset [from] sampai [to]) yang memuat hukum [rule]:
/// rentang awal–akhir tiap kata, tanpa duplikat, urut seperti di ayat.
List<(int, int)> tajweedRuleWords(
  TajweedVerse verse,
  TajweedRule rule, {
  int from = 0,
  int? to,
}) {
  final text = verse.text;
  final limit = to ?? text.length;
  final words = <(int, int)>{};
  for (final segment in verse.segments) {
    if (segment.rule != rule || segment.start < from) continue;
    if (segment.start >= limit) continue;
    final space = text.lastIndexOf(' ', segment.start - 1);
    final start = space < from ? from : space + 1;
    final next = text.indexOf(' ', segment.end);
    final end = next < 0 || next > limit ? limit : next;
    words.add((start, end));
  }
  return words.toList()..sort((a, b) => a.$1.compareTo(b.$1));
}

/// Lembar penjelasan satu hukum tajwid, dibuka dengan mengetuk huruf
/// berwarna. Menunjukkan huruf mana yang dimaksud di ayat itu; penjelasan
/// cara membaca hanya dari guru tajwid (berkas konten berstatus review).
Future<void> showTajweedRuleSheet(
  BuildContext context, {
  required TajweedVerse verse,
  required TajweedRule rule,
  required TajweedPalette palette,
  required VoidCallback onPlay,
  required VoidCallback onLegend,
  int from = 0,
  int? to,
  String area = 'Di ayat ini',
  TajweedExplanations? explanations,
}) {
  final tokens = Theme.of(context).extension<SacredTokens>()!;
  return showGlassSheet<void>(
    context: context,
    background: tokens.bg,
    header: (sheetContext) => _RuleHeader(
      rule: rule,
      color: palette.colorFor(rule, Theme.of(sheetContext).brightness),
    ),
    builder: (sheetContext) => TajweedRuleSheet(
      verse: verse,
      rule: rule,
      palette: palette,
      from: from,
      to: to,
      area: area,
      explanations: explanations ?? TajweedExplanations.instance,
      onPlay: () {
        Navigator.pop(sheetContext);
        onPlay();
      },
      onLegend: () {
        Navigator.pop(sheetContext);
        onLegend();
      },
    ),
  );
}

/// Kepala kaca sheet aturan tajwid: warna hukum dan namanya.
class _RuleHeader extends StatelessWidget {
  const _RuleHeader({required this.rule, required this.color});

  final TajweedRule rule;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                rule.nameId,
                style: SacredText.stageTitle.copyWith(color: tokens.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TajweedRuleSheet extends StatelessWidget {
  const TajweedRuleSheet({
    super.key,
    required this.verse,
    required this.rule,
    required this.palette,
    required this.explanations,
    required this.onPlay,
    required this.onLegend,
    this.from = 0,
    this.to,
    this.area = 'Di ayat ini',
  });

  final TajweedVerse verse;
  final TajweedRule rule;
  final TajweedPalette palette;
  final TajweedExplanations explanations;
  final VoidCallback onPlay;
  final VoidCallback onLegend;
  final int from;
  final int? to;

  /// Judul daftar kata: 'Di ayat ini' atau 'Di basmalah'.
  final String area;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final color = palette.colorFor(rule, Theme.of(context).brightness);
    final words = tajweedRuleWords(verse, rule, from: from, to: to);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 2),
            Text(
              'DRAF — nama hukum belum direview guru tajwid',
              style: SacredText.cardNote.copyWith(color: tokens.goldText),
            ),
            if (words.isNotEmpty) ...[
              const SizedBox(height: 16),
              SectionLabel(area),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                textDirection: TextDirection.rtl,
                children: [
                  for (final (start, end) in words)
                    _Word(
                      verse: verse,
                      rule: rule,
                      start: start,
                      end: end,
                      color: color,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Huruf berwarna adalah bagian yang dibaca dengan hukum ini.',
                style: SacredText.cardNote.copyWith(color: tokens.sec),
              ),
            ],
            const SizedBox(height: 16),
            const SectionLabel('Cara membaca'),
            FutureBuilder<Map<TajweedRule, TajweedExplanation>>(
              future: explanations.load(),
              builder: (context, snapshot) {
                final explanation = snapshot.data?[rule];
                if (explanation != null && explanation.visible()) {
                  return _Explained(explanation: explanation);
                }
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tokens.surf,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: tokens.cardShadows,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Penjelasan cara membaca sedang disiapkan bersama '
                        'guru tajwid. Sementara itu, dengarkan bacaan qari '
                        'lalu tirukan.',
                        style: SacredText.lessonBody.copyWith(
                          color: tokens.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SacredButton(
                        label: 'Putar ayat ini',
                        icon: SacredIcons.play,
                        iconFilled: true,
                        tone: ButtonTone.soft,
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        textStyle: SacredText.buttonSmall,
                        onTap: onPlay,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            GroupedList(
              children: [
                ListRow(
                  title: 'Arti semua warna',
                  chevron: true,
                  onTap: onLegend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu kata dari ayat; hanya huruf yang terkena hukum yang diwarnai.
class _Word extends StatelessWidget {
  const _Word({
    required this.verse,
    required this.rule,
    required this.start,
    required this.end,
    required this.color,
  });

  final TajweedVerse verse;
  final TajweedRule rule;
  final int start;
  final int end;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final spans = <TextSpan>[];
    var cursor = start;
    final marks = [
      for (final s in verse.segments)
        if (s.rule == rule && s.start < end && s.end > start)
          (s.start < start ? start : s.start, s.end > end ? end : s.end),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final (a, b) in marks) {
      if (a > cursor) {
        spans.add(TextSpan(text: verse.text.substring(cursor, a)));
      }
      if (b > cursor) {
        spans.add(
          TextSpan(
            text: verse.text.substring(a < cursor ? cursor : a, b),
            style: TextStyle(color: color),
          ),
        );
        cursor = b;
      }
    }
    if (cursor < end) {
      spans.add(TextSpan(text: verse.text.substring(cursor, end)));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(14),
        boxShadow: tokens.cardShadows,
      ),
      child: Text.rich(
        TextSpan(children: spans),
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: SacredText.quran,
          fontSize: 28,
          height: 2,
          color: tokens.ink,
        ),
      ),
    );
  }
}

class _Explained extends StatelessWidget {
  const _Explained({required this.explanation});

  final TajweedExplanation explanation;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(18),
        boxShadow: tokens.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!explanation.publishable) ...[
            Text(
              'DRAF — belum direview',
              style: SacredText.pill.copyWith(color: tokens.goldText),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            explanation.howToRead!,
            style: SacredText.lessonBody.copyWith(color: tokens.ink),
          ),
          if (explanation.source != null ||
              explanation.reviewers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (explanation.source != null) 'Sumber: ${explanation.source}',
                if (explanation.reviewers.isNotEmpty)
                  'Diperiksa: ${explanation.reviewers.join(', ')}',
              ].join(' · '),
              style: SacredText.cardNote.copyWith(color: tokens.sec),
            ),
          ],
        ],
      ),
    );
  }
}
