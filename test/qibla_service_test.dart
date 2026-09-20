import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/services/qibla_service.dart';

void main() {
  group('QiblaService', () {
    test('returns north when Ka’bah is directly north', () {
      final bearing = QiblaService.bearingFrom(
        latitude: 20.0,
        longitude: QiblaService.kaabaLongitude,
      );

      expect(bearing, closeTo(0, 0.01));
    });

    test('returns a stable Jakarta bearing', () {
      final bearing = QiblaService.bearingFrom(
        latitude: -6.2088,
        longitude: 106.8456,
      );

      expect(bearing, closeTo(295.1, 1));
    });

    test('finds the smallest angular difference across north', () {
      expect(QiblaService.shortestAngle(358, 2), 4);
      expect(QiblaService.shortestAngle(20, 340), 40);
    });
  });
}
