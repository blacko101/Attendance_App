import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smart_attend/core/providers/theme_provider.dart';
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
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    final baseLight = ThemeData(
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
    );

    final baseDark = ThemeData.dark(useMaterial3: true).copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF9B1B42),
        primary: const Color(0xFF9B1B42),
        brightness: Brightness.dark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Attend',
      theme: baseLight,
      darkTheme: baseDark,
      themeMode: themeProvider.themeMode,
      initialRoute: WelcomeScreen.id,
      onGenerateRoute: (settings) {
        if (settings.name == ChangePasswordScreen.id) {
          final nextRoute = settings.arguments as String? ?? LoginScreen.id;
          return MaterialPageRoute(
            builder: (_) => ChangePasswordScreen(nextRoute: nextRoute),
            settings: settings,
          );
        }
        return null;
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