import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'auth_user';
  static const String _keyCustomBaseUrl = 'custom_base_url';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Token
  static Future<bool> saveToken(String token) async {
    await init();
    return _prefs!.setString(_keyToken, token);
  }

  static String? getToken() {
    return _prefs?.getString(_keyToken);
  }

  static bool hasToken() {
    final t = getToken();
    return t != null && t.isNotEmpty;
  }

  // User
  static Future<bool> saveUser(Map<String, dynamic> user) async {
    await init();
    return _prefs!.setString(_keyUser, jsonEncode(user));
  }

  static Map<String, dynamic>? getUser() {
    final raw = _prefs?.getString(_keyUser);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // Custom Base URL
  static Future<bool> saveBaseUrl(String url) async {
    await init();
    return _prefs!.setString(_keyCustomBaseUrl, url);
  }

  static Future<bool> setCustomBaseUrl(String? url) async {
    await init();
    if (url == null || url.isEmpty) {
      return _prefs!.remove(_keyCustomBaseUrl);
    }
    return _prefs!.setString(_keyCustomBaseUrl, url);
  }

  static String? getCustomBaseUrl() {
    return _prefs?.getString(_keyCustomBaseUrl);
  }

  // Clear all on logout
  static Future<bool> clearAuth() async {
    await init();
    await _prefs!.remove(_keyToken);
    await _prefs!.remove(_keyUser);
    return true;
  }
}
