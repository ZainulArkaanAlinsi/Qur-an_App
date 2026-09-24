import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';

/// Kertas pembaca: palet dan terang/gelap yang dipakai layar baca.
enum ReaderPaper {
  ivory('Gading', AppPalette.sacred, Brightness.light),
  sepia('Sepia', AppPalette.sepia, Brightness.light),
  night('Malam', AppPalette.sacred, Brightness.dark);

  const ReaderPaper(this.label, this.palette, this.brightness);
  final String label;
  final AppPalette palette;
  final Brightness brightness;

  ThemeData get theme => SacredTheme.themeFor(palette, brightness);
  SacredTokens get tokens => SacredTheme.tokensFor(palette, brightness);

  static ReaderPaper? byName(String? name) =>
      values.where((paper) => paper.name == name).firstOrNull;
}

/// Lembar "Tampilan baca" (docs/design/v2/screens/02-mode-baca.md).
Future<void> showReadingModeSheet(
  BuildContext context, {
  required bool tajweed,
  required ValueChanged<bool> onTajweed,
  required ReaderPaper paper,
  required ValueChanged<ReaderPaper> onPaper,
  required VoidCallback onLegend,
  required VoidCallback onTextSize,
}) {
  final tokens = Theme.of(context).extension<SacredTokens>()!;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: tokens.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => ReadingModeSheet(
      tajweed: tajweed,
      onTajweed: onTajweed,
      paper: paper,
      onPaper: onPaper,
      onLegend: onLegend,
      onTextSize: onTextSize,
    ),
  );
}

class ReadingModeSheet extends StatefulWidget {
  const ReadingModeSheet({
    super.key,
    required this.tajweed,
    required this.onTajweed,
    required this.paper,
    required this.onPaper,
    required this.onLegend,
    required this.onTextSize,
  });

  final bool tajweed;
  final ValueChanged<bool> onTajweed;
  final ReaderPaper paper;
  final ValueChanged<ReaderPaper> onPaper;
  final VoidCallback onLegend;
  final VoidCallback onTextSize;

  @override
  State<ReadingModeSheet> createState() => _ReadingModeSheetState();
}

class _ReadingModeSheetState extends State<ReadingModeSheet> {
  late bool _tajweed = widget.tajweed;
  late ReaderPaper _paper = widget.paper;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final stacked = MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.6;
    const modes = [
      // Tata letak halaman mushaf menunggu izin lisensi (layar 03/04).
      _ModeCard(
        icon: SacredIcons.pageSingle,
        title: '1 Halaman',
        subtitle: 'Persis mushaf · segera',
        selected: false,
      ),
      _ModeCard(
        icon: SacredIcons.pageDouble,
        title: '2 Halaman',
        subtitle: 'Miringkan HP · segera',
        selected: false,
      ),
      _ModeCard(
        icon: SacredIcons.cards,
        title: 'Kartu ayat',
        subtitle: 'Dengan terjemahan',
        selected: true,
      ),
    ];
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Tampilan baca',
                      style: SacredText.headline.copyWith(
                        color: tokens.ink,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  excludeSemantics: true,
                  label: 'Selesai',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      child: Text(
                        'Selesai',
                        style: SacredText.headline.copyWith(
                          color: tokens.primaryText,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (stacked)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final card in modes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: card,
                    ),
                ],
              )
            else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < modes.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: modes[i]),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 14),
            GroupedList(
              children: [
                ListRow(
                  title: 'Tajwid berwarna',
                  subtitle: 'Palet draf, menunggu guru tajwid',
                  leading: const IconBadge(
                    icon: SacredIcons.palette,
                    color: SacredBadge.gold,
                  ),
                  trailing: IosToggle(
                    value: _tajweed,
                    semanticsLabel: 'Tajwid berwarna',
                    onChanged: (value) {
                      setState(() => _tajweed = value);
                      widget.onTajweed(value);
                    },
                  ),
                ),
                ListRow(
                  title: 'Legenda warna',
                  leading: const IconBadge(
                    icon: SacredIcons.info,
                    color: SacredBadge.blue,
                  ),
                  chevron: true,
                  onTap: widget.onLegend,
                ),
                ListRow(
                  title: 'Ukuran & jarak teks',
                  leading: const IconBadge(
                    icon: SacredIcons.textSize,
                    color: SacredBadge.green,
                  ),
                  chevron: true,
                  onTap: widget.onTextSize,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SectionLabel('Kertas'),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final paper in ReaderPaper.values)
                    _PaperButton(
                      paper: paper,
                      selected: paper == _paper,
                      width: stacked
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 16) / 3,
                      onTap: () {
                        setState(() => _paper = paper);
                        widget.onPaper(paper);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
  });

  final List<String> icon;
  final String title;
  final String subtitle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    // Hanya Kartu ayat yang tersedia; mode halaman ditandai "segera".
    final available = selected;
    return Semantics(
      button: true,
      selected: selected,
      enabled: available,
      excludeSemantics: true,
      label: available ? '$title, terpilih' : '$title, belum tersedia',
      child: Opacity(
        opacity: available ? 1 : .55,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
          decoration: BoxDecoration(
            color: selected ? tokens.surf : tokens.bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? tokens.cta : tokens.sep,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              LineIcon(icon, color: tokens.primaryText, size: 26),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: SacredText.buttonSmall.copyWith(color: tokens.ink),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: SacredText.cardNote.copyWith(color: tokens.sec),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaperButton extends StatelessWidget {
  const _PaperButton({
    required this.paper,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final ReaderPaper paper;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    // Contoh warna diambil dari token tema kertas itu sendiri.
    final swatch = paper.tokens;
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: 'Kertas ${paper.label}${selected ? ', terpilih' : ''}',
      child: Material(
        color: swatch.bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: width,
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? tokens.cta : swatch.sep,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              paper.label,
              style: SacredText.buttonSmall.copyWith(color: swatch.ink),
            ),
          ),
        ),
      ),
    );
  }
}
