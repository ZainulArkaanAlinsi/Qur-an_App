import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/app_controller.dart';
import 'package:quran_app_2025/app/distribution.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/chip_palette.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/app/widgets/theme_preview.dart';
import 'package:quran_app_2025/core/app_version.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/features/khatam/domain/juz_coverage.dart';
import 'package:quran_app_2025/features/onboarding/domain/start_point.dart';
import 'package:quran_app_2025/features/onboarding/presentation/brand_art.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/reciter_repository.dart';
import 'package:quran_app_2025/models/reciter.dart';
import 'package:quran_app_2025/screens/prayer_screen.dart';
import 'package:quran_app_2025/screens/progress_screen.dart';
import 'package:quran_app_2025/screens/reciter_picker.dart';
import 'package:quran_app_2025/screens/sources_screen.dart';
import 'package:quran_app_2025/screens/translation_picker.dart';
import 'package:quran_app_2025/services/audio_download_service.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/features/mushaf/presentation/debug_reader_prototype_screen.dart';
import 'package:quran_app_2025/features/tajweed/presentation/debug_tajweed_preview_screen.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_legend_screen.dart';
import 'package:quran_app_2025/services/auto_update_service.dart';
import 'package:quran_app_2025/services/cloud_sync_service.dart';
import 'package:quran_app_2025/services/update_check_service.dart';
import 'package:quran_app_2025/services/firebase_sync.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ruang di bawah daftar supaya tab bar mengambang tidak menutupi isinya.
const _bottomInset = 132.0;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// Kecerahan yang akan berlaku untuk [mode], supaya pratinjau "Otomatis"
/// menampilkan tema yang benar-benar dipakai perangkat saat ini.
Brightness _brightnessFor(BuildContext context, ThemeMode mode) =>
    switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };

class _SettingsScreenState extends State<SettingsScreen> {
  late double _arabic;
  late double _translation;
  late int _targetSeconds;
  late double _lineHeight;

  @override
  void initState() {
    super.initState();
    _arabic = SharedPreferencesService.getArabicFontSize();
    _translation = SharedPreferencesService.getTranslationFontSize();
    _targetSeconds = SharedPreferencesService.getDailyTargetSeconds();
    _lineHeight = SharedPreferencesService.getArabicLineHeight();
  }

