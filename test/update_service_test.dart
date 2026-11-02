import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:masters/core/update_service.dart';

const _body =
    '{"app_id":"com.example.masters","latest_version_code":42,"latest_version_name":"1.2.3","min_supported_version_code":10,"apk_url":"http://mirror/app.apk","sha256":"abc","changelog":"changes","update_available":true,"force_update":false}';

void main() {
  test('primary endpoint is used by default', () async {
    final client = MockClient((req) async {
      expect(req.url.host, 'primary');
      return http.Response(_body, 200);
    });
    final service = UpdateService(
      client: client,
      primaryUrl: 'http://primary',
      currentVersionCode: 5,
      appId: 'com.example.masters',
    );
    final info = await service.checkForUpdate();
    expect(info.latestVersionCode, 42);
    expect(info.updateAvailable, isTrue);
  });

  test('mirror endpoint is used when mirrorOnly', () async {
    final client = MockClient((req) async {
      expect(req.url.host, 'mirror');
      return http.Response(_body, 200);
    });
    final service = UpdateService(
      client: client,
      primaryUrl: 'http://primary',
      mirrorUrl: 'http://mirror',
      currentVersionCode: 5,
      appId: 'com.example.masters',
    );
    final info = await service.checkForUpdate(mirrorOnly: true);
    expect(info.latestVersionCode, 42);
  });

  test('beta channel checks mirror first', () async {
    final client = MockClient((req) async {
      if (req.url.host == 'mirror') {
        return http.Response(_body, 200);
      }
      // Primary must not be reached.
      throw Exception('primary should not be called');
    });
    final service = UpdateService(
      client: client,
      primaryUrl: 'http://primary',
      mirrorUrl: 'http://mirror',
      channel: 'beta',
      currentVersionCode: 5,
      appId: 'com.example.masters',
    );
    final info = await service.checkForUpdate();
    expect(info.latestVersionCode, 42);
  });

  test('falls back to mirror when primary fails', () async {
    final client = MockClient((req) async {
      if (req.url.host == 'primary') {
        throw Exception('network down');
      }
      return http.Response(_body, 200);
    });
    final service = UpdateService(
      client: client,
      primaryUrl: 'http://primary',
      mirrorUrl: 'http://mirror',
      currentVersionCode: 5,
      appId: 'com.example.masters',
    );
    final info = await service.checkForUpdate();
    expect(info.latestVersionCode, 42);
  });

  test('falls back to primary when mirror fails in beta mode', () async {
    const primaryBody =
        '{"app_id":"com.example.masters","latest_version_code":7,"latest_version_name":"1.0.7","min_supported_version_code":1,"apk_url":"","sha256":"","changelog":"","update_available":false,"force_update":false}';
    final client = MockClient((req) async {
      if (req.url.host == 'mirror') {
        throw Exception('mirror down');
      }
      return http.Response(primaryBody, 200);
    });
    final service = UpdateService(
      client: client,
      primaryUrl: 'http://primary',
      mirrorUrl: 'http://mirror',
      channel: 'beta',
      currentVersionCode: 5,
      appId: 'com.example.masters',
    );
    final info = await service.checkForUpdate();
    expect(info.latestVersionCode, 7);
    expect(info.updateAvailable, isFalse);
  });

  test('throws FormatException on invalid JSON', () async {
    final client = MockClient((req) async {
      return http.Response('not-json', 200);
    });
    final service = UpdateService(
      client: client,
      primaryUrl: 'http://primary',
      currentVersionCode: 5,
      appId: 'com.example.masters',
    );
    await expectLater(
      service.checkForUpdate(),
      throwsA(isA<FormatException>()),
    );
  });
}
