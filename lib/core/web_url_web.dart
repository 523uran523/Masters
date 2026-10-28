import 'package:web/web.dart' as web;

/// Заменяет адрес в строке браузера без перезагрузки.
void replaceUrl(String url) {
  web.window.history.replaceState(null, '', url);
}
