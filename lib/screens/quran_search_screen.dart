import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';

/// Lengkung mihrab pada keadaan kosong, verbatim dari Cari.html (96×120).
const _archPath =
    'M0 104 L0 46.0 C0 19.3 28.8 7.4 48.0 0 C67.2 7.4 96 19.3 96 46.0 '
    'L96 104 Q96 120 80 120 L16 120 Q0 120 0 104 Z';

/// Banyaknya hasil yang ditampilkan sebelum dipangkas.
const _maxHits = 120;

/// Lingkup pencarian, sesuai segmented control pada mockup.
enum _Scope {
  semua('Semua'),
  surah('Surah'),
  ayat('Ayat'),
  terjemahan('Terjemahan');

  const _Scope(this.label);
  final String label;
}

class QuranSearchScreen extends StatefulWidget {
  const QuranSearchScreen({super.key});

  @override
  State<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends State<QuranSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  _Scope _scope = _Scope.semua;
  late Future<_Corpus> _corpus = _load();

  Future<_Corpus> _load() async {
    final arabic = await Future.wait(
      List.generate(
        surahCatalog.length,
        (index) => QuranTextRepository.instance.versesForSurah(index + 1),
      ),
    );
    final translation = await Future.wait(
      List.generate(
        surahCatalog.length,
        (index) => TranslationRepository.instance.forSurah(index + 1),
      ),
    );
    return _Corpus(arabic: arabic, translation: translation);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    final trimmed = value.trim();
    if (trimmed == _query) return;
    setState(() => _query = trimmed);
  }

