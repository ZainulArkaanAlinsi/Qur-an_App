import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/core/app_version.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/features/onboarding/presentation/brand_art.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Satu sumber data beserta versi, lisensi, dan tautannya.
@immutable
class DataSource {
  const DataSource({
    required this.name,
    required this.use,
    required this.license,
    required this.url,
    this.version,
  });

  final String name;
  final String use;
  final String license;
  final String url;
  final String? version;
}

/// Semua sumber yang dipakai aplikasi (API-Qur'an-gratis.md, "Kombinasi
/// untuk Qur'an App"). Teks ayat & terjemahan ditampilkan tanpa diubah.
abstract final class DataSources {
  static const text = [
    DataSource(
      name: 'Tanzil Quran Text',
      use: 'Teks Arab (Uthmani), bawaan tanpa internet',
      version: 'Uthmani 1.0.2',
      license: 'CC BY 3.0 · teks persis, tanpa perubahan',
      url: 'https://tanzil.net/download/',
    ),
    DataSource(
      name: 'cpfair/quran-tajweed',
      use:
          'Anotasi warna tajwid, sinkron dengan Tanzil; alat bantu memilih '
          'contoh ayat materi tajwid',
      license: 'CC BY 4.0 · wajib atribusi',
      url: 'https://github.com/cpfair/quran-tajweed',
    ),
  ];

  static const translation = [
    DataSource(
      name: 'Terjemahan Kementerian Agama RI',
      use: 'Bahasa Indonesia, bawaan tanpa internet (lewat Tanzil)',
      version: '4 Juni 2010',
      license: 'Non-komersial · teks persis, tanpa perubahan',
      url: 'https://tanzil.net/trans/',
    ),
    DataSource(
      name: 'QuranEnc',
      use: 'Terjemahan dunia yang diunduh (sumber utama)',
      license: 'Tanpa kunci API · tidak boleh diubah · sebut sumber & versi',
      url: 'https://quranenc.com',
    ),
    DataSource(
      name: 'fawazahmed0/quran-api',
      use: 'Terjemahan cadangan bila QuranEnc gagal',
      license: 'Unlicense · hak cipta terjemahan milik penerjemahnya',
      url: 'https://github.com/fawazahmed0/quran-api',
    ),
  ];

  static const audio = [
    DataSource(
      name: 'Islamic Network CDN (alquran.cloud)',
      use: 'Murottal per ayat (utama) — hafalan dan ulang ayat',
      license: 'Sebut sumber · hak cipta rekaman milik qari',
      url: 'https://alquran.cloud/cdn',
    ),
    DataSource(
      name: 'MP3Quran',
      use: 'Murottal per surah (utama)',
      license: 'Sebut sumber · hak cipta rekaman milik qari',
      url: 'https://mp3quran.net',
    ),
    DataSource(
      name: 'equran.id',
      use: 'Murottal cadangan per ayat dan per surah',
      version: 'API v2',
      license: 'Sebut sumber · hak cipta rekaman milik qari',
      url: 'https://equran.id',
    ),
  ];

  static const prayer = [
    DataSource(
      name: 'AlAdhan',
      use:
          'Waktu salat, metode ${PrayerService.methodId} '
          '(${PrayerService.methodName})',
      license: 'Gratis, tanpa kunci API',
      url: 'https://aladhan.com',
    ),
  ];
}

/// Atribusi qari yang sedang dipakai, sesuai bitrate yang benar-benar
/// diputar.
DataSource _selectedReciter() {
  final reciter = SharedPreferencesService.getReciter();
  return DataSource(
    name: 'Qari pilihan: ${reciter.displayName}',
    use: 'Per ayat ${reciter.bitrate ?? 128} kbps',
    license: reciter.attribution,
    url: 'https://alquran.cloud/terms-and-conditions',
  );
}

