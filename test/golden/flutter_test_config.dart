import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// Dijalankan sekali untuk semua tes di test/golden/: memuat font asli
/// supaya golden tidak tampil sebagai kotak Ahem.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  if (storeShots) goldenFileComparator = _StoreShotComparator();
  await testMain();
}

/// Mode STORE_SHOTS: tulis gambar ke build/store_shots/ lalu kembalikan
/// debugDisableShadows sebelum tes selesai (invarian flutter_test).
class _StoreShotComparator extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    await update(golden, imageBytes);
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    final file = File('build/store_shots/${golden.pathSegments.last}');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(imageBytes);
    debugDisableShadows = true;
  }
}
