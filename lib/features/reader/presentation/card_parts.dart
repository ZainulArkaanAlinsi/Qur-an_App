import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/online_translations.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_markup_parser.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_palette.dart';

export 'package:quran_app_2025/data/basmalah.dart';

/// Potongan teks ayat berwarna tajwid. Teksnya dipotong per rentang tanpa
/// diubah; bagian tanpa hukum memakai [base]. [from]/[to] membatasi ke
/// sebagian teks (mis. basmalah dan ayat 1 ditampilkan terpisah).
List<InlineSpan> tajweedSpans(
  TajweedVerse verse, {
  required TajweedPalette palette,
  required Brightness brightness,
  required Color base,
  int from = 0,
  int? to,
  void Function(TajweedRule rule)? onTap,
  List<TapGestureRecognizer>? recognizers,
}) {
  final end = to ?? verse.text.length;
  // Huruf berwarna bisa diketuk untuk melihat hukumnya. Recognizer dibuat
  // di sini dan dikumpulkan ke [recognizers] supaya pemanggil membuangnya.
  TapGestureRecognizer? tapFor(TajweedRule? rule) {
    if (rule == null || onTap == null) return null;
    final recognizer = TapGestureRecognizer()..onTap = () => onTap(rule);
    recognizers?.add(recognizer);
    return recognizer;
  }

  return [
    for (final run in verse.runs)
      if (run.end > from && run.start < end)
        TextSpan(
          text: verse.text.substring(
            run.start < from ? from : run.start,
            run.end > end ? end : run.end,
          ),
          style: TextStyle(
            color: run.rule == null
                ? base
                : palette.colorFor(run.rule!, brightness),
          ),
          recognizer: tapFor(run.rule),
        ),
  ];
}

/// Nama bahasa dalam aksaranya sendiri untuk kode ISO QuranEnc; nama bahasa
/// fawazahmed0 (sudah berupa nama) dipakai apa adanya.
const _languageNames = {
  'id': 'Bahasa Indonesia',
  'en': 'English',
  'ar': 'العربية',
  'ur': 'اردو',
  'fr': 'Français',
  'de': 'Deutsch',
  'es': 'Español',
  'pt': 'Português',
  'it': 'Italiano',
  'nl': 'Nederlands',
  'tr': 'Türkçe',
  'ms': 'Bahasa Melayu',
  'bn': 'বাংলা',
  'ru': 'Русский',
  'zh': '中文',
  'ja': '日本語',
  'ko': '한국어',
  'fa': 'فارسی',
  'hi': 'हिन्दी',
  'ta': 'தமிழ்',
  'th': 'ไทย',
  'vi': 'Tiếng Việt',
  'sw': 'Kiswahili',
  'ha': 'Hausa',
  'so': 'Soomaali',
  'am': 'አማርኛ',
  'ps': 'پښتو',
  'ku': 'Kurdî',
  'bs': 'Bosanski',
  'sq': 'Shqip',
  'uz': 'Oʻzbek',
  'az': 'Azərbaycan',
  'tl': 'Tagalog',
  'jv': 'Basa Jawa',
  'su': 'Basa Sunda',
};

String translationLanguage(TranslationEdition edition) =>
    _languageNames[edition.language.toLowerCase()] ?? edition.language;

/// Nama penerjemah dari judul sumber. QuranEnc menulis "Bahasa - Penerjemah";
/// bagian sesudah " - " pertama adalah penerjemahnya. Judul tanpa pemisah
/// dipakai utuh.
String translatorOf(TranslationEdition edition) {
  final title = edition.title.trim();
  final dash = title.indexOf(' - ');
  return dash < 0 ? title : title.substring(dash + 3).trim();
}

/// Kode dua huruf di depan terjemahan ("EN").
String translationCode(TranslationEdition edition) {
  final language = edition.language.trim();
  if (language.length <= 3) return language.toUpperCase();
  return language.substring(0, 2).toUpperCase();
}

/// Terjemahan kedua yang disarankan saat belum memilih: Saheeh International
/// dari QuranEnc.
const suggestedSecondTranslation = TranslationEdition(
  provider: TranslationProvider.quranEnc,
  id: 'english_saheeh',
  title: 'Saheeh International',
  language: 'en',
);

