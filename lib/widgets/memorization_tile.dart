import 'package:flutter/material.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/models/memorization_status.dart';
import 'package:quran_app_2025/screens/practice_screen.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Baris surah dengan status hafalan yang dapat diubah dengan satu ketukan.
/// Status hanya catatan pribadi: aplikasi tidak menilai bacaan.
class MemorizationTile extends StatefulWidget {
  const MemorizationTile({super.key, required this.surah, this.onChanged});

  final int surah;
  final VoidCallback? onChanged;

  @override
  State<MemorizationTile> createState() => _MemorizationTileState();
}

class _MemorizationTileState extends State<MemorizationTile> {
  late MemorizationStatus _status =
      SharedPreferencesService.getMemorizationStatus(widget.surah);

  Future<void> _cycle() async {
    final next = _status.next;
    setState(() => _status = next);
    await SharedPreferencesService.setMemorizationStatus(widget.surah, next);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final meta = surahCatalog[widget.surah - 1];
    final theme = Theme.of(context);
    // ListTile berada di atas permukaan berwarna (GlassSurface); tanpa
    // Material sendiri, efek sentuhnya tidak terlihat.
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: .12),
          child: Text(
            '${meta.number}',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(meta.displayName),
        subtitle: Text('${meta.ayahCount} ayat · ${meta.revelation}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Latihan hafalan',
              icon: const Icon(Icons.school_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PracticeScreen(surah: meta),
                ),
              ),
            ),
            ActionChip(
              avatar: Icon(_status.icon, size: 18),
              label: Text(_status.label),
              tooltip: 'Ubah status hafalan',
              onPressed: _cycle,
            ),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ReaderScreen(surah: meta)),
        ),
      ),
    );
  }
}
