import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/auth/models/auth_model.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/auth/views/mobile/login_screen.dart';

class AuthController {
  AuthModel? _currentUser;
  AuthModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<AuthModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse('${AppConfig.authUrl}/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
        throw Exception('Connection timed out. Check your internet.'),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final String token = body['token'] as String;
        final Map<String, dynamic> userData =
            body['user'] as Map<String, dynamic>? ?? {};
        final Map<String, dynamic> payload = JwtDecoder.decode(token);
        final String userId = payload['id'] as String? ?? '';

        final user = AuthModel.fromLoginResponse(
          token: token,
          role: userData['role'] as String? ?? 'student',
          id: userData['_id'] as String? ?? userId,
          fullName: userData['fullName'] as String? ?? '',
          email: userData['email'] as String? ?? email.trim().toLowerCase(),
          mustChangePassword:
          body['mustChangePassword'] as bool? ??
              userData['mustChangePassword'] as bool? ??
              false,
          faceRegistered: userData['faceRegistered'] as bool? ?? false,
          indexNumber: userData['indexNumber'] as String?,
          programme: userData['programme'] as String?,
          level: userData['level'] as String?,
          staffId: userData['staffId'] as String?,
          department: userData['department'] as String?,
        );

        _currentUser = user;
        await SessionService.saveSession(user);
        return user;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid email or password.');
      } else if (response.statusCode == 403) {
        throw Exception('Your account has been suspended. Contact admin.');
      } else if (response.statusCode == 429) {
        final msg =
            body['message'] as String? ??
                'Too many attempts. Please try again later.';
        throw Exception(msg);
      } else if (response.statusCode == 500) {
        throw Exception('Server error. Please try again later.');
      } else {
        final msg =
            body['message'] as String? ?? 'Login failed. Please try again.';
        throw Exception(msg);
      }
    } on http.ClientException {
      throw Exception(
        'Cannot connect to server. Make sure the backend is running.',
      );
    } on FormatException {
      throw Exception('Unexpected server response. Please try again.');
    }
  }

  Future<AuthModel?> restoreSession() async {
    final user = await SessionService.getSession();
    if (user == null) return null;

    if (JwtDecoder.isExpired(user.token)) {
      await SessionService.clearSession();
      return null;
    }

    _currentUser = user;
    return user;
  }

  // ── POST /api/auth/change-password ────────────────────────────────
  // FIX: The old code checked `if (_currentUser != null)` before
  // clearing mustChangePassword from the session. Since
  // ChangePasswordScreen creates a NEW AuthController instance,
  // _currentUser is always null — the session flag never got cleared,
  // so the user was sent back to this screen on every app restart.
  //
  // Fix: always read the session from SessionService directly, update
  // it, and save it back — no dependency on _currentUser at all.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final session = await SessionService.getSession();
    if (session == null) throw Exception('Not authenticated.');

    final response = await http
        .post(
      Uri.parse('${AppConfig.authUrl}/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.token}',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      // Always clear the flag directly from the saved session —
      // do NOT rely on _currentUser which is null in a fresh instance.
      final updated = session.copyWithPasswordChanged();
      await SessionService.saveSession(updated);
      _currentUser = updated;
      return;
    }

    if (response.statusCode == 429) {
      throw Exception(
        body['message'] as String? ??
            'Too many attempts. Please try again later.',
      );
    }

    final msg = body['message'] as String? ?? 'Password change failed.';
    throw Exception(msg);
  }

  Future<void> logout(BuildContext context) async {
    _currentUser = null;
    await SessionService.clearSession();

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        LoginScreen.id,
            (route) => false,
      );
    }
  }
}
