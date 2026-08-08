import 'dart:convert';

import 'package:flutter/services.dart';

class LocalizationService {
  Future<Map<String, String>> loadLang(String code) async {
    final raw = await rootBundle.loadString('assets/lang/$code.json');
    final data = jsonDecode(raw);
    if (data is! Map) return const {};
    return data.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  /// Loads all supported languages at once for instant switching.
  Future<Map<String, Map<String, String>>> preloadAll() async {
    final uz = await loadLang('uz');
    final ru = await loadLang('ru');
    final en = await loadLang('en');
    return {'uz': uz, 'ru': ru, 'en': en};
  }
}

