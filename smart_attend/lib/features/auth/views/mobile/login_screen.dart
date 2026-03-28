import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_attend/features/auth/controllers/auth_controller.dart';
import 'package:smart_attend/features/auth/views/mobile/change_password_screen.dart';
import 'package:smart_attend/features/auth/views/mobile/face_registration_screen.dart';
import 'package:smart_attend/features/auth/widgets/custom_button_widget.dart';
import 'package:smart_attend/features/student/views/mobile/student_dashboard.dart';
import 'package:smart_attend/features/lecturer/views/lecturer_dashboard.dart';
import 'package:smart_attend/features/dean/views/dean_access_screen.dart';
import 'package:smart_attend/features/super_admin/views/super_admin_dashboard.dart';
import 'package:smart_attend/features/admin/views/admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  static String id = 'login_screen';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authController = AuthController();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await _authController.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      _navigateByRole(
        user.role.toLowerCase().trim(),
        mustChangePassword: user.mustChangePassword,
        faceRegistered: user.faceRegistered,
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateByRole(
    String role, {
    bool mustChangePassword = false,
    bool faceRegistered = false,
  }) {
    if (mustChangePassword) {
      final String nextRoute;
      switch (role) {
        case 'lecturer':
          nextRoute = LecturerDashboard.id;
          break;
        case 'super_admin':
          nextRoute = SuperAdminDashboard.id;
          break;
        case 'admin':
          nextRoute = AdminDashboard.id;
          break;
        case 'dean':
          nextRoute = DeanAccessScreen.id;
          break;
        default:
          nextRoute = StudentDashboard.id;
          break;
      }
      Navigator.pushReplacementNamed(
        context,
        ChangePasswordScreen.id,
        arguments: nextRoute,
      );
      return;
    }

    // ── Face registration check for students ──────────────────────
    // If the student hasn't registered their face yet, send them
    // to the face registration screen before the dashboard.
    if (role == 'student' && !faceRegistered) {
      Navigator.pushReplacementNamed(context, FaceRegistrationScreen.id);
      return;
    }

    final String destination;
    switch (role) {
      case 'lecturer':
        destination = LecturerDashboard.id;
        break;
      case 'super_admin':
        destination = SuperAdminDashboard.id;
        break;
      case 'admin':
        destination = AdminDashboard.id;
        break;
      case 'dean':
        destination = DeanAccessScreen.id;
        break;
      case 'student':
      default:
        destination = StudentDashboard.id;
        break;
    }
    Navigator.pushReplacementNamed(context, destination);
  }

  void _showErrorSnackbar(String message) {
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
      // Web → cherry background, mobile → plain off-white
      backgroundColor: kIsWeb
          ? const Color(0xFF9B1B42)
          : const Color(0xFFFAF9F6),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: kIsWeb ? 24.0 : 24.0,
                vertical: kIsWeb ? 40.0 : 0,
              ),
              child: kIsWeb ? _webCard() : _formBody(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Web: form inside a white card with shadow ───────────────────────────────
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

  // ── Shared form used by both platforms ─────────────────────────────────────
  Widget _formBody() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo + App Name ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 50,
                width: 50,
                child: Image.asset('assets/images/cap.png'),
              ),
              const SizedBox(width: 10),
              Text(
                'SMART-ATTEND',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ── Hero Image ──
          Center(
            child: SizedBox(
              height: 100,
              width: 100,
              child: Image.asset('assets/images/cal.png', fit: BoxFit.contain),
            ),
          ),

          const SizedBox(height: 16),

          Center(
            child: Text(
              'Login to your account',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Email ──
          Text(
            'Email',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_passwordFocusNode),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
            decoration: _inputDecoration(
              hint: 'Enter your email',
              icon: Icons.mail_outline,
            ),
          ),

          const SizedBox(height: 20),

          // ── Password ──
          Text(
            'Password',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: !_isVisible,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
            decoration: _inputDecoration(
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                  _isVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _isVisible = !_isVisible),
              ),
            ),
          ),

          // ── Forgot Password ──
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                // TODO: ForgotPasswordScreen
              },
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF9B1B42),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Login Button ──
          CustomButtonWidget(
            onPressed: _isLoading ? null : _handleLogin,
            text: 'Login',
            isLoading: _isLoading,
          ),

          const SizedBox(height: 8),
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
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
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
