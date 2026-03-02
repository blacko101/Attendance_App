import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomButtonWidget extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const CustomButtonWidget({
    super.key,
    required this.onPressed,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return
       GestureDetector(
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
              color: Color(0xffD12629),
        ),

          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: Color(0xffFFFFFF),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
  }
}
