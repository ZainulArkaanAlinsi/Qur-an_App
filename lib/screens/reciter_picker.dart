import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/reciter_repository.dart';
import 'package:quran_app_2025/models/reciter.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Menyaring daftar qari dengan kata kunci.
///
/// Dipisah sebagai fungsi murni supaya bisa diuji tanpa membuka layarnya.
/// Mencocokkan nama Latin maupun nama Arab, tanpa peduli besar kecil huruf.
List<Reciter> filterReciters(List<Reciter> all, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return all;
  return [
    for (final reciter in all)
      if (reciter.englishName.toLowerCase().contains(needle) ||
          reciter.name.toLowerCase().contains(needle) ||
          reciter.identifier.toLowerCase().contains(needle))
        reciter,
  ];
}

/// Mengelompokkan qari menurut gaya bacaannya, urut sesuai [RecitationStyle].
///
/// Kelompok kosong tidak disertakan, jadi daftar yang seluruhnya satu gaya
/// tidak menampilkan judul kelompok yang tidak berguna.
Map<RecitationStyle, List<Reciter>> groupReciters(List<Reciter> all) {
  final groups = <RecitationStyle, List<Reciter>>{};
  for (final style in RecitationStyle.values) {
    final members = [
      for (final reciter in all)
        if (reciter.style == style) reciter,
    ];
    if (members.isNotEmpty) groups[style] = members;
  }
  return groups;
}

/// Inisial avatar: huruf pertama dua kata pertama nama Latin
/// ("Mahmoud Khalil Al-Husary" → "MK"). Nama satu kata atau nama Arab saja
/// cukup satu huruf, karena huruf Arab yang dipisah tidak terbaca wajar.
String reciterInitials(Reciter reciter) {
  // Keterangan dalam kurung ("Husary (Mujawwad)") bukan bagian nama.
  final name = reciter.displayName.replaceAll(RegExp(r'\(.*?\)'), ' ');
  final words = name
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  final latin = RegExp('^[A-Za-z]');
  final latinWords = words.where(latin.hasMatch).toList();
  if (latinWords.isEmpty) return words.first.substring(0, 1);
  if (latinWords.length == 1) return latinWords.first[0].toUpperCase();
  return '${latinWords[0][0]}${latinWords[1][0]}'.toUpperCase();
}

/// Filter gaya di bawah pencarian. "Semua" juga memuat qari yang gayanya
/// belum disebut penyedia.
enum ReciterFilter {
  all('Semua'),
  murattal('Murattal'),
  mujawwad('Mujawwad'),
  muallim('Muallim');

  const ReciterFilter(this.label);
  final String label;

  bool accepts(Reciter reciter) => switch (this) {
    all => true,
    murattal => reciter.style == RecitationStyle.murattal,
    mujawwad => reciter.style == RecitationStyle.mujawwad,
    muallim => reciter.style == RecitationStyle.muallim,
  };
}

/// Pemutar contoh suara qari; bawaannya [QuranAudioService].
class PreviewPlayer {
  const PreviewPlayer({
    required this.isPlaying,
    required this.play,
    required this.stop,
  });

  factory PreviewPlayer.quran() {
    final service = QuranAudioService.instance;
    return PreviewPlayer(
      isPlaying: service.isPlaying,
      play: service.playPreview,
      stop: service.stop,
    );
  }

  final ValueListenable<bool> isPlaying;
  final Future<void> Function(Reciter reciter) play;
  final Future<void> Function() stop;
}

/// Qari (docs/design/v2/screens/13-qari.md): cari, saring per gaya, dengar
/// contoh, lalu pilih. Pilihan disimpan langsung setelah bitratenya
/// terbukti ada di server; layar tetap terbuka supaya bisa membandingkan.
class ReciterPicker extends StatefulWidget {
  const ReciterPicker({super.key, this.repository, this.player});

  /// Hanya untuk tes: repositori dengan klien buatan.
  @visibleForTesting
  final ReciterRepository? repository;

  /// Hanya untuk tes: pemutar contoh buatan.
  @visibleForTesting
  final PreviewPlayer? player;

