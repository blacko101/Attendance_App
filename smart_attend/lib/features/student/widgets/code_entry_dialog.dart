import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/core/theme/app_colors.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/auth/services/location_service.dart';

void showCodeEntryDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const _CodeEntryDialog(),
  );
}

class _CodeEntryDialog extends StatefulWidget {
  const _CodeEntryDialog();

  @override
  State<_CodeEntryDialog> createState() => _CodeEntryDialogState();
}

class _CodeEntryDialogState extends State<_CodeEntryDialog> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();

    if (code.length != 6) {
      setState(() => _error = 'Please enter the full 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await SessionService.getSession();
      if (session == null) {
        setState(() {
          _error = 'Session expired. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      // Try to get GPS — backend requires it for in-person sessions
      double? lat, lng;
      try {
        final pos = await LocationService.getCurrentLocation();
        lat = pos?.latitude;
        lng = pos?.longitude;
      } catch (_) {
        // GPS unavailable — backend will reject if in-person session requires it
      }

      final body = <String, dynamic>{'code': code};
      if (lat != null && lng != null) {
        body['studentLat'] = lat;
        body['studentLng'] = lng;
      }

      final response = await http
          .post(
        Uri.parse('${AppConfig.attendanceUrl}/checkin-by-code'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.token}',
        },
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Attendance marked successfully!',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        final resBody = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _error = resBody['message'] as String? ??
              'Invalid code. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Connection error. Check your internet and try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Enter Attendance Code',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: AppColors.text(context),
        ),
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
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              color: AppColors.text(context),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
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
                borderSide:
                BorderSide(color: AppColors.cherry, width: 1.5),
              ),
            ),
          ),

          // ── Inline error message ──
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.cherry),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style:
            GoogleFonts.poppins(color: AppColors.subtext(context)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cherry,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
          )
              : Text(
            'Submit',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
        ),
      ],
    );
  }
}