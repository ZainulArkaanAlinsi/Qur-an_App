import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass_surface.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tersimpan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: keys.isEmpty
          ? const _EmptyBookmarks()
          : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              itemCount: keys.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final parts = keys[index].split('_');
                final surahId = int.parse(parts[1]);
                final verse = int.parse(parts[2]);
                final surah = surahCatalog.firstWhere(
                  (item) => item.number == surahId,
                );
                return GlassSurface(
                  padding: const EdgeInsets.fromLTRB(15, 12, 10, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: SacredTheme.gold.withValues(alpha: .28),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.bookmark_rounded,
                          color: SacredTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReaderScreen(
                                surah: surah,
                                initialVerse: verse,
                              ),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  surah.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Ayat $verse',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  SharedPreferencesService.getBookmarkCollection(
                                    surahId,
                                    verse,
                                  ),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: SacredTheme.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Hapus bookmark',
                        onPressed: () async {
                          await SharedPreferencesService.removeBookmark(
                            surahId,
                            verse,
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.folder_outlined),
                        onSelected: (value) async {
                          await SharedPreferencesService.setBookmarkCollection(
                            surahId,
                            verse,
                            value,
                          );
                          if (mounted) setState(() {});
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'Umum', child: Text('Umum')),
                          PopupMenuItem(
                            value: 'Hafalan',
                            child: Text('Hafalan'),
                          ),
                          PopupMenuItem(
                            value: 'Favorit',
                            child: Text('Favorit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyBookmarks extends StatelessWidget {
  const _EmptyBookmarks();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: GlassSurface(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SacredTheme.primary.withValues(alpha: .10),
              ),
              child: const Icon(
                Icons.bookmark_add_outlined,
                color: SacredTheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada yang disimpan',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              'Tandai ayat dari Reader agar mudah dilanjutkan kembali.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
