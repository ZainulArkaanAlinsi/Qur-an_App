import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass/glass_sheet.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/features/prayer/application/prayer_locator.dart';
import 'package:quran_app_2025/features/prayer/application/prayer_reminders.dart';
import 'package:quran_app_2025/features/prayer/application/prayer_settings_store.dart';
import 'package:quran_app_2025/features/prayer/domain/prayer_settings.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Membuka lembar "Waktu salat" (docs/design/v6/screens/22-pengaturan-
/// salat.md). Mengembalikan setelan yang disimpan, atau null bila ditutup.
///
/// [preview] = jadwal hari ini dengan setelan sekarang, untuk menampilkan
/// jam hasil koreksi menit secara langsung.
Future<PrayerSettings?> showPrayerSettingsSheet(
  BuildContext context, {
  PrayerDay? preview,
  PrayerFetcher? fetch,
  PrayerRescheduler onSaved = reschedulePrayerReminders,
}) => showGlassSheet<PrayerSettings>(
  context,
  builder: (_) => PrayerSettingsSheet(
    preview: preview,
    fetch: fetch ?? fetchPrayerDay,
    onSaved: onSaved,
  ),
);

class PrayerSettingsSheet extends StatefulWidget {
  const PrayerSettingsSheet({
    super.key,
    this.initial,
    this.preview,
    this.locator = const GeolocatorPrayerLocator(),
    this.fetch = fetchPrayerDay,
    this.onSaved = reschedulePrayerReminders,
  });

  /// Setelan awal; bawaan dibaca dari preferensi.
  final PrayerSettings? initial;
  final PrayerDay? preview;
  final PrayerLocator locator;

  /// Mengambil jadwal untuk setelan baru sebelum disimpan.
  final PrayerFetcher fetch;

  /// Setelah disimpan: jadwalkan ulang pengingat.
  final PrayerRescheduler onSaved;

  static const privacyNote =
      'Lokasi dipakai untuk menghitung jadwal salat. Koordinat dibulatkan '
      'ke kisi ±3 km dan tidak disimpan di server kami.';

  @override
  State<PrayerSettingsSheet> createState() => _PrayerSettingsSheetState();
}

class _PrayerSettingsSheetState extends State<PrayerSettingsSheet> {
  late final PrayerSettings _saved =
      widget.initial ?? PrayerSettingsStore.load();
  late PrayerLocationMode _mode = _saved.mode;
  late final _city = TextEditingController(text: _saved.city);
  late final _country = TextEditingController(text: _saved.country);
  late Coordinates? _coordinates = _saved.coordinates;
  late String? _zone = _saved.usesCoordinates ? widget.preview?.timezone : null;
  late int _method = _saved.method;
  late int _school = _saved.school;
  late final List<int> _tune = [..._saved.tune];
  late bool _tuneOpen = _saved.hasTune;
  final _recent = PrayerSettingsStore.recentCities();

