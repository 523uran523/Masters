import 'dart:io';

import 'api_proxy.dart';

/// Локальный прокси только для Яндекс API.
///
/// Используется в процессе разработки (при `flutter run -d chrome` /
/// `flutter run -d web-server`), когда статику отдаёт dev-сервер Flutter,
/// а нам всё равно нужен same-origin/localhost-API, чтобы браузер пропускал
/// запросы (web-fetch CORS) и мог спрятать `YANDEX_CLIENT_SECRET`.
///
/// Запуск:
///   dart run web_server/proxy_server.dart [port]
///
/// По умолчанию порт 8081. Приложение в dev-режиме должно быть собрано с
/// `--dart-define=YANDEX_API_BASE=http://localhost:8081`.
void main(List<String> args) async {
  final port = args.isNotEmpty ? int.tryParse(args[0]) ?? 8081 : 8081;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Yandex API proxy listening on http://localhost:$port');
  stdout.writeln('Environment: YANDEX_CLIENT_SECRET ${Platform.environment['YANDEX_CLIENT_SECRET'] == null || Platform.environment['YANDEX_CLIENT_SECRET']!.isEmpty ? 'MISSING' : 'set'}');
  await for (HttpRequest request in server) {
    try {
      if (isApiPath(request.uri.path)) {
        await handleApiRequest(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } catch (e) {
      stdout.writeln('❌ proxy error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }
}
