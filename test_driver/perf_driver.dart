// Driver tes kinerja kaca (integration_test/glass_perf_test.dart). Ringkasan
// frame tiap skenario (watchPerformance) ditulis ke build/glass_perf.json.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    await writeResponseData(data, testOutputFilename: 'glass_perf');
  },
);
