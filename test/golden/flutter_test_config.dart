import 'dart:async';

import 'golden_harness.dart';

/// Dijalankan sekali untuk semua tes di test/golden/: memuat font asli
/// supaya golden tidak tampil sebagai kotak Ahem.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  await testMain();
}