  /// Lembar bawah v2 untuk pengaturan yang panjang. Isinya dibangun ulang
  /// setiap kali nilainya berubah, begitu pula layar di belakangnya.
  Future<void> _openSheet(
    String title,
    Widget Function(BuildContext context) body,
  ) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) {
          _refreshSheet = () => setSheet(() {});
          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                    child: Text(
                      title,
                      style: SacredText.stageTitle.copyWith(color: tokens.ink),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: tokens.surf,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: tokens.cardShadows,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: body(context),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() => _refreshSheet = null);
  }

  VoidCallback? _refreshSheet;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _refreshSheet?.call();
  }

  Widget _textSettings(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Column(
      children: [
        _SliderRow(
          label: 'Ukuran teks Arab',
          value: '${_arabic.round()} pt',
          slider: Slider(
            value: _arabic,
            min: 22,
            max: 42,
            divisions: 10,
            label: '${_arabic.round()} pt',
            onChanged: (value) {
              setState(() => _arabic = value);
              SharedPreferencesService.setArabicFontSize(value);
            },
          ),
          preview: _ArabicPreview(size: _arabic, lineHeight: _lineHeight),
        ),
        Divider(height: 1, thickness: 1, color: tokens.sep),
        _SliderRow(
          label: 'Jarak antar baris',
          value: '${_lineHeight.toStringAsFixed(1)}×',
          slider: Slider(
            value: _lineHeight,
            min: 1.6,
            max: 3.0,
            divisions: 7,
            label: '${_lineHeight.toStringAsFixed(1)}×',
            onChanged: (value) {
              setState(() => _lineHeight = value);
              SharedPreferencesService.setArabicLineHeight(value);
            },
          ),
        ),
        Divider(height: 1, thickness: 1, color: tokens.sep),
        _SliderRow(
          label: 'Ukuran terjemahan',
          value: '${_translation.round()} pt',
          slider: Slider(
            value: _translation,
            min: 14,
            max: 24,
            divisions: 10,
            label: '${_translation.round()} pt',
            onChanged: (value) {
              setState(() => _translation = value);
              SharedPreferencesService.setTranslationFontSize(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _startSettings(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final current = StartPoint.saved ?? StartPoint.initial;
    const icons = {
      StartPoint.nol: SacredIcons.cap,
      StartPoint.tajwid: SacredIcons.book,
      StartPoint.hafalan: SacredIcons.layers,
    };
    return Column(
      children: [
        for (final point in StartPoint.values) ...[
          if (point != StartPoint.values.first)
            Divider(
              height: .5,
              thickness: .5,
              indent: SettingsRow.separatorInset,
              color: tokens.sep,
            ),
          Semantics(
            selected: point == current,
            inMutuallyExclusiveGroup: true,
            child: SettingsRow(
              icon: icons[point]!,
              chipColor: SacredBadge.green,
              title: point.title,
              subtitle: point.subtitle,
              trailing: point == current
                  ? LineIcon(
                      SacredIcons.checkCircle,
                      color: tokens.primaryText,
                      size: 22,
                    )
                  : const SizedBox(width: 22),
              onTap: () async {
                await SharedPreferencesService.setStartPoint(point.id);
                if (mounted) setState(() {});
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _themeSettings(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final controller = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pratinjau memakai warna temanya sendiri, jadi yang terlihat
          // memang yang akan dipakai.
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final mode in ThemeMode.values)
                ThemePreviewTile(
                  tokens: SacredTheme.tokensFor(
                    controller.palette,
                    _brightnessFor(context, mode),
                  ),
                  label: switch (mode) {
                    ThemeMode.system => 'Otomatis',
                    ThemeMode.light => 'Terang',
                    ThemeMode.dark => 'Gelap',
                  },
                  selected: controller.themeMode == mode,
                  onTap: () => controller.setThemeMode(mode),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Sepia lebih teduh untuk membaca lama; kontras tinggi '
            'memperjelas teks.',
            style: SacredText.cardNote.copyWith(color: tokens.sec),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final palette in AppPalette.values)
                ThemePreviewTile(
                  tokens: SacredTheme.tokensFor(
                    palette,
                    _brightnessFor(context, controller.themeMode),
                  ),
                  label: palette.label,
                  selected: controller.palette == palette,
                  onTap: () => controller.setPalette(palette),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: _bottomInset),
      children: [
        // Judul besar sekali saja (bug lama: "Pengaturan" tampil dobel).
        const ScreenHeader(title: 'Saya'),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _ProfileCard(),
        ),
        // Progres pindah dari tab sendiri ke sini (12-saya.md).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: GroupedList(
            children: [
              ListRow(
                leading: const IconBadge(
                  icon: SacredIcons.chart,
                  color: SacredBadge.green,
                ),
                title: 'Progres lengkap',
                subtitle: 'Istiqamah, menit, khatam',
                chevron: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProgressScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),

        _Group(
          header: 'Membaca',
          child: Column(
            children: [
              SettingsRow(
                icon: SacredIcons.textSize,
                chipColor: SacredBadge.green,
                title: 'Tampilan teks',
                value: '${_arabic.round()} pt',
                onTap: () => _openSheet('Tampilan teks', _textSettings),
              ),
              Divider(
                height: .5,
                thickness: .5,
                indent: SettingsRow.separatorInset,
                color: tokens.sep,
              ),
              SettingsRow(
                icon: SacredIcons.translate,
                chipColor: SacredBadge.blue,
                title: 'Terjemahan',
                value: 'Unduh bahasa lain',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TranslationPicker(),
                  ),
                ),
              ),
              Divider(
                height: .5,
                thickness: .5,
                indent: SettingsRow.separatorInset,
                color: tokens.sep,
              ),
              SettingsRow(
                icon: SacredIcons.palette,
                chipColor: SacredBadge.gold,
                title: 'Warna tajwid',
                value: 'Arti tiap warna',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const TajweedLegendScreen(backLabel: 'Saya'),
                  ),
                ),
              ),
              Divider(
                height: .5,
                thickness: .5,
                indent: SettingsRow.separatorInset,
                color: tokens.sep,
              ),
              SettingsRow(
                icon: SacredIcons.sun,
                chipColor: SacredBadge.grey,
                title: 'Tema',
                value: switch (controller.themeMode) {
                  ThemeMode.system => 'Otomatis',
                  ThemeMode.light => 'Terang',
                  ThemeMode.dark => 'Gelap',
                },
                onTap: () => _openSheet('Tema', _themeSettings),
              ),
            ],
          ),
        ),

        // Titik mulai pilihan onboarding bisa diubah di sini
        // (docs/design/v3/DESIGN.md §5b).
        _Group(
          header: 'Belajar',
          child: SettingsRow(
            icon: SacredIcons.cap,
            chipColor: SacredBadge.green,
            title: 'Titik mulai',
            value: (StartPoint.saved ?? StartPoint.initial).shortLabel,
            onTap: () => _openSheet('Mulai dari mana?', _startSettings),
          ),
        ),

        _Group(
          header: 'Audio & kebiasaan',
          child: Column(
            children: [
              const _ReciterCard(),
              Divider(
                height: .5,
                thickness: .5,
                indent: SettingsRow.separatorInset,
                color: tokens.sep,
              ),
              _TargetRow(
                seconds: _targetSeconds,
                onChanged: (seconds) {
                  setState(() => _targetSeconds = seconds);
                  SharedPreferencesService.setDailyTargetSeconds(seconds);
                },
              ),
              Divider(
                height: .5,
                thickness: .5,
                indent: SettingsRow.separatorInset,
                color: tokens.sep,
              ),
              const _ReminderRow(),
            ],
          ),
        ),

        _Group(
          header: 'Salat',
          child: SettingsRow(
            icon: SacredIcons.sun,
            chipColor: SacredBadge.blue,
            title: 'Jadwal salat & adzan',
            subtitle: 'Kota, metode, dan pengingat tiap waktu',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PrayerScreen()),
            ),
          ),
        ),

        _Group(
          header: 'Sumber & lisensi',
          child: SettingsRow(
            icon: SacredIcons.book,
            chipColor: SacredBadge.gold,
            title: 'Sumber & lisensi',
            subtitle: 'Teks, terjemahan, audio, dan waktu salat',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SourcesScreen()),
            ),
          ),
        ),

        // Tentang dan pembaruan digabung jadi satu kelompok (12-saya.md).
        _Group(
          header: 'Tentang & pembaruan',
          child: Column(
            children: [
              // Pengunduh APK hanya di build GitHub; build Play diperbarui
              // lewat Play (lib/app/distribution.dart).
              if (isGithubBuild) ...[
                const _AutoUpdateCard(),
                Divider(height: .5, thickness: .5, color: tokens.sep),
              ],
              const _AboutCard(),
            ],
          ),
        ),

        // Konstanta `kDebugMode` membuat cabang ini (dan layar pratinjau yang
        // memanggil api.quran.com langsung) terbuang dari build rilis.
        if (kDebugMode)
          _Group(
            header: 'Debug',
            child: Column(
              children: [
                SettingsRow(
                  icon: SacredIcons.palette,
                  chipColor: SacredBadge.gold,
                  title: 'Pratinjau tajwid',
                  subtitle: 'Data langsung dari api.quran.com',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DebugTajweedPreviewScreen(),
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: SettingsRow.separatorInset,
                  color: tokens.sep,
                ),
                SettingsRow(
                  icon: SacredIcons.book,
                  chipColor: SacredBadge.grey,
                  title: 'Prototipe tiga layout baca',
                  subtitle: 'Card, mushaf 1 halaman, mushaf 2 halaman',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DebugReaderPrototypeScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Satu kelompok v2: label bagian lalu kartu radius 22 berbayang tipis.
class _Group extends StatelessWidget {
  const _Group({required this.header, required this.child});

  final String header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(header),
          Container(
            decoration: BoxDecoration(
              color: tokens.surf,
              borderRadius: BorderRadius.circular(22),
              boxShadow: tokens.cardShadows,
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Baris dengan penggeser: label kiri, nilai kanan, lalu penggesernya.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.slider,
    this.preview,
  });

  final String label;
  final String value;
  final Widget slider;
  final Widget? preview;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: SacredText.settingTitle.copyWith(color: tokens.ink),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: SacredText.settingValue.copyWith(color: tokens.sec),
              ),
            ],
          ),
          if (preview != null) ...[const SizedBox(height: 10), preview!],
          slider,
        ],
      ),
    );
  }
}

/// Target harian. Perubahannya berlaku besok, dan itu ditulis di barisnya.
class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.seconds, required this.onChanged});

  final int seconds;
  final ValueChanged<int> onChanged;

  Future<void> _choose(BuildContext context) async {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: tokens.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  'Target harian',
                  style: SacredText.stageTitle.copyWith(color: tokens.ink),
                ),
              ),
              GroupedList(
                children: [
                  for (final option in const [300, 600, 900, 1800])
                    ListRow(
                      title: '${option ~/ 60} menit',
                      trailing: seconds == option
                          ? LineIcon(
                              SacredIcons.checkCircle,
                              color: tokens.primaryText,
                              size: 22,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, option),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(
                  'Perubahan target berlaku besok. Riwayat hari sebelumnya '
                  'tetap tersimpan.',
                  style: SacredText.cardNote.copyWith(color: tokens.sec),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) => SettingsRow(
    icon: SacredIcons.timer,
    chipColor: SacredBadge.grey,
    title: 'Target harian',
    value: '${seconds ~/ 60} menit',
    onTap: () => _choose(context),
  );
}

/// Pemilih qari. Daftarnya diambil dinamis dari provider, bukan ditulis tetap
/// di kode, dan bitrate tiap qari diperiksa sebelum pilihan disimpan.
class _ReciterCard extends StatefulWidget {
  const _ReciterCard();

  @override
  State<_ReciterCard> createState() => _ReciterCardState();
}

class _ReciterCardState extends State<_ReciterCard> {
  final _repository = ReciterRepository();
  final _downloads = AudioDownloadService();
  late Reciter _selected = SharedPreferencesService.getReciter();
  late bool _lowData = SharedPreferencesService.getLowDataAudio();
  bool _busy = false;
  int? _storageBytes;

  @override
  void initState() {
    super.initState();
    _refreshStorage();
  }

  Future<void> _refreshStorage() async {
    final used = await _downloads.storageUsed(_selected);
    if (mounted) setState(() => _storageBytes = used);
  }

  /// Layar Qari menyimpan pilihannya sendiri; sepulangnya, qari dan ukuran
  /// unduhan dibaca ulang.
  Future<void> _choose() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ReciterPicker()));
    if (!mounted) return;
    setState(() => _selected = SharedPreferencesService.getReciter());
    await _refreshStorage();
  }

  Future<void> _toggleLowData(bool value) async {
    setState(() {
      _lowData = value;
      _busy = true;
    });
    await SharedPreferencesService.setLowDataAudio(value);
    // Kualitas berkas berikutnya ikut berubah, jadi bitrate qari saat ini
    // diperiksa ulang.
    final resolved = await _repository.resolveBitrate(
      Reciter(
        identifier: _selected.identifier,
        name: _selected.name,
        englishName: _selected.englishName,
      ),
      lowData: value,
    );
    if (resolved != null) {
      await SharedPreferencesService.setReciter(resolved);
      await QuranAudioService.instance.stop();
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (resolved != null) _selected = resolved;
    });
  }

  Future<void> _deleteDownloads() async {
    setState(() => _busy = true);
    await _downloads.deleteAll(_selected);
    final used = await _downloads.storageUsed(_selected);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _storageBytes = used;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final megabytes = (_storageBytes ?? 0) / (1024 * 1024);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          icon: SacredIcons.headphones,
          chipColor: SacredBadge.grey,
          title: 'Qari',
          value: _selected.displayName,
          trailing: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _busy ? null : _choose,
        ),
        Divider(
          height: 1,
          thickness: 1,
          indent: SettingsRow.separatorInset,
          color: tokens.sep,
        ),
        SettingsRow(
          icon: SacredIcons.cloud,
          chipColor: SacredBadge.red,
          title: 'Hemat kuota',
          subtitle:
              'Pakai berkas 64 kbps bila tersedia. Ukurannya sekitar separuh, '
              'suaranya sedikit lebih rendah.',
          trailing: IosToggle(
            value: _lowData,
            semanticsLabel: 'Hemat kuota',
            onChanged: _busy ? null : _toggleLowData,
          ),
        ),
        if ((_storageBytes ?? 0) > 0) ...[
          Divider(
            height: 1,
            thickness: 1,
            indent: SettingsRow.separatorInset,
            color: tokens.sep,
          ),
          SettingsRow(
            icon: SacredIcons.download,
            chipColor: SacredBadge.gold,
            title: 'Murottal offline',
            value: '${megabytes.toStringAsFixed(1)} MB',
            subtitle: 'Tersimpan untuk ${_selected.displayName}.',
            trailing: TextButton(
              onPressed: _busy ? null : _deleteDownloads,
              child: const Text('Hapus'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Pembaruan otomatis: unduh sendiri lalu buka pemasang. Android tetap
/// meminta konfirmasi tiap pemasangan, jadi teksnya tidak menjanjikan
/// "tanpa dialog".
class _AutoUpdateCard extends StatefulWidget {
  const _AutoUpdateCard();

  @override
  State<_AutoUpdateCard> createState() => _AutoUpdateCardState();
}

class _AutoUpdateCardState extends State<_AutoUpdateCard> {
  late bool _enabled = SharedPreferencesService.getAutoUpdate();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          icon: SacredIcons.download,
          chipColor: SacredBadge.blue,
          title: 'Unduh pembaruan otomatis',
          subtitle:
              'Versi baru diunduh sendiri saat aplikasi dibuka, lalu pemasang '
              'Android terbuka. Konfirmasi pemasangan tetap dari Anda.',
          trailing: IosToggle(
            value: _enabled,
            semanticsLabel: 'Unduh pembaruan otomatis',
            onChanged: (value) async {
              setState(() => _enabled = value);
              await SharedPreferencesService.setAutoUpdate(value);
            },
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          indent: SettingsRow.separatorInset,
          color: tokens.sep,
        ),
        SettingsRow(
          icon: SacredIcons.checkCircle,
          chipColor: SacredBadge.green,
          title: 'Izin pasang aplikasi',
          subtitle:
              'Diperlukan sekali agar pembaruan bisa dipasang langsung dari '
              'aplikasi.',
          onTap: () => const ApkInstaller().openPermissionSettings(),
        ),
      ],
    );
  }
}

class _AboutCard extends StatefulWidget {
  const _AboutCard();

  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  bool _checking = false;
  String? _status;
  AvailableUpdate? _update;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _status = null;
    });
    final update = await UpdateCheckService.check();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _update = update;
      _status = update == null
          ? 'Anda sudah memakai versi terbaru (atau belum terhubung ke internet).'
          : 'Versi ${update.version} tersedia.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final update = _update;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        children: [
          // Logo utama 160 dp, utuh (docs/design/v3/screens/15-logo-ikon.md).
          const BrandLogo(width: 160, semanticLabel: 'Logo MyQuran'),
          const SizedBox(height: 12),
          Text(
            'MyQuran $appVersion',
            textAlign: TextAlign.center,
            style: SacredText.settingTitle.copyWith(color: tokens.ink),
          ),
          if (_status != null) ...[
            const SizedBox(height: 4),
            Semantics(
              liveRegion: true,
              child: Text(
                _status!,
                textAlign: TextAlign.center,
                style: SacredText.cardNote.copyWith(color: tokens.sec),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              // Build Play diperbarui lewat Play; pemeriksa rilis GitHub
              // hanya ada di build GitHub.
              if (isGithubBuild)
                if (update != null)
                  SacredButton(
                    label: 'Unduh pembaruan',
                    icon: SacredIcons.download,
                    height: 40,
                    textStyle: SacredText.buttonSmall,
                    onTap: () => launchUrl(
                      update.url,
                      mode: LaunchMode.externalApplication,
                    ),
                  )
                else
                  SacredButton(
                    label: _checking ? 'Memeriksa…' : 'Periksa pembaruan',
                    icon: SacredIcons.download,
                    tone: ButtonTone.soft,
                    height: 40,
                    textStyle: SacredText.buttonSmall,
                    onTap: _checking ? null : _check,
                  ),
              SacredButton(
                label: 'Kebijakan privasi',
                tone: ButtonTone.fill,
                height: 40,
                textStyle: SacredText.buttonSmall,
                onTap: () => launchUrl(
                  Uri.parse(privacyPolicyUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SyncCard extends StatefulWidget {
  const _SyncCard();

  @override
  State<_SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends State<_SyncCard> {
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _refreshLastSync();
    AccountService.instance.sync?.state.addListener(_refreshLastSync);
  }

  @override
  void dispose() {
    AccountService.instance.sync?.state.removeListener(_refreshLastSync);
    super.dispose();
  }

  Future<void> _refreshLastSync() async {
    final last = await AccountService.instance.sync?.lastSuccess();
    if (mounted) setState(() => _lastSync = last);
  }

  void _show(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus akun & data cloud?'),
        content: const Text(
          'Sesi baca dan bookmark di server akan dihapus permanen, lalu akun '
          'sinkronisasi ditutup. Data di perangkat ini tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _show(
        await AccountService.instance.deleteAccount() ??
            'Akun dan data cloud telah dihapus.',
      );
    }
  }

  String _lastSyncLabel() {
    final last = _lastSync;
    if (last == null) return 'Belum pernah disinkronkan.';
    final time =
        '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}';
    return 'Terakhir disinkronkan ${last.day}/${last.month}/${last.year} $time.';
  }

  /// Kartu profil pada mockup: lingkaran 54 px berisi huruf awal nama.
  Widget _avatar(BuildContext context, String name) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tokens.cta, shape: BoxShape.circle),
      child: Text(
        initial,
        style: SacredText.avatar.copyWith(color: tokens.ctaInk),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = AccountService.instance;
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final sync = service.sync;
    if (!service.available || sync == null) {
      return SoftCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Text(
          'Sinkronisasi cloud tidak tersedia di perangkat ini. Semua data '
          'tetap tersimpan secara lokal.',
          style: SacredText.cardNote.copyWith(color: tokens.sec),
        ),
      );
    }
    return ListenableBuilder(
      listenable: Listenable.merge([
        service.account,
        service.busy,
        sync.state,
        sync.message,
      ]),
      builder: (context, _) {
        final account = service.account.value;
        final busy = service.busy.value;
        final syncing = sync.state.value == SyncState.syncing;
        if (account == null) {
          return SoftCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Simpan progres baca dan bookmark',
                  style: SacredText.settingTitle.copyWith(color: tokens.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  'Masuk agar data bisa dipakai di HP lain. Membaca tetap '
                  'bisa tanpa masuk; data di perangkat ini ikut diunggah.',
                  style: SacredText.cardNote.copyWith(color: tokens.sec),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async => _show(await service.signInWithGoogle()),
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login_rounded),
                  label: const Text('Masuk dengan Google'),
                ),
              ],
            ),
          );
        }
        final name = account.name ?? account.email ?? 'Akun Google';
        return SoftCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _avatar(context, name),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SacredText.listName.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            LineIcon(
                              SacredIcons.cloud,
                              color: tokens.primaryText,
                              size: 15,
                              strokeWidth: 2,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                syncing
                                    ? 'Menyinkronkan data'
                                    : sync.message.value ?? _lastSyncLabel(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: SacredText.cardNote.copyWith(
                                  color: sync.state.value == SyncState.failed
                                      ? Theme.of(context).colorScheme.error
                                      : tokens.sec,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: syncing || busy ? null : service.syncNow,
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Sinkronkan'),
                  ),
                  TextButton(
                    onPressed: busy ? null : service.signOut,
                    child: const Text('Keluar'),
                  ),
                ],
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  padding: EdgeInsets.zero,
                ),
                onPressed: busy || syncing ? null : _confirmDelete,
                child: const Text('Hapus akun & data cloud'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pratinjau ukuran teks Arab memakai ayat sungguhan dari dataset, bukan
/// kalimat contoh, supaya yang terlihat sama dengan yang dibaca nanti.
class _ArabicPreview extends StatelessWidget {
  const _ArabicPreview({required this.size, required this.lineHeight});

  final double size;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: FutureBuilder<List<String>>(
        future: QuranTextRepository.instance.versesForSurah(1),
        builder: (context, snapshot) {
          final verse = snapshot.data?.first;
          if (verse == null) {
            return Text(
              'Pratinjau sedang dimuat…',
              style: SacredText.cardNote.copyWith(color: tokens.sec),
            );
          }
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              verse,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: SacredText.quran,
                fontSize: size,
                height: lineHeight,
                color: tokens.ink,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Kartu profil v2: avatar, nama akun, status sinkron, dan tiga angka nyata
/// (hari istiqamah, menit minggu ini, juz khatam). Ketuk untuk akun &
/// sinkronisasi.
class _ProfileCard extends StatefulWidget {
  const _ProfileCard();

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  final Future<List<JuzBoundary>> _juz = JuzRepository.load();
  late Future<DateTime?> _lastSync = _loadLastSync();

  Future<DateTime?> _loadLastSync() async {
    try {
      return await AccountService.instance.sync?.lastSuccess();
    } on Object {
      return null;
    }
  }

  Future<void> _openAccount() async {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: _SyncCard(),
        ),
      ),
    );
    if (mounted) setState(() => _lastSync = _loadLastSync());
  }

  /// Menit membaca Senin–hari ini.
  static int _minutesThisWeek() {
    final now = DateTime.now();
    var seconds = 0;
    for (var i = 0; i < now.weekday; i++) {
      final day = DateTime(now.year, now.month, now.day - i);
      seconds += SharedPreferencesService.getReadingSeconds(
        ReadingProgressService.localDate(day),
      );
    }
    return seconds ~/ 60;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final streak = ReadingProgressService.read().currentStreak;
    return SacredCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ValueListenableBuilder<SyncAccount?>(
            valueListenable: AccountService.instance.account,
            builder: (context, account, _) {
              final name = account?.name?.trim();
              final initial = (name == null || name.isEmpty)
                  ? null
                  : name.substring(0, 1).toUpperCase();
              return InkWell(
                onTap: _openAccount,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tokens.cta,
                          shape: BoxShape.circle,
                        ),
                        child: initial == null
                            ? LineIcon(
                                SacredIcons.user,
                                color: tokens.ctaInk,
                                size: 24,
                              )
                            : Text(
                                initial,
                                textScaler: TextScaler.noScaling,
                                style: SacredText.profileInitial.copyWith(
                                  color: tokens.ctaInk,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account == null
                                  ? 'Belum masuk'
                                  : (name == null || name.isEmpty
                                        ? (account.email ?? 'Akun Google')
                                        : name),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: SacredText.profileName.copyWith(
                                color: tokens.ink,
                              ),
                            ),
                            FutureBuilder<DateTime?>(
                              future: _lastSync,
                              builder: (context, snapshot) => Text(
                                _syncLine(account, snapshot.data),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: SacredText.rowSubtitle.copyWith(
                                  color: tokens.sec,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      LineIcon(
                        SacredIcons.chevronRight,
                        color: tokens.tertiary,
                        size: 17,
                        strokeWidth: 2.2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Divider(
            height: .5,
            thickness: .5,
            indent: 16,
            endIndent: 16,
            color: tokens.sep,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: FutureBuilder<List<JuzBoundary>>(
              future: _juz,
              builder: (context, snapshot) {
                final boundaries = snapshot.data;
                final juz = boundaries == null
                    ? null
                    : JuzCoverage.completeJuz(
                        SharedPreferencesService.getCompletedSurahs(),
                        boundaries,
                      ).length;
                final stats = [
                  ('$streak', 'hari istiqamah'),
                  ('${_minutesThisWeek()}', 'menit minggu ini'),
                  (juz == null ? '–' : '$juz/30', 'juz khatam'),
                ];
                // Teks sangat besar: angka ditumpuk sebaris dengan
                // keterangannya supaya "istiqamah" dan "0/30" tidak dipecah.
                if (MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.6) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (value, label) in stats)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _Stat(value, label, inline: true),
                        ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (value, label) in stats)
                      Expanded(child: _Stat(value, label)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _syncLine(SyncAccount? account, DateTime? last) {
    if (account == null) return 'Masuk untuk menyimpan progres di cloud';
    if (last == null) return 'Belum pernah tersinkron';
    final local = last.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return sameDay
        ? 'Tersinkron · $time'
        : 'Tersinkron · ${local.day}/${local.month} $time';
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, {this.inline = false});

  final String value;
  final String label;

  /// Angka dan keterangan sebaris (dipakai saat teks sangat besar).
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: inline
          ? Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$value  ',
                    style: SacredText.metric.copyWith(color: tokens.ink),
                  ),
                  TextSpan(
                    text: label,
                    style: SacredText.cardNote.copyWith(color: tokens.sec),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: SacredText.metric.copyWith(color: tokens.ink),
                ),
                Text(
                  label,
                  style: SacredText.cardNote.copyWith(color: tokens.sec),
                ),
              ],
            ),
    );
  }
}

/// Pengingat tilawah: jamnya atau "Nonaktif". Diatur di layar Salat karena
/// penjadwalannya ikut jadwal salat hari itu.
class _ReminderRow extends StatelessWidget {
  const _ReminderRow();

  @override
  Widget build(BuildContext context) {
    final minutes = SharedPreferencesService.getQuranReminderMinutes();
    return SettingsRow(
      icon: SacredIcons.bell,
      chipColor: SacredBadge.red,
      title: 'Pengingat tilawah',
      value: minutes == null
          ? 'Nonaktif'
          : '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
                '${(minutes % 60).toString().padLeft(2, '0')}',
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const PrayerScreen())),
    );
  }
}
