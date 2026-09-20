import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';

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
    final percent = (progress.todaySeconds / progress.targetSeconds).clamp(
      0.0,
      1.0,
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Progres',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Estimasi waktu saat pembaca aktif di depan layar. Ini bukan ukuran ibadah.',
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: SacredTheme.primaryContainer,
                  ),
                  child: const Icon(
                    Icons.local_fire_department_outlined,
                    color: SacredTheme.gold,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${progress.currentStreak} hari berturut-turut',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Terbaik: ${progress.longestStreak} hari'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Target hari ini',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${progress.todaySeconds ~/ 60}/${progress.targetSeconds ~/ 60} menit',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: percent,
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(height: 10),
                Text(
                  progress.completedToday
                      ? 'Target hari ini sudah tercapai.'
                      : 'Baca di halaman Qur’an untuk melanjutkan target.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(
              Icons.timelapse_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text(
              'Total waktu membaca',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${progress.totalSeconds ~/ 60} menit tercatat secara lokal',
            ),
          ),
        ),
      ],
    );
  }
}
