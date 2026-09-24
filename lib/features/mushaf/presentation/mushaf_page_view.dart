import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_shapes.dart';
import 'package:quran_app_2025/features/mushaf/domain/mushaf_text.dart';
import 'package:quran_app_2025/features/mushaf/presentation/mushaf_tokens.dart';
import 'package:quran_app_2025/features/reader/presentation/card_parts.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_markup_parser.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_palette.dart';

/// Lebar halaman acuan (390 − 2×10); ukuran lain diskalakan dari sini.
const _baseWidth = 370.0;

/// Satu halaman mushaf (docs/design/v2/screens/03-mushaf-1-halaman.md):
/// kertas, bingkai hijau + garis emas, rosette sudut, tab juz, 15 baris dari
/// data layout, dan medali nomor halaman. Teks tidak ikut skala teks sistem:
/// tata letaknya tetap, yang mengatur ukuran adalah lebar halaman.
class MushafPageView extends StatelessWidget {
  const MushafPageView({
    super.key,
    required this.page,
    required this.arabicNames,
    this.tajweed = const {},
    this.juz,
  });

  final MushafComposedPage page;

  /// Nama surah berbahasa Arab (indeks 0 = surah 1).
  final List<String> arabicNames;

  /// Rentang tajwid per `surah:ayat`; kosong = teks polos.
  final Map<String, TajweedVerse> tajweed;
  final int? juz;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colors = MushafTokens.of(brightness);
    return MediaQuery.withNoTextScaling(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final kw = width / _baseWidth;
          // Margin atas/bawah mengikuti lebar, tapi tidak memakan tinggi
          // halaman yang pendek (dua halaman saat HP mendatar).
          final top = math.min(26 * kw, height * .045);
          final bottom = math.min(50 * kw, height * .08);
          final rowHeight = (height - top - bottom) / page.rows.length;
          // Ukuran huruf dan ornamen: terkecil antara skala lebar dan tinggi
          // baris, supaya semua kata satu baris diperkecil bersama, bukan
          // kata per kata.
          final k = math.min(kw, rowHeight / 27);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.paper,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: colors.ink.withValues(alpha: .08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CustomPaint(painter: _FramePainter(colors, k)),
                ),
              ),
              if (juz != null)
                Positioned(
                  right: -4,
                  top: 70 * k,
                  child: _JuzTab(juz: juz!, colors: colors, k: k),
                ),
              Positioned(
                left: 24 * k,
                right: 24 * k,
                top: top,
                height: rowHeight * page.rows.length,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    children: [
                      for (final row in page.rows)
                        SizedBox(
                          height: rowHeight,
                          child: _row(row, colors, brightness, k, rowHeight),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 14 * k,
                child: Center(
                  child: _PageMedallion(
                    number: page.number,
                    colors: colors,
                    k: k,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(
    MushafRow row,
    MushafTokens colors,
    Brightness brightness,
    double k,
    double rowHeight,
  ) {
    final fontSize = 18.5 * k;
    final quran = TextStyle(
      fontFamily: SacredText.quran,
      fontSize: fontSize,
      // Tinggi baris teks tidak melebihi baris halaman.
      height: math.min(1.9, rowHeight / fontSize),
      color: colors.ink,
    );
    switch (row) {
      case MushafHeaderRow(:final surah):
        return _SurahBand(
          // "سورة" adalah label judul, bukan teks ayat.
          name: 'سورة ${arabicNames[surah - 1]}',
          colors: colors,
          k: k,
        );
      case MushafBasmalahRow():
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(page.fatihahFirst, style: quran),
          ),
        );
      case MushafTextRow(:final items, :final centered):
        return Row(
          mainAxisAlignment: centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.spaceBetween,
          children: [
            for (final item in items)
              switch (item) {
                MushafVerseEnd(:final ayah) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2 * k),
                  child: RosetteBadge.ayah(ayah, size: 22 * k),
                ),
                MushafWordItem() => Flexible(
                  flex: math.max(1, item.range.end - item.range.start),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: centered ? 3 * k : 0,
                      ),
                      child: _word(item, quran, colors, brightness),
                    ),
                  ),
                ),
              },
          ],
        );
    }
  }

  Widget _word(
    MushafWordItem item,
    TextStyle style,
    MushafTokens colors,
    Brightness brightness,
  ) {
    final verse = tajweed[item.verseKey];
    return Text.rich(
      TextSpan(
        children: verse == null
            ? [TextSpan(text: page.textOf(item))]
            : tajweedSpans(
                verse,
                palette: TajweedPalette.draftPreview,
                brightness: brightness,
                base: colors.ink,
                from: item.range.start,
                to: item.range.end,
              ),
      ),
      textDirection: TextDirection.rtl,
      maxLines: 1,
      softWrap: false,
      style: style,
    );
  }
}

