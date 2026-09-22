import 'package:flutter/material.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';

class QuranSearchScreen extends StatefulWidget {
  const QuranSearchScreen({super.key});
  @override
  State<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends State<QuranSearchScreen> {
  String _query = '';
  late Future<List<List<String>>> _all;

  Future<List<List<String>>> _load() => Future.wait(
    List.generate(
      114,
      (index) => QuranTextRepository.instance.versesForSurah(index + 1),
    ),
  );

  @override
  void initState() {
    super.initState();
    _all = _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cari ayat Arab')),
    body: FutureBuilder<List<List<String>>>(
      future: _all,
      builder: (context, snapshot) {
        // Checked before hasData: a failed load would otherwise leave the
        // spinner running forever with no way to recover.
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Teks Al-Qur’an tidak dapat dimuat.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => setState(() => _all = _load()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = <_SearchResult>[];
        if (_query.isNotEmpty) {
          for (var s = 0; s < snapshot.data!.length; s++) {
            for (var a = 0; a < snapshot.data![s].length; a++) {
              if (snapshot.data![s][a].contains(_query)) {
                results.add(_SearchResult(s + 1, a + 1, snapshot.data![s][a]));
              }
            }
          }
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Masukkan kata Arab',
                ),
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? const Center(
                      child: Text(
                        'Pencarian dilakukan offline pada teks Arab.',
                      ),
                    )
                  : results.isEmpty
                  ? const Center(child: Text('Ayat tidak ditemukan.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final result = results[index];
                        final surah = surahCatalog[result.surah - 1];
                        return Card(
                          child: ListTile(
                            title: Text(
                              '${surah.displayName} : ${result.ayah}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(
                                result.text,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontFamily: 'Amiri',
                                  fontSize: 21,
                                ),
                              ),
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReaderScreen(
                                  surah: surah,
                                  initialVerse: result.ayah,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );
}

class _SearchResult {
  const _SearchResult(this.surah, this.ayah, this.text);
  final int surah;
  final int ayah;
  final String text;
}
