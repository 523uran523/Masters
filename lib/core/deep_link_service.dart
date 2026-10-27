import 'package:url_launcher/url_launcher.dart';

class DeepLinkService {
  static String _digits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  static Future<void> openWhatsApp({required String phone, String? text}) async {
    final number = _digits(phone);
    final uri = Uri.parse('https://wa.me/$number${text == null ? '' : '?text=${Uri.encodeComponent(text)}'}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> openTelegram({String? username, String? text}) async {
    Uri uri;
    if (username != null && username.isNotEmpty) {
      uri = Uri.parse('https://t.me/$username');
    } else if (text != null) {
      uri = Uri.parse('https://t.me/share/url?text=${Uri.encodeComponent(text)}');
    } else {
      uri = Uri.parse('tg://');
    }
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}