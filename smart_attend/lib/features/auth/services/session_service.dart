import 'dart:convert';                                                    // ← fixes jsonEncode/jsonDecode
import 'package:shared_preferences/shared_preferences.dart';             // ← fixes SharedPreferences
import 'package:smart_attend/features/auth/models/auth_model.dart';      // ← fixes AuthModel

class SessionService {
  static const _key = 'smart_attend_user';

  static Future<void> saveSession(AuthModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(user.toJson()));
  }

  static Future<AuthModel?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_key);
      if (data == null) return null;
      return AuthModel.fromJson(jsonDecode(data));
    } catch (e) {
      print('Session restore error: $e');
      return null;
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}