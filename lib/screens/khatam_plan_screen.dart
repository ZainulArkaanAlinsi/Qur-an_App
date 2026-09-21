import 'package:flutter/material.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

class KhatamPlanScreen extends StatefulWidget {
  const KhatamPlanScreen({super.key});
  @override
  State<KhatamPlanScreen> createState() => _KhatamPlanScreenState();
}

class _KhatamPlanScreenState extends State<KhatamPlanScreen> {
  late Set<int> _completed;
  @override
  void initState() {
    super.initState();
    _completed = SharedPreferencesService.getCompletedSurahs();
  }

  int get _completedAyahs => surahCatalog
      .where((surah) => _completed.contains(surah.number))
      .fold(0, (sum, surah) => sum + surah.ayahCount);

  @override
  Widget build(BuildContext context) {
    final progress = _completedAyahs / 6236;
    return Scaffold(
      appBar: AppBar(title: const Text('Progres Khatam')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(progress * 100).round()}% selesai',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress, minHeight: 8),
                    const SizedBox(height: 10),
                    Text(
                      '$_completedAyahs dari 6.236 ayat pada ${_completed.length} surah. Tandai hanya setelah selesai membaca surah.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
              itemCount: surahCatalog.length,
              separatorBuilder: (_, __) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final surah = surahCatalog[index];
                final checked = _completed.contains(surah.number);
                return Card(
                  child: CheckboxListTile(
                    value: checked,
                    title: Text(
                      surah.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('${surah.ayahCount} ayat'),
                    onChanged: (value) async {
                      setState(() {
                        value == true
                            ? _completed.add(surah.number)
                            : _completed.remove(surah.number);
                      });
                      await SharedPreferencesService.setSurahCompleted(
                        surah.number,
                        value ?? false,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
