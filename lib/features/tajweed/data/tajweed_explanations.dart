import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';

/// Penjelasan cara membaca satu hukum tajwid untuk orang awam. Isinya ditulis
/// dan direview guru tajwid di assets/learn/tajweed_explanations.json, bukan
/// oleh aplikasi (docs/RELIGIOUS_CONTENT_GOVERNANCE.md).
@immutable
class TajweedExplanation {
  const TajweedExplanation({
    required this.rule,
    required this.status,
    this.howToRead,
    this.source,
    this.reviewers = const [],
    this.reviewedAt,
  });

  factory TajweedExplanation.fromJson(
    TajweedRule rule,
    Map<String, dynamic> json,
  ) => TajweedExplanation(
    rule: rule,
    howToRead: json['howToRead'] as String?,
    source: json['source'] as String?,
    reviewers: [
      for (final name in json['reviewers'] as List? ?? const []) '$name',
    ],
    status:
        ContentReviewStatus.values
            .where((s) => s.name == json['reviewStatus'])
            .firstOrNull ??
        ContentReviewStatus.draft,
    reviewedAt: DateTime.tryParse('${json['reviewedAt']}'),
  );

  final TajweedRule rule;
  final String? howToRead;
  final String? source;
  final List<String> reviewers;
  final ContentReviewStatus status;
  final DateTime? reviewedAt;

  bool get _hasText => howToRead != null && howToRead!.trim().isNotEmpty;

  /// Boleh tampil di build rilis: sudah terbit dan disetujui minimal dua
  /// reviewer (konten tajwid).
  bool get publishable =>
      _hasText &&
      status == ContentReviewStatus.published &&
      reviewers.length >= 2;

  /// Boleh tampil di build ini. Build debug boleh menampilkan draf yang
  /// sudah ada teksnya, dengan label draf.
  bool visible({bool debug = kDebugMode}) => publishable || (debug && _hasText);
}

/// Memuat penjelasan dari aset. Gagal memuat berarti tidak ada penjelasan,
/// bukan galat yang menghentikan pembaca.
class TajweedExplanations {
  TajweedExplanations({Future<String> Function()? loadAsset})
    : _loadAsset = loadAsset ?? (() => rootBundle.loadString(_asset));

  static final instance = TajweedExplanations();
  static const _asset = 'assets/learn/tajweed_explanations.json';

  final Future<String> Function() _loadAsset;
  Future<Map<TajweedRule, TajweedExplanation>>? _cache;

  Future<Map<TajweedRule, TajweedExplanation>> load() => _cache ??= () async {
    try {
      final root = jsonDecode(await _loadAsset()) as Map<String, dynamic>;
      return <TajweedRule, TajweedExplanation>{
        for (final item in (root['rules'] as List).cast<Map<String, dynamic>>())
          if (TajweedRule.values
                  .where((r) => r.name == item['rule'])
                  .firstOrNull
              case final rule?)
            rule: TajweedExplanation.fromJson(rule, item),
      };
    } on Object {
      return const <TajweedRule, TajweedExplanation>{};
    }
  }();
}
