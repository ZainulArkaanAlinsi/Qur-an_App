import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/app_controller.dart';
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
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/reciter_repository.dart';
import 'package:quran_app_2025/models/reciter.dart';
import 'package:quran_app_2025/screens/progress_screen.dart';
import 'package:quran_app_2025/screens/reciter_picker.dart';
import 'package:quran_app_2025/services/audio_download_service.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/features/mushaf/presentation/debug_reader_prototype_screen.dart';
import 'package:quran_app_2025/features/tajweed/presentation/debug_tajweed_preview_screen.dart';
import 'package:quran_app_2025/services/auto_update_service.dart';
import 'package:quran_app_2025/services/cloud_sync_service.dart';
import 'package:quran_app_2025/services/update_check_service.dart';
import 'package:quran_app_2025/services/firebase_sync.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ruang di bawah daftar supaya tab bar mengambang tidak menutupi isinya.
const _bottomInset = 132.0;

/// Atribusi murottal yang mengikuti qari dan bitrate yang benar-benar dipakai.
String _murottalAttribution() {
  final reciter = SharedPreferencesService.getReciter();
  return '${reciter.displayName}, per ayat ${reciter.bitrate ?? 128} kbps. '
      '${reciter.attribution}';
}

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

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: _bottomInset),
      children: [
        const ScreenHeader(title: 'Saya'),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: _SyncCard(),
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
          header: 'Tampilan',
          child: Padding(
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
          ),
        ),

        _Group(
          header: 'Bacaan',
          child: Column(
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
          ),
        ),

        _Group(
          header: 'Kebiasaan & audio',
          separatorInset: SettingsRow.separatorInset,
          child: Column(
            children: [
              _TargetRow(
                seconds: _targetSeconds,
                onChanged: (seconds) {
                  setState(() => _targetSeconds = seconds);
                  SharedPreferencesService.setDailyTargetSeconds(seconds);
                },
              ),
              Divider(
                height: 1,
                thickness: 1,
                indent: SettingsRow.separatorInset,
                color: tokens.sep,
              ),
              const _ReciterCard(),
            ],
          ),
        ),

        _Group(
          header: 'Sumber & lisensi',
          separatorInset: SettingsRow.separatorInset,
          child: Column(
            children: [
              _SourceRow(
                icon: SacredIcons.checkCircle,
                chipColor: ChipTone.green.of(context),
                title: 'Teks Arab offline',
                body:
                    'Tanzil Quran Text, Uthmani v1.0.2 (CC BY 3.0). Disimpan '
                    'tanpa perubahan.',
                url: 'https://tanzil.net/',
              ),
              _SourceRow(
                icon: SacredIcons.translate,
                chipColor: ChipTone.translate.of(context),
                title: 'Terjemahan Kemenag RI',
                body:
                    'Edisi “Bahasa Indonesia” dari Tanzil (pembaruan 4 Juni '
                    '2010), penerjemah Kementerian Agama RI. Tersimpan offline '
                    'tanpa perubahan; untuk penggunaan non-komersial.',
                url: 'https://tanzil.net/trans/',
              ),
              // Dulu baris ini selalu menyebut "Alafasy, 128 kbps" apa pun
              // qari yang dipilih, karena seluruh grupnya `const` sehingga
              // mustahil membaca pilihan pengguna.
              _SourceRow(
                icon: SacredIcons.headphones,
                chipColor: ChipTone.gold.of(context),
                title: 'Murottal',
                body: _murottalAttribution(),
                url: 'https://alquran.cloud/terms-and-conditions',
              ),
            ],
          ),
        ),

        const _Group(
          header: 'Pembaruan aplikasi',
          separatorInset: SettingsRow.separatorInset,
          child: _AutoUpdateCard(),
        ),

        const _Group(header: 'Tentang aplikasi', child: _AboutCard()),

        // Konstanta `kDebugMode` membuat cabang ini (dan layar pratinjau yang
        // memanggil api.quran.com langsung) terbuang dari build rilis.
        if (kDebugMode)
          _Group(
            header: 'Debug',
            separatorInset: SettingsRow.separatorInset,
            child: Column(
              children: [
                SettingsRow(
                  icon: SacredIcons.palette,
                  chipColor: ChipTone.gold.of(context),
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
                  chipColor: ChipTone.slate.of(context),
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

/// Satu kelompok: judul kecil lalu kartu radius 22 (Pengaturan.html).
class _Group extends StatelessWidget {
  const _Group({
    required this.header,
    required this.child,
    this.separatorInset = 0,
  });

  final String header;
  final Widget child;
  final double separatorInset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    child: InsetGroupedList(
      header: header,
      radius: 22,
      separatorInset: separatorInset,
      children: [child],
    ),
  );
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

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          icon: SacredIcons.timer,
          chipColor: ChipTone.green.of(context),
          title: 'Target harian',
          value: '${seconds ~/ 60} menit',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(60, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in const [300, 600, 900, 1800])
                    ChoiceChip(
                      label: Text('${option ~/ 60} menit'),
                      selected: seconds == option,
                      onSelected: (_) => onChanged(option),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Perubahan target berlaku besok. Riwayat hari sebelumnya tetap '
                'tersimpan.',
                style: SacredText.cardNote.copyWith(color: tokens.sec),
              ),
            ],
          ),
        ),
      ],
    );
  }
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

  Future<void> _choose() async {
    setState(() => _busy = true);
    final reciters = await _repository.load();
    if (!mounted) return;
    setState(() => _busy = false);

    final picked = await showReciterPicker(
      context,
      reciters: reciters,
      selected: _selected,
      // Contoh diputar dengan qari yang sedang disorot, bukan qari terpilih,
      // supaya bisa dibandingkan sebelum memutuskan.
      onPreview: (reciter) => _preview(reciter),
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    final resolved = await _repository.resolveBitrate(picked);
    if (!mounted) return;
    setState(() => _busy = false);
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Murottal ${picked.displayName} belum tersedia di server. '
            'Qari sebelumnya tetap dipakai.',
          ),
        ),
      );
      return;
    }
    await SharedPreferencesService.setReciter(resolved);
    // Antrean yang sedang berjalan memakai qari lama; hentikan agar tidak
    // tercampur di tengah surah.
    await QuranAudioService.instance.stop();
    if (mounted) setState(() => _selected = resolved);
  }

  /// Memutar Al-Fatihah ayat 1 dengan [reciter] sebagai contoh suara.
  ///
  /// Bitrate-nya belum tentu tersedia, jadi dipastikan dulu; kalau tidak ada,
  /// dikatakan apa adanya alih-alih memutar berkas yang tidak ada.
  Future<void> _preview(Reciter reciter) async {
    final resolved = await _repository.resolveBitrate(reciter);
    if (!mounted) return;
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contoh ${reciter.displayName} belum tersedia.'),
        ),
      );
      return;
    }
    try {
      await QuranAudioService.instance.playPreview(resolved);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contoh gagal diputar. Periksa koneksi.')),
      );
    }
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
          chipColor: ChipTone.slate.of(context),
          title: 'Qari',
          value: _selected.displayName,
          subtitle: _selected.name.isEmpty
              ? 'Ketuk untuk memilih qari lain'
              : '${_selected.name} · ${_selected.bitrate ?? 128} kbps',
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
          chipColor: ChipTone.terracotta.of(context),
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
            chipColor: ChipTone.gold.of(context),
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
          chipColor: ChipTone.translate.of(context),
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
          chipColor: ChipTone.green.of(context),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ruang Tilawah $appVersion',
            style: SacredText.settingTitle.copyWith(color: tokens.ink),
          ),
          if (_status != null) ...[
            const SizedBox(height: 4),
            Text(
              _status!,
              style: SacredText.cardNote.copyWith(color: tokens.sec),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (update != null)
                FilledButton.icon(
                  onPressed: () => launchUrl(
                    update.url,
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Unduh pembaruan'),
                )
              else
                OutlinedButton.icon(
                  onPressed: _checking ? null : _check,
                  icon: _checking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_rounded),
                  label: const Text('Periksa pembaruan'),
                ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(privacyPolicyUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Kebijakan privasi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Baris sumber teks/audio. Membuka tautan lisensinya di peramban.
class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.chipColor,
    required this.title,
    required this.body,
    required this.url,
  });

  final List<String> icon;
  final Color chipColor;
  final String title;
  final String body;
  final String url;

  @override
  Widget build(BuildContext context) => SettingsRow(
    icon: icon,
    chipColor: chipColor,
    title: title,
    subtitle: body,
    onTap: () async {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      ).catchError((Object _) => false);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tautan tidak dapat dibuka: $url')),
        );
      }
    },
  );
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