  void _useSuggestion(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    _setQuery(value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _SearchField(
                      controller: _controller,
                      onChanged: _setQuery,
                      onClear: () {
                        _controller.clear();
                        _setQuery('');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Semantics(
                    button: true,
                    container: true,
                    excludeSemantics: true,
                    label: 'Batal',
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                        child: Text(
                          'Batal',
                          style: SacredText.backLabel.copyWith(
                            color: tokens.primaryText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SegmentedPill<_Scope>(
                segments: {
                  for (final scope in _Scope.values) scope: scope.label,
                },
                value: _scope,
                onChanged: (value) => setState(() => _scope = value),
              ),
            ),
            Expanded(
              child: FutureBuilder<_Corpus>(
                future: _corpus,
                builder: (context, snapshot) {
                  // Diperiksa sebelum hasData: pemuatan yang gagal kalau tidak
                  // akan meninggalkan layar kosong tanpa jalan keluar.
                  if (snapshot.hasError) {
                    return _Message(
                      text: 'Teks Al-Qur’an tidak dapat dimuat.',
                      action: FilledButton.icon(
                        onPressed: () => setState(() => _corpus = _load()),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba lagi'),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const _Message(text: 'Menyiapkan teks…');
                  }
                  if (_query.isEmpty) {
                    return _Intro(onSuggestion: _useSuggestion);
                  }
                  final results = snapshot.data!.search(_query, _scope);
                  if (results.isEmpty) {
                    return _Empty(query: _query, onSuggestion: _useSuggestion);
                  }
                  return _Results(results: results);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu baris hasil: rujukan, potongan Arab, dan terjemahannya.
class _Hit {
  const _Hit({
    required this.surah,
    required this.ayah,
    required this.arabic,
    required this.translation,
  });

  final int surah;
  final int ayah;
  final String arabic;
  final String translation;
}

/// Teks Arab dan terjemahan yang sudah dimuat, beserta cara mencarinya.
class _Corpus {
  const _Corpus({required this.arabic, required this.translation});

  final List<List<String>> arabic;
  final List<List<String>> translation;

  /// Rujukan "2:153"; null bila bukan rujukan yang sah.
  static (int, int)? parseReference(String query) {
    final match = RegExp(r'^(\d{1,3})\s*[:.]\s*(\d{1,3})$').firstMatch(query);
    if (match == null) return null;
    final surah = int.parse(match[1]!);
    final ayah = int.parse(match[2]!);
    if (surah < 1 || surah > surahCatalog.length) return null;
    if (ayah < 1 || ayah > surahCatalog[surah - 1].ayahCount) return null;
    return (surah, ayah);
  }

  List<_Hit> search(String query, _Scope scope) {
    final hits = <_Hit>[];
    final needle = query.toLowerCase();

    // Rujukan langsung selalu dihormati, apa pun lingkupnya, karena itu yang
    // paling sering diketik.
    final reference = parseReference(query);
    if (reference != null) {
      return [_hit(reference.$1, reference.$2)];
    }

    if (scope == _Scope.semua || scope == _Scope.surah) {
      for (var s = 0; s < surahCatalog.length; s++) {
        if (surahCatalog[s].displayName.toLowerCase().contains(needle)) {
          hits.add(_hit(s + 1, 1));
        }
      }
      if (scope == _Scope.surah) return hits;
    }

    final wantArabic = scope == _Scope.semua || scope == _Scope.ayat;
    final wantTranslation = scope == _Scope.semua || scope == _Scope.terjemahan;

    for (var s = 0; s < arabic.length && hits.length < _maxHits; s++) {
      for (var a = 0; a < arabic[s].length && hits.length < _maxHits; a++) {
        if (wantArabic && arabic[s][a].contains(query)) {
          hits.add(_hit(s + 1, a + 1));
          continue;
        }
        if (wantTranslation &&
            a < translation[s].length &&
            translation[s][a].toLowerCase().contains(needle)) {
          hits.add(_hit(s + 1, a + 1));
        }
      }
    }
    return hits;
  }

  _Hit _hit(int surah, int ayah) => _Hit(
    surah: surah,
    ayah: ayah,
    arabic: arabic[surah - 1][ayah - 1],
    translation: ayah - 1 < translation[surah - 1].length
        ? translation[surah - 1][ayah - 1]
        : '',
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: tokens.fill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          LineIcon(
            SacredIcons.search,
            color: tokens.sec,
            size: 18,
            strokeWidth: 2,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              style: SacredText.searchInput.copyWith(color: tokens.ink),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Cari surah, 2:153, atau terjemahan',
                hintStyle: SacredText.searchInput.copyWith(color: tokens.sec),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox(width: 4)
                : Semantics(
                    button: true,
                    container: true,
                    excludeSemantics: true,
                    label: 'Hapus pencarian',
                    child: GestureDetector(
                      onTap: onClear,
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tokens.sec,
                          shape: BoxShape.circle,
                        ),
                        child: LineIcon(
                          SacredIcons.close,
                          color: tokens.bg,
                          size: 12,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.results});

  final List<_Hit> results;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 28),
      itemCount: results.length + 1,
      separatorBuilder: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Divider(height: 1, thickness: 1, color: tokens.sep),
      ),
      itemBuilder: (context, index) {
        if (index == results.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Text(
              results.length >= _maxHits
                  ? 'Menampilkan $_maxHits hasil pertama. Persempit kata '
                        'kuncinya untuk hasil yang lebih tepat.'
                  : 'Sumber: Tanzil Uthmani 1.0.2 · id.indonesian',
              style: SacredText.cardNote.copyWith(color: tokens.sec),
            ),
          );
        }
        return _ResultRow(hit: results[index]);
      },
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.hit});

  final _Hit hit;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final surah = surahCatalog[hit.surah - 1];
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '${surah.displayName} ayat ${hit.ayah}',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReaderScreen(surah: surah, initialVerse: hit.ayah),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${surah.displayName} · ${hit.surah}:${hit.ayah}',
                style: SacredText.verseLabel.copyWith(color: tokens.sec),
              ),
              const SizedBox(height: 8),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  hit.arabic,
                  textAlign: TextAlign.right,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SacredText.quran,
                    fontSize: 24,
                    height: 2,
                    color: tokens.ink,
                  ),
                ),
              ),
              if (hit.translation.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  hit.translation,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: SacredText.verseTranslation.copyWith(
                    color: tokens.sec,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Keadaan sebelum mengetik apa pun.
class _Intro extends StatelessWidget {
  const _Intro({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) => _EmptyLayout(
    title: 'Cari di dalam mushaf',
    body:
        'Pencarian mencakup nama surah, nomor ayat seperti 2:153, teks Arab, '
        'dan terjemahan Kemenag RI. Semuanya dilakukan offline.',
    onSuggestion: onSuggestion,
  );
}

/// Keadaan tanpa hasil, mengikuti Cari.html.
class _Empty extends StatelessWidget {
  const _Empty({required this.query, required this.onSuggestion});

  final String query;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) => _EmptyLayout(
    title: 'Tidak ada hasil untuk “$query”',
    body:
        'Pencarian mencakup nama surah, nomor ayat seperti 2:153, dan '
        'terjemahan Kemenag RI. Periksa ejaan atau coba kata lain.',
    onSuggestion: onSuggestion,
  );
}

class _EmptyLayout extends StatelessWidget {
  const _EmptyLayout({
    required this.title,
    required this.body,
    required this.onSuggestion,
  });

  final String title;
  final String body;
  final ValueChanged<String> onSuggestion;

  /// Saran yang memang menghasilkan sesuatu di aplikasi ini; kata yang pasti
  /// nihil tidak ditawarkan.
  static const _suggestions = ['sabar', '2:153', 'Al-Kahf', 'Ar-Rahman'];

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 28),
      children: [
        Center(
          child: SizedBox(
            width: 96,
            height: 120,
            child: CustomPaint(
              painter: _ArchPainter(fill: tokens.goldSoft, stroke: tokens.gold),
              child: Padding(
                padding: const EdgeInsets.only(top: 52),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: LineIcon(
                    SacredIcons.search,
                    color: tokens.goldText,
                    size: 34,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: SacredText.cardTitle.copyWith(color: tokens.ink),
        ),
        const SizedBox(height: 14),
        Text(
          body,
          textAlign: TextAlign.center,
          style: SacredText.body.copyWith(color: tokens.sec),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in _suggestions)
              _SuggestionChip(
                label: suggestion,
                onTap: () => onSuggestion(suggestion),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Sumber: Tanzil Uthmani 1.0.2 · id.indonesian',
          textAlign: TextAlign.center,
          style: SacredText.cardNote.copyWith(color: tokens.sec),
        ),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: 'Cari $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tokens.surf,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.sep),
          ),
          child: Text(
            label,
            style: SacredText.chipLabel.copyWith(color: tokens.ink),
          ),
        ),
      ),
    );
  }
}

/// Lengkung mihrab kecil di balik kaca pembesar.
class _ArchPainter extends CustomPainter {
  const _ArchPainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final path = parseSvgPath(_archPath).transform(
      Matrix4.diagonal3Values(size.width / 96, size.height / 120, 1).storage,
    );
    canvas
      ..drawPath(path, Paint()..color = fill)
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = stroke,
      );
  }

  @override
  bool shouldRepaint(_ArchPainter old) =>
      old.fill != fill || old.stroke != stroke;
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: SacredText.body.copyWith(color: tokens.sec),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
