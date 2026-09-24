import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/source_fallback.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/features/reader/presentation/card_parts.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Terjemahan kedua yang dipakai kartu ayat, atau null.
TranslationEdition? readSecondTranslation() {
  final raw = SharedPreferencesService.getSecondTranslation();
  if (raw == null) return null;
  try {
    return TranslationEdition.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } on Object {
    return null;
  }
}

Future<void> saveSecondTranslation(TranslationEdition? edition) =>
    SharedPreferencesService.setSecondTranslation(
      edition == null ? null : jsonEncode(edition.toJson()),
    );

/// Terjemahan (docs/design/v2/screens/06-bahasa.md): Indonesia bawaan plus
/// satu terjemahan lain (maksimal dua). Baris: nama bahasa dalam aksaranya
/// sendiri + nama penerjemah; kanan centang (dipakai) atau Unduh.
class TranslationPicker extends StatefulWidget {
  const TranslationPicker({super.key, this.library, this.backLabel = 'Saya'});

  final String backLabel;

  /// Hanya untuk tes: sumber data buatan.
  @visibleForTesting
  final OnlineTranslations? library;

  @override
  State<TranslationPicker> createState() => _TranslationPickerState();
}

enum _RowState { idle, downloading, failed }

class _TranslationPickerState extends State<TranslationPicker> {
  late final OnlineTranslations _library =
      widget.library ?? TranslationRepository.instance.online;
  late Future<SourceResult<List<TranslationEdition>>> _catalog = _library
      .catalog();
  late Future<List<SavedTranslation>> _saved = _library.saved();
  final _states = <TranslationEdition, _RowState>{};
  String _query = '';
  bool _showIndonesian = SharedPreferencesService.getShowIndonesian();
  TranslationEdition? _second = readSecondTranslation();

  void _reload() => setState(() {
    _catalog = _library.catalog();
    _saved = _library.saved();
  });

  Future<void> _use(TranslationEdition? edition) async {
    await saveSecondTranslation(edition);
    if (mounted) setState(() => _second = edition);
  }

  Future<void> _toggleIndonesian() async {
    final next = !_showIndonesian;
    await SharedPreferencesService.setShowIndonesian(next);
    if (mounted) setState(() => _showIndonesian = next);
  }

  /// Mengunduh lalu langsung memakainya: orang mengunduh untuk membaca.
  Future<void> _download(TranslationEdition edition) async {
    setState(() => _states[edition] = _RowState.downloading);
    try {
      final saved = await _library.download(edition);
      // Muat daftar dulu supaya baris tidak sempat kembali ke "Unduh".
      final list = await _library.saved();
      await saveSecondTranslation(saved);
      if (!mounted) return;
      setState(() {
        _states.remove(edition);
        _saved = Future.value(list);
        _second = saved;
      });
      if (saved.provider != edition.provider) {
        _say(
          'QuranEnc tidak merespons; terjemahan yang sama diunduh dari '
          '${saved.provider.label}.',
        );
      }
    } on Object {
      if (!mounted) return;
      setState(() => _states[edition] = _RowState.failed);
      _say('Gagal mengunduh. Periksa koneksi lalu coba lagi.');
    }
  }

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  bool _matches(TranslationEdition e) {
    final q = _query.trim().toLowerCase();
    return q.isEmpty ||
        translationLanguage(e).toLowerCase().contains(q) ||
        e.language.toLowerCase().contains(q) ||
        translatorOf(e).toLowerCase().contains(q);
  }

  static bool _isLanguage(TranslationEdition e, String code, String name) =>
      e.language.toLowerCase() == code || e.language == name;

