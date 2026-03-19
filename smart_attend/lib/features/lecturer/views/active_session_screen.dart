import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_attend/features/lecturer/controllers/lecturer_controller.dart';
import 'package:smart_attend/features/lecturer/models/lecturer_model.dart';

// ── Theme constants ────────────────────────────
const _kCherry = Color(0xFF9B1B42);
const _kCherryBg = Color(0xFFFFEEF2);
const _kGreen = Color(0xFF4CAF50);
const _kGreenBg = Color(0xFFE8F5E9);
const _kOrange = Color(0xFFFF9800);
const _kOrangeBg = Color(0xFFFFF3E0);
const _kBg = Color(0xFFEEEEF3);
const _kWhite = Color(0xFFFFFFFF);
const _kText = Color(0xFF1A1A1A);
const _kSubtext = Color(0xFF888888);

// QR rotates every 15 seconds (silently)
const _kQrRotateSeconds = 15;
// 6-digit code rotates every 20 seconds
const _kCodeRotateSeconds = 20;
// How often we poll the backend for student count
const _kCountPollSeconds = 5;

class ActiveSessionScreen extends StatefulWidget {
  final ActiveSessionModel session;
  final LecturerController ctrl;
  final VoidCallback onEnded;

  const ActiveSessionScreen({
    super.key,
    required this.session,
    required this.ctrl,
    required this.onEnded,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen>
    with WidgetsBindingObserver {
  // ── Live state ──────────────────────────────────────────────────
  late String _qrData;
  late String _sixDigitCode;
  late int _secondsLeft;
  int _studentsMarked = 0;

  // ── Timers ──────────────────────────────────────────────────────
  Timer? _countdownTimer;
  Timer? _qrRotateTimer;
  Timer? _codeRotateTimer;
  Timer? _countPollTimer;

  // ── QR visual state ─────────────────────────────────────────────
  // We crossfade between two QR widgets so the rotation is seamless.
  // Students never see a blank QR — the old one stays visible until
  // the new one is fully rendered.
  bool _qrVisible = true; // controls opacity of the QR widget
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _qrData = widget.session.qrData;
    _sixDigitCode = widget.session.sixDigitCode;
    _secondsLeft = widget.session.secondsLeft;
    _studentsMarked = widget.session.studentsMarked;
    _startAllTimers();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelAllTimers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resume timers when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _startAllTimers();
    } else if (state == AppLifecycleState.paused) {
      _cancelAllTimers();
    }
  }

  // ── Timer management ────────────────────────────────────────────
  void _startAllTimers() {
    _startCountdown();
    if (widget.session.method == AttendanceMethod.qrCode) {
      _startQrRotation();
    } else {
      _startCodeRotation();
    }
    _startCountPoll();
  }

  void _cancelAllTimers() {
    _countdownTimer?.cancel();
    _qrRotateTimer?.cancel();
    _codeRotateTimer?.cancel();
    _countPollTimer?.cancel();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
          _cancelAllTimers();
          // Session expired — end it and go back
          _endSession(expired: true);
        }
      });
    });
  }

  void _startQrRotation() {
    _qrRotateTimer?.cancel();
    // Rotate every 15 seconds
    _qrRotateTimer = Timer.periodic(
      const Duration(seconds: _kQrRotateSeconds),
          (_) => _rotateQr(),
    );
  }

  void _startCodeRotation() {
    _codeRotateTimer?.cancel();
    _codeRotateTimer = Timer.periodic(
      const Duration(seconds: _kCodeRotateSeconds),
          (_) => _rotateCode(),
    );
  }

  // Fetch a fresh code from the backend and update the display.
  // If the request fails (e.g. brief network blip), we keep showing
  // the old code — the next rotation attempt will try again.
  Future<void> _rotateCode() async {
    if (!mounted) return;
    final newCode = await widget.ctrl.refreshCode(
      sessionId: widget.session.sessionId,
    );
    if (newCode != null && mounted) {
      setState(() => _sixDigitCode = newCode);
    }
  }

  void _startCountPoll() {
    _countPollTimer?.cancel();
    _countPollTimer = Timer.periodic(
      const Duration(seconds: _kCountPollSeconds),
          (_) => _pollStudentCount(),
    );
  }

  // ── QR rotation logic ────────────────────────────────────────────
  // We silently fetch a fresh signed payload from the backend.
  // The old QR stays visible during the network call — students
  // scanning during this brief window will still succeed because
  // the backend validates against the session's main expiresAt,
  // not the QR's short window.
  Future<void> _rotateQr() async {
    if (_isRefreshing || !mounted) return;
    _isRefreshing = true;

    final newPayload = await widget.ctrl.refreshQrPayload(
      sessionId: widget.session.sessionId,
      courseName: widget.session.courseName,
    );

    if (!mounted) {
      _isRefreshing = false;
      return;
    }

    if (newPayload != null) {
      // Fade out briefly (100ms), swap data, fade back in
      setState(() => _qrVisible = false);
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) {
        _isRefreshing = false;
        return;
      }
      setState(() {
        _qrData = jsonEncode(newPayload);
        _qrVisible = true;
      });
    }

    _isRefreshing = false;
  }

  // ── Student count poll ───────────────────────────────────────────
  Future<void> _pollStudentCount() async {
    final count = await widget.ctrl.getSessionCount(widget.session.sessionId);
    if (mounted) setState(() => _studentsMarked = count);
  }

  // ── End session ──────────────────────────────────────────────────
  Future<void> _endSession({bool expired = false}) async {
    _cancelAllTimers();

    if (!expired) {
      // Manual end — confirm
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'End Session?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'This will stop students from marking attendance. '
                'Are you sure?',
            style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: _kSubtext),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kCherry,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'End Session',
                style: GoogleFonts.poppins(
                  color: _kWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        // Restart timers if user cancelled
        _startAllTimers();
        return;
      }
    }

    await widget.ctrl.endSessionOnBackend(widget.session.sessionId);
    if (mounted) {
      widget.onEnded();
      Navigator.pop(context);
    }
  }

  // ── Timer display ────────────────────────────────────────────────
  String get _timeDisplay {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _timerColor {
    if (_secondsLeft > 120) return _kGreen;
    if (_secondsLeft > 30) return _kOrange;
    return _kCherry;
  }

  // ── QR rotation indicator ────────────────────────────────────────
  // Shows how many seconds until the next QR rotation so the lecturer
  // knows why the QR is about to change (but students never see this).
  int get _secondsUntilQrRotate {
    final elapsed = widget.session.totalSeconds - _secondsLeft;
    return _kQrRotateSeconds - (elapsed % _kQrRotateSeconds);
  }

  int get _secondsUntilCodeRotate {
    final elapsed = widget.session.totalSeconds - _secondsLeft;
    return _kCodeRotateSeconds - (elapsed % _kCodeRotateSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final isQr = widget.session.method == AttendanceMethod.qrCode;

    return PopScope(
      canPop: false, // prevent accidental back-press
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────────────
              _buildHeader(),

              // ── Body ───────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // Session info strip
                      _buildInfoStrip(),
                      const SizedBox(height: 20),

                      // QR or 6-digit code
                      isQr ? _buildQrPanel() : _buildCodePanel(),
                      const SizedBox(height: 20),

                      // Student count
                      _buildCountCard(),
                      const SizedBox(height: 20),

                      // End session button
                      _buildEndButton(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header with countdown ────────────────────────────────────────
  Widget _buildHeader() => Container(
    padding: EdgeInsets.only(top: 16, bottom: 16, left: 20, right: 20),
    decoration: const BoxDecoration(color: _kCherry),
    child: Row(
      children: [
        // Course info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.session.courseCode,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _kWhite,
                ),
              ),
              Text(
                widget.session.courseName,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _kWhite.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        // Countdown pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _timerColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _timerColor.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_rounded, size: 16, color: _timerColor),
              const SizedBox(width: 6),
              Text(
                _timeDisplay,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _timerColor,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Session info strip ───────────────────────────────────────────
  Widget _buildInfoStrip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _InfoChip(
          icon: widget.session.type == AttendanceType.inPerson
              ? Icons.location_on_rounded
              : Icons.wifi_rounded,
          label: widget.session.type == AttendanceType.inPerson
              ? 'In-Person'
              : 'Online',
          color: _kCherry,
          bg: _kCherryBg,
        ),
        _InfoChip(
          icon: widget.session.method == AttendanceMethod.qrCode
              ? Icons.qr_code_rounded
              : Icons.pin_rounded,
          label: widget.session.method == AttendanceMethod.qrCode
              ? 'QR Code'
              : '6-Digit Code',
          color: const Color(0xFF1565C0),
          bg: const Color(0xFFE3F2FD),
        ),
        _InfoChip(
          icon: Icons.people_rounded,
          label: '$_studentsMarked marked',
          color: _kGreen,
          bg: _kGreenBg,
        ),
      ],
    ),
  );

  // ── QR Panel ─────────────────────────────────────────────────────
  Widget _buildQrPanel() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Text(
          'Scan to Mark Attendance',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'QR updates automatically — students won\'t notice',
          style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
        ),
        const SizedBox(height: 20),

        // Animated QR — crossfades on rotation
        AnimatedOpacity(
          opacity: _qrVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: QrImageView(
            data: _qrData,
            version: QrVersions.auto,
            size: 240,
            backgroundColor: _kWhite,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: _kCherry,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: _kText,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Rotation indicator (lecturer-only info)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded, size: 13, color: _kSubtext),
              const SizedBox(width: 5),
              Text(
                'Refreshes in ${_secondsUntilQrRotate}s',
                style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        // Location note for in-person
        if (widget.session.type == AttendanceType.inPerson)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kGreenBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: _kGreen),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Location locked — students must be within 50m to check in',
                    style: GoogleFonts.poppins(fontSize: 11, color: _kGreen),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  // ── 6-Digit Code Panel ───────────────────────────────────────────
  Widget _buildCodePanel() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Text(
          'Share This Code',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Code changes every ${_kCodeRotateSeconds}s automatically',
          style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
        ),
        const SizedBox(height: 24),

        // Big code display
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Digit boxes
            ..._sixDigitCode
                .split('')
                .map(
                  (d) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 46,
                height: 58,
                decoration: BoxDecoration(
                  color: _kCherryBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _kCherry.withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    d,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _kCherry,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Copy button
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: _sixDigitCode));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Code copied to clipboard'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.copy_rounded, size: 14, color: _kSubtext),
                const SizedBox(width: 6),
                Text(
                  'Copy code',
                  style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Rotation countdown bar
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Next code in',
                  style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
                ),
                Text(
                  '${_secondsUntilCodeRotate}s',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kCherry,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _secondsUntilCodeRotate / _kCodeRotateSeconds,
                backgroundColor: _kBg,
                valueColor: const AlwaysStoppedAnimation<Color>(_kCherry),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  // ── Student count card ───────────────────────────────────────────
  Widget _buildCountCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _kGreenBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.how_to_reg_rounded, color: _kGreen, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Students Marked',
                style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
              ),
              Text(
                '$_studentsMarked'
                    '${widget.session.totalStudents > 0 ? " / ${widget.session.totalStudents}" : ""}',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _kText,
                ),
              ),
            ],
          ),
        ),
        // Progress ring
        if (widget.session.totalStudents > 0)
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              value: _studentsMarked / widget.session.totalStudents,
              strokeWidth: 5,
              backgroundColor: _kBg,
              valueColor: const AlwaysStoppedAnimation<Color>(_kGreen),
            ),
          ),
      ],
    ),
  );

  // ── End session button ───────────────────────────────────────────
  Widget _buildEndButton() => SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: _kCherry, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.stop_circle_outlined, color: _kCherry, size: 20),
      label: Text(
        'End Session',
        style: GoogleFonts.poppins(
          color: _kCherry,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      onPressed: () => _endSession(),
    ),
  );
}

// ── Small info chip ────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}