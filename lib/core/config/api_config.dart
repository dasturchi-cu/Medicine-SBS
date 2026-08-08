import 'dart:io';

String getApiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (fromEnv.isNotEmpty) return _normalizeBaseUrl(fromEnv);
  // Android emulator usually reaches host by 10.0.2.2,
  // while real phone needs LAN IP (same Wi-Fi).
  if (Platform.isAndroid) {
    const lanDefault = String.fromEnvironment(
      'API_BASE_URL_LAN',
      defaultValue: 'https://neuroscience-app.onrender.com',
    );
    return _normalizeBaseUrl(lanDefault);
  }
  return _normalizeBaseUrl('http://localhost:8000');
}

String _normalizeBaseUrl(String input) {
  var value = input.trim();
  if (value.isEmpty) return value;

  // Common typo: missing "om" in onrender.com
  value = value.replaceAll('.onrender.c/', '.onrender.com/');
  value = value.replaceAll('.onrender.c', '.onrender.com');
  // Common typo: double "om" — onrender.comom (e.g. dart-define or env paste error)
  value = value.replaceAll('.onrender.comom', '.onrender.com');
  value = value.replaceAll('.onrender.comom/', '.onrender.com/');

  if (!value.startsWith('http://') && !value.startsWith('https://')) {
    value = 'https://$value';
  }

  return value.replaceAll(RegExp(r'/+$'), '');
}
