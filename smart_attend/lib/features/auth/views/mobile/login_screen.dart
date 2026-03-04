import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_attend/features/auth/controllers/auth_controller.dart';
import 'package:smart_attend/features/auth/widgets/custom_button_widget.dart';
import 'package:smart_attend/features/student/views/mobile/student_dashboard.dart';
import 'package:smart_attend/features/lecturer/views/lecturer_dashboard.dart';
import 'package:smart_attend/features/dean/views/dean_access_screen.dart';

class LoginScreen extends StatefulWidget {
  static String id = 'login_screen';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authController     = AuthController();
  final _formKey            = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode  = FocusNode();

  // FIX (naming): _isVisible = true means the password is currently
  // shown in plain text. This naming is clearer than the old
  // _isObscure=false-means-hidden convention.
  bool _isVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // ── LOGIN HANDLER ──────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await _authController.login(
        email:    _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      _navigateByRole((user?.role ?? 'student').toLowerCase().trim());

    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── ROLE ROUTER ────────────────────────────────────────────────────
  // FIX 1: 'admin' now routes to DeanAccessScreen (the closest
  //         available dashboard) instead of StudentDashboard.
  //         TODO: replace with SuperAdminDashboard.id once built.
  // FIX 2: Removed duplicate `case 'super_admin':` which caused a
  //         Dart compile warning and dead code.
  void _navigateByRole(String role) {
    final String destination;

    switch (role) {
      case 'lecturer':
        destination = LecturerDashboard.id;
        break;

      case 'admin':
      // TODO Sprint 9: replace with SuperAdminDashboard.id
        destination = DeanAccessScreen.id;
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
        content: Text(message,
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: const Color(0xFF9B1B42),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // ── Logo + App Name ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 50, width: 50,
                      child: Image.asset('assets/images/cap.png'),
                    ),
                    const SizedBox(width: 10),
                    Text('SMART-ATTEND',
                        style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.black)),
                  ],
                ),

                const SizedBox(height: 40),

                // ── Hero Image ──
                Center(
                  child: SizedBox(
                    height: 120, width: 120,
                    child: Image.asset(
                        'assets/images/cal.png',
                        fit: BoxFit.contain),
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: Text('Login to your account',
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                ),

                const SizedBox(height: 30),

                // ── Email ──
                Text('Email',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context)
                      .requestFocus(_passwordFocusNode),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                        .hasMatch(value.trim())) {
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
                Text('Password',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87)),
                const SizedBox(height: 8),
                TextFormField(
                  controller:     _passwordController,
                  focusNode:      _passwordFocusNode,
                  // FIX (naming): _isVisible=true → show text, false → hide
                  obscureText:    !_isVisible,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleLogin(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    // FIX: backend now requires minimum 8 characters.
                    // Old code checked < 6, which would let a 6-char
                    // password pass client validation but get rejected
                    // by the server with a 400.
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
                      onPressed: () =>
                          setState(() => _isVisible = !_isVisible),
                    ),
                  ),
                ),

                // ── Forgot Password ──
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // TODO Sprint 10: ForgotPasswordScreen
                    },
                    child: Text('Forgot Password?',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF9B1B42),
                            fontWeight: FontWeight.w500)),
                  ),
                ),

                const SizedBox(height: 30),

                // ── Login Button ──
                CustomButtonWidget(
                  onPressed: _isLoading ? null : _handleLogin,
                  text: 'Login',
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String   hint,
    required IconData icon,
    Widget?           suffix,
  }) {
    return InputDecoration(
      filled:     true,
      fillColor:  Colors.white,
      hintText:   hint,
      hintStyle:  GoogleFonts.poppins(
          fontSize: 13, color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: Colors.black),
      suffixIcon: suffix,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFF9B1B42), width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Colors.red, width: 1.2)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Colors.red, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
    );
  }
}