  LocationAccess? _access;
  bool _locating = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _city.dispose();
    _country.dispose();
    super.dispose();
  }

  PrayerSettings get _draft => PrayerSettings(
    mode: _mode,
    city: _city.text.trim(),
    country: _country.text.trim(),
    coordinates: _coordinates,
    method: _method,
    school: _school,
    tune: List.unmodifiable(_tune),
  );

  bool get _canSave =>
      !_saving &&
      !_locating &&
      (_mode == PrayerLocationMode.auto
          ? _coordinates != null
          : _city.text.trim().isNotEmpty && _country.text.trim().isNotEmpty);

  /// Izin diminta di sini, saat tombol ditekan; tidak pernah otomatis.
  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    final access = await widget.locator.request();
    if (!mounted) return;
    if (access != LocationAccess.granted) {
      setState(() {
        _access = access;
        _locating = false;
      });
      return;
    }
    final raw = await widget.locator.current();
    if (!mounted) return;
    setState(() {
      _access = access;
      _locating = false;
      if (raw == null) {
        _error =
            'Lokasi belum didapat. Coba lagi di tempat terbuka, atau pilih '
            'kota secara manual.';
      } else {
        _coordinates = Coordinates.rounded(raw.$1, raw.$2);
        _zone = null;
      }
    });
  }

  /// Simpan → ambil jadwal → simpan setelan → jadwalkan ulang pengingat.
  /// Setelan baru tidak disimpan bila jadwalnya tidak bisa dimuat.
  Future<void> _save() async {
    final draft = _draft;
    setState(() {
      _saving = true;
      _error = null;
    });
    final PrayerDay day;
    try {
      day = await widget.fetch(draft);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = draft.usesCoordinates
            ? 'Jadwal untuk lokasi ini belum bisa dimuat. Periksa koneksi '
                  'internet, lalu coba lagi.'
            : 'Jadwal untuk kota ini belum bisa dimuat. Periksa nama kota, '
                  'negara, dan koneksi internet, lalu coba lagi.';
      });
      return;
    }
    await PrayerSettingsStore.save(draft);
    try {
      await widget.onSaved(day, draft);
    } on Object catch (error) {
      // Setelan sudah tersimpan; pengingat dicoba lagi saat dibuka ulang.
      debugPrint('Pengingat salat belum dijadwalkan ulang: $error');
    }
    if (mounted) Navigator.of(context).pop(draft);
  }

  void _setMode(PrayerLocationMode mode) => setState(() {
    _mode = mode;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final error = _error;
    return GlassSheet(
      title: 'Waktu salat',
      action: _SaveButton(
        saving: _saving,
        onTap: _canSave ? () => unawaited(_save()) : null,
      ),
      // Isinya pendek: dibangun utuh (bukan lazy), supaya isian kota tetap
      // ada saat lembar digulir ke bagian bawah.
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) ...[
              _Notice(text: error),
              const SizedBox(height: 14),
            ],
            const _Eyebrow('Lokasi'),
            SegmentedPill<PrayerLocationMode>(
              segments: const {
                PrayerLocationMode.auto: 'Otomatis',
                PrayerLocationMode.city: 'Pilih kota',
              },
              value: _mode,
              onChanged: _setMode,
            ),
            const SizedBox(height: 12),
            if (_mode == PrayerLocationMode.auto)
              ..._autoSection(tokens)
            else
              ..._citySection(tokens),
            const SizedBox(height: 24),
            const _Eyebrow('Cara hitung'),
            InsetGroupedList(
              children: [
                for (final method in prayerMethods)
                  _OptionRow(
                    label: method.label,
                    selected: method.id == _method,
                    onTap: () => setState(() => _method = method.id),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _Note('Bawaan mengikuti Kementerian Agama RI.', tokens: tokens),
            const SizedBox(height: 20),
            const _Eyebrow('Asar'),
            SegmentedPill<int>(
              segments: const {0: 'Standar', 1: 'Hanafi'},
              value: _school,
              onChanged: (school) => setState(() => _school = school),
            ),
            const SizedBox(height: 8),
            _Note('Standar: Syafi’i, Maliki, Hanbali.', tokens: tokens),
            const SizedBox(height: 24),
            _TuneSection(
              tune: _tune,
              open: _tuneOpen,
              preview: widget.preview,
              savedTune: _saved.tune,
              onToggle: () => setState(() => _tuneOpen = !_tuneOpen),
              onChanged: (index, value) => setState(() => _tune[index] = value),
              onReset: () =>
                  setState(() => _tune.fillRange(0, _tune.length, 0)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _autoSection(SacredTokens tokens) {
    final point = _coordinates;
    final zone = _zone;
    return [
      if (point != null)
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          decoration: BoxDecoration(
            color: tokens.fill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              LineIcon(SacredIcons.pin, color: tokens.primaryText, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lokasi sekarang',
                      style: SacredText.settingTitle.copyWith(
                        color: tokens.ink,
                      ),
                    ),
                    Text(
                      [point.display, ?zone].join(' · '),
                      style: SacredText.listMeta.copyWith(color: tokens.sec),
                    ),
                  ],
                ),
              ),
              _LinkButton(
                label: _locating ? 'Mencari…' : 'Perbarui',
                onTap: _locating ? null : () => unawaited(_locate()),
              ),
            ],
          ),
        )
      else
        SacredButton(
          label: _locating ? 'Mencari lokasi…' : 'Pakai lokasi sekarang',
          icon: SacredIcons.pin,
          tone: ButtonTone.soft,
          expand: true,
          onTap: _locating ? null : () => unawaited(_locate()),
        ),
      const SizedBox(height: 8),
      _Note(PrayerSettingsSheet.privacyNote, tokens: tokens),
      ..._accessNotice(tokens),
    ];
  }

  List<Widget> _accessNotice(SacredTokens tokens) {
    final text = switch (_access) {
      LocationAccess.deniedForever =>
        'Izin lokasi ditolak. Pilih kota secara manual atau buka '
            'Pengaturan HP.',
      LocationAccess.denied =>
        'Izin lokasi belum diberikan. Coba lagi, atau pilih kota secara '
            'manual.',
      LocationAccess.serviceOff =>
        'Layanan lokasi HP sedang mati. Nyalakan, lalu coba lagi, atau '
            'pilih kota secara manual.',
      LocationAccess.granted || null => null,
    };
    if (text == null) return const [];
    return [
      const SizedBox(height: 12),
      _Notice(
        text: text,
        actions: [
          if (_access == LocationAccess.deniedForever)
            _NoticeAction(
              label: 'Buka pengaturan',
              onTap: () => unawaited(widget.locator.openSettings()),
            ),
          _NoticeAction(
            label: 'Pilih kota',
            onTap: () => _setMode(PrayerLocationMode.city),
          ),
        ],
      ),
    ];
  }

  List<Widget> _citySection(SacredTokens tokens) => [
    _Field(label: 'Kota', controller: _city, onChanged: (_) => setState(() {})),
    const SizedBox(height: 10),
    _Field(
      label: 'Negara',
      controller: _country,
      onChanged: (_) => setState(() {}),
    ),
    const SizedBox(height: 8),
    _Note(
      SharedPreferencesService.hasPrayerCity()
          ? 'Tulis nama kota dan negara, misalnya Bandung, Indonesia.'
          : 'Belum memilih kota: jadwal memakai Jakarta (bawaan).',
      tokens: tokens,
    ),
    if (_recent.isNotEmpty) ...[
      const SizedBox(height: 14),
      const _Eyebrow('Terakhir dipakai'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (city, country) in _recent)
            _RecentChip(
              label: '$city · $country',
              onTap: () => setState(() {
                _city.text = city;
                _country.text = country;
                _error = null;
              }),
            ),
        ],
      ),
    ],
  ];
}