  /// Terpilih, tersimpan, Indonesia, English, lalu sisanya per bahasa.
  List<TranslationEdition> _ordered(
    Iterable<TranslationEdition> all,
    Set<TranslationEdition> saved,
  ) {
    int rank(TranslationEdition e) {
      if (e == _second) return 0;
      if (saved.contains(e)) return 1;
      if (_isLanguage(e, 'id', 'Indonesian')) return 2;
      if (_isLanguage(e, 'en', 'English')) return 3;
      return 4;
    }

    final list = [
      for (final e in {...all})
        // Tidak ada terjemahan tanpa nama penerjemah.
        if (translatorOf(e).isNotEmpty && _matches(e)) e,
    ];
    list.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      final byLanguage = translationLanguage(
        a,
      ).compareTo(translationLanguage(b));
      return byLanguage != 0
          ? byLanguage
          : translatorOf(a).compareTo(translatorOf(b));
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<SavedTranslation>>(
          future: _saved,
          builder: (context, savedSnapshot) {
            final saved = {
              for (final item in savedSnapshot.data ?? <SavedTranslation>[])
                item.edition,
            };
            return FutureBuilder<SourceResult<List<TranslationEdition>>>(
              future: _catalog,
              builder: (context, snapshot) {
                final catalog = snapshot.data?.value ?? const [];
                final languages = {
                  for (final e in catalog) translationLanguage(e),
                }.length;
                final rows = _ordered([...catalog, ...saved], saved);
                return ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    ScreenHeader(
                      title: 'Terjemahan',
                      backLabel: widget.backLabel,
                      subtitle: languages == 0
                          ? 'Pilih maksimal 2'
                          : 'Pilih maksimal 2 · $languages bahasa',
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: SacredSearchField(
                        hint: 'Cari bahasa atau penerjemah',
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    if (snapshot.data?.fromFallback ?? false)
                      const _Notice(
                        text:
                            'QuranEnc tidak merespons; daftar diambil dari '
                            'sumber cadangan fawazahmed0.',
                      ),
                    if (snapshot.hasError)
                      _Notice(
                        text:
                            'Daftar terjemahan butuh internet untuk pertama '
                            'kali. Terjemahan yang sudah tersimpan tetap bisa '
                            'dipakai.',
                        action: 'Coba lagi',
                        onAction: _reload,
                      )
                    else if (snapshot.connectionState != ConnectionState.done)
                      const _Notice(text: 'Memuat daftar terjemahan…'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: GroupedList(
                        children: [
                          if (_query.trim().isEmpty ||
                              'bahasa indonesia kementerian agama'.contains(
                                _query.trim().toLowerCase(),
                              ))
                            ListRow(
                              title: 'Bahasa Indonesia',
                              subtitle:
                                  'Kementerian Agama RI · bawaan, offline',
                              semanticsLabel:
                                  'Bahasa Indonesia, Kementerian Agama RI, '
                                  '${_showIndonesian ? 'dipakai' : 'disembunyikan'}',
                              trailing: _showIndonesian ? _check(tokens) : null,
                              onTap: _toggleIndonesian,
                            ),
                          for (final edition in rows)
                            _row(tokens, edition, saved.contains(edition)),
                          if (rows.isEmpty && _query.trim().isNotEmpty)
                            ListRow(
                              title:
                                  'Tidak ada yang cocok dengan '
                                  '"${_query.trim()}"',
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
                      child: Text(
                        'Terjemahan dari QuranEnc.com (cadangan: '
                        'fawazahmed0), ditampilkan tanpa diubah beserta nama '
                        'penerjemah dan versinya. Tekan lama terjemahan '
                        'tersimpan untuk menghapusnya dari perangkat.',
                        style: SacredText.cardNote.copyWith(color: tokens.sec),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  static Widget _check(SacredTokens tokens) => LineIcon(
    SacredIcons.checkCircle,
    color: tokens.primaryText,
    size: 22,
    strokeWidth: 2.2,
  );

  Widget _row(SacredTokens tokens, TranslationEdition edition, bool saved) {
    final active = edition == _second;
    final state = _states[edition] ?? _RowState.idle;
    final language = translationLanguage(edition);
    final translator = translatorOf(edition);
    final status = active
        ? 'dipakai'
        : saved
        ? 'tersimpan, ketuk untuk memakai'
        : switch (state) {
            _RowState.downloading => 'sedang diunduh',
            _RowState.failed => 'gagal diunduh',
            _RowState.idle => 'belum diunduh',
          };
    final Widget trailing = active
        ? _check(tokens)
        : saved
        ? Text('Tersimpan', style: SacredText.pill.copyWith(color: tokens.sec))
        : switch (state) {
            _RowState.downloading => Text(
              'Mengunduh…',
              style: SacredText.pill.copyWith(color: tokens.sec),
            ),
            _RowState.failed => _Link(
              label: 'Coba lagi',
              color: tokens.danger,
              onTap: () => _download(edition),
            ),
            _RowState.idle => _Link(
              label: 'Unduh',
              color: tokens.primaryText,
              onTap: () => _download(edition),
            ),
          };
    return GestureDetector(
      onLongPress: saved ? () => _confirmRemove(edition) : null,
      child: ListRow(
        title: language,
        subtitle: translator,
        semanticsLabel: '$language, $translator, $status',
        trailing: trailing,
        onTap: () {
          if (saved) {
            _use(active ? null : edition);
          } else if (state != _RowState.downloading) {
            _download(edition);
          }
        },
      ),
    );
  }

  Future<void> _confirmRemove(TranslationEdition edition) async {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final remove = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: tokens.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GroupedList(
            children: [
              ListRow(
                title: translationLanguage(edition),
                subtitle: [
                  translatorOf(edition),
                  edition.provider.label,
                  if (edition.version != null) 'versi ${edition.version}',
                ].join(' · '),
              ),
              ListRow(
                title: 'Hapus dari perangkat',
                subtitle: 'Bisa diunduh lagi kapan saja',
                titleColor: tokens.danger,
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (!(remove ?? false)) return;
    await _library.remove(edition);
    if (edition == _second) await _use(null);
    if (mounted) setState(() => _saved = _library.saved());
  }
}

/// Tautan teks di kanan baris ("Unduh", "Coba lagi"), target sentuh 44.
class _Link extends StatelessWidget {
  const _Link({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: SacredText.buttonSmall.copyWith(color: color),
          ),
        ),
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.goldSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: SacredText.infoBox.copyWith(color: tokens.ink)),
            if (action != null) ...[
              const SizedBox(height: 10),
              SacredButton(
                label: action!,
                tone: ButtonTone.soft,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: SacredText.buttonSmall,
                onTap: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
