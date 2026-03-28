import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_attend/features/auth/controllers/auth_controller.dart';
import 'package:smart_attend/features/auth/views/mobile/login_screen.dart';
import 'package:smart_attend/features/auth/views/mobile/face_registration_screen.dart';
import 'package:smart_attend/features/auth/widgets/custom_button_widget.dart';
import 'package:smart_attend/features/student/views/mobile/student_dashboard.dart';
import 'package:smart_attend/features/lecturer/views/lecturer_dashboard.dart';
import 'package:smart_attend/features/dean/views/dean_access_screen.dart';
import 'package:smart_attend/features/super_admin/views/super_admin_dashboard.dart';
import 'package:smart_attend/features/admin/views/admin_dashboard.dart';

class WelcomeScreen extends StatefulWidget {
  static String id = 'welcome_screen';
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _authController = AuthController();
  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    final user = await _authController.restoreSession();

    if (!mounted) return;

    if (user != null) {
      final role = user.role.toLowerCase().trim();

      // ── Face registration check ────────────────────────────────
      // Students must register their face before accessing the
      // dashboard. Runs on every app launch until face is registered.
      if (role == 'student' && !user.faceRegistered) {
        Navigator.pushReplacementNamed(context, FaceRegistrationScreen.id);
        return;
      }

      // ── Route to correct dashboard ─────────────────────────────
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
      return;
    }

    setState(() => _checkingSession = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAF9F6),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF9B1B42)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: SizedBox(
              width: 180,
              child: Image.asset(
                'assets/images/circle_2.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SizedBox(
              width: 102,
              height: 150,
              child: Image.asset(
                'assets/images/circle_1.png',
                fit: BoxFit.fill,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: SizedBox(
              width: 180,
              child: Image.asset(
                'assets/images/circle_3.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: SizedBox(
              width: 102,
              height: 140,
              child: Image.asset(
                'assets/images/circle_4.png',
                fit: BoxFit.fill,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        constraints: const BoxConstraints(
                          maxWidth: 150,
                          maxHeight: 150,
                        ),
                        child: Image.asset('assets/images/cu_logo.png'),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'SMART-ATTEND',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Track your attendance and stay on top of your academic progress.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 25),
                      Text(
                        'What Time Is Better Than The Present',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 80),
                      CustomButtonWidget(
                        onPressed: () {
                          Navigator.pushNamed(context, LoginScreen.id);
                        },
                        text: 'Get Started',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