  @override
  State<ReciterPicker> createState() => _ReciterPickerState();
}

class _ReciterPickerState extends State<ReciterPicker> {
  late final ReciterRepository _repository =
      widget.repository ?? ReciterRepository();
  late final PreviewPlayer _audio = widget.player ?? PreviewPlayer.quran();
  late Reciter _selected = SharedPreferencesService.getReciter();

  /// Qari terpilih saat layar dibuka ditaruh paling atas. Tidak ikut
  /// berpindah saat memilih yang lain, supaya daftar tidak melompat.
  late final String _pinned = _selected.identifier;
  late Future<List<Reciter>> _list = _repository.load();
  String _query = '';
  ReciterFilter _filter = ReciterFilter.all;

  /// Qari yang sedang diperiksa ketersediaannya sebelum disimpan.
  String? _pending;

  /// Qari yang contohnya sedang dimuat atau diputar.
  String? _previewing;
  bool _previewLoading = false;

  @override
  void initState() {
    super.initState();
    _audio.isPlaying.addListener(_onPlayback);
  }

  @override
  void dispose() {
    _audio.isPlaying.removeListener(_onPlayback);
    // Keluar dari layar menghentikan contoh yang masih berbunyi.
    if (_previewing != null) _audio.stop();
    super.dispose();
  }

  void _onPlayback() {
    if (_previewing != null && !_previewLoading && !_audio.isPlaying.value) {
      setState(() => _previewing = null);
    }
  }

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  void _retry() => setState(() => _list = _repository.load(forceRefresh: true));

  Future<void> _pick(Reciter reciter) async {
    if (reciter.identifier == _selected.identifier || _pending != null) return;
    setState(() => _pending = reciter.identifier);
    final resolved = await _repository.resolveBitrate(reciter);
    if (!mounted) return;
    if (resolved == null) {
      setState(() => _pending = null);
      _say(
        'Murottal ${reciter.displayName} belum bisa diputar dari server. '
        'Qari sebelumnya tetap dipakai.',
      );
      return;
    }
    await SharedPreferencesService.setReciter(resolved);
    // Antrean yang sedang berjalan memakai qari lama; hentikan agar tidak
    // tercampur di tengah surah.
    if (_previewing == null) await _audio.stop();
    if (!mounted) return;
    setState(() {
      _pending = null;
      _selected = resolved;
    });
  }

  /// Memutar Al-Fatihah ayat 1 sebagai contoh; ketuk lagi untuk berhenti.
  Future<void> _togglePreview(Reciter reciter) async {
    if (_previewing == reciter.identifier) {
      setState(() => _previewing = null);
      await _audio.stop();
      return;
    }
    setState(() {
      _previewing = reciter.identifier;
      _previewLoading = true;
    });
    final resolved = reciter.bitrate != null
        ? reciter
        : await _repository.resolveBitrate(reciter);
    if (!mounted || _previewing != reciter.identifier) return;
    if (resolved == null) {
      setState(() {
        _previewing = null;
        _previewLoading = false;
      });
      _say('Contoh ${reciter.displayName} belum tersedia.');
      return;
    }
    try {
      await _audio.play(resolved);
      if (mounted) setState(() => _previewLoading = false);
    } on Object {
      if (!mounted) return;
      setState(() {
        _previewing = null;
        _previewLoading = false;
      });
      _say('Contoh gagal diputar. Periksa koneksi internet.');
    }
  }

