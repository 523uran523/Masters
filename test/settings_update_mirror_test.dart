import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masters/state/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('update mirror defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsController.load();
    expect(settings.updateMirrorEnabled, isFalse);
    expect(settings.updateMirrorUrl, '');
    expect(settings.updateChannel, 'stable');
  });

  test('update mirror keys persist', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await SettingsController.load();
    await first.setUpdateMirrorEnabled(true);
    await first.setUpdateMirrorUrl('http://10.0.0.1:8080');
    await first.setUpdateChannel('beta');

    final second = await SettingsController.load();
    expect(second.updateMirrorEnabled, isTrue);
    expect(second.updateMirrorUrl, 'http://10.0.0.1:8080');
    expect(second.updateChannel, 'beta');
  });

  test('invalid channel ignored', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsController.load();
    await settings.setUpdateChannel('gamma');
    expect(settings.updateChannel, 'stable');
  });
}
