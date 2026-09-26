import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';

/// Penunjuk langkah bernomor (Setor hafalan, Sesi hari ini): titik 26 dengan
/// label di bawahnya. Sebelum = emas, aktif = CTA, sesudah = abu.
///
/// [onTap] null berarti penunjuk hanya menunjukkan posisi, tidak bisa
/// diketuk.
class StepDots extends StatelessWidget {
  const StepDots({
    super.key,
    required this.labels,
    required this.current,
    this.onTap,
    this.semanticLabels,
  });

  final List<String> labels;

  /// Indeks langkah aktif.
  final int current;
  final ValueChanged<int>? onTap;

  /// Nama lengkap untuk pembaca layar; bawaannya [labels].
  final List<String>? semanticLabels;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: Semantics(
                button: onTap != null,
                selected: index == current,
                label:
                    'Langkah ${index + 1}, '
                    '${(semanticLabels ?? labels)[index]}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: onTap == null ? null : () => onTap!(index),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        _dot(tokens, index),
                        const SizedBox(height: 5),
                        // Jarak kecil supaya label yang mengecil di teks
                        // besar tidak saling menempel.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              labels[index],
                              maxLines: 1,
                              style:
                                  (index == current
                                          ? SacredText.stepActive
                                          : SacredText.stepIdle)
                                      .copyWith(
                                        color: index == current
                                            ? tokens.ink
                                            : tokens.sec,
                                      ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot(SacredTokens tokens, int index) {
    final (Color bg, Color fg) = index == current
        ? (tokens.cta, tokens.ctaInk)
        : index < current
        // Selesai = emas. Di tema gelap CTA juga emas, jadi pakai emas lembut
        // supaya langkah aktif tetap terbedakan.
        ? tokens.cta == tokens.artInk
              ? (tokens.goldSoft, tokens.goldText)
              : (tokens.artInk, tokens.onGold)
        : (tokens.surf2, tokens.sec);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        '${index + 1}',
        textScaler: TextScaler.noScaling,
        style: SacredText.stepNumber.copyWith(color: fg),
      ),
    );
  }
}