  List<Reciter> _visible(List<Reciter> all) {
    final matches = [
      for (final reciter in filterReciters(all, _query))
        if (_filter.accepts(reciter)) reciter,
    ];
    final pinned = matches.indexWhere((r) => r.identifier == _pinned);
    if (pinned > 0) matches.insert(0, matches.removeAt(pinned));
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<Reciter>>(
          future: _list,
          builder: (context, snapshot) {
            final all = snapshot.data;
            // Repositori mengembalikan qari bawaan saja bila daftar belum
            // pernah berhasil diunduh dan perangkat sedang luring.
            final offline =
                all != null && all.length == 1 && all.single == defaultReciter;
            final visible = all == null ? const <Reciter>[] : _visible(all);
            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                ScreenHeader(
                  title: 'Qari',
                  backLabel: 'Saya',
                  subtitle: all == null || offline
                      ? 'Riwayat Hafs'
                      : 'Riwayat Hafs · ${all.length} qari',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: SacredSearchField(
                    hint: 'Cari qari',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SegmentedPill<ReciterFilter>(
                    segments: {
                      for (final filter in ReciterFilter.values)
                        filter: filter.label,
                    },
                    value: _filter,
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                ),
                if (offline)
                  _Notice(
                    text:
                        'Daftar qari butuh internet untuk pertama kali. '
                        'Sementara ini hanya qari bawaan yang bisa dipilih.',
                    action: 'Coba lagi',
                    onAction: _retry,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: GroupedList(
                    children: [
                      if (all == null)
                        const ListRow(title: 'Memuat daftar qari…')
                      else if (visible.isEmpty)
                        ListRow(title: _emptyText())
                      else
                        for (final reciter in visible) _row(tokens, reciter),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
                  child: Text(
                    'Hanya riwayat Hafs, sama dengan teks di aplikasi. Audio '
                    'dari Al Quran Cloud; hak cipta rekaman milik qari.',
                    style: SacredText.cardNote.copyWith(color: tokens.sec),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _emptyText() {
    if (_query.trim().isNotEmpty) {
      return 'Tidak ada qari yang cocok dengan "${_query.trim()}"';
    }
    return 'Belum ada qari ${_filter.label.toLowerCase()} di daftar ini';
  }

  Widget _row(SacredTokens tokens, Reciter reciter) {
    final selected = reciter.identifier == _selected.identifier;
    // Qari terpilih memakai bitrate yang benar-benar tersimpan.
    final shown = selected ? _selected : reciter;
    final details = [
      if (shown.style != RecitationStyle.unknown) shown.style.label,
      if (shown.bitrate != null) '${shown.bitrate} kbps',
      shown.provider.label,
    ].join(' · ');
    final previewing = _previewing == reciter.identifier;
    return ListRow(
      title: reciter.displayName,
      subtitleSpan: TextSpan(
        children: [
          if (reciter.name.isNotEmpty && reciter.name != reciter.displayName)
            TextSpan(
              // Diisolasi (FSI…PDI) supaya angka bitrate sesudahnya tidak
              // ikut terbalik ke arah kanan-ke-kiri. Namanya tidak diubah.
              text:
                  '${String.fromCharCode(0x2068)}${reciter.name}'
                  '${String.fromCharCode(0x2069)} · ',
              style: const TextStyle(fontFamily: SacredText.quran),
            ),
          TextSpan(text: details),
        ],
      ),
      semanticsLabel: [
        reciter.displayName,
        details,
        if (selected) 'terpilih',
      ].join(', '),
      leading: _Initials(text: reciterInitials(reciter), selected: selected),
      onTap: () => _pick(reciter),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (previewing && _previewLoading)
            const _Spinner(size: 36)
          else
            RoundIconButton(
              icon: previewing ? SacredIcons.pause : SacredIcons.play,
              tooltip: previewing
                  ? 'Hentikan contoh'
                  : 'Dengar contoh ${reciter.displayName}',
              onTap: () => _togglePreview(reciter),
              size: 36,
              iconSize: 14,
              filled: true,
            ),
          const SizedBox(width: 8),
          SizedBox.square(
            dimension: 22,
            child: _pending == reciter.identifier
                ? const _Spinner(size: 22)
                : selected
                ? LineIcon(
                    SacredIcons.checkCircle,
                    color: tokens.primaryText,
                    size: 22,
                    strokeWidth: 2.2,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.text, required this.selected});

  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return ExcludeSemantics(
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? tokens.primarySoft : tokens.fill,
          shape: BoxShape.circle,
        ),
        child: Text(
          text,
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: SacredText.buttonSmall.copyWith(
            color: selected ? tokens.primaryText : tokens.ink,
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return SizedBox.square(
      dimension: size,
      child: Padding(
        padding: EdgeInsets.all(size / 4),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: tokens.primaryText,
        ),
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
