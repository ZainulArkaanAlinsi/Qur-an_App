import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/audio_sources.dart';
import 'package:quran_app_2025/data/qari_catalog.dart';
import 'package:quran_app_2025/data/reciter_repository.dart';
import 'package:quran_app_2025/features/murottal/application/now_playing_audio.dart';
import 'package:quran_app_2025/features/murottal/application/player_view_model.dart';
import 'package:quran_app_2025/models/reciter.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Inisial avatar: huruf awal kata pertama dan terakhir nama Latin, tanpa
/// keterangan dalam kurung dan awalan "Al-" ("Ali Al-Hudhaify" → "AH").
String qariInitials(String name) {
  final words = name
      .replaceAll(RegExp(r'\(.*?\)'), ' ')
      .split(RegExp(r'\s+'))
      .map((word) => word.split('-').last)
      .where((word) => word.isNotEmpty && RegExp('^[A-Za-z]').hasMatch(word))
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final word = words.first;
    return word.substring(0, word.length < 2 ? 1 : 2).toUpperCase();
  }
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
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

/// Antrean murottal yang sedang dimuat diputar ulang dengan qari baru di
/// ayat yang sama (23-qari.md §Tampilan 7).
Future<void> reloadQueueWithNewReciter() async {
  final audio = QuranNowPlayingAudio();
  final view = PlayerView.of(audio.queue, audio.playingVerse);
  if (view == null) return;
  await audio.playRange(
    surah: view.surah,
    fromAyah: view.queue.firstAyah,
    toAyah: view.queue.lastAyah,
    startAyah: view.ayah,
  );
}

/// Pilih qari v6.1 (docs/design/v6/screens/23-qari.md, V6-Qari.png): cari,
/// chip suasana, Dipilih, Populer sekarang + A–Z, dengar contoh.
///
/// Build rilis hanya menampilkan qari dengan sumber berizin; build debug
/// menampilkan semua, yang belum berizin diberi lencana MENUNGGU IZIN.
class ReciterPicker extends StatefulWidget {
  const ReciterPicker({
    super.key,
    this.repository,
    this.player,
    this.catalog,
    this.allowPending,
    this.reloadQueue,
  });

  /// Hanya untuk tes: repositori dengan klien buatan.
  @visibleForTesting
  final ReciterRepository? repository;

  /// Hanya untuk tes: pemutar contoh buatan.
  @visibleForTesting
  final PreviewPlayer? player;

  /// Hanya untuk tes: katalog tanpa aset.
  @visibleForTesting
  final Future<QariCatalog>? catalog;

  /// Hanya untuk tes: meniru build rilis (false) atau debug (true).
  @visibleForTesting
  final bool? allowPending;

  /// Hanya untuk tes: pengganti [reloadQueueWithNewReciter].
  @visibleForTesting
  final Future<void> Function()? reloadQueue;

  @override
  State<ReciterPicker> createState() => _ReciterPickerState();
}

class _ReciterPickerState extends State<ReciterPicker> {
  late final ReciterRepository _repository =
      widget.repository ?? ReciterRepository();
  late final PreviewPlayer _audio = widget.player ?? PreviewPlayer.quran();
  late final bool _allowPending =
      widget.allowPending ?? AudioSources.allowPending;
  late Future<QariCatalog> _data = _load();
  late Reciter _selected = SharedPreferencesService.getReciter();
  final _search = TextEditingController();
  late QariFilter _filter = QariFilter.parse(
    SharedPreferencesService.getQariFilter(),
  );

  /// Qari yang sedang diperiksa ketersediaannya sebelum disimpan.
  String? _pending;

  /// Qari yang contohnya sedang dimuat atau diputar.
  String? _previewing;
  bool _previewLoading = false;

  Future<QariCatalog> _load() async {
    final catalog = await (widget.catalog ?? QariCatalog.load());
    // Nama Arab dari daftar alquran.cloud (cache seminggu; gagal = tanpa).
    try {
      return catalog.withArabicNames(await _repository.load());
    } on Object {
      return catalog;
    }
  }

  @override
  void initState() {
    super.initState();
    _audio.isPlaying.addListener(_onPlayback);
  }

