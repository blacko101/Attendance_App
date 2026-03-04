import 'dart:convert';
import 'package:flutter/foundation.dart';             // ← debugPrint
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_attend/features/auth/models/auth_model.dart';

class SessionService {
  SessionService._(); // prevent instantiation

  static const _key = 'smart_attend_user';

  static Future<void> saveSession(AuthModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(user.toJson()));
  }

  static Future<AuthModel?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data  = prefs.getString(_key);
      if (data == null) return null;
      return AuthModel.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (e) {
      // FIX: print() outputs to device logs in release builds and can
      // expose session/token data to anyone with logcat/Console access.
      // debugPrint() is stripped in release mode — safe to use here.
      debugPrint('SessionService: restore error — $e');
      return null;
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}