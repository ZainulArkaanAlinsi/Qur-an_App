import 'dart:math' as math;

/// Calculates the initial great-circle bearing to the Ka'bah from a coordinate.
///
/// The result is degrees clockwise from true north, in the range 0–360.
class QiblaService {
  const QiblaService._();

  static const double kaabaLatitude = 21.422487;
  static const double kaabaLongitude = 39.826206;

  static double bearingFrom({
    required double latitude,
    required double longitude,
  }) {
    final fromLatitude = _toRadians(latitude);
    final fromLongitude = _toRadians(longitude);
    final toLatitude = _toRadians(kaabaLatitude);
    final toLongitude = _toRadians(kaabaLongitude);
    final deltaLongitude = toLongitude - fromLongitude;

    final y = math.sin(deltaLongitude) * math.cos(toLatitude);
    final x = math.cos(fromLatitude) * math.sin(toLatitude) -
        math.sin(fromLatitude) *
            math.cos(toLatitude) *
            math.cos(deltaLongitude);
    return (_toDegrees(math.atan2(y, x)) + 360) % 360;
  }

  static double shortestAngle(double from, double to) {
    final difference = (to - from + 540) % 360 - 180;
    return difference.abs();
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
  static double _toDegrees(double radians) => radians * 180 / math.pi;
}
