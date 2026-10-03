import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass/glass_tokens.dart';
import 'package:quran_app_2025/app/glass/liquid_glass.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';

/// Lembar bawah v4 (docs/design/v4-liquid-glass/LIQUID_GLASS.md §2): hanya
/// kepala yang berkaca (grabber + judul + aksi); isinya padat `surf`.
///
/// [builder] mengembalikan [GlassSheet] supaya isi yang punya state (mis.
/// tombol Simpan) bisa mengisi kepala sendiri.
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  elevation: 0,
  // Bentuk & warna dibuat sendiri oleh [GlassSheet].
  backgroundColor: const Color(0x00000000),
  builder: (context) => BackdropGroup(child: Builder(builder: builder)),
);

class GlassSheet extends StatelessWidget {
  const GlassSheet({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });

  final String title;

  /// Aksi di kanan kepala, mis. "Simpan".
  final Widget? action;

  /// Isi yang bisa digulir.
  final Widget child;

  static const radius = Radius.circular(28);

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final action = this.action;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .92,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: radius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LiquidGlass(
                borderRadius: const BorderRadius.vertical(top: radius),
                size: GlassSize.sheet,
                shadow: false,
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 6),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: tokens.tertiary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: SacredText.stageTitle.copyWith(
                                color: tokens.ink,
                              ),
                            ),
                          ),
                        ),
                        ?action,
                      ],
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ColoredBox(color: tokens.surf, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
