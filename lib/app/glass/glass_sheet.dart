import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass/glass_tokens.dart';
import 'package:quran_app_2025/app/glass/liquid_glass.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';

/// Bottom sheet v4 (LIQUID_GLASS.md §2): kepala berkaca (grabber + judul),
/// isi tetap padat. Semua sheet kaca dibuka lewat sini supaya bentuk,
/// angka, dan geraknya sama; jangan menyalin susunan ini di tiap sheet.
///
/// [header] dibangun dengan context sheet (mis. untuk tombol tutup).
/// [background] warna isi; bawaannya `surf`.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  WidgetBuilder? header,
  Color? background,
  bool isScrollControlled = true,
}) {
  final tokens = Theme.of(context).extension<SacredTokens>()!;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    // Warna dan bentuk digambar GlassSheet: kepala kaca bersudut 28, isi padat.
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (sheetContext) => GlassSheet(
      header: header?.call(sheetContext),
      background: background ?? tokens.surf,
      child: builder(sheetContext),
    ),
  );
}

/// Susunan sheet kaca: kepala [LiquidGlass] ukuran sheet, lalu isi padat.
class GlassSheet extends StatelessWidget {
  const GlassSheet({
    super.key,
    required this.child,
    required this.background,
    this.header,
  });

  final Widget child;
  final Widget? header;
  final Color background;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LiquidGlass(
        size: GlassSize.sheet,
        // Sheet menempel di tepi bawah layar; bayangan L0 tidak perlu.
        shadow: false,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [const _Grabber(), ?header],
        ),
      ),
      Flexible(
        child: ColoredBox(color: background, child: child),
      ),
    ],
  );
}

/// Grabber 36 × 5. Setelah sheet terbuka penuh, grabber meregang sedikit
/// (maks 30%) saat sheet ditarik turun (§6).
class _Grabber extends StatefulWidget {
  const _Grabber();

  @override
  State<_Grabber> createState() => _GrabberState();
}

class _GrabberState extends State<_Grabber> {
  static const _width = 36.0;
  static const _maxStretch = .30;

  /// Regangan hanya dihitung setelah sheet pernah terbuka penuh, supaya
  /// grabber tidak ikut meregang saat sheet sedang muncul.
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final animation = ModalRoute.of(context)?.animation;
    final reduced = MediaQuery.disableAnimationsOf(context);
    Widget bar(double stretch) => Container(
      width: _width * (1 + stretch),
      height: 5,
      decoration: BoxDecoration(
        color: tokens.tertiary,
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
        child: Center(
          child: animation == null || reduced
              ? bar(0)
              : AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    if (animation.value >= 1) _opened = true;
                    final pulled = _opened ? 1 - animation.value : 0.0;
                    return bar((pulled * 3).clamp(0.0, 1.0) * _maxStretch);
                  },
                ),
        ),
      ),
    );
  }
}
