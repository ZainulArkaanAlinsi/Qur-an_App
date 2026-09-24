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

/// Cara membaca: halaman mushaf (1 atau 2) atau kartu per ayat.
enum ReadingMode { onePage, twoPages, cards }

/// Lembar "Tampilan baca" (docs/design/v2/screens/02-mode-baca.md).
///
/// Mode halaman hanya bisa dipilih bila ada data tata letak mushaf yang
/// sah; selain itu kartunya tampil "segera".
Future<void> showReadingModeSheet(
  BuildContext context, {
  required bool tajweed,
  required ValueChanged<bool> onTajweed,
  required ReaderPaper paper,
  required ValueChanged<ReaderPaper> onPaper,
  required VoidCallback onLegend,
  required VoidCallback onTextSize,
  ReadingMode mode = ReadingMode.cards,
  Set<ReadingMode> available = const {ReadingMode.cards},
  ValueChanged<ReadingMode>? onMode,
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
    builder: (sheetContext) => ReadingModeSheet(
      tajweed: tajweed,
      onTajweed: onTajweed,
      paper: paper,
      onPaper: onPaper,
      onLegend: onLegend,
      onTextSize: onTextSize,
      mode: mode,
      available: available,
      onMode: onMode == null
          ? null
          : (picked) {
              Navigator.pop(sheetContext);
              onMode(picked);
            },
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
    this.mode = ReadingMode.cards,
    this.available = const {ReadingMode.cards},
    this.onMode,
  });

  final ReadingMode mode;
  final Set<ReadingMode> available;
  final ValueChanged<ReadingMode>? onMode;

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
    // Tata letak halaman mushaf menunggu izin lisensi (layar 03/04): tanpa
    // data yang sah, kartunya tampil "segera".
    _ModeCard card(
      ReadingMode value,
      List<String> icon,
      String title,
      String subtitle,
    ) {
      final open = widget.available.contains(value);
      return _ModeCard(
        icon: icon,
        title: title,
        subtitle: open ? subtitle : '$subtitle · segera',
        selected: widget.mode == value,
        available: open,
        onTap: open && widget.mode != value && widget.onMode != null
            ? () => widget.onMode!(value)
            : null,
      );
    }

    final modes = [
      card(
        ReadingMode.onePage,
        SacredIcons.pageSingle,
        '1 Halaman',
        'Persis mushaf',
      ),
      card(
        ReadingMode.twoPages,
        SacredIcons.pageDouble,
        '2 Halaman',
        'Miringkan HP',
      ),
      card(
        ReadingMode.cards,
        SacredIcons.cards,
        'Kartu ayat',
        'Dengan terjemahan',
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
    this.available = false,
    this.onTap,
  });

  final List<String> icon;
  final String title;
  final String subtitle;
  final bool selected;

  /// Mode ini punya data dan bisa dipilih.
  final bool available;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final open = available || selected;
    return Semantics(
      button: true,
      selected: selected,
      enabled: open,
      excludeSemantics: true,
      label: selected
          ? '$title, terpilih'
          : open
          ? '$title, ketuk untuk memilih'
          : '$title, belum tersedia',
      child: Opacity(
        opacity: open ? 1 : .55,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
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