/// Bingkai hijau tebal 3 (inset 6), garis emas 1 (inset 11), rosette emas di
/// empat sudut. Ornamen digambar sendiri, tidak menjiplak ornamen penerbit.
class _FramePainter extends CustomPainter {
  const _FramePainter(this.colors, this.k);

  final MushafTokens colors;
  final double k;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = colors.frame;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(7.5, 7.5, size.width - 7.5, size.height - 7.5),
        const Radius.circular(4),
      ),
      frame,
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colors.gold;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(11.5, 11.5, size.width - 11.5, size.height - 11.5),
        const Radius.circular(2),
      ),
      line,
    );
    for (final corner in [
      const Offset(11, 11),
      Offset(size.width - 11, 11),
      Offset(11, size.height - 11),
      Offset(size.width - 11, size.height - 11),
    ]) {
      _rosette(canvas, corner, 6.8);
    }
  }

  void _rosette(Canvas canvas, Offset center, double half) {
    final fill = Paint()..color = colors.paper;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = colors.gold;
    final square = Rect.fromCenter(
      center: Offset.zero,
      width: half * 2,
      height: half * 2,
    );
    for (final angle in [0.0, math.pi / 4]) {
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(angle)
        ..drawRRect(
          RRect.fromRectAndRadius(square, const Radius.circular(1.1)),
          fill,
        )
        ..drawRRect(
          RRect.fromRectAndRadius(square, const Radius.circular(1.1)),
          stroke,
        )
        ..restore();
    }
    canvas.drawCircle(
      center,
      half * .78,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .66
        ..color = colors.gold.withValues(alpha: .55),
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.colors != colors || old.k != k;
}

/// Pita judul surah bersudut runcing, isi hdrFill dan garis emas ganda.
class _SurahBand extends StatelessWidget {
  const _SurahBand({required this.name, required this.colors, required this.k});

  final String name;
  final MushafTokens colors;
  final double k;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    label: name,
    excludeSemantics: true,
    child: CustomPaint(
      painter: _BandPainter(colors),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            name,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: SacredText.quran,
              fontSize: 15.9 * k,
              height: 1.4,
              color: colors.headerInk,
            ),
          ),
        ),
      ),
    ),
  );
}

class _BandPainter extends CustomPainter {
  const _BandPainter(this.colors);

  final MushafTokens colors;

  @override
  void paint(Canvas canvas, Size size) {
    // Pita 322×32,4 di tengah baris setinggi 40,5 (V2-Mushaf.html).
    final h = size.height * .8;
    final top = (size.height - h) / 2;
    final w = size.width;
    final tip = h * .52;
    Path band(double inset) => Path()
      ..moveTo(tip + inset, top + inset * .8)
      ..lineTo(w - tip - inset, top + inset * .8)
      ..lineTo(w - inset, top + h / 2)
      ..lineTo(w - tip - inset, top + h - inset * .8)
      ..lineTo(tip + inset, top + h - inset * .8)
      ..lineTo(inset, top + h / 2)
      ..close();
    canvas
      ..drawPath(band(.8), Paint()..color = colors.headerFill)
      ..drawPath(
        band(.8),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = colors.gold,
      )
      ..drawPath(
        band(4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .6
          ..color = colors.gold.withValues(alpha: .75),
      );
  }

  @override
  bool shouldRepaint(_BandPainter old) => old.colors != colors;
}

class _JuzTab extends StatelessWidget {
  const _JuzTab({required this.juz, required this.colors, required this.k});

  final int juz;
  final MushafTokens colors;
  final double k;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Juz $juz',
    excludeSemantics: true,
    child: Container(
      width: 14,
      height: 54 * k,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.tab,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
      ),
      child: RotatedBox(
        quarterTurns: 1,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'JUZ $juz',
            style: SacredText.chip.copyWith(color: colors.tabInk, fontSize: 9),
          ),
        ),
      ),
    ),
  );
}

class _PageMedallion extends StatelessWidget {
  const _PageMedallion({
    required this.number,
    required this.colors,
    required this.k,
  });

  final int number;
  final MushafTokens colors;
  final double k;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Halaman $number',
    excludeSemantics: true,
    child: Container(
      constraints: BoxConstraints(minWidth: 44 * k, minHeight: 24 * k),
      padding: EdgeInsets.symmetric(horizontal: 8 * k),
      decoration: BoxDecoration(
        color: colors.headerFill,
        borderRadius: BorderRadius.circular(12 * k),
        border: Border.all(color: colors.gold),
      ),
      child: Text(
        RosetteBadge.arabicNumerals(number),
        style: TextStyle(
          fontFamily: SacredText.quran,
          fontSize: 14 * k,
          height: 1.2,
          color: colors.headerInk,
        ),
      ),
    ),
  );
}
