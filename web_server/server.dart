import 'dart:io';
import 'package:path/path.dart' as p;

import 'api_proxy.dart';

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
  if (isApiPath(request.uri.path)) {
    await handleApiRequest(request);
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
    '.map' => ContentType.json,
    _ => null,
  };
}
