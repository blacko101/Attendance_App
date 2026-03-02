import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_attend/features/auth/views/mobile/login_screen.dart';
import 'package:smart_attend/features/auth/widgets/custom_button_widget.dart';

class WelcomeScreen extends StatefulWidget {
  static String id = 'welcome_screen';
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(255, 255, 255, 1),
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          constraints: const BoxConstraints(
                            maxWidth: 150,
                            maxHeight: 150,
                          ),
                          child: Image.asset('assets/images/cu_logo.png'),
                        ),
                      ],
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        'Track your attendance and stay on top of your academic progress.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
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
                    CustomButtonWidget(onPressed: () {
                      Navigator.pushNamed(context, LoginScreen.id);
                    }, text: 'Get Started'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
