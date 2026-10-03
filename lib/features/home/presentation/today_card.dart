import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/concentric_rings.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/features/home/domain/today_summary.dart';

/// Kartu "Hari ini" (docs/design/v6/screens/19-beranda.md §5): tiga cincin +
/// legenda, kalimat bantu, dan pekan istiqamah. Ketuk → Progres.
class TodayCard extends StatelessWidget {
  const TodayCard({
    super.key,
    required this.summary,
    required this.today,
    required this.onTap,
  });

  final TodaySummary summary;
  final DateTime today;
  final VoidCallback onTap;

  static const _days = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final largeText = MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.6;
    final colors = {
      TodayRingKind.baca: tokens.primaryText,
      TodayRingKind.sesi: tokens.gold,
      TodayRingKind.murajaah: tokens.teal,
    };
    final rings = ConcentricRings(
      rings: [
        for (final ring in summary.rings)
          RingValue(fill: ring.fill, color: colors[ring.kind]!),
      ],
    );
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final ring in summary.rings)
          _LegendRow(ring: ring, color: colors[ring.kind]!),
      ],
    );
    return Semantics(
      button: true,
      label: [
        for (final ring in summary.rings) _spoken(ring),
        ?summary.hint,
        'Istiqamah ${summary.streak} hari',
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Teks besar atau kartu sempit (layar ~320 dp: isi 248):
                // legenda di samping cincin tidak muat, jadi cincin pindah ke
                // atas legenda (DESIGN v6 §7).
                LayoutBuilder(
                  builder: (context, box) => largeText || box.maxWidth < 300
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: rings),
                            const SizedBox(height: 12),
                            legend,
                          ],
                        )
                      : Row(
                          children: [
                            rings,
                            const SizedBox(width: 16),
                            Expanded(child: legend),
                          ],
                        ),
                ),
                if (summary.hint case final hint?) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: BoxDecoration(
                      color: tokens.bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      hint,
                      style: SacredText.nextStepBody.copyWith(
                        color: tokens.ink,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(height: 1, color: tokens.sep),
                const SizedBox(height: 12),
                _Week(
                  week: summary.week,
                  streak: summary.streak,
                  today: today,
                  days: _days,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _spoken(TodayRing ring) => switch (ring.kind) {
    TodayRingKind.baca => 'Baca ${ring.value} dari ${ring.total} menit',
    TodayRingKind.sesi => 'Sesi ${ring.value} dari ${ring.total} langkah',
    TodayRingKind.murajaah =>
      ring.note ?? 'Murajaah ${ring.value} dari ${ring.total} ayat',
  };
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.ring, required this.color});

  final TodayRing ring;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final (label, unit) = switch (ring.kind) {
      TodayRingKind.baca => ('Baca', 'mnt'),
      TodayRingKind.sesi => ('Sesi', 'langkah'),
      TodayRingKind.murajaah => ('Murajaah', 'ayat'),
    };
    final note = ring.note;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SacredText.legendLabel.copyWith(color: tokens.ink),
            ),
          ),
          if (note != null)
            Text(note, style: SacredText.legendUnit.copyWith(color: tokens.sec))
          else
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${ring.value}',
                    style: SacredText.legendValue.copyWith(color: tokens.ink),
                  ),
                  TextSpan(
                    text: '/${ring.total} $unit',
                    style: SacredText.legendUnit.copyWith(color: tokens.sec),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Api + "N hari" lalu 7 titik Senin–Minggu pekan ini. Tercapai `gold`,
/// hari ini lingkaran putus-putus `gold`, belum `surf2`.
class _Week extends StatelessWidget {
  const _Week({
    required this.week,
    required this.streak,
    required this.today,
    required this.days,
  });

  /// 7 hari terakhir (terlama dulu, hari ini terakhir).
  final List<bool> week;
  final int streak;
  final DateTime today;
  final List<String> days;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final todayIndex = today.weekday - 1;
    return Row(
      children: [
        LineIcon(SacredIcons.flame, color: tokens.goldText, size: 18),
        const SizedBox(width: 6),
        Text(
          '$streak hari',
          style: SacredText.withWeight(
            SacredText.legendLabel,
            800,
          ).copyWith(color: tokens.ink),
        ),
        const SizedBox(width: 12),
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Column(
              children: [
                _DayDot(
                  reached: _reached(i, todayIndex),
                  today: i == todayIndex,
                ),
                const SizedBox(height: 4),
                Text(
                  days[i],
                  style: SacredText.weekDay.copyWith(
                    color: i == todayIndex ? tokens.ink : tokens.sec,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Hari ke-[i] pekan ini (0 = Senin) tercapai menurut 7 hari terakhir.
  bool _reached(int i, int todayIndex) {
    final ago = todayIndex - i;
    if (ago < 0 || ago >= week.length) return false;
    return week[week.length - 1 - ago];
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.reached, required this.today});

  final bool reached;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return SizedBox.square(
      dimension: 14,
      child: CustomPaint(
        painter: _DotPainter(
          fill: reached ? tokens.gold : (today ? null : tokens.surf2),
          dashed: today && !reached ? tokens.gold : null,
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter({this.fill, this.dashed});

  final Color? fill;
  final Color? dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (fill case final color?) canvas.drawCircle(c, r, Paint()..color = color);
    if (dashed case final color?) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color;
      const segments = 8;
      for (var i = 0; i < segments; i++) {
        final start = i * 2 * 3.14159265 / segments;
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r - 1),
          start,
          3.14159265 / segments,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.fill != fill || old.dashed != dashed;
}
