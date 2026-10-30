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

  Future<UpdateInfo> checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final currentCode = int.tryParse(info.buildNumber) ?? 0;
    final response = await http.get(
      Uri.parse('$base/api/updates/check?app_id=${info.packageName}&version_code=$currentCode'),
    ).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw Exception('Сервер обновлений недоступен (${response.statusCode}).');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final latest = (data['latest_version_code'] as num?)?.toInt() ?? currentCode;
    final minSupported = (data['min_supported_version_code'] as num?)?.toInt() ?? 1;
    final force = (data['force_update'] as bool?) ?? (currentCode < minSupported);
    final available = (data['update_available'] as bool?) ?? currentCode < latest;
    return UpdateInfo(
      appId: data['app_id']?.toString() ?? info.packageName,
      currentVersionCode: currentCode,
      latestVersionCode: latest,
      latestVersionName: data['latest_version_name']?.toString() ?? info.version,
      minSupportedVersionCode: minSupported,
      apkUrl: data['apk_url']?.toString() ?? '',
      sha256: data['sha256']?.toString() ?? '',
      changelog: data['changelog']?.toString() ?? '',
      updateAvailable: available,
      forceUpdate: force,
    );
  }

  Future<File> downloadVerifiedApk(UpdateInfo info, {void Function(int received, int? total)? onProgress}) async {
    if (info.apkUrl.isEmpty) throw Exception('APK не найден на сервере обновлений.');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/masters-update-${info.latestVersionCode}.apk');
    // If a fully verified APK is already cached, use it without re-downloading.
    if (await file.exists() && info.sha256.isNotEmpty) {
      final digest = sha256.convert(await file.readAsBytes()).toString().toLowerCase();
      if (digest == info.sha256.toLowerCase()) return file;
    }
    final existing = await file.exists() ? await file.length() : 0;
    final request = http.Request('GET', Uri.parse(info.apkUrl));
    if (existing > 0) request.headers['Range'] = 'bytes=$existing-';
    final streamed = await request.send().timeout(const Duration(seconds: 30));
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
      onProgress?.call(received, streamed.contentLength == null ? null : streamed.contentLength! + (streamed.statusCode == 206 ? existing : 0));
    }
    await sink.close();

    final digest = sha256.convert(await file.readAsBytes()).toString().toLowerCase();
    if (info.sha256.isNotEmpty && digest != info.sha256.toLowerCase()) {
      await file.delete();
      throw Exception('APK не прошёл проверку SHA-256 и удалён.');
    }
    return file;
  }

  Future<void> installApk(File file) async {
    final result = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }
}
