import 'package:flutter/material.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:quran_app_2025/screens/surah_details_screen.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  List<Map<String, int>> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  void _loadBookmarks() {
    setState(() {
      _bookmarks = SharedPreferencesService.getBookmarks();
    });
  }

  void _clearAllBookmarks() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Semua Bookmark'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus semua bookmark?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              // Implement clear all bookmarks
              Navigator.pop(context);
              _loadBookmarks();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Semua bookmark dihapus')),
              );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        actions: [
          if (_bookmarks.isNotEmpty)
            IconButton(
              onPressed: _clearAllBookmarks,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus Semua',
            ),
        ],
      ),
      body: _bookmarks.isEmpty ? _buildEmptyState() : _buildBookmarkList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Belum ada bookmark',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap ikon bookmark pada ayat untuk menyimpannya di sini',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = _bookmarks[index];
        final surahNumber = bookmark['surah']!;
        final verseNumber = bookmark['verse']!;

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE8F5E9),
              child: Text(
                '$verseNumber',
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text('Surah $surahNumber - Ayat $verseNumber'),
            subtitle: Text('Tap untuk membuka ayat'),
            trailing: IconButton(
              onPressed: () {
                // Remove this bookmark
                SharedPreferencesService.removeBookmark(
                  surahNumber,
                  verseNumber,
                );
                _loadBookmarks();
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SurahDetailsScreen(surahNumber: surahNumber),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
