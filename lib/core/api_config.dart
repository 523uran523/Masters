import 'package:flutter/foundation.dart' show kIsWeb;

/// Prefix for API requests (`/api` in production, `http://localhost:8081` in dev).
class ApiConfig {
  const ApiConfig._();

  static const String _override = String.fromEnvironment('YANDEX_API_BASE');

  static String get apiBase {
    if (kIsWeb) {
      return _override.isEmpty ? '' : _override;
    }
    return '';
  }

  static String get diskApi => '$apiBase/api/disk';
  static String get oauthTokenEndpoint => '$apiBase/api/oauth/token';
  static String get uploadProxy => '$apiBase/api/upload';
  static String get fetchProxy => '$apiBase/api/fetch';
}
