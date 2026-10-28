import 'dart:io';
import 'dart:convert';
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
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }
}

Future<void> _handleRequest(HttpRequest request, String webDir) async {
  var path = request.uri.path;
  if (path == '/') path = '/index.html';

  final file = File(p.join(webDir, path.substring(1)));

  if (!file.existsSync()) {
    // Для SPA возвращаем index.html на все несуществующие пути
    final indexFile = File(p.join(webDir, 'index.html'));
    if (indexFile.existsSync()) {
      request.response.headers.contentType = ContentType.html;
      await request.response.addStream(indexFile.openRead());
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('404 Not Found');
    }
    await request.response.close();
    return;
  }

  // Определяем MIME-тип
  final contentType = _getContentType(path);
  if (contentType != null) {
    request.response.headers.contentType = contentType;
  }

  // Отправляем файл
  await request.response.addStream(file.openRead());
  await request.response.close();

  print('${request.method} ${request.uri.path} - ${request.response.statusCode}');
}

ContentType? _getContentType(String path) {
  final ext = p.extension(path).toLowerCase();
  return switch (ext) {
    '.html' => ContentType.html,
    '.js' => ContentType('application', 'javascript', charset: 'utf-8'),
    '.json' => ContentType.json,
    '.css' => ContentType('text', 'css', charset: 'utf-8'),
    '.png' => ContentType('image', 'png'),
    '.jpg' || '.jpeg' => ContentType('image', 'jpeg'),
    '.gif' => ContentType('image', 'gif'),
    '.svg' => ContentType('image', 'svg+xml'),
    '.ico' => ContentType('image', 'x-icon'),
    '.wasm' => ContentType('application', 'wasm'),
    '.ttf' => ContentType('font', 'ttf'),
    '.woff' => ContentType('font', 'woff'),
    '.woff2' => ContentType('font', 'woff2'),
    _ => ContentType.binary,
  };
}
