import 'package:flutter/material.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});
  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  @override
  Widget build(BuildContext context) {
    final keys = SharedPreferencesService.getBookmarks();
    if (keys.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bookmark')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'Belum ada bookmark. Tandai ayat dari halaman pembaca agar mudah kembali lagi.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmark')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: keys.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final parts = keys[index].split('_');
          final surahId = int.parse(parts[1]);
          final verse = int.parse(parts[2]);
          final surah = surahCatalog.firstWhere(
            (item) => item.number == surahId,
          );
          return Card(
            child: ListTile(
              leading: const Icon(Icons.bookmark),
              title: Text(
                surah.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('Ayat $verse'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Hapus bookmark',
                onPressed: () async {
                  await SharedPreferencesService.removeBookmark(surahId, verse);
                  if (mounted) setState(() {});
                },
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ReaderScreen(surah: surah)),
              ),
            ),
          );
        },
      ),
    );
  }
}
