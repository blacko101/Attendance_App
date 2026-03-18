import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_attend/core/theme/app_colors.dart';
import 'package:smart_attend/features/attendance/views/mobile/qr_scanner_screen.dart';
import 'package:smart_attend/features/student/widgets/code_entry_dialog.dart';

void showAttendanceOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AttendanceOptionsSheet(),
  );
}

class _AttendanceOptionsSheet extends StatelessWidget {
  const _AttendanceOptionsSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Mark Attendance',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context)),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how you\'d like to mark your attendance',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.subtext(context)),
          ),
          const SizedBox(height: 28),
          _OptionTile(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Scan QR Code',
            subtitle: 'Use your camera to scan the lecturer\'s QR code',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, QrScannerScreen.id);
            },
          ),
          const SizedBox(height: 12),
          _OptionTile(
            icon: Icons.pin_outlined,
            title: 'Enter 6-Digit Code',
            subtitle: 'Manually type the code displayed by your lecturer',
            onTap: () {
              Navigator.pop(context);
              showCodeEntryDialog(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardAlt(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider(context)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cherry.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.cherry, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(context))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.subtext(context))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.subtext(context)),
          ],
        ),
      ),
    );
  }
}