/// Chip di bawah nav kartu ayat: bahasa aktif dan warna tajwid.
class ReaderChips extends StatelessWidget {
  const ReaderChips({
    super.key,
    required this.languageLabel,
    required this.tajweed,
    required this.onLanguage,
    required this.onTajweed,
  });

  final String languageLabel;
  final bool tajweed;
  final VoidCallback onLanguage;
  final VoidCallback onTajweed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Chip(
            label: languageLabel,
            icon: SacredIcons.translate,
            background: tokens.cta,
            foreground: tokens.ctaInk,
            trailing: SacredIcons.chevronDown,
            semantics: 'Terjemahan: $languageLabel. Ketuk untuk mengganti.',
            onTap: onLanguage,
          ),
          _Chip(
            label: 'Tajwid',
            icon: SacredIcons.palette,
            background: tajweed ? tokens.primarySoft : tokens.fill,
            foreground: tajweed ? tokens.primaryText : tokens.ink,
            semantics: tajweed ? 'Warna tajwid menyala' : 'Warna tajwid mati',
            toggled: tajweed,
            onTap: onTajweed,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.semantics,
    required this.onTap,
    this.trailing,
    this.toggled,
  });

  final String label;
  final List<String> icon;
  final Color background;
  final Color foreground;
  final String semantics;
  final VoidCallback onTap;
  final List<String>? trailing;
  final bool? toggled;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: toggled,
    excludeSemantics: true,
    label: semantics,
    child: Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LineIcon(icon, color: foreground, size: 18, strokeWidth: 2),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: SacredText.buttonSmall.copyWith(color: foreground),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                LineIcon(
                  trailing!,
                  color: foreground,
                  size: 16,
                  strokeWidth: 2.4,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Petunjuk untuk pembaca awam: huruf berwarna bisa diketuk.
class TajweedHint extends StatelessWidget {
  const TajweedHint({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
      child: Row(
        children: [
          LineIcon(SacredIcons.info, color: tokens.primaryText, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ketuk huruf berwarna untuk melihat artinya.',
              style: SacredText.infoBox.copyWith(color: tokens.ink),
            ),
          ),
          Semantics(
            button: true,
            excludeSemantics: true,
            label: 'Tutup petunjuk',
            child: InkResponse(
              onTap: onClose,
              radius: 22,
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: LineIcon(
                    SacredIcons.close,
                    color: tokens.sec,
                    size: 16,
                    strokeWidth: 2.2,
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

/// Terjemahan berlabel kode bahasa: "ID  Katakanlah…".
class LabeledTranslation extends StatelessWidget {
  const LabeledTranslation({
    super.key,
    required this.code,
    required this.text,
    required this.size,
    this.rtl = false,
  });

  final String code;
  final String text;
  final double size;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              code,
              style: SacredText.pill.copyWith(color: tokens.goldText),
            ),
          ),
        ),
        Expanded(
          child: Text(
            // Verbatim dari dataset: tanpa trim atau penggantian.
            text,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            style: SacredText.body.copyWith(
              color: tokens.ink,
              fontSize: size,
              height: 22 / 15,
            ),
          ),
        ),
      ],
    );
  }
}

/// Keadaan unduhan terjemahan kedua.
enum DownloadState { idle, downloading, failed }

/// Baris "EN English · Saheeh International  [Unduh]" untuk bahasa kedua yang
/// belum tersimpan di perangkat.
class TranslationDownloadRow extends StatelessWidget {
  const TranslationDownloadRow({
    super.key,
    required this.edition,
    required this.state,
    required this.onDownload,
  });

  final TranslationEdition edition;
  final DownloadState state;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final title = '${translationLanguage(edition)} · ${translatorOf(edition)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: tokens.fill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              translationCode(edition),
              style: SacredText.pill.copyWith(color: tokens.sec),
            ),
          ),
          Expanded(
            child: Text(
              state == DownloadState.failed ? 'Gagal mengunduh $title' : title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SacredText.rowSubtitle.copyWith(color: tokens.sec),
            ),
          ),
          const SizedBox(width: 8),
          switch (state) {
            DownloadState.downloading => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Mengunduh…',
                style: SacredText.pill.copyWith(color: tokens.sec),
              ),
            ),
            _ => SacredButton(
              label: state == DownloadState.failed ? 'Coba lagi' : 'Unduh',
              tone: ButtonTone.soft,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: SacredText.buttonSmall,
              onTap: onDownload,
            ),
          },
        ],
      ),
    );
  }
}
