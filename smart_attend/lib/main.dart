import 'package:flutter/material.dart';
import 'package:smart_attend/features/auth/views/mobile/welcome_screen.dart';

import 'features/auth/views/mobile/login_screen.dart';

void main() {
  runApp(const MyApp());
}

 class MyApp extends StatelessWidget {
   const MyApp({super.key});

   @override
   Widget build(BuildContext context) {
     return MaterialApp(
       debugShowCheckedModeBanner: false,
        initialRoute: WelcomeScreen.id,
       routes: {
         WelcomeScreen.id: (context) => const WelcomeScreen(),
         LoginScreen.id: (context) => const LoginScreen(),
       },

     );
   }
 }
