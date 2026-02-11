import 'package:flutter_test/flutter_test.dart';
import 'package:lan_screen_share/models/stream_settings.dart';

void main() {
  test('default settings are valid', () {
    const defaults = StreamSettings.defaults;
    expect(defaults.bitrateKbps, 6000);
    expect(defaults.resolutionPercent, 100);
    expect(defaults.crop.isValid, isTrue);
  });

  test('crop validity fails when opposite edges exceed limit', () {
    const invalidCrop = EdgeCrop(leftPercent: 50, rightPercent: 50);
    expect(invalidCrop.isValid, isFalse);
  });
}
