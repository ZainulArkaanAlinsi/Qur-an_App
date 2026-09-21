import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/screens/khatam_plan_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final progress = ReadingProgressService.read();
    final completion = (progress.todaySeconds / progress.targetSeconds).clamp(
      0.0,
      1.0,
    );
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text(
          'Progres',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Catatan kecil untuk menemani kebiasaan baikmu.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [SacredTheme.primaryContainer, SacredTheme.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: completion,
                      strokeWidth: 8,
                      color: SacredTheme.gold,
                      backgroundColor: Colors.white.withValues(alpha: .18),
                    ),
                    Text(
                      '${(completion * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target hari ini',
                      style: TextStyle(color: Color(0xFFD7F0E4)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${progress.todaySeconds ~/ 60} / ${progress.targetSeconds ~/ 60} menit',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      progress.completedToday
                          ? 'Target hari ini telah tercapai.'
                          : 'Lanjutkan dari halaman Qur’an.',
                      style: const TextStyle(
                        color: Color(0xFFD7F0E4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Kebiasaan membaca',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.local_fire_department_outlined,
                label: 'Rentetan',
                value: '${progress.currentStreak} hari',
                tint: SacredTheme.gold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.workspace_premium_outlined,
                label: 'Terbaik',
                value: '${progress.longestStreak} hari',
                tint: const Color(0xFFB0F0D6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _WeekStrip(days: progress.recentDays),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: SacredTheme.primary.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.timelapse_rounded,
                    color: SacredTheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total waktu membaca',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${progress.totalSeconds ~/ 60} menit tercatat di perangkat ini',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.auto_stories_outlined),
            title: const Text(
              'Progres Khatam',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Tandai surah yang telah selesai dibaca.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const KhatamPlanScreen())),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Waktu ini adalah estimasi saat pembaca aktif di depan layar, bukan ukuran ibadah.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days});

  /// Oldest-first qualifying flags; the last entry is today.
  final List<bool> days;
  static const _labels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final today = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '7 hari terakhir',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: _DayDot(
                      label:
                          _labels[today
                                  .subtract(Duration(days: days.length - 1 - i))
                                  .weekday -
                              1],
                      done: days[i],
                      isToday: i == days.length - 1,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.done,
    required this.isToday,
  });
  final String label;
  final bool done;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label, ${done ? 'target tercapai' : 'belum tercapai'}',
      excludeSemantics: true,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? SacredTheme.primaryContainer : Colors.transparent,
              border: Border.all(
                color: isToday
                    ? SacredTheme.gold
                    : theme.colorScheme.outlineVariant,
                width: isToday ? 2 : 1,
              ),
            ),
            child: done
                ? const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: SacredTheme.gold,
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 3),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}
