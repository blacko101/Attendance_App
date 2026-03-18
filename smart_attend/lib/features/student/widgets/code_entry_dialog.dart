import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_attend/core/theme/app_colors.dart';

void showCodeEntryDialog(BuildContext context) {
  final codeCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Enter Attendance Code',
        style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.text(context)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter the 6-digit code shown by your lecturer.',
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.subtext(context)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              color: AppColors.text(context),
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: AppColors.inputFill(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.cherry, width: 1.5),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: GoogleFonts.poppins(color: AppColors.subtext(context))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cherry,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            if (codeCtrl.text.length == 6) {
              Navigator.pop(context);
              // TODO: submit codeCtrl.text to your attendance API
            }
          },
          child: Text('Submit',
              style: GoogleFonts.poppins(color: Colors.white)),
        ),
      ],
    ),
  );
}