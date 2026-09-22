import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_markup_parser.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_palette.dart';

/// Teks Arab satu ayat dengan warna tajwid, chip hukum, dan legend untuk
/// kartu ayat.
///
/// Bila markup rusak, widget menampilkan [fallbackText] tanpa warna, menyebut
/// edisinya lewat [fallbackEditionLabel], dan memanggil [onParseError]; markup
/// tidak pernah diperbaiki. Tidak ada teks polos yang benar-benar satu edisi
/// dengan `text_uthmani_tajweed` (bahkan `text_uthmani` Quran Foundation
/// berbeda encoding pada 4.210 ayat), jadi edisi cadangan wajib dilabeli
/// (docs/SDD.md ADR-2).
class TajweedVersePanel extends StatefulWidget {
  const TajweedVersePanel({
    super.key,
    required this.verseKey,
    required this.markup,
    required this.fallbackText,
    required this.fallbackEditionLabel,
    required this.arabicStyle,
    this.palette = TajweedPalette.draftPreview,
    this.tajweedEnabled = true,
    this.onParseError,
    this.onLearnRule,
  });

  final String verseKey;
  final String markup;
  final String fallbackText;
  final String fallbackEditionLabel;
  final TextStyle arabicStyle;
  final TajweedPalette palette;
  final bool tajweedEnabled;
  final void Function(String verseKey, FormatException error)? onParseError;

  /// Membuka materi Akademi Tajwid. `null` = tombol dinonaktifkan.
  final ValueChanged<TajweedRule>? onLearnRule;

  @override
  State<TajweedVersePanel> createState() => _TajweedVersePanelState();
}

class _TajweedVersePanelState extends State<TajweedVersePanel> {
  static const _parser = TajweedMarkupParser();