/// Sumber & Lisensi (tab Saya): nama sumber, versi, lisensi, tautan, dan
/// terjemahan yang tersimpan di perangkat beserta versinya.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key, this.library});

  /// Hanya untuk tes.
  @visibleForTesting
  final OnlineTranslations? library;

  Future<void> _open(BuildContext context, String url) async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      ok = false;
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tautan tidak dapat dibuka: $url')),
      );
    }
  }

  void _licenses(BuildContext context) => showLicensePage(
    context: context,
    applicationName: 'MyQuran',
    applicationVersion: appVersion,
    applicationIcon: Padding(
      padding: const EdgeInsets.all(8),
      child: Image.asset(BrandAssets.secondary, width: 56, height: 56),
    ),
  );

  Widget _group(BuildContext context, String label, List<DataSource> items) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: GroupedList(
          label: label,
          children: [
            for (final source in items)
              ListRow(
                title: source.name,
                subtitle: [
                  source.use,
                  ?source.version,
                  source.license,
                ].join(' · '),
                chevron: true,
                semanticsLabel: '${source.name}. ${source.license}',
                onTap: () => _open(context, source.url),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final saved = (library ?? TranslationRepository.instance.online).saved();
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const ScreenHeader(
              title: 'Sumber & lisensi',
              subtitle: 'Teks ayat dan terjemahan tampil tanpa diubah',
              backLabel: 'Saya',
            ),
            const _BrandNote(),
            _group(context, 'Teks & tajwid', DataSources.text),
            _group(context, 'Terjemahan', DataSources.translation),
            FutureBuilder<List<SavedTranslation>>(
              future: saved,
              builder: (context, snapshot) {
                final items = snapshot.data ?? const [];
                if (items.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: GroupedList(
                    label: 'Terjemahan tersimpan',
                    children: [
                      for (final item in items)
                        ListRow(
                          title: item.edition.title,
                          subtitle: [
                            item.edition.provider.label,
                            if (item.edition.version != null)
                              'versi ${item.edition.version}',
                            'disimpan ${item.savedAt.toLocal().day}/'
                                '${item.savedAt.toLocal().month}/'
                                '${item.savedAt.toLocal().year}',
                          ].join(' · '),
                          chevron: true,
                          onTap: () =>
                              _open(context, item.edition.provider.url),
                        ),
                    ],
                  ),
                );
              },
            ),
            _group(context, 'Audio murottal', [
              _selectedReciter(),
              ...DataSources.audio,
            ]),
            _group(context, 'Waktu salat', DataSources.prayer),
            // Teks lisensi SIL OFL 1.1 keempat font ikut dibundel dan
            // tampil di halaman lisensi (docs/design/v3/LISENSI_ASET.md §2).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: GroupedList(
                label: 'Font & perangkat lunak',
                children: [
                  ListRow(
                    title: 'Font aplikasi',
                    subtitle:
                        'Plus Jakarta Sans, EB Garamond, Amiri, Amiri Quran · '
                        'SIL OFL 1.1',
                    chevron: true,
                    onTap: () => _licenses(context),
                  ),
                  ListRow(
                    title: 'Lisensi perangkat lunak',
                    subtitle: 'Flutter dan paket sumber terbuka yang dipakai',
                    chevron: true,
                    onTap: () => _licenses(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 14, 32, 0),
              child: Text(
                'Tashih LPMQ (PMA 44/2016) adalah urusan terpisah dan tidak '
                'gugur karena memakai sumber gratis.',
                style: SacredText.cardNote.copyWith(color: tokens.sec),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo sekunder dan asal tulisan Arab di logo (docs/design/v3/DESIGN.md §2).
class _BrandNote extends StatelessWidget {
  const _BrandNote();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(
        children: [
          Image.asset(
            BrandAssets.secondary,
            width: 48,
            height: 48,
            semanticLabel: 'Logo MyQuran',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Logo MyQuran milik pemilik aplikasi. Tulisan Arab di logo '
              'dirender dengan font Amiri (SIL OFL 1.1).',
              style: SacredText.cardNote.copyWith(color: tokens.sec),
            ),
          ),
        ],
      ),
    );
  }
}
