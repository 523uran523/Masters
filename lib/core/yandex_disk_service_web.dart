// Platform implementation for web
import 'package:http/http.dart' as http;

Future<bool> testCredentialsImpl(
  String login,
  String password,
  String base,
  String Function(String, String) authFunc,
) async {
  try {
    final r = await http.get(
      Uri.parse('$base/'),
      headers: {
        'Authorization': authFunc(login, password),
        'Depth': '0',
      },
    );
    return r.statusCode == 207 || r.statusCode == 200;
  } catch (_) {
    return false;
  }
}

Future<void> ensureFolderImpl(
  String login,
  String password,
  String base,
  String Function(String, String) authFunc,
) async {
  // Web: folders are created automatically on WebDAV
  return;
}