  TajweedVerse? _verse;
  List<TajweedRun> _runs = const [];
  List<TapGestureRecognizer?> _recognizers = const [];
  TajweedSegment? _selected;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(TajweedVersePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markup != widget.markup ||
        oldWidget.verseKey != widget.verseKey) {
      _parse();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer?.dispose();
    }
    _recognizers = const [];
  }

  void _parse() {
    _disposeRecognizers();
    _selected = null;
    try {
      final verse = _parser.parse(widget.verseKey, widget.markup);
      _verse = verse;
      _runs = verse.runs;
      _recognizers = [
        for (final run in _runs)
          run.rule == null
              ? null
              : (TapGestureRecognizer()..onTap = () => _onRunTap(run)),
      ];
    } on FormatException catch (error) {
      _verse = null;
      _runs = const [];
      final callback = widget.onParseError;
      if (callback != null) {
        final key = widget.verseKey;
        SchedulerBinding.instance.addPostFrameCallback(
          (_) => callback(key, error),
        );
      }
    }
  }

  TajweedSegment _innermostAt(TajweedRun run) {
    return _verse!.segments
        .where((s) => s.start <= run.start && s.end >= run.end)
        .reduce((a, b) => b.depth > a.depth ? b : a);
  }

  Future<void> _onRunTap(TajweedRun run) async {
    final segment = _innermostAt(run);
    setState(() => _selected = segment);
    await _showRule(segment.rule);
    if (mounted) setState(() => _selected = null);
  }

  Future<void> _showRule(TajweedRule rule) {
    return showTajweedRuleSheet(
      context,
      rule: rule,
      palette: widget.palette,
      count: _verse?.ruleCounts[rule] ?? 0,
      onLearn: widget.onLearnRule,
    );
  }

  @override
  Widget build(BuildContext context) {
    final verse = _verse;
    if (verse == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _arabic(Text(widget.fallbackText, style: widget.arabicStyle)),
          const SizedBox(height: 8),
          Text(
            'Warna tajwid tidak tersedia untuk ayat ini. '
            'Ditampilkan: ${widget.fallbackEditionLabel}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }
    if (!widget.tajweedEnabled) {
      return _arabic(Text(verse.text, style: widget.arabicStyle));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _arabic(
          Text.rich(
            TextSpan(
              style: widget.arabicStyle,
              children: _spans(context, verse),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TajweedRuleChips(
          verse: verse,
          palette: widget.palette,
          onRuleTap: _showRule,
        ),
      ],
    );
  }

  Widget _arabic(Widget child) => Directionality(
    textDirection: TextDirection.rtl,
    child: SizedBox(width: double.infinity, child: child),
  );

  List<InlineSpan> _spans(BuildContext context, TajweedVerse verse) {
    final brightness = Theme.of(context).brightness;
    final selected = _selected;
    return [
      for (var i = 0; i < _runs.length; i++)
        _span(verse, _runs[i], _recognizers[i], brightness, selected),
    ];
  }

  TextSpan _span(
    TajweedVerse verse,
    TajweedRun run,
    TapGestureRecognizer? recognizer,
    Brightness brightness,
    TajweedSegment? selected,
  ) {
    final rule = run.rule;
    final text = verse.text.substring(run.start, run.end);
    if (rule == null) return TextSpan(text: text);
    final color = widget.palette.colorFor(rule, brightness);
    final isSelected =
        selected != null &&
        run.start >= selected.start &&
        run.end <= selected.end;
    return TextSpan(
      text: text,
      recognizer: recognizer,
      style: TextStyle(
        color: color,
        backgroundColor: isSelected ? color.withValues(alpha: .18) : null,
      ),
    );
  }
}

/// Chip ringkas "Nama hukum ×n", urut sesuai kemunculan pertama di ayat.
class TajweedRuleChips extends StatelessWidget {
  const TajweedRuleChips({
    super.key,
    required this.verse,
    required this.palette,
    required this.onRuleTap,
  });

  final TajweedVerse verse;
  final TajweedPalette palette;
  final ValueChanged<TajweedRule> onRuleTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final counts = verse.ruleCounts;
    final ordered = <TajweedRule>[];
    for (final segment in verse.segments) {
      if (!ordered.contains(segment.rule)) ordered.add(segment.rule);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Tajwid:', style: Theme.of(context).textTheme.labelMedium),
        for (final rule in ordered)
          ActionChip(
            avatar: _Swatch(palette.colorFor(rule, brightness)),
            label: Text('${rule.nameId} ×${counts[rule]}'),
            onPressed: () => onRuleTap(rule),
          ),
        IconButton(
          tooltip: 'Legend warna tajwid',
          icon: const Icon(Icons.palette_outlined),
          onPressed: () => showTajweedLegendSheet(context, palette: palette),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _DraftNotice extends StatelessWidget {
  const _DraftNotice();

  @override
  Widget build(BuildContext context) => Text(
    'DRAF — nama hukum dan warna belum direview guru tajwid.',
    style: Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
  );
}

/// Menampilkan nama hukum saja, bukan uraian panjang (uraian ada di Akademi
/// Tajwid).
Future<void> showTajweedRuleSheet(
  BuildContext context, {
  required TajweedRule rule,
  required TajweedPalette palette,
  required int count,
  ValueChanged<TajweedRule>? onLearn,
}) {
  final color = palette.colorFor(rule, Theme.of(context).brightness);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Swatch(color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    rule.nameId,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Muncul $count kali pada ayat ini.'),
            const SizedBox(height: 8),
            if (palette.reviewStatus != ContentReviewStatus.published)
              const _DraftNotice(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onLearn == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        onLearn(rule);
                      },
                icon: const Icon(Icons.school_outlined),
                label: Text(
                  onLearn == null
                      ? 'Akademi Tajwid belum tersedia'
                      : 'Pelajari hukum ini',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showTajweedLegendSheet(
  BuildContext context, {
  required TajweedPalette palette,
}) {
  final brightness = Theme.of(context).brightness;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .75,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Text(
              'Legend tajwid · ${palette.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            if (palette.reviewStatus != ContentReviewStatus.published)
              const _DraftNotice(),
            const SizedBox(height: 8),
            for (final rule in TajweedRule.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _Swatch(palette.colorFor(rule, brightness)),
                title: Text(rule.nameId),
              ),
            const SizedBox(height: 8),
            Text(
              'Sumber anotasi: Quran Foundation (text_uthmani_tajweed).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
