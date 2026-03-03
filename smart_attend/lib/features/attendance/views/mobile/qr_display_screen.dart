import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_attend/features/attendance/controllers/checkin_controller.dart';

const _kCherry  = Color(0xFF9B1B42);
const _kWhite   = Color(0xFFFFFFFF);
const _kBg      = Color(0xFFEEEEF3);
const _kCard    = Color(0xFFF5F5F8);

class QrDisplayScreen extends StatefulWidget {
  final String sessionId;
  final String courseCode;
  final String courseName;

  const QrDisplayScreen({
    super.key,
    required this.sessionId,
    required this.courseCode,
    required this.courseName,
  });

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  final _controller = CheckInController();

  String?  _qrData;
  int      _secondsLeft = 600; // 10 minutes
  bool     _loading     = true;
  String?  _error;
  Timer?   _timer;
  Position? _position;

  @override
  void initState() {
    super.initState();
    _generateQr();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _generateQr() async {
    setState(() { _loading = true; _error = null; });

    // Get lecturer's position
    final pos = await _controller.getCurrentPosition();
    if (pos == null) {
      setState(() {
        _loading = false;
        _error   = 'Could not get location. Enable GPS and try again.';
      });
      return;
    }

    _position = pos;

    final qrData = _controller.generateQrData(
      sessionId:    widget.sessionId,
      courseCode:   widget.courseCode,
      courseName:   widget.courseName,
      lat:          pos.latitude,
      lng:          pos.longitude,
      validMinutes: 10,
    );

    setState(() {
      _qrData      = qrData;
      _secondsLeft = 600;
      _loading     = false;
    });

    // Start countdown timer
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
          _qrData = null; // QR expired — force regenerate
        }
      });
    });
  }

  String get _timeDisplay {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft  % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _timerColor {
    if (_secondsLeft > 120) return Colors.green;
    if (_secondsLeft > 30)  return Colors.orange;
    return _kCherry;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCherry,
        elevation: 0,
        title: Text('${widget.courseCode} — Check-in',
            style: GoogleFonts.poppins(
                color: _kWhite, fontWeight: FontWeight.w600, fontSize: 16)),
        iconTheme: const IconThemeData(color: _kWhite),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [

          const SizedBox(height: 12),

          // ── Course info ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: _kCherry,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              Text(widget.courseName,
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: _kWhite)),
              const SizedBox(height: 4),
              Text('Ask students to scan this QR code',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: _kWhite.withValues(alpha: 0.8))),
            ]),
          ),

          const SizedBox(height: 24),

          // ── QR Code / Loading / Error ──
          if (_loading)
            const SizedBox(
                height: 280,
                child: Center(
                    child: CircularProgressIndicator(color: _kCherry)))

          else if (_error != null)
            _ErrorWidget(message: _error!, onRetry: _generateQr)

          else if (_qrData == null)
              _ExpiredWidget(onRegenerate: _generateQr)

            else ...[
                // QR display card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _kWhite,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: Column(children: [
                    QrImageView(
                      data:            _qrData!,
                      version:         QrVersions.auto,
                      size:            220,
                      backgroundColor: _kWhite,
                      eyeStyle: const QrEyeStyle(
                        eyeShape:  QrEyeShape.square,
                        color:     _kCherry,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color:           Color(0xFF1A1A1A),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Countdown timer
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: _timerColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_rounded,
                              size: 18, color: _timerColor),
                          const SizedBox(width: 8),
                          Text('Expires in $_timeDisplay',
                              style: GoogleFonts.poppins(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: _timerColor)),
                        ],
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 20),

                // Location chip
                if (_position != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.location_on_rounded,
                          size: 14, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                          'Location set — ${_position!.latitude.toStringAsFixed(4)}, '
                              '${_position!.longitude.toStringAsFixed(4)}',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.green)),
                    ]),
                  ),

                const SizedBox(height: 20),

                // Regenerate button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kCherry),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh_rounded,
                        color: _kCherry, size: 18),
                    label: Text('Regenerate QR',
                        style: GoogleFonts.poppins(
                            color: _kCherry, fontWeight: FontWeight.w600)),
                    onPressed: _generateQr,
                  ),
                ),
              ],

          const SizedBox(height: 20),

          // Info box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              _InfoItem(
                  icon:  Icons.timer_rounded,
                  text:  'QR code is valid for 10 minutes'),
              _InfoItem(
                  icon:  Icons.location_on_rounded,
                  text:  'Students must be within 100m to check in'),
              _InfoItem(
                  icon:  Icons.security_rounded,
                  text:  'Each QR code is cryptographically signed'),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _InfoItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 14, color: _kCherry),
      const SizedBox(width: 8),
      Expanded(
          child: Text(text,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey.shade500))),
    ]),
  );
}

class _ErrorWidget extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorWidget({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Column(children: [
    const Icon(Icons.location_off_rounded,
        size: 60, color: Colors.grey),
    const SizedBox(height: 12),
    Text(message,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(color: Colors.grey.shade500)),
    const SizedBox(height: 16),
    ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: _kCherry),
      onPressed: onRetry,
      child: Text('Try Again',
          style: GoogleFonts.poppins(color: _kWhite)),
    ),
  ]);
}

class _ExpiredWidget extends StatelessWidget {
  final VoidCallback onRegenerate;
  const _ExpiredWidget({required this.onRegenerate});

  @override
  Widget build(BuildContext context) => Column(children: [
    const Icon(Icons.timer_off_rounded, size: 60, color: Colors.grey),
    const SizedBox(height: 12),
    Text('QR Code Expired',
        style: GoogleFonts.poppins(
            fontSize: 18, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    Text('Generate a new code to continue check-in',
        style: GoogleFonts.poppins(color: Colors.grey.shade500)),
    const SizedBox(height: 16),
    ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: _kCherry),
      icon: const Icon(Icons.refresh_rounded, color: _kWhite),
      label: Text('New QR Code',
          style: GoogleFonts.poppins(color: _kWhite)),
      onPressed: onRegenerate,
    ),
  ]);
}