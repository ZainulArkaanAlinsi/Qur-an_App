import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';

/// Rentang teks polos yang ditandai satu hukum tajwid oleh provider.
///
/// [start]/[end] adalah offset UTF-16 pada [TajweedVerse.text]. Rentang dapat
/// bersarang (mis. `slnt` di dalam `madda_obligatory`); [depth] 0 = terluar.
class TajweedSegment {
  const TajweedSegment({
    required this.start,
    required this.end,
    required this.rule,
    required this.depth,
  });

  final int start;
  final int end;
  final TajweedRule rule;
  final int depth;
}

/// Potongan teks tanpa tumpang tindih untuk dirender; [rule] adalah hukum
/// terdalam yang menutupinya, atau `null` bila tidak bertanda.
class TajweedRun {
  const TajweedRun(this.start, this.end, this.rule);

  final int start;
  final int end;
  final TajweedRule? rule;
}

class TajweedVerse {
  const TajweedVerse({
    required this.verseKey,
    required this.text,
    required this.endMarker,
    required this.segments,
    required this.rejectedClasses,
  });

  final String verseKey;

  /// Teks ayat persis seperti markup provider tanpa tag dan tanpa penanda
  /// akhir ayat. Tidak ada normalisasi Unicode maupun trim.
  final String text;

  /// Isi `<span class=end>` (nomor ayat), atau `null` bila tidak ada.
  final String? endMarker;

  final List<TajweedSegment> segments;

  /// Class di luar whitelist. Teksnya tetap tampil, tetapi tanpa warna.
  final Set<String> rejectedClasses;

  /// Jumlah kemunculan per hukum untuk chip ringkas di kartu ayat.
  Map<TajweedRule, int> get ruleCounts {
    final counts = <TajweedRule, int>{};
    for (final segment in segments) {
      counts[segment.rule] = (counts[segment.rule] ?? 0) + 1;
    }
    return counts;
  }

  List<TajweedRun> get runs {
    final boundaries = <int>{0, text.length};
    for (final segment in segments) {
      boundaries
        ..add(segment.start)
        ..add(segment.end);
    }
    final sorted = boundaries.toList()..sort();
    final runs = <TajweedRun>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final start = sorted[i];
      final end = sorted[i + 1];
      if (start == end) continue;
      TajweedSegment? innermost;
      for (final segment in segments) {
        if (segment.start <= start &&
            segment.end >= end &&
            (innermost == null || segment.depth > innermost.depth)) {
          innermost = segment;
        }
      }
      final rule = innermost?.rule;
      if (runs.isNotEmpty && runs.last.rule == rule) {
        runs[runs.length - 1] = TajweedRun(runs.last.start, end, rule);
      } else {
        runs.add(TajweedRun(start, end, rule));
      }
    }
    return runs;
  }
}

/// Parser ketat untuk `text_uthmani_tajweed`.
///
/// Hanya menerima tag `<tajweed class=…>` dan `<span class=end>`. Tag lain,
/// tag tidak seimbang, atau teks setelah penanda akhir ayat dianggap data
/// rusak dan melempar [FormatException] agar teks tidak ditampilkan dalam
/// bentuk tebakan.
class TajweedMarkupParser {
  const TajweedMarkupParser();

  static final RegExp _tag = RegExp(
    r'''<(/?)(tajweed|span)(?:\s+class=(?:"([^"]*)"|'([^']*)'|([A-Za-z0-9_-]+)))?\s*>''',
  );

  TajweedVerse parse(String verseKey, String markup) {
    final text = StringBuffer();
    final marker = StringBuffer();
    final segments = <TajweedSegment>[];
    final rejected = <String>{};
    // Tag terbuka: (nama, hukum atau null, offset awal).
    final stack = <(String, TajweedRule?, int)>[];
    var inEndSpan = false;
    var endSpanClosed = false;
    var cursor = 0;

    void appendText(String chunk) {
      if (chunk.isEmpty) return;
      if (chunk.contains('<') || chunk.contains('>')) {
        throw FormatException('Tag tidak dikenal pada $verseKey', markup);
      }
      if (inEndSpan) {
        marker.write(chunk);
      } else if (endSpanClosed) {
        if (chunk.trim().isNotEmpty) {
          throw FormatException('Teks setelah akhir ayat $verseKey', markup);
        }
      } else {
        text.write(chunk);
      }
    }

    for (final match in _tag.allMatches(markup)) {
      appendText(markup.substring(cursor, match.start));
      cursor = match.end;
      final closing = match.group(1) == '/';
      final name = match.group(2)!;
      final cls = match.group(3) ?? match.group(4) ?? match.group(5);

      if (closing) {
        if (stack.isEmpty || stack.last.$1 != name) {
          throw FormatException('Tag </$name> tidak seimbang di $verseKey');
        }
        final (_, rule, start) = stack.removeLast();
        if (name == 'span') {
          inEndSpan = false;
          endSpanClosed = true;
        } else if (rule != null && text.length > start) {
          segments.add(TajweedSegment(
            start: start,
            end: text.length,
            rule: rule,
            depth: stack.where((open) => open.$1 == 'tajweed').length,
          ));
        }
        continue;
      }

      if (name == 'span') {
        if (cls != 'end' || stack.isNotEmpty || endSpanClosed) {
          throw FormatException('span tak terduga di $verseKey', markup);
        }
        inEndSpan = true;
        stack.add((name, null, text.length));
        continue;
      }

      if (inEndSpan || endSpanClosed) {
        throw FormatException('tajweed di luar teks ayat $verseKey', markup);
      }
      final rule = cls == null ? null : TajweedRule.fromProviderClass(cls);
      if (rule == null) rejected.add(cls ?? '');
      stack.add((name, rule, text.length));
    }
    appendText(markup.substring(cursor));

    if (stack.isNotEmpty) {
      throw FormatException('Tag <${stack.last.$1}> tidak ditutup di $verseKey');
    }
    segments.sort((a, b) =>
        a.start != b.start ? a.start.compareTo(b.start) : a.depth - b.depth);

    return TajweedVerse(
      verseKey: verseKey,
      text: text.toString(),
      endMarker: marker.isEmpty ? null : marker.toString(),
      segments: List.unmodifiable(segments),
      rejectedClasses: Set.unmodifiable(rejected),
    );
  }
}
