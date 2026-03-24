import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/auth/views/mobile/face_registration_screen.dart';
import 'package:smart_attend/features/auth/widgets/custom_button_widget.dart';

class ChangePasswordScreen extends StatefulWidget {
  static String id = 'change_password_screen';

  final String nextRoute;

  const ChangePasswordScreen({super.key, required this.nextRoute});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey              = GlobalKey<FormState>();
  final _currentPasswordCtrl  = TextEditingController();
  final _newPasswordCtrl      = TextEditingController();
  final _confirmPasswordCtrl  = TextEditingController();

  bool _showCurrent = false;
  bool _showNew     = false;
  bool _showConfirm = false;
  bool _isLoading   = false;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final session = await SessionService.getSession();
      if (session == null) {
        throw Exception('Session expired. Please log in again.');
      }

      final response = await http
          .post(
        Uri.parse('${AppConfig.authUrl}/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.token}',
        },
        body: jsonEncode({
          'currentPassword': _currentPasswordCtrl.text,
          'newPassword': _newPasswordCtrl.text,
        }),
      )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final updated = session.copyWithPasswordChanged();
        await SessionService.saveSession(updated);

        if (!mounted) return;

        // Students who haven't registered their face yet must do
        // so before accessing the dashboard — redirect them there.
        if (updated.role == 'student' && !updated.faceRegistered) {
          Navigator.pushReplacementNamed(
              context, FaceRegistrationScreen.id);
          return;
        }

        Navigator.pushReplacementNamed(context, widget.nextRoute);
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final msg = body['message'] as String? ?? 'Failed to change password.';
        _showError(msg);
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: const Color(0xFF9B1B42),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kIsWeb
          ? const Color(0xFF9B1B42)
          : const Color(0xFFFAF9F6),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: kIsWeb ? 40.0 : 0,
              ),
              child: kIsWeb ? _webCard() : _formBody(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Web: form inside a white card ──────────────────────────────────────────
  Widget _webCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(36),
      child: _formBody(),
    );
  }

  // ── Shared form body ───────────────────────────────────────────────────────
  Widget _formBody() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          const Center(
            child: Icon(
              Icons.lock_reset_rounded,
              size: 64,
              color: Color(0xFF9B1B42),
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              'Set New Password',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: Text(
              'Your account requires a password change\nbefore you can continue.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ── Info banner ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF2196F3).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFF2196F3), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your current (default) password is  Central@123\n'
                        'Enter it below, then choose a new personal password.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Current Password ──
          Text('Current Password',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _currentPasswordCtrl,
            obscureText: !_showCurrent,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter your current password';
              return null;
            },
            decoration: _inputDecoration(
              hint: 'Enter current password',
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                  _showCurrent
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey,
                ),
                onPressed: () =>
                    setState(() => _showCurrent = !_showCurrent),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── New Password ──
          Text('New Password',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _newPasswordCtrl,
            obscureText: !_showNew,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a new password';
              if (v.length < 8) return 'Must be at least 8 characters';
              if (v == 'Central@123') {
                return 'Choose a different password — do not reuse the default';
              }
              return null;
            },
            decoration: _inputDecoration(
              hint: 'Enter new password',
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                  _showNew
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _showNew = !_showNew),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Confirm Password ──
          Text('Confirm Password',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmPasswordCtrl,
            obscureText: !_showConfirm,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your new password';
              if (v != _newPasswordCtrl.text) return 'Passwords do not match';
              return null;
            },
            decoration: _inputDecoration(
              hint: 'Re-enter new password',
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                  _showConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey,
                ),
                onPressed: () =>
                    setState(() => _showConfirm = !_showConfirm),
              ),
            ),
          ),

          const SizedBox(height: 36),

          CustomButtonWidget(
            onPressed: _isLoading ? null : _submit,
            text: 'Change Password',
            isLoading: _isLoading,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      hintText: hint,
      hintStyle:
      GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: Colors.black),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF9B1B42), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
    );
  }
}