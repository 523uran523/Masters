import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.appId,
    required this.currentVersionCode,
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.minSupportedVersionCode,
    required this.apkUrl,
    required this.sha256,
    required this.changelog,
    required this.updateAvailable,
    required this.forceUpdate,
  });

  final String appId;
  final int currentVersionCode;
  final int latestVersionCode;
  final String latestVersionName;
  final int minSupportedVersionCode;
  final String apkUrl;
  final String sha256;
  final String changelog;
  final bool updateAvailable;
  final bool forceUpdate;
}

class UpdateService {
  static const base = 'https://kzvk.212-19-134-251.sslip.io:8443';

  final http.Client _client;
  final String primaryUrl;
  String mirrorUrl;
  bool isMirrorEnabled;
  String channel;
  final String? _appIdOverride;
  final int? _currentVersionCodeOverride;

  UpdateService({
    http.Client? client,
    http.Client? httpClient,
    String? primaryUrl,
    String? mirrorUrl,
    this.isMirrorEnabled = false,
    this.channel = 'stable',
    String? appId,
    int? currentVersionCode,
  }) : _client = client ?? httpClient ?? http.Client(),
       primaryUrl = primaryUrl ?? base,
       mirrorUrl = mirrorUrl ?? '',
       _appIdOverride = appId,
       _currentVersionCodeOverride = currentVersionCode;

  bool _isValidUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<int> _currentVersionCode() async {
    if (_currentVersionCodeOverride != null)
      return _currentVersionCodeOverride!;
    try {
      final info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<String> _appId() async {
    if (_appIdOverride != null && _appIdOverride!.isNotEmpty) {
      return _appIdOverride!;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.packageName.isNotEmpty) return info.packageName;
    } catch (_) {}
    return 'masters';
  }

  Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) return info.version;
    } catch (_) {}
    return '';
  }

  Future<UpdateInfo> _checkAt(String baseUrl) async {
    final currentCode = await _currentVersionCode();
    final packageName = await _appId();
    final response = await _client
        .get(
          Uri.parse(
            '$baseUrl/api/updates/check?app_id=${Uri.encodeQueryComponent(packageName)}&version_code=$currentCode',
          ),
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw Exception('Сервер обновлений недоступен (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Некорректный ответ сервера обновлений.');
    }
    final data = decoded;
    final latest =
        (data['latest_version_code'] as num?)?.toInt() ?? currentCode;
    final minSupported =
        (data['min_supported_version_code'] as num?)?.toInt() ?? 1;
    final force =
        (data['force_update'] as bool?) ?? (currentCode < minSupported);
    final available =
        (data['update_available'] as bool?) ?? currentCode < latest;
    var latestName = data['latest_version_name']?.toString();
    if (latestName == null || latestName.isEmpty) {
      latestName = await _appVersion();
    }
    return UpdateInfo(
      appId: data['app_id']?.toString() ?? packageName,
      currentVersionCode: currentCode,
      latestVersionCode: latest,
      latestVersionName: latestName,
      minSupportedVersionCode: minSupported,
      apkUrl: data['apk_url']?.toString() ?? '',
      sha256: data['sha256']?.toString() ?? '',
      changelog: data['changelog']?.toString() ?? '',
      updateAvailable: available,
      forceUpdate: force,
    );
  }

  Future<UpdateInfo> checkForUpdate({bool mirrorOnly = false}) async {
    final preferMirror = mirrorOnly || channel == 'beta';
    final mirrorValid = _isValidUrl(mirrorUrl);
    final targets = <String>[];
    if (preferMirror) {
      if (mirrorValid) targets.add(mirrorUrl.trim());
      targets.add(primaryUrl);
    } else {
      targets.add(primaryUrl);
      if (mirrorValid) targets.add(mirrorUrl.trim());
    }
    final seen = <String>{};
    final unique = <String>[];
    for (final t in targets) {
      if (seen.add(t)) unique.add(t);
    }

    Object? lastError;
    for (final url in unique) {
      try {
        return await _checkAt(url);
      } catch (e) {
        if (e is FormatException || e is TypeError) rethrow;
        lastError = e;
      }
    }
    if (lastError is Exception) throw lastError;
    throw Exception('Не удалось проверить обновления.');
  }

  Future<File> downloadVerifiedApk(
    UpdateInfo info, {
    void Function(int received, int? total)? onProgress,
  }) async {
    if (info.apkUrl.isEmpty)
      throw Exception('APK не найден на сервере обновлений.');
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/masters-update-${info.latestVersionCode}.apk',
    );
    // If a fully verified APK is already cached, use it without re-downloading.
    if (await file.exists() && info.sha256.isNotEmpty) {
      final digest = sha256
          .convert(await file.readAsBytes())
          .toString()
          .toLowerCase();
      if (digest == info.sha256.toLowerCase()) return file;
    }
    final existing = await file.exists() ? await file.length() : 0;
    final request = http.Request('GET', Uri.parse(info.apkUrl));
    if (existing > 0) request.headers['Range'] = 'bytes=$existing-';
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    IOSink sink;
    int received = existing;
    if (streamed.statusCode == 206) {
      sink = file.openWrite(mode: FileMode.append);
    } else if (streamed.statusCode == 200) {
      if (await file.exists()) await file.delete();
      sink = file.openWrite();
      received = 0;
    } else {
      throw Exception('Не удалось скачать APK (${streamed.statusCode}).');
    }
    await for (final chunk in streamed.stream) {
      sink.add(chunk);
      received += chunk.length;
      onProgress?.call(
        received,
        streamed.contentLength == null
            ? null
            : streamed.contentLength! +
                  (streamed.statusCode == 206 ? existing : 0),
      );
    }
    await sink.close();

    final digest = sha256
        .convert(await file.readAsBytes())
        .toString()
        .toLowerCase();
    if (info.sha256.isNotEmpty && digest != info.sha256.toLowerCase()) {
      await file.delete();
      throw Exception('APK не прошёл проверку SHA-256 и удалён.');
    }
    return file;
  }

  Future<void> installApk(File file) async {
    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }
}
