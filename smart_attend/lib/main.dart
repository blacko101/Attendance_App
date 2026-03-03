import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_attend/features/auth/views/mobile/welcome_screen.dart';
import 'package:smart_attend/features/auth/views/mobile/login_screen.dart';
import 'package:smart_attend/features/student/views/mobile/student_dashboard.dart';

import 'features/attendance/views/mobile/qr_scanner_screen.dart';


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

      // ── Global Theme ── set once here, no need to repeat GoogleFonts everywhere
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
      routes: {
        WelcomeScreen.id:    (context) => const WelcomeScreen(),
        LoginScreen.id:      (context) => const LoginScreen(),
        StudentDashboard.id: (context) => const StudentDashboard(),
        QrScannerScreen.id:  (context) => const QrScannerScreen(),
      },
    );
  }
}