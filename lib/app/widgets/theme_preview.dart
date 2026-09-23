import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';

/// Pratinjau satu tema: kotak kecil yang memakai warna tema itu sendiri, jadi
/// yang terlihat memang yang akan dipakai.
class ThemePreviewTile extends StatelessWidget {
  const ThemePreviewTile({
    super.key,
    required this.tokens,
    required this.label,
    required this.selected,
    required this.onTap,
    this.width = 96,
  });

  final SacredTokens tokens;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final current = Theme.of(context).extension<SacredTokens>()!;
    // `container` + `excludeSemantics` di simpul yang sama: membungkus
    // ExcludeSemantics justru membuat labelnya ikut hilang.
    return Semantics(
      container: true,
      excludeSemantics: true,
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 66,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? current.primary : current.sep,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: tokens.art,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: tokens.ink.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 6,
                      width: width * .4,
                      decoration: BoxDecoration(
                        color: tokens.ink.withValues(alpha: .28),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          width: 14,
                          height: 6,
                          decoration: BoxDecoration(
                            color: tokens.gold,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 22,
                          height: 6,
                          decoration: BoxDecoration(
                            color: tokens.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Tanpa ikon centang: pilihan sudah ditandai garis tebal dan
              // warna teks, sementara ikonnya memotong label yang panjang.
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: SacredText.footnote.copyWith(
                  color: selected ? current.primaryText : current.sec,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
