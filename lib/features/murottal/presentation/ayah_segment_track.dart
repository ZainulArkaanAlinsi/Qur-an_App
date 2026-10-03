import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/features/murottal/application/player_view_model.dart';

/// Kemajuan murottal per ayat (docs/design/v6/screens/20-murottal.md §4,
/// 21-dock.md): satu segmen per ayat dalam antrean.
///
/// - Selesai `primaryText`, belum `surf2`, ayat aktif terisi `gold` sesuai
///   [fraction] posisi audio.
/// - Antrean lebih dari [segmentLimit] ayat: satu bar kontinu supaya tidak
///   menjadi garis rapat.
/// - [mini]: versi dock (tinggi 3, celah 3, tanpa halo, tidak bisa diketuk).
/// - [onSelect]: versi Murottal. Ketuk segmen = lompat ke ayat itu; geser =
///   pilih ayat (haptic per ayat), audio pindah saat jari diangkat.
class AyahSegmentTrack extends StatefulWidget {
  const AyahSegmentTrack({
    super.key,
    required this.total,
    required this.index,
    required this.fraction,
    this.mini = false,
    this.onSelect,
    this.semanticsValue,
  });

  /// Jumlah ayat di antrean.
  final int total;

  /// Indeks ayat yang diputar dalam antrean (0-based).
  final int index;

  /// Posisi di ayat yang diputar, 0..1.
  final double fraction;
  final bool mini;

  /// Dipanggil dengan indeks ayat yang dipilih; null = hanya tampilan.
  final ValueChanged<int>? onSelect;

  /// Label untuk pembaca layar, mis. "Ayat 5 dari 7"; nilainya posisi dalam
  /// antrean ("5 dari 7") supaya bisa digeser naik/turun.
  final String? semanticsValue;

  /// Batas segmen: lebih dari ini memakai bar kontinu (DATA.md §5.2).
  static const segmentLimit = PlayerView.segmentLimit;

  /// Isi bar kontinu, tidak pernah > 1.
  static double continuousFill(int total, int index, double fraction) =>
      PlayerView.continuousFill(total, index, fraction);

  @override
  State<AyahSegmentTrack> createState() => _AyahSegmentTrackState();
}

class _AyahSegmentTrackState extends State<AyahSegmentTrack> {
  /// Ayat yang sedang dipilih dengan jari; null bila tidak sedang digeser.
  int? _dragging;

  int _indexAt(double dx, double width) {
    if (width <= 0 || widget.total <= 0) return 0;
    return (dx / width * widget.total).floor().clamp(0, widget.total - 1);
  }

  void _drag(double dx, double width) {
    final next = _indexAt(dx, width);
    if (next == _dragging) return;
    HapticFeedback.selectionClick();
    setState(() => _dragging = next);
  }

  void _release() {
    final picked = _dragging;
    setState(() => _dragging = null);
    if (picked != null) widget.onSelect?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final total = widget.total;
    final dragging = _dragging;
    final track = RepaintBoundary(
      child: CustomPaint(
        size: Size(double.infinity, widget.mini ? 3 : 7),
        painter: _TrackPainter(
          total: total,
          index: (dragging ?? widget.index).clamp(0, total > 0 ? total - 1 : 0),
          fraction: dragging != null ? 0 : widget.fraction.clamp(0.0, 1.0),
          gap: widget.mini ? 3 : 4,
          radius: widget.mini ? 1.5 : 4,
          done: tokens.primaryText,
          rest: tokens.surf2,
          active: tokens.gold,
          halo: widget.mini ? null : tokens.goldSoft,
        ),
      ),
    );
    final onSelect = widget.onSelect;
    if (widget.mini) return track;
    // Jarak atas/bawah sama dengan versi yang bisa diketuk, supaya tata
    // letak panel tidak bergeser saat lompat dimatikan (galat, per surah).
    if (onSelect == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: track,
      );
    }
    String position(int index) => '${index + 1} dari $total';
    final canIncrease = widget.index < total - 1;
    final canDecrease = widget.index > 0;
    return LayoutBuilder(
      builder: (context, box) => Semantics(
        label: widget.semanticsValue ?? 'Ayat dalam antrean',
        value: position(widget.index),
        increasedValue: canIncrease ? position(widget.index + 1) : null,
        decreasedValue: canDecrease ? position(widget.index - 1) : null,
        onIncrease: canIncrease ? () => onSelect(widget.index + 1) : null,
        onDecrease: canDecrease ? () => onSelect(widget.index - 1) : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) =>
              onSelect(_indexAt(details.localPosition.dx, box.maxWidth)),
          onHorizontalDragStart: (details) =>
              _drag(details.localPosition.dx, box.maxWidth),
          onHorizontalDragUpdate: (details) =>
              _drag(details.localPosition.dx, box.maxWidth),
          onHorizontalDragEnd: (_) => _release(),
          onHorizontalDragCancel: () => setState(() => _dragging = null),
          // Bar setinggi 7 terlalu kecil untuk jari; area sentuhnya 31.
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: track,
          ),
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
