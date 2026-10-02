import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';

/// Kemajuan murottal per ayat (docs/design/v6/screens/20-murottal.md §4,
/// 21-dock.md): satu segmen per ayat dalam antrean.
///
/// - Selesai `primaryText`, belum `surf2`, ayat aktif terisi `gold` sesuai
///   [fraction] posisi audio.
/// - Antrean lebih dari [segmentLimit] ayat: satu bar kontinu supaya tidak
///   menjadi garis rapat.
/// - [mini]: versi dock (tinggi 3, celah 3, tanpa halo). Versi besar yang
///   bisa diketuk/digeser ditambahkan bersama layar Murottal v6.
class AyahSegmentTrack extends StatelessWidget {
  const AyahSegmentTrack({
    super.key,
    required this.total,
    required this.index,
    required this.fraction,
    this.mini = false,
  });

  /// Jumlah ayat di antrean.
  final int total;

  /// Indeks ayat yang diputar dalam antrean (0-based).
  final int index;

  /// Posisi di ayat yang diputar, 0..1.
  final double fraction;
  final bool mini;

  /// Batas segmen: lebih dari ini memakai bar kontinu (DATA.md §5.2).
  static const segmentLimit = 40;

  /// Isi bar kontinu, tidak pernah > 1.
  static double continuousFill(int total, int index, double fraction) {
    if (total <= 0) return 0;
    return ((index + fraction.clamp(0.0, 1.0)) / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(double.infinity, mini ? 3 : 7),
        painter: _TrackPainter(
          total: total,
          index: index.clamp(0, total > 0 ? total - 1 : 0),
          fraction: fraction.clamp(0.0, 1.0),
          gap: mini ? 3 : 4,
          radius: mini ? 1.5 : 4,
          done: tokens.primaryText,
          rest: tokens.surf2,
          active: tokens.gold,
          halo: mini ? null : tokens.goldSoft,
        ),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.total,
    required this.index,
    required this.fraction,
    required this.gap,
    required this.radius,
    required this.done,
    required this.rest,
    required this.active,
    required this.halo,
  });

  final int total;
  final int index;
  final double fraction;
  final double gap;
  final double radius;
  final Color done;
  final Color rest;
  final Color active;
  final Color? halo;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final r = Radius.circular(radius);
    final h = size.height;
    if (total > AyahSegmentTrack.segmentLimit) {
      final full = Offset.zero & size;
      canvas.drawRRect(RRect.fromRectAndRadius(full, r), Paint()..color = rest);
      final fill = AyahSegmentTrack.continuousFill(total, index, fraction);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width * fill, h), r),
        Paint()..color = active,
      );
      return;
    }
    final width = (size.width - gap * (total - 1)) / total;
    for (var i = 0; i < total; i++) {
      final rect = Rect.fromLTWH(i * (width + gap), 0, width, h);
      if (i < index) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, r),
          Paint()..color = done,
        );
      } else if (i == index) {
        final glow = halo;
        if (glow != null) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              rect.inflate(3),
              Radius.circular(radius + 3),
            ),
            Paint()..color = glow,
          );
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, r),
          Paint()..color = rest,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left, 0, width * fraction, h),
            r,
          ),
          Paint()..color = active,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, r),
          Paint()..color = rest,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.total != total ||
      old.index != index ||
      old.fraction != fraction ||
      old.done != done ||
      old.rest != rest ||
      old.active != active ||
      old.halo != halo;
}