/// Koreksi menit (terlipat): stepper −10…+10 per waktu, jam hasil koreksi
/// langsung tampil.
class _TuneSection extends StatelessWidget {
  const _TuneSection({
    required this.tune,
    required this.open,
    required this.preview,
    required this.savedTune,
    required this.onToggle,
    required this.onChanged,
    required this.onReset,
  });

  final List<int> tune;
  final bool open;
  final PrayerDay? preview;

  /// Koreksi yang sudah ada di [preview], supaya pratinjau dihitung dari
  /// jam tanpa koreksi.
  final List<int> savedTune;
  final VoidCallback onToggle;
  final void Function(int index, int value) onChanged;
  final VoidCallback onReset;

  static String signed(int minutes) => minutes > 0
      ? '+$minutes'
      : minutes < 0
      ? '−${-minutes}'
      : '0';

  String get _summary {
    final parts = [
      for (var i = 0; i < tune.length; i++)
        if (tune[i] != 0) '${PrayerService.prayerNames[i]} ${signed(tune[i])}',
    ];
    return parts.isEmpty ? 'Tidak ada koreksi' : parts.join(' · ');
  }

  String? _previewTime(int index) {
    final day = preview;
    if (day == null) return null;
    final base = day.prayers[PrayerService.prayerNames[index]];
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(base ?? '');
    if (match == null) return null;
    final minutes =
        int.parse(match[1]!) * 60 +
        int.parse(match[2]!) -
        savedTune[index] +
        tune[index];
    final wrapped = minutes % (24 * 60);
    return '${(wrapped ~/ 60).toString().padLeft(2, '0')}:'
        '${(wrapped % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final changed = tune.any((minutes) => minutes != 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              decoration: BoxDecoration(
                color: tokens.surf,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tokens.sep),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Koreksi menit',
                          style: SacredText.settingTitle.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                        Text(
                          _summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SacredText.listMeta.copyWith(
                            color: tokens.sec,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? .5 : 0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    child: LineIcon(
                      SacredIcons.chevronDown,
                      color: tokens.sec,
                      size: 18,
                      strokeWidth: 2.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 10),
          InsetGroupedList(
            children: [
              for (var i = 0; i < tune.length; i++)
                _TuneRow(
                  name: PrayerService.prayerNames[i],
                  minutes: tune[i],
                  time: _previewTime(i),
                  onChanged: (value) => onChanged(i, value),
                ),
            ],
          ),
          if (changed) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: _LinkButton(label: 'Kembalikan ke bawaan', onTap: onReset),
            ),
          ],
        ],
      ],
    );
  }
}