  @override
  void dispose() {
    _audio.isPlaying.removeListener(_onPlayback);
    _search.dispose();
    // Keluar dari layar menghentikan contoh yang masih berbunyi.
    if (_previewing != null) unawaited(_audio.stop());
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

  void _setFilter(QariFilter filter) {
    setState(() => _filter = filter);
    unawaited(SharedPreferencesService.setQariFilter(filter.name));
  }

  /// Penyedia Islamic Network: bitrate dicek dulu supaya pilihan yang pasti
  /// gagal tidak disimpan. equran.id (debug) tidak punya pilihan bitrate.
  Future<Reciter?> _resolve(Reciter reciter) =>
      reciter.provider == AudioProvider.alQuranCloud
      ? _repository.resolveBitrate(reciter)
      : Future.value(reciter);

  Future<void> _pick(QariEntry entry) async {
    final reciter = entry.toReciter(allowPending: _allowPending);
    if (reciter == null) {
      _say(
        'Sumber audio ${entry.name} masih menunggu izin, jadi belum bisa '
        'diputar.',
      );
      return;
    }
    if (entry.matches(_selected) || _pending != null) return;
    setState(() => _pending = entry.id);
    final resolved = await _resolve(reciter);
    if (!mounted) return;
    if (resolved == null) {
      setState(() => _pending = null);
      _say(
        'Murottal ${entry.name} belum bisa diputar dari server. Qari '
        'sebelumnya tetap dipakai.',
      );
      return;
    }
    await SharedPreferencesService.setReciter(resolved);
    if (!mounted) return;
    setState(() {
      _pending = null;
      _selected = resolved;
    });
    try {
      await (widget.reloadQueue ?? reloadQueueWithNewReciter)();
    } on Object {
      if (mounted) _say('Murottal dengan qari baru belum dapat diputar.');
    }
  }

  /// Memutar Al-Fatihah ayat 1 sebagai contoh; ketuk lagi untuk berhenti.
  /// Hanya satu contoh yang berbunyi.
  Future<void> _togglePreview(QariEntry entry) async {
    final reciter = entry.toReciter(allowPending: _allowPending);
    if (reciter == null) return;
    if (_previewing == entry.id) {
      setState(() => _previewing = null);
      await _audio.stop();
      return;
    }
    setState(() {
      _previewing = entry.id;
      _previewLoading = true;
    });
    final resolved = await _resolve(reciter);
    if (!mounted || _previewing != entry.id) return;
    if (resolved == null) {
      setState(() {
        _previewing = null;
        _previewLoading = false;
      });
      _say('Contoh ${entry.name} belum tersedia.');
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

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(onClose: () => Navigator.of(context).maybePop()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _SearchField(
                controller: _search,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),
            _FilterChips(value: _filter, onChanged: _setFilter),
            Expanded(
              child: FutureBuilder<QariCatalog>(
                future: _data,
                builder: (context, snapshot) {
                  final catalog = snapshot.data;
                  if (snapshot.hasError) {
                    return _LoadError(
                      onRetry: () => setState(() => _data = _load()),
                    );
                  }
                  if (catalog == null) return const SizedBox.shrink();
                  return _list(context, tokens, catalog);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, SacredTokens tokens, QariCatalog catalog) {
    final selected = catalog.entryFor(_selected);
    final query = _search.text.trim();
    final sections = <Widget>[];
    void section(String title, List<QariEntry> entries, {String? trailing}) {
      sections
        ..add(_SectionLabel(title: title, trailing: trailing))
        ..add(
          entries.isEmpty
              ? _Empty(tokens: tokens)
              : _Group(
                  children: [
                    for (final entry in entries) _row(entry, selected: false),
                  ],
                ),
        );
    }

    final scope = _allowPending ? 'semua sumber' : 'berizin';
    if (_filter == QariFilter.semua && query.isEmpty) {
      section(
        'Populer sekarang',
        catalog.popularNow(allowPending: _allowPending, exceptId: selected?.id),
        trailing: 'diperbarui ${_date(catalog.updated)}',
      );
      final all = catalog.alphabetical(
        allowPending: _allowPending,
        exceptId: selected?.id,
      );
      section('Semua A–Z · ${all.length} qari', all, trailing: scope);
    } else {
      final list = catalog.filtered(
        _filter,
        allowPending: _allowPending,
        query: query,
        exceptId: selected?.id,
      );
      section(
        '${query.isEmpty ? _filter.label : 'Hasil'} · ${list.length} qari',
        list,
        trailing: scope,
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        if (_allowPending) _DebugBanner(tokens: tokens),
        const _SectionLabel(title: 'Dipilih'),
        _Group(
          children: [
            if (selected != null)
              _row(selected, selected: true)
            else
              // Pilihan lama di luar katalog tetap ditampilkan apa adanya.
              _QariRow(
                name: _selected.displayName,
                subtitle: 'Murattal',
                selected: true,
              ),
          ],
        ),
        ...sections,
      ],
    );
  }

  Widget _row(QariEntry entry, {required bool selected}) {
    final playable = entry.playableSource(allowPending: _allowPending) != null;
    final pending = !entry.granted;
    return _QariRow(
      key: ValueKey('qari-${entry.id}'),
      name: entry.name,
      subtitle: [
        entry.styleLabel,
        if (!pending && entry.country.isNotEmpty) entry.country,
        if (entry.perSurahOnly) 'per surah',
      ].join(' · '),
      tag: pending ? 'MENUNGGU IZIN' : entry.tag,
      pendingTag: pending,
      selected: selected,
      busy: _pending == entry.id,
      previewing: _previewing == entry.id,
      onTap: () => unawaited(_pick(entry)),
      onPreview: playable ? () => unawaited(_togglePreview(entry)) : null,
    );
  }

  static String _date(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Tutup',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tokens.surf,
                      shape: BoxShape.circle,
                      boxShadow: tokens.cardShadows,
                    ),
                    child: LineIcon(
                      SacredIcons.chevronDown,
                      color: tokens.ink,
                      size: 20,
                      strokeWidth: 2.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Pilih qari',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SacredText.murottalTitle.copyWith(color: tokens.ink),
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.sep),
      ),
      child: Row(
        children: [
          LineIcon(SacredIcons.search, color: tokens.sec, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: SacredText.searchInput.copyWith(color: tokens.ink),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Cari nama qari',
                hintStyle: SacredText.searchInput.copyWith(color: tokens.sec),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip suasana dalam satu baris yang bisa digeser.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.value, required this.onChanged});

  final QariFilter value;
  final ValueChanged<QariFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final filter in QariFilter.values) ...[
            if (filter != QariFilter.values.first) const SizedBox(width: 8),
            Semantics(
              button: true,
              selected: filter == value,
              child: GestureDetector(
                onTap: () => onChanged(filter),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: filter == value ? tokens.primary : tokens.surf,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: filter == value ? tokens.primary : tokens.sep,
                    ),
                  ),
                  child: Text(
                    filter.label,
                    style: SacredText.actionPill.copyWith(
                      color: filter == value ? tokens.surf : tokens.ink,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: SacredText.eyebrow.copyWith(color: tokens.sec),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing,
              style: SacredText.listMeta.copyWith(color: tokens.sec),
            ),
          ],
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.sep),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: tokens.sep),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Satu baris qari (tinggi ≥ 64): inisial, nama, gaya · negara + satu tag,
/// lalu dengar contoh (atau centang bila dipilih).
class _QariRow extends StatelessWidget {
  const _QariRow({
    super.key,
    required this.name,
    required this.subtitle,
    this.tag,
    this.pendingTag = false,
    this.selected = false,
    this.busy = false,
    this.previewing = false,
    this.onTap,
    this.onPreview,
  });

  final String name;
  final String subtitle;
  final String? tag;
  final bool pendingTag;
  final bool selected;
  final bool busy;
  final bool previewing;
  final VoidCallback? onTap;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final tag = this.tag;
    final Widget trailing;
    if (selected) {
      trailing = Padding(
        padding: const EdgeInsets.all(9),
        child: LineIcon(
          SacredIcons.checkCircle,
          color: tokens.primaryText,
          size: 22,
        ),
      );
    } else if (busy) {
      trailing = SizedBox.square(
        dimension: 40,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: tokens.primaryText,
            value: MediaQuery.disableAnimationsOf(context) ? .3 : null,
          ),
        ),
      );
    } else {
      trailing = Semantics(
        // Simpul sendiri: tidak digabung dengan baris (pilih ≠ dengar).
        container: true,
        button: true,
        enabled: onPreview != null,
        label: onPreview == null
            ? 'Contoh $name belum bisa diputar: sumber menunggu izin'
            : previewing
            ? 'Hentikan contoh $name'
            : 'Dengar contoh $name',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPreview,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.fill,
                  shape: BoxShape.circle,
                ),
                child: LineIcon(
                  previewing ? SacredIcons.pause : SacredIcons.play,
                  color: onPreview == null ? tokens.tertiary : tokens.ink,
                  size: 16,
                  filled: true,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? tokens.primary : tokens.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  qariInitials(name),
                  style: SacredText.qariName.copyWith(
                    color: selected ? tokens.surf : tokens.primaryText,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Teks besar: nama boleh dua baris, tidak terpotong.
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SacredText.qariName.copyWith(color: tokens.ink),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          subtitle,
                          style: SacredText.listMeta.copyWith(
                            color: tokens.sec,
                          ),
                        ),
                        if (tag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: pendingTag
                                  ? tokens.surf2
                                  : tokens.goldSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              tag,
                              style: SacredText.qariTag.copyWith(
                                color: pendingTag
                                    ? tokens.sec
                                    : tokens.goldText,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _DebugBanner extends StatelessWidget {
  const _DebugBanner({required this.tokens});

  final SacredTokens tokens;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: tokens.goldSoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      'Build debug: qari dari sumber yang belum berizin ikut tampil. Di '
      'build rilis mereka tersembunyi.',
      style: SacredText.infoBox.copyWith(color: tokens.goldText),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.tokens});

  final SacredTokens tokens;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Text(
      'Tidak ada qari yang cocok.',
      style: SacredText.body.copyWith(color: tokens.sec),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

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
              'Daftar qari belum dapat dimuat.',
              textAlign: TextAlign.center,
              style: SacredText.body.copyWith(color: tokens.sec),
            ),
            const SizedBox(height: 12),
            SacredButton(
              label: 'Coba lagi',
              tone: ButtonTone.soft,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
