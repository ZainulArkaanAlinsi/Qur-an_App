import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/core/app_version.dart';

void main() {
  test('appVersion sama dengan versi di pubspec.yaml', () {
    final line = File(
      'pubspec.yaml',
    ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final version = line.split(':').last.trim().split('+').first;
    expect(appVersion, version);
  });
}
