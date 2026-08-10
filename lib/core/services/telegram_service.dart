import 'package:url_launcher/url_launcher.dart';

class TelegramService {
  static const String _adminUsername = 'Mr_Xusanboy';

  Future<bool> openTelegram({
    required String courseName,
    required String userId,
    String? courseId,
    String? userName,
    String? userPhone,
    String? telegramRecipient,
  }) async {
    var recipient = (telegramRecipient ?? _adminUsername).trim();
    if (recipient.startsWith('@')) recipient = recipient.substring(1);
    if (recipient.isEmpty) recipient = _adminUsername;

    final normalizedName = (userName ?? '').trim().isEmpty ? '-' : userName!.trim();
    final normalizedPhone = (userPhone ?? '').trim().isEmpty ? '-' : userPhone!.trim();
    // Neuroscience uslubi: qisqa, User ID / Kurs ID siz — admin ism va telefon orqali topadi.
    final message = '''
Salom men shu kursni sotib olmoqchiman.

Ism: $normalizedName
Telefon: $normalizedPhone
Kurs nomi: "$courseName"
''';
    final encoded = Uri.encodeComponent(message);
    final appUri = Uri.parse(
      'tg://resolve?domain=$recipient&text=$encoded',
    );
    final webUri = Uri.parse('https://t.me/$recipient?text=$encoded');

    try {
      final openedInTelegram = await launchUrl(
        appUri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (openedInTelegram) return true;
    } catch (_) {
      // If deep link fails, continue with web fallback.
    }

    try {
      final openedExternal = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
      if (openedExternal) return true;
    } catch (_) {
      // Last fallback below.
    }

    try {
      return await launchUrl(webUri, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }
}
