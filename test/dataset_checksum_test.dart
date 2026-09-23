import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checksum dataset Qur'an yang dibundel, persis seperti tercatat di
/// docs/DATASET_ATTRIBUTION.md. Teks harus verbatim (lisensi Tanzil), jadi
/// perubahan satu byte pun — termasuk normalisasi akhir baris oleh Git
/// (lihat `.gitattributes`) — harus menggagalkan build.
const _expected = {
  'assets/quran/raw/tanzil_uthmani_v1.0.2.txt': (
    sha256: '3bcdcf93e06fd7b932e023916a8c4b4046bfe8346ed1876fb23ff76884cc9169',
    bytes: 1354097,
  ),
  'assets/quran/raw/quran-data.xml': (
    sha256: '8867c1d88191472adec9db694b3cd9f135b1a2ef580574d32cf888dcb22c5c7a',
    bytes: 77234,
  ),
  'assets/quran/raw/tanzil_id.indonesian_2010-06-04.txt': (
    sha256: '70428e875c50c3c42d3829654d2bd386e146f0fa68cc20c34fdd4ea3b53e21a8',
    bytes: 1159449,
  ),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final MapEntry(key: asset, value: expected) in _expected.entries) {
    test('aset yang dibundel identik byte-per-byte: $asset', () async {
      // Lewat rootBundle: yang diuji adalah isi aset yang ikut ke aplikasi.
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      expect(bytes.length, expected.bytes);
      expect(sha256.convert(bytes).toString(), expected.sha256);
    });
  }

  test('checksum di dokumen atribusi sama dengan checksum yang diuji', () {
    final doc = File(
      'docs/DATASET_ATTRIBUTION.md',
    ).readAsStringSync().toLowerCase();
    for (final MapEntry(key: asset, value: expected) in _expected.entries) {
      expect(doc, contains(expected.sha256), reason: asset);
    }
  });

  test('pubspec membundel semua aset yang punya checksum', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final asset in _expected.keys) {
      expect(pubspec, contains('- $asset'), reason: asset);
    }
  });
}
