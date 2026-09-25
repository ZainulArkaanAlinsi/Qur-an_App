import 'package:integration_test/integration_test_driver.dart';

/// Driver tes kinerja kaca. Menulis ringkasan tiap skenario ke
/// `build/glass_perf_<skenario>_<tingkat>.json`, lalu salin angkanya ke
/// docs/design/v4-liquid-glass/HASIL_KINERJA.md.
///
///   flutter drive --profile --driver=test_driver/perf_driver.dart \
///     --target=integration_test/glass_perf_test.dart
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    for (final entry in data.entries) {
      await writeResponseData(
        entry.value as Map<String, dynamic>,
        testOutputFilename: 'glass_perf_${entry.key}',
      );
    }
  },
);
