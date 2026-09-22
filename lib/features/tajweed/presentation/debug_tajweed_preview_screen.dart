import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_palette.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_verse_panel.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Layar pratinjau tajwid KHUSUS build debug (dibuka dari Pengaturan hanya
/// bila `kDebugMode`). Mengambil data langsung dari endpoint publik
/// api.quran.com untuk uji visual; ini bukan jalur produksi — produksi wajib
/// lewat BFF dengan Content API resmi (docs/DATA_SOURCES_AND_LICENSES.md).
class DebugTajweedPreviewScreen extends StatefulWidget {
  const DebugTajweedPreviewScreen({super.key, this.client});

  /// Untuk tes; `null` = klien HTTP baru.
  final http.Client? client;

  @override
  State<DebugTajweedPreviewScreen> createState() =>
      _DebugTajweedPreviewScreenState();
}

class _PreviewVerse {
  const _PreviewVerse(this.key, this.tajweed, this.uthmani, this.translation);

  final String key;
  final String tajweed;
  final String uthmani;
  final String? translation;
}

class _DebugTajweedPreviewScreenState extends State<DebugTajweedPreviewScreen> {
  static const _base = 'https://api.quran.com/api/v4/quran/verses';
  static const _fallbackLabel = 'QF text_uthmani (encoding berbeda)';

  late final http.Client _client = widget.client ?? http.Client();
  int _surah = 1;
  bool _tajweed = true;
  late Future<List<_PreviewVerse>> _future = _load();
  final Set<String> _parseErrors = {};

  @override
  void dispose() {
    if (widget.client == null) _client.close();
    super.dispose();
  }

  Future<Map<String, String>> _fetch(String field, int surah) async {
    final uri = Uri.parse('$_base/$field?chapter_number=$surah');
    final response = await _client.get(uri).timeout(
          const Duration(seconds: 20),
        );
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    return {
      for (final verse in json['verses'] as List)
        verse['verse_key'] as String: verse['text_$field'] as String,
    };
  }

  Future<List<_PreviewVerse>> _load() async {
    final surah = _surah;
    final meta = surahCatalog[surah - 1];
    final results = await Future.wait([
      _fetch('uthmani_tajweed', surah),
      _fetch('uthmani', surah),
    ]);
    List<String>? translation;
    try {
      translation = await TranslationRepository.instance.forSurah(surah);
    } catch (_) {
      translation = null;
    }
    final keys = [for (var i = 1; i <= meta.ayahCount; i++) '$surah:$i'];
    // Tolak respons yang tidak lengkap/tidak sesuai manifest daripada
    // menampilkan ayat yang hilang atau tertukar.
    for (final map in results) {
      if (map.length != keys.length || !keys.every(map.containsKey)) {
        throw const FormatException('Jumlah/kunci ayat tidak cocok manifest');
      }
    }
    return [
      for (var i = 0; i < keys.length; i++)
        _PreviewVerse(
          keys[i],
          results[0][keys[i]]!,
          results[1][keys[i]]!,
          translation != null && i < translation.length ? translation[i] : null,
        ),
    ];
  }

  void _select(int surah) {
    setState(() {
      _surah = surah;
      _parseErrors.clear();
      _future = _load();
    });
  }

  void _onParseError(String key, FormatException _) {
    if (!mounted || _parseErrors.contains(key)) return;
    setState(() => _parseErrors.add(key));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pratinjau tajwid (debug)'),
        actions: [
          IconButton(
            tooltip: 'Legend warna tajwid',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => showTajweedLegendSheet(
              context,
              palette: TajweedPalette.draftPreview,
            ),
          ),
          Tooltip(
            message: 'Warna tajwid',
            child: Switch(
              value: _tajweed,
              onChanged: (value) => setState(() => _tajweed = value),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DropdownButtonFormField<int>(
              initialValue: _surah,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Surah'),
              items: [
                for (final meta in surahCatalog)
                  DropdownMenuItem(
                    value: meta.number,
                    child: Text('${meta.number}. ${meta.displayName}'),
                  ),
              ],
              onChanged: (value) {
                if (value != null && value != _surah) _select(value);
              },
            ),
          ),
          _Banner(parseErrors: _parseErrors),
          Expanded(
            child: FutureBuilder<List<_PreviewVerse>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorState(
                    message: '${snapshot.error}',
                    onRetry: () => _select(_surah),
                  );
                }
                final verses = snapshot.data;
                if (verses == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: verses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _VerseCard(
                    verse: verses[index],
                    tajweed: _tajweed,
                    fallbackLabel: _fallbackLabel,
                    onParseError: _onParseError,
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

class _Banner extends StatelessWidget {
  const _Banner({required this.parseErrors});

  final Set<String> parseErrors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Hanya build debug. Sumber: api.quran.com (Quran Foundation), bukan '
        'jalur produksi. Teks tajwid adalah edisi QF, berbeda dengan teks '
        'Tanzil di Reader. Nama hukum dan warna: DRAF.'
        '${parseErrors.isEmpty ? '' : '\nMarkup ditolak: ${parseErrors.join(', ')}'}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

class _VerseCard extends StatelessWidget {
  const _VerseCard({
    required this.verse,
    required this.tajweed,
    required this.fallbackLabel,
    required this.onParseError,
  });

  final _PreviewVerse verse;
  final bool tajweed;
  final String fallbackLabel;
  final void Function(String, FormatException) onParseError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              verse.key,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            TajweedVersePanel(
              verseKey: verse.key,
              markup: verse.tajweed,
              fallbackText: verse.uthmani,
              fallbackEditionLabel: fallbackLabel,
              tajweedEnabled: tajweed,
              onParseError: onParseError,
              arabicStyle: TextStyle(
                fontFamily: 'Amiri',
                fontSize: SharedPreferencesService.getArabicFontSize(),
                height: 2.0,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            if (verse.translation != null) ...[
              const SizedBox(height: 12),
              Text(
                verse.translation!,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40),
              const SizedBox(height: 12),
              Text(
                'Gagal memuat data tajwid.\n$message',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
}
