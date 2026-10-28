// Platform implementation for dart:io (desktop/mobile)
import 'dart:io';

Future<bool> testCredentialsImpl(
  String login,
  String password,
  String base,
  String Function(String, String) authFunc,
) async {
  final client = HttpClient();
  try {
    final req = await client.openUrl('PROPFIND', Uri.parse('$base/'));
    req.headers.set('Authorization', authFunc(login, password));
    req.headers.set('Depth', '0');
    final res = await req.close();
    await res.drain();
    return res.statusCode == 207 || res.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    client.close();
  }
}

Future<void> ensureFolderImpl(
  String login,
  String password,
  String base,
  String Function(String, String) authFunc,
) async {
  final client = HttpClient();
  try {
    final req = await client.openUrl('MKCOL', Uri.parse('$base/Masters'));
    req.headers.set('Authorization', authFunc(login, password));
    final res = await req.close();
    await res.drain();
  } catch (_) {
    // ignore
  } finally {
    client.close();
  }
}
