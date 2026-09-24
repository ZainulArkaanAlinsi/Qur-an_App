import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/source_fallback.dart';
import 'package:quran_app_2025/data/translation_repository.dart';

/// Terjemahan (docs/design/v2/screens/06-bahasa.md): terjemahan Kemenag
/// bawaan, lalu daftar QuranEnc (cadangan fawazahmed0) yang bisa diunduh.
/// Status tiap baris: Unduh / Mengunduh… / Tersimpan / Gagal.
class TranslationPicker extends StatefulWidget {
  const TranslationPicker({super.key, this.library});

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

  void _reload() => setState(() {
    _catalog = _library.catalog();
    _saved = _library.saved();
  });

  Future<void> _download(TranslationEdition edition) async {
    setState(() => _states[edition] = _RowState.downloading);
    try {
      final saved = await _library.download(edition);
      // Muat daftar dulu supaya baris tidak sempat kembali ke "Unduh".
      final list = await _library.saved();
      if (!mounted) return;
      setState(() {
        _states.remove(edition);
        _saved = Future.value(list);
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

  Future<void> _remove(TranslationEdition edition) async {
    await _library.remove(edition);
    if (mounted) setState(() => _saved = _library.saved());
  }

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  bool _matches(TranslationEdition e) {
    final q = _query.trim().toLowerCase();
    return q.isEmpty ||
        e.title.toLowerCase().contains(q) ||
        e.language.toLowerCase().contains(q) ||
        e.id.toLowerCase().contains(q);
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
            final saved = <TranslationEdition, SavedTranslation>{
              for (final item in savedSnapshot.data ?? <SavedTranslation>[])
                item.edition: item,
            };
            return FutureBuilder<SourceResult<List<TranslationEdition>>>(
              future: _catalog,
              builder: (context, snapshot) => ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  ScreenHeader(
                    title: 'Terjemahan',
                    backLabel: 'Saya',
                    subtitle: snapshot.hasData
                        ? '${snapshot.data!.value.length} terjemahan dapat '
                              'diunduh'
                        : 'Bahasa Indonesia tersedia tanpa internet',
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: GroupedList(
                      label: 'Tersimpan',
                      children: [
                        ListRow(
                          title: 'Bahasa Indonesia',
                          subtitle:
                              'Kementerian Agama RI · bawaan, tanpa internet',
                          trailing: _savedIcon(tokens),
                        ),
                        for (final item in saved.values)
                          ListRow(
                            title: item.edition.title,
                            subtitle: _meta(item.edition),
                            trailing: _savedIcon(tokens),
                            onTap: () => _confirmRemove(item.edition),
                          ),
                      ],
                    ),
                  ),
                  ..._catalogSection(context, snapshot, saved),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
                    child: Text(
                      'Terjemahan dari QuranEnc.com (cadangan: fawazahmed0), '
                      'ditampilkan tanpa diubah beserta nama penerjemah dan '
                      'versinya.',
                      style: SacredText.cardNote.copyWith(color: tokens.sec),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _catalogSection(
    BuildContext context,
    AsyncSnapshot<SourceResult<List<TranslationEdition>>> snapshot,
    Map<TranslationEdition, SavedTranslation> saved,
  ) {
    if (snapshot.hasError) {
      return [
        _Notice(
          text:
              'Daftar terjemahan butuh internet untuk pertama kali. '
              'Terjemahan yang sudah tersimpan tetap bisa dibaca.',
          action: 'Coba lagi',
          onAction: _reload,
        ),
      ];
    }
    final data = snapshot.data;
    if (data == null) {
      return [const _Notice(text: 'Memuat daftar terjemahan…')];
    }
    final rows = [
      for (final edition in data.value)
        if (!saved.containsKey(edition) && _matches(edition)) edition,
    ];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: GroupedList(
          label: 'Bisa diunduh',
          children: [
            if (rows.isEmpty)
              ListRow(
                title: _query.trim().isEmpty
                    ? 'Semua terjemahan sudah tersimpan'
                    : 'Tidak ada yang cocok dengan pencarian',
              ),
            for (final edition in rows)
              ListRow(
                title: edition.title,
                subtitle: _meta(edition),
                trailing: _action(context, edition),
              ),
          ],
        ),
      ),
    ];
  }

  static String _meta(TranslationEdition edition) => [
    edition.language,
    edition.provider.label,
    if (edition.version != null) 'versi ${edition.version}',
  ].join(' · ');

  Widget _savedIcon(SacredTokens tokens) => Semantics(
    label: 'Tersimpan',
    child: LineIcon(
      SacredIcons.checkCircle,
      color: tokens.primaryText,
      size: 22,
    ),
  );

  Widget _action(BuildContext context, TranslationEdition edition) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return switch (_states[edition] ?? _RowState.idle) {
      _RowState.downloading => Text(
        'Mengunduh…',
        style: SacredText.pill.copyWith(color: tokens.sec),
      ),
      _RowState.failed => SacredButton(
        label: 'Coba lagi',
        tone: ButtonTone.fill,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: SacredText.pill.copyWith(color: tokens.danger),
        onTap: () => _download(edition),
      ),
      _RowState.idle => SacredButton(
        label: 'Unduh',
        tone: ButtonTone.soft,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: SacredText.pill,
        onTap: () => _download(edition),
      ),
    };
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
              ListRow(title: edition.title, subtitle: _meta(edition)),
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
    if (remove ?? false) await _remove(edition);
  }
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
