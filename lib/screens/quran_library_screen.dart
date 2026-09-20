import 'package:flutter/material.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';

class QuranLibraryScreen extends StatefulWidget {
  const QuranLibraryScreen({super.key});
  @override
  State<QuranLibraryScreen> createState() => _QuranLibraryScreenState();
}

class _QuranLibraryScreenState extends State<QuranLibraryScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final results = surahCatalog
        .where(
          (surah) =>
              surah.name.toLowerCase().contains(_query.toLowerCase()) ||
              surah.number.toString() == _query,
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Qur’an',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '114 surah · pilih untuk mulai membaca',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              TextField(
                onChanged: (value) => setState(() => _query = value.trim()),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Cari nama atau nomor surah',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? const Center(child: Text('Surah tidak ditemukan.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _SurahRow(surah: results[index]),
                ),
        ),
      ],
    );
  }
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({required this.surah});
  final SurahMeta surah;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ReaderScreen(surah: surah))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
        child: Text(
          '${surah.number}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(
        surah.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${surah.revelation} · ${surah.ayahCount} ayat'),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}
