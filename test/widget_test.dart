import 'package:flutter_test/flutter_test.dart';
import 'package:confident_cam/core/config/app_config.dart';

void main() {
  test('AppConfig has expected app metadata', () {
    expect(AppConfig.appName, 'Confident Creator');
    expect(AppConfig.appVersion, '1.2.2');
  });
}
