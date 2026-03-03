import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:smart_attend/features/attendance/controllers/checkin_controller.dart';
import 'package:smart_attend/features/attendance/models/checkin_model.dart';


const _kCherry  = Color(0xFF9B1B42);
const _kGreen   = Color(0xFF4CAF50);
const _kWhite   = Color(0xFFFFFFFF);

class QrScannerScreen extends StatefulWidget {
  static String id = 'qr_scanner_screen';
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _controller    = CheckInController();
  final _cameraCtrl    = MobileScannerController();

  bool _processing     = false;
  bool _hasScanned     = false;

  @override
  void dispose() {
    _cameraCtrl.dispose();
    super.dispose();
  }

  Future<void> _onQrDetected(BarcodeCapture capture) async {
    if (_hasScanned || _processing) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;

    setState(() { _hasScanned = true; _processing = true; });
    _cameraCtrl.stop();

    final result = await _controller.processCheckIn(raw);

    if (!mounted) return;
    setState(() => _processing = false);

    _showResultSheet(result);
  }

  void _showResultSheet(CheckInResult result) {
    showModalBottomSheet(
      context: context,
      isDismissible:     false,
      backgroundColor:   Colors.transparent,
      enableDrag:        false,
      builder: (_) => _ResultSheet(
        result: result,
        onDone: () {
          Navigator.pop(context); // close sheet
          Navigator.pop(context); // close scanner
        },
        onRetry: () {
          Navigator.pop(context); // close sheet
          setState(() { _hasScanned = false; });
          _cameraCtrl.start();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [

        // ── Camera feed ──
        MobileScanner(
          controller: _cameraCtrl,
          onDetect: _onQrDetected,
        ),

        // ── Dark overlay with scan window cutout ──
        CustomPaint(
          painter: _ScanOverlayPainter(),
          size: Size.infinite,
        ),

        // ── Top bar ──
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: _kWhite, size: 20),
                  ),
                ),
                Text('Scan QR Code',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: _kWhite)),
                // Flash toggle
                GestureDetector(
                  onTap: () => _cameraCtrl.toggleTorch(),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flash_on_rounded,
                        color: _kWhite, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Scan frame corners ──
        Center(
          child: SizedBox(
            width: 250, height: 250,
            child: CustomPaint(painter: _CornerPainter()),
          ),
        ),

        // ── Instruction text ──
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_processing)
                const CircularProgressIndicator(color: _kCherry)
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.qr_code_scanner_rounded,
                        color: _kWhite, size: 16),
                    const SizedBox(width: 8),
                    Text('Point camera at lecturer\'s QR code',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: _kWhite)),
                  ]),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  RESULT BOTTOM SHEET
// ─────────────────────────────────────────────
class _ResultSheet extends StatelessWidget {
  final CheckInResult result;
  final VoidCallback  onDone;
  final VoidCallback  onRetry;
  const _ResultSheet({
    required this.result,
    required this.onDone,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = result.isSuccess;
    final color     = isSuccess ? _kGreen : _kCherry;
    final icon      = isSuccess
        ? Icons.check_circle_rounded
        : result.status == CheckInStatus.tooFar
        ? Icons.location_off_rounded
        : result.status == CheckInStatus.expired
        ? Icons.timer_off_rounded
        : Icons.error_rounded;

    return Container(
      decoration: const BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Icon
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 40),
        ),
        const SizedBox(height: 16),

        // Status title
        Text(
          isSuccess ? 'Checked In!' : _statusTitle(result.status),
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A)),
        ),
        const SizedBox(height: 8),

        // Message
        Text(result.message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.grey.shade500)),

        // Course info
        if (result.courseCode != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.book_rounded, size: 16, color: color),
                const SizedBox(width: 8),
                Text('${result.courseCode} — ${result.courseName ?? ""}',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ),
        ],

        // Distance info
        if (result.distanceMeters != null && !isSuccess) ...[
          const SizedBox(height: 10),
          Text(
              'Your distance: ${result.distanceMeters!.toInt()}m '
                  '(max: ${CheckInController.maxDistanceM.toInt()}m)',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey.shade400)),
        ],

        const SizedBox(height: 24),

        // Buttons
        Row(children: [
          if (!isSuccess && result.status != CheckInStatus.alreadyMarked) ...[
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kCherry),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: onRetry,
                child: Text('Try Again',
                    style: GoogleFonts.poppins(
                        color: _kCherry, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSuccess ? _kGreen : _kCherry,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: onDone,
              child: Text('Done',
                  style: GoogleFonts.poppins(
                      color: _kWhite, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),

        const SizedBox(height: 8),
      ]),
    );
  }

  String _statusTitle(CheckInStatus s) {
    switch (s) {
      case CheckInStatus.tooFar:       return 'Too Far Away';
      case CheckInStatus.expired:      return 'QR Expired';
      case CheckInStatus.alreadyMarked: return 'Already Checked In';
      case CheckInStatus.invalid:      return 'Invalid QR Code';
      default:                         return 'Check-in Failed';
    }
  }
}

// ─────────────────────────────────────────────
//  PAINTERS
// ─────────────────────────────────────────────
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    const scanSize = 250.0;
    final left   = (size.width  - scanSize) / 2;
    final top    = (size.height - scanSize) / 2;
    final cutout = Rect.fromLTWH(left, top, scanSize, scanSize);

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(
            cutout, const Radius.circular(16))),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = _kCherry
      ..strokeWidth = 4
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    const len = 30.0;
    const r   = 16.0;

    // Top-left
    canvas.drawLine(const Offset(r, 0),       Offset(r + len, 0),        paint);
    canvas.drawLine(const Offset(0, r),        Offset(0, r + len),        paint);
    // Top-right
    canvas.drawLine(Offset(size.width - r - len, 0),
        Offset(size.width - r, 0),       paint);
    canvas.drawLine(Offset(size.width, r),
        Offset(size.width, r + len),     paint);
    // Bottom-left
    canvas.drawLine(Offset(0, size.height - r),
        Offset(0, size.height - r - len),paint);
    canvas.drawLine(Offset(r, size.height),
        Offset(r + len, size.height),    paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height - r),
        Offset(size.width, size.height - r - len), paint);
    canvas.drawLine(Offset(size.width - r - len, size.height),
        Offset(size.width - r, size.height),       paint);
  }

  @override
  bool shouldRepaint(_) => false;
}