import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_attend/features/auth/views/mobile/welcome_screen.dart';
import 'package:smart_attend/features/auth/views/mobile/login_screen.dart';
import 'package:smart_attend/features/auth/views/mobile/change_password_screen.dart';
import 'package:smart_attend/features/student/views/mobile/student_dashboard.dart';
import 'package:smart_attend/features/lecturer/views/lecturer_dashboard.dart';
import 'package:smart_attend/features/dean/views/dean_access_screen.dart';
import 'package:smart_attend/features/dean/views/dean_dashboard.dart';
import 'package:smart_attend/features/super_admin/views/super_admin_dashboard.dart';
import 'package:smart_attend/features/attendance/views/mobile/qr_scanner_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Attend',
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFFAF9F6),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9B1B42),
          primary: const Color(0xFF9B1B42),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      initialRoute: WelcomeScreen.id,
      // ChangePasswordScreen needs a nextRoute argument so it uses
      // onGenerateRoute. All other screens use the simple routes table.
      onGenerateRoute: (settings) {
        if (settings.name == ChangePasswordScreen.id) {
          final nextRoute =
              (settings.arguments as String?) ?? StudentDashboard.id;
          return MaterialPageRoute(
            builder: (_) => ChangePasswordScreen(nextRoute: nextRoute),
          );
        }
        return null; // falls through to routes table below
      },
      routes: {
        WelcomeScreen.id: (context) => const WelcomeScreen(),
        LoginScreen.id: (context) => const LoginScreen(),
        StudentDashboard.id: (context) => const StudentDashboard(),
        LecturerDashboard.id: (context) => const LecturerDashboard(),
        DeanAccessScreen.id: (context) => const DeanAccessScreen(),
        DeanDashboard.id: (context) => const DeanDashboard(),
        SuperAdminDashboard.id: (context) => const SuperAdminDashboard(),
        QrScannerScreen.id: (context) => const QrScannerScreen(),
      },
    );
  }
}
