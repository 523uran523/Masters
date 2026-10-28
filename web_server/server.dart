import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  final port = args.isNotEmpty ? int.tryParse(args[0]) ?? 8080 : 8080;
  final webDir = p.join(Directory.current.path, 'build', 'web');

  if (!Directory(webDir).existsSync()) {
    print('❌ Папка build/web не найдена!');
    print('Сначала выполните: flutter build web --release');
    exit(1);
  }

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('🚀 Masters Web Server запущен');
  print('📍 http://localhost:$port/');
  print('📁 Корневая папка: $webDir');
  print('Нажмите Ctrl+C для остановки');
  print('');

  await for (HttpRequest request in server) {
    try {
      await _handleRequest(request, webDir);
    } catch (e) {
      print('❌ Ошибка: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }
}

Future<void> _handleRequest(HttpRequest request, String webDir) async {
  if (request.uri.path.startsWith('/api/')) {
    await _handleApi(request);
    return;
  }

  var urlPath = Uri.decodeComponent(request.uri.path);
  if (urlPath == '/') urlPath = '/index.html';

  // Защита от выхода за пределы папки build/web
  final relative = urlPath.startsWith('/') ? urlPath.substring(1) : urlPath;
  final file = File(p.join(webDir, relative));
  final normalizedFile = p.normalize(file.path);
  final normalizedRoot = p.normalize(webDir);

  if (!normalizedFile.startsWith(normalizedRoot) || !file.existsSync()) {
    // Для SPA возвращаем index.html только для «страничных» адресов.
    // Отсутствующие файлы ресурсов должны давать честный 404.
    final isAsset = p.extension(relative).isNotEmpty;
    final indexFile = File(p.join(webDir, 'index.html'));
    if (!isAsset && indexFile.existsSync()) {
      request.response.headers.contentType = ContentType.html;
      request.response.headers.set('Cache-Control', 'no-store');
      await request.response.addStream(indexFile.openRead());
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('404 Not Found');
    }
    await request.response.close();
    print('${request.method} ${request.uri.path} - ${request.response.statusCode}');
    return;
  }

  final contentType = _getContentType(relative);
  if (contentType != null) {
    request.response.headers.contentType = contentType;
  }
  // Локальный сервер: никогда не кэшируем, чтобы обновления подхватывались сразу
  request.response.headers.set('Cache-Control', 'no-store');

  await request.response.addStream(file.openRead());
  await request.response.close();

  print('${request.method} ${request.uri.path} - ${request.response.statusCode}');
}

// ---------------------------------------------------------------------------
// API-прокси для Яндекс Диска.
//
// Браузер не может обращаться к oauth.yandex.ru и cloud-api.yandex.net
// напрямую из-за CORS, поэтому запросы идут через локальный сервер.
// Прокси не хранит токены: он только перенаправляет запросы.
// ---------------------------------------------------------------------------

const _yandexHostSuffixes = ['yandex.ru', 'yandex.net', 'yandex.com'];

Future<void> _handleApi(HttpRequest request) async {
  final response = request.response;
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Headers',
      'Authorization, Content-Type, Accept');
  response.headers.set('Access-Control-Allow-Methods',
      'GET, POST, PUT, DELETE, OPTIONS');

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
      if (href == null || !_isYandexHost(Uri.parse(href))) {
        response.statusCode = HttpStatus.forbidden;
        response.write('Forbidden target');
        await response.close();
        return;
      }
      await _forward(request, Uri.parse(href));
    } else {
      response.statusCode = HttpStatus.notFound;
      response.write('Unknown API route');
      await response.close();
    }
  } catch (e) {
    print('API error: $e');
    try {
      response.statusCode = HttpStatus.badGateway;
      await response.close();
    } catch (_) {}
  }
}

bool _isYandexHost(Uri uri) => _yandexHostSuffixes
    .any((suffix) => uri.host == suffix || uri.host.endsWith('.$suffix'));

/// Обмен кода на токен: секрет приложения добавляет сервер, а не браузер.
Future<void> _forwardTokenRequest(HttpRequest request) async {
  final body = utf8.decode(await request.fold<List<int>>([], (a, b) => a..addAll(b)));
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
      if (lower == 'host' || lower == 'content-length' || lower == 'origin') {
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
    HttpResponse response, HttpClientResponse res) async {
  response.statusCode = res.statusCode;
  final contentType = res.headers.contentType;
  if (contentType != null) response.headers.contentType = contentType;
  response.headers.set('Access-Control-Allow-Origin', '*');
  await response.addStream(res);
  await response.close();
}

ContentType? _getContentType(String path) {
  final ext = p.extension(path).toLowerCase();
  return switch (ext) {
    '.html' => ContentType.html,
    '.js' || '.mjs' => ContentType('application', 'javascript', charset: 'utf-8'),
    '.json' => ContentType.json,
    '.css' => ContentType('text', 'css', charset: 'utf-8'),
    '.png' => ContentType('image', 'png'),
    '.jpg' || '.jpeg' => ContentType('image', 'jpeg'),
    '.gif' => ContentType('image', 'gif'),
    '.svg' => ContentType('image', 'svg+xml'),
    '.ico' => ContentType('image', 'x-icon'),
    '.wasm' => ContentType('application', 'wasm'),
    '.ttf' => ContentType('font', 'ttf'),
    '.otf' => ContentType('font', 'otf'),
    '.woff' => ContentType('font', 'woff'),
    '.woff2' => ContentType('font', 'woff2'),
    '.map' => ContentType('application', 'json', charset: 'utf-8'),
    _ => ContentType.binary,
  };
}