class _TuneRow extends StatelessWidget {
  const _TuneRow({
    required this.name,
    required this.minutes,
    required this.time,
    required this.onChanged,
  });

  final String name;
  final int minutes;
  final String? time;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final time = this.time;
    Widget step(List<String> icon, String hint, int next, bool enabled) =>
        Semantics(
          button: true,
          enabled: enabled,
          label: hint,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => onChanged(next) : null,
            child: SizedBox.square(
              dimension: 44,
              child: Center(
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.fill,
                    shape: BoxShape.circle,
                  ),
                  child: LineIcon(
                    icon,
                    color: enabled ? tokens.ink : tokens.tertiary,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SacredText.settingTitle.copyWith(color: tokens.ink),
            ),
          ),
          if (time != null)
            Text(time, style: SacredText.panelTime.copyWith(color: tokens.sec)),
          step(
            const ['M6 12h12'],
            '$name dikurangi satu menit',
            minutes - 1,
            minutes > -PrayerSettings.tuneLimit,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 34),
            child: Text(
              _TuneSection.signed(minutes),
              textAlign: TextAlign.center,
              semanticsLabel:
                  '$name koreksi ${_TuneSection.signed(minutes)} '
                  'menit',
              style: SacredText.panelLabel.copyWith(color: tokens.ink),
            ),
          ),
          step(
            SacredIcons.plus,
            '$name ditambah satu menit',
            minutes + 1,
            minutes < PrayerSettings.tuneLimit,
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onTap});

  final bool saving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _LinkButton(
    label: saving ? 'Menyimpan…' : 'Simpan',
    onTap: onTap,
    strong: true,
  );
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, this.onTap, this.strong = false});

  final String label;
  final VoidCallback? onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Text(
            label,
            style: (strong ? SacredText.button : SacredText.linkLabel).copyWith(
              color: onTap == null ? tokens.sec : tokens.primaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                // Teks besar: nama metode boleh dua baris, tidak terpotong.
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SacredText.settingTitle.copyWith(color: tokens.ink),
                ),
              ),
              if (selected)
                LineIcon(
                  SacredIcons.checkCircle,
                  color: tokens.primaryText,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: tokens.fill,
            borderRadius: BorderRadius.circular(20),
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: tokens.fill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.words,
        style: SacredText.searchInput.copyWith(color: tokens.ink),
        // Wadah `fill` sudah jadi bidang isian; isian tema (putih + garis)
        // tidak ikut supaya tidak tampak bertumpuk.
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          labelText: label,
          labelStyle: SacredText.listMeta.copyWith(color: tokens.sec),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: SacredText.eyebrow.copyWith(color: tokens.sec),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {required this.tokens});

  final String text;
  final SacredTokens tokens;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(text, style: SacredText.cardNote.copyWith(color: tokens.sec)),
  );
}

class _NoticeAction {
  const _NoticeAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.actions = const []});

  final String text;
  final List<_NoticeAction> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.goldSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: SacredText.infoBox.copyWith(color: tokens.ink)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in actions)
                  SacredButton(
                    label: action.label,
                    tone: ButtonTone.soft,
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: SacredText.buttonSmall,
                    onTap: action.onTap,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
