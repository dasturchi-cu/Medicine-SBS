import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/device_id.dart';

class ActivationService {
  ActivationService();

  static const _prefsKey = 'activated_courses_sha';
  static const _secret = 'neuroscience_local_secret_v1';

  Future<Set<String>> _loadActivatedHashes() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_prefsKey) ?? <String>[]).toSet();
  }

  Future<void> _saveActivatedHashes(Set<String> hashes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, hashes.toList()..sort());
  }

  /// Rule: Code = device_id + course_id (secured with hashing).
  Future<String> generateActivationCode({required String courseId}) async {
    final device = await DeviceId.getStableDeviceId();
    final raw = '$device|$courseId';
    final digest = sha256.convert(utf8.encode('$raw|$_secret'));
    return digest.toString().substring(0, 10).toUpperCase();
  }

  Future<bool> isActivated(String courseId) async {
    final device = await DeviceId.getStableDeviceId();
    final raw = '$device|$courseId';
    final hash = sha256.convert(utf8.encode('$raw|$_secret')).toString();
    final set = await _loadActivatedHashes();
    return set.contains(hash);
  }

  Future<bool> tryActivate({
    required String courseId,
    required String inputCode,
  }) async {
    final expected = await generateActivationCode(courseId: courseId);
    if (inputCode.trim().toUpperCase() != expected) return false;

    final device = await DeviceId.getStableDeviceId();
    final raw = '$device|$courseId';
    final hash = sha256.convert(utf8.encode('$raw|$_secret')).toString();
    final set = await _loadActivatedHashes();
    set.add(hash);
    await _saveActivatedHashes(set);
    return true;
  }
}

