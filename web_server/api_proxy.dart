// Прокси для Яндекс API.
library;

import 'dart:convert';
import 'dart:io';

// Браузер не может обращаться к oauth.yandex.ru и cloud-api.yandex.net
// напрямую из-за CORS, поэтому запросы идут через локальный сервер.
// Прокси не хранит токены: access/refresh живут в браузере. `client_secret`
// добавляется только здесь (YANDEX_CLIENT_SECRET), поэтому в браузер не попадает.

const _allowedHostSuffixes = ['yandex.ru', 'yandex.net', 'yandex.com'];

bool isApiPath(String path) => path.startsWith('/api/');

void applyCors(HttpResponse response) {
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set(
    'Access-Control-Allow-Headers',
    'Authorization, Content-Type, Accept',
  );
  response.headers.set(
    'Access-Control-Allow-Methods',
    'GET, POST, PUT, DELETE, OPTIONS',
  );
}

Future<void> handleApiRequest(HttpRequest request) async {
  final response = request.response;
  applyCors(response);

  if (request.method == 'OPTIONS') {
    response.statusCode = HttpStatus.noContent;
    await response.close();
    return;
  }

  try {
    final path = request.uri.path;
    if (path == '/api/oauth/token') {
      await _forwardTokenRequest(request);
    } else if (path.startsWith('/api/disk')) {
      final rest = path.substring('/api/disk'.length);
      final target = Uri.https(
        'cloud-api.yandex.net',
        '/v1/disk$rest',
        request.uri.queryParameters.isEmpty ? null : request.uri.queryParameters,
      );
      await _forward(request, target);
    } else if (path == '/api/upload' || path == '/api/fetch') {
      final href = request.uri.queryParameters['href'];
      final parsed = href == null ? null : Uri.tryParse(href);
      if (parsed == null || !_isAllowedHost(parsed)) {
        response.statusCode = HttpStatus.forbidden;
        response.write('Forbidden target');
        await response.close();
        return;
      }
      await _forward(request, parsed);
    } else {
      response.statusCode = HttpStatus.notFound;
      response.write('Unknown API route');
      await response.close();
    }
  } catch (e) {
    stdout.writeln('API error: $e');
    try {
      response.statusCode = HttpStatus.badGateway;
      await response.close();
    } catch (_) {}
  }
}

bool _isAllowedHost(Uri uri) => _allowedHostSuffixes
    .any((suffix) => uri.host == suffix || uri.host.endsWith('.$suffix'));

/// Обмен кода на токен: секрет приложения добавляет сервер, а не браузер.
Future<void> _forwardTokenRequest(HttpRequest request) async {
  final body =
      utf8.decode(await request.fold<List<int>>([], (a, b) => a..addAll(b)));
  final secret = Platform.environment['YANDEX_CLIENT_SECRET'] ?? '';
  final payload = secret.isEmpty
      ? body
      : '$body&client_secret=${Uri.encodeQueryComponent(secret)}';

  final client = HttpClient();
  try {
    final out = await client.postUrl(Uri.parse('https://oauth.yandex.ru/token'));
    out.headers.set('Content-Type', 'application/x-www-form-urlencoded');
    out.headers.set('Accept', 'application/json');
    out.add(utf8.encode(payload));
    final res = await out.close();
    await _copyResponse(request.response, res);
  } finally {
    client.close();
  }
}

/// Перенаправляет запрос на внешний адрес и возвращает ответ как есть.
Future<void> _forward(HttpRequest request, Uri target) async {
  final client = HttpClient();
  try {
    final out = await client.openUrl(request.method, target);
    request.headers.forEach((name, values) {
      final lower = name.toLowerCase();
      if (lower == 'host' ||
          lower == 'content-length' ||
          lower == 'origin') {
        return;
      }
      for (final value in values) {
        out.headers.add(name, value);
      }
    });
    final body = await request.fold<List<int>>([], (a, b) => a..addAll(b));
    if (body.isNotEmpty) out.add(body);
    final res = await out.close();
    await _copyResponse(request.response, res);
  } finally {
    client.close();
  }
}

Future<void> _copyResponse(
  HttpResponse response,
  HttpClientResponse res,
) async {
  response.statusCode = res.statusCode;
  final contentType = res.headers.contentType;
  if (contentType != null) response.headers.contentType = contentType;
  applyCors(response);
  await response.addStream(res);
  await response.close();
}
