import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/features/session/domain/session_plan.dart';

/// Kartu "Sesi hari ini" di Beranda (SESI_HARIAN.md §4): ±10 menit, lima
/// titik langkah, tombol Mulai/Lanjutkan. Setelah selesai menjadi
/// "Selesai hari ini ✓ · besok: `judul`".
class SessionTodayCard extends StatelessWidget {
  const SessionTodayCard({
    super.key,
    required this.session,
    required this.onOpen,
  });

  /// Sesi hari ini, atau null bila belum dimulai.
  final DailySession? session;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final today = session;
    final done = today?.completed ?? false;
    final started = today != null && !done;
    final step = today?.step.index ?? 0;
    final String subtitle;
    if (done) {
      // Tanda centang digambar sebagai ikon: font antarmuka tidak punya
      // glyph ✓.
      subtitle = [
        'Selesai hari ini',
        if (today?.tomorrow case final next?) 'besok: $next',
      ].join(' · ');
    } else if (started) {
      subtitle = 'Lanjut dari langkah ${step + 1}: ${today.step.title}';
    } else {
      subtitle = 'Ulang, materi baru, temukan di ayat, lalu tirukan qari.';
    }

    final dots = Semantics(
      label: done ? 'Kelima langkah selesai' : 'Langkah ${step + 1} dari 5',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var index = 0; index < SessionStep.values.length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            // Selesai = emas, aktif = CTA dan lebih besar (di tema gelap
            // CTA juga emas, jadi ukurannya yang membedakan), belum =
            // lingkaran bergaris supaya tetap terlihat di kartu gelap.
            Container(
              width: index == step && started ? 14 : 10,
              height: index == step && started ? 14 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || index < step
                    ? tokens.artInk
                    : index == step && started
                    ? tokens.cta
                    : null,
                border: done || index < step || (index == step && started)
                    ? null
                    : Border.all(color: tokens.sec, width: 1.5),
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(24),
          child: SacredCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SoftIconCircle(
                      icon: done ? SacredIcons.checkCircle : SacredIcons.cap,
                      size: 40,
                      iconSize: 18,
                    ),
                    const SizedBox(width: 12),
                    // Judul boleh turun baris di teks besar, tidak dipotong.
                    Expanded(
                      child: Text(
                        'Sesi hari ini',
                        style: SacredText.stageTitle.copyWith(
                          color: tokens.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const StatusPill('±10 mnt', tone: PillTone.neutral),
                  ],
                ),
                const SizedBox(height: 10),
                if (done)
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Selesai hari ini '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: LineIcon(
                            SacredIcons.checkCircle,
                            color: tokens.primaryText,
                            size: 16,
                          ),
                        ),
                        if (today?.tomorrow case final next?)
                          TextSpan(text: ' · besok: $next'),
                      ],
                    ),
                    semanticsLabel: subtitle,
                    style: SacredText.stageSummary.copyWith(
                      color: tokens.primaryText,
                    ),
                  )
                else
                  Text(
                    subtitle,
                    style: SacredText.stageSummary.copyWith(color: tokens.sec),
                  ),
                const SizedBox(height: 12),
                if (done)
                  dots
                else
                  Row(
                    children: [
                      Expanded(child: dots),
                      const SizedBox(width: 12),
                      SacredButton(
                        label: started ? 'Lanjutkan' : 'Mulai',
                        height: 44,
                        icon: started ? null : SacredIcons.play,
                        iconFilled: true,
                        onTap: onOpen,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
