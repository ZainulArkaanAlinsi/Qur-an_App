import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/app_controller.dart';
import 'package:quran_app_2025/app/glass_surface.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/core/app_version.dart';
import 'package:quran_app_2025/features/mushaf/presentation/debug_reader_prototype_screen.dart';
import 'package:quran_app_2025/features/tajweed/presentation/debug_tajweed_preview_screen.dart';
import 'package:quran_app_2025/services/auto_update_service.dart';
import 'package:quran_app_2025/services/cloud_sync_service.dart';
import 'package:quran_app_2025/services/update_check_service.dart';
import 'package:quran_app_2025/services/firebase_sync.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

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
    final theme = Theme.of(context);
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        Text(
          'Pengaturan',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Atur ruang baca agar nyaman untukmu.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 26),
        const _SectionTitle('Tampilan'),
        const SizedBox(height: 10),
        GlassSurface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tema aplikasi',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Sistem', maxLines: 1),
                    ),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Terang', maxLines: 1),
                    ),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Gelap', maxLines: 1),
                    ),
                  ),
                ],
                selected: {controller.themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    controller.setThemeMode(value.first),
              ),
              const SizedBox(height: 18),
              const Text(
                'Warna',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Sepia lebih teduh untuk membaca lama; kontras tinggi '
                'memperjelas teks.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final palette in AppPalette.values)
                    ChoiceChip(
                      label: Text(palette.label),
                      selected: controller.palette == palette,
                      onSelected: (_) => controller.setPalette(palette),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const _SectionTitle('Pembaca'),
        const SizedBox(height: 10),
        GlassSurface(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ukuran huruf Arab',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: SacredTheme.primary.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${_arabic.round()} px',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _arabic,
                min: 22,
                max: 42,
                divisions: 10,
                onChanged: (value) {
                  setState(() => _arabic = value);
                  SharedPreferencesService.setArabicFontSize(value);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Jarak antar baris Arab',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text('${_lineHeight.toStringAsFixed(1)}×'),
                ],
              ),
              Slider(
                value: _lineHeight,
                min: 1.6,
                max: 3.0,
                divisions: 7,
                onChanged: (value) {
                  setState(() => _lineHeight = value);
                  SharedPreferencesService.setArabicLineHeight(value);
                },
              ),
              Text(
                'Gunakan mode fokus di Reader untuk pengalaman baca yang lebih hening.',
                style: theme.textTheme.bodySmall,
              ),
              const Divider(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ukuran terjemahan',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: SacredTheme.primary.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${_translation.round()} px',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _translation,
                min: 14,
                max: 24,
                divisions: 10,
                onChanged: (value) {
                  setState(() => _translation = value);
                  SharedPreferencesService.setTranslationFontSize(value);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const _SectionTitle('Target harian'),
        const SizedBox(height: 10),
        GlassSurface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Waktu membaca',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Perubahan target berlaku besok. Riwayat hari sebelumnya tetap tersimpan.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [300, 600, 900, 1800]
                    .map(
                      (seconds) => ChoiceChip(
                        label: Text('${seconds ~/ 60} menit'),
                        selected: _targetSeconds == seconds,
                        onSelected: (_) {
                          setState(() => _targetSeconds = seconds);
                          SharedPreferencesService.setDailyTargetSeconds(
                            seconds,
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const _SectionTitle('Akun & sinkronisasi'),
        const SizedBox(height: 10),
        const _SyncCard(),
        const SizedBox(height: 26),
        const _SectionTitle('Konten & sumber'),
        const SizedBox(height: 10),
        const _SourceCard(
          icon: Icons.verified_outlined,
          title: 'Teks Arab offline',
          body:
              'Tanzil Quran Text, Uthmani v1.0.2 (CC BY 3.0). Disimpan tanpa perubahan.',
          url: 'https://tanzil.net/',
        ),
        const SizedBox(height: 10),
        const _SourceCard(
          icon: Icons.translate_rounded,
          title: 'Terjemahan Indonesia',
          body:
              'Edisi “Bahasa Indonesia” dari Tanzil (pembaruan 4 Juni 2010), penerjemah Kementerian Agama RI. Tersimpan offline tanpa perubahan; untuk penggunaan non-komersial.',
          url: 'https://tanzil.net/trans/',
        ),
        const SizedBox(height: 10),
        const _SourceCard(
          icon: Icons.graphic_eq_rounded,
          title: 'Murottal',
          body:
              'Mishary Rashid Alafasy, per ayat 128 kbps, di-streaming dari CDN Islamic Network (Al Quran Cloud). Hak cipta rekaman milik qari.',
          url: 'https://alquran.cloud/terms-and-conditions',
        ),
        const SizedBox(height: 26),
        const _SectionTitle('Pembaruan aplikasi'),
        const SizedBox(height: 10),
        const _AutoUpdateCard(),
        const SizedBox(height: 26),
        const _SectionTitle('Tentang aplikasi'),
        const SizedBox(height: 10),
        const _AboutCard(),
        // Konstanta `kDebugMode` membuat cabang ini (dan layar pratinjau yang
        // memanggil api.quran.com langsung) terbuang dari build rilis.
        if (kDebugMode) ...[
          const SizedBox(height: 26),
          const _SectionTitle('Debug'),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Pratinjau tajwid'),
              subtitle: const Text('Data langsung dari api.quran.com'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DebugTajweedPreviewScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Prototipe tiga layout baca'),
              subtitle: const Text('Card, mushaf 1 halaman, mushaf 2 halaman'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DebugReaderPrototypeScreen(),
                ),
              ),
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
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            value: _enabled,
            title: const Text('Unduh pembaruan otomatis'),
            subtitle: const Text(
              'Versi baru diunduh sendiri saat aplikasi dibuka, lalu pemasang '
              'Android terbuka. Konfirmasi pemasangan tetap dari Anda.',
            ),
            onChanged: (value) async {
              setState(() => _enabled = value);
              await SharedPreferencesService.setAutoUpdate(value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Izin pasang aplikasi'),
            subtitle: const Text(
              'Diperlukan sekali agar pembaruan bisa dipasang langsung dari '
              'aplikasi.',
            ),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => const ApkInstaller().openPermissionSettings(),
          ),
        ],
      ),
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
    final theme = Theme.of(context);
    final update = _update;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ruang Tilawah $appVersion',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            if (_status != null) ...[
              const SizedBox(height: 4),
              Text(_status!, style: theme.textTheme.bodySmall),
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
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.url,
  });
  final IconData icon;
  final String title;
  final String body;
  final String url;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: SacredTheme.gold.withValues(alpha: .28),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(body),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              semanticLabel: 'Buka sumber',
            ),
          ],
        ),
      ),
    ),
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

  @override
  Widget build(BuildContext context) {
    final service = AccountService.instance;
    final theme = Theme.of(context);
    final sync = service.sync;
    if (!service.available || sync == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Sinkronisasi cloud tidak tersedia di perangkat ini. Semua data '
            'tetap tersimpan secara lokal.',
            style: theme.textTheme.bodySmall,
          ),
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
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (account == null) ...[
                  const Text(
                    'Simpan progres baca dan bookmark',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Masuk agar data bisa dipakai di HP lain. Membaca tetap '
                    'bisa tanpa masuk; data di perangkat ini ikut diunggah.',
                    style: theme.textTheme.bodySmall,
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
                ] else ...[
                  Text(
                    account.name ?? account.email ?? 'Akun Google',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (account.email != null && account.name != null)
                    Text(
                      account.email!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    syncing
                        ? 'Menyinkronkan data'
                        : sync.message.value ?? _lastSyncLabel(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: sync.state.value == SyncState.failed
                          ? theme.colorScheme.error
                          : null,
                    ),
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
                      foregroundColor: theme.colorScheme.error,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: busy || syncing ? null : _confirmDelete,
                    child: const Text('Hapus akun & data cloud'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
  );
}
