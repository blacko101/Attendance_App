import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_attend/features/auth/controllers/auth_controller.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/student/controllers/profile_controller.dart';
import 'package:smart_attend/features/student/models/profile_model.dart';
import 'package:smart_attend/features/auth/views/mobile/login_screen.dart';

const _kCherry   = Color(0xFF9B1B42);
const _kCherryBg = Color(0xFFFFEEF2);
const _kGreen    = Color(0xFF4CAF50);
const _kBg       = Color(0xFFEEEEF3);
const _kCard     = Color(0xFFF5F5F8);
const _kWhite    = Color(0xFFFFFFFF);

class ProfileScreen extends StatefulWidget {
  static String id = 'profile_screen';
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileController = ProfileController();
  final _authController    = AuthController();

  ProfileModel? _profile;
  bool _loading         = true;
  bool _notificationsOn = true;
  bool _isDarkMode      = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final authUser = await SessionService.getSession();
      if (authUser == null) {
        if (mounted) _navigateToLogin();
        return;
      }
      final profile = await _profileController.fetchProfile(authUser);
      if (mounted) {
        setState(() { _profile = profile; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateToLogin() {
    Navigator.pushNamedAndRemoveUntil(
        context, LoginScreen.id, (route) => false);
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Logout',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to logout?',
            style: GoogleFonts.poppins(
                fontSize: 14, color: Colors.grey.shade600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kCherry,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _authController.logout(context);
            },
            child: Text('Logout',
                style: GoogleFonts.poppins(
                    color: _kWhite, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _handleChangePassword() {
    // FIX 8: Removed leading underscore from local variables —
    //        local vars cannot start with _ in Dart (lint warning)
    final currentPwCtrl = TextEditingController();
    final newPwCtrl     = TextEditingController();
    final confirmPwCtrl = TextEditingController();
    bool obscure1 = true, obscure2 = true, obscure3 = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: _kWhite,
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Text('Change Password',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              _PwField(
                label: 'Current Password',
                controller: currentPwCtrl,
                obscure: obscure1,
                onToggle: () =>
                    setSheetState(() => obscure1 = !obscure1),
              ),
              const SizedBox(height: 14),
              _PwField(
                label: 'New Password',
                controller: newPwCtrl,
                obscure: obscure2,
                onToggle: () =>
                    setSheetState(() => obscure2 = !obscure2),
              ),
              const SizedBox(height: 14),
              _PwField(
                label: 'Confirm New Password',
                controller: confirmPwCtrl,
                obscure: obscure3,
                onToggle: () =>
                    setSheetState(() => obscure3 = !obscure3),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kCherry,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    // TODO: wire to PATCH /api/auth/change-password
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(
                      content: Text('Password updated successfully',
                          style: GoogleFonts.poppins(fontSize: 13)),
                      backgroundColor: _kGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                  child: Text('Update Password',
                      style: GoogleFonts.poppins(
                          color: _kWhite,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      // FIX 9: Profile screen now has its own Scaffold with no
      //        AppBar — SafeArea is handled inside _buildBody
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: _kCherry))
          : _profile == null
          ? _ErrorState(onRetry: _loadProfile)
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final p = _profile!;
    return SingleChildScrollView(
      child: Column(children: [
        _buildHeader(p),
        _buildStudentInfoCard(p),
        const SizedBox(height: 16),
        _buildAttendanceSummary(p),
        const SizedBox(height: 16),
        _buildSettingsSection(),
        const SizedBox(height: 16),
        _buildAccountActions(),
        // FIX 10: Bottom padding so logout button isn't hidden
        //         behind the nav bar
        const SizedBox(height: 100),
      ]),
    );
  }

  // ── CHERRY HEADER ─────────────────────────────────────────────────────────
  Widget _buildHeader(ProfileModel p) {
    return Container(
      width: double.infinity,
      color: _kCherry,
      // FIX 11: Use MediaQuery padding.top for proper status bar spacing
      //         since this screen is inside IndexedStack (no AppBar)
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 40,
        left: 20, right: 20,
      ),
      child: Column(children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _kWhite, width: 3),
                color: _kWhite.withValues(alpha: 0.2),
              ),
              child: p.profileImageUrl != null
                  ? ClipOval(
                  child: Image.network(p.profileImageUrl!,
                      fit: BoxFit.cover))
                  : Center(
                  child: Text(p.initials,
                      style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: _kWhite))),
            ),
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: _kWhite,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4)],
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 14, color: _kCherry),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(p.fullName,
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _kWhite)),
        const SizedBox(height: 4),
        Text(p.programme,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 13, color: _kWhite.withValues(alpha: 0.8))),
        const SizedBox(height: 8),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: _kWhite.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(p.role.toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kWhite,
                  letterSpacing: 1)),
        ),
      ]),
    );
  }

  // ── STUDENT INFO CARD ─────────────────────────────────────────────────────
  Widget _buildStudentInfoCard(ProfileModel p) {
    return Transform.translate(
      offset: const Offset(0, -20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _kWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
            _InfoRow(icon: Icons.badge_rounded,
                label: 'Index Number', value: p.indexNumber),
            _Divider(),
            _InfoRow(icon: Icons.school_rounded,
                label: 'Programme', value: p.programme),
            _Divider(),
            _InfoRow(icon: Icons.bar_chart_rounded,
                label: 'Level', value: '${p.level} Level'),
            _Divider(),
            _InfoRow(icon: Icons.mail_outline_rounded,
                label: 'Email', value: p.email),
            _Divider(),
            _InfoRow(icon: Icons.calendar_today_rounded,
                label: 'Academic Year', value: p.academicYear),
          ]),
        ),
      ),
    );
  }

  // ── ATTENDANCE SUMMARY ────────────────────────────────────────────────────
  Widget _buildAttendanceSummary(ProfileModel p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Semester Summary',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A))),
          const SizedBox(height: 16),
          Row(children: [
            SizedBox(
              width: 80, height: 80,
              child: CustomPaint(
                painter:
                _RingPainter(percentage: p.attendanceRate / 100),
                child: Center(
                    child: Text('${p.attendancePercent}%',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1A1A)))),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(children: [
                _SummaryRow(
                    label: 'Total Classes',
                    value: '${p.totalClasses}',
                    color: Colors.grey.shade600),
                const SizedBox(height: 8),
                _SummaryRow(
                    label: 'Attended',
                    value: '${p.attended}',
                    color: _kGreen),
                const SizedBox(height: 8),
                _SummaryRow(
                    label: 'Absent',
                    value: '${p.absent}',
                    color: _kCherry),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: p.attendanceRate / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                  p.attendanceRate >= 75 ? _kGreen : _kCherry),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
              p.attendanceRate >= 75
                  ? '✅ Attendance is on track'
                  : '⚠️ Attendance below required threshold',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color:
                  p.attendanceRate >= 75 ? _kGreen : _kCherry,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  // ── SETTINGS ──────────────────────────────────────────────────────────────
  Widget _buildSettingsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: _kWhite,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(children: [
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Push Notifications',
            subtitle: 'Get alerts for upcoming classes',
            trailing: Switch(
              value: _notificationsOn,
              activeThumbColor: _kCherry,
              onChanged: (v) =>
                  setState(() => _notificationsOn = v),
            ),
          ),
          _Divider(),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            label: 'Dark Mode',
            subtitle: 'Switch app appearance',
            trailing: Switch(
              value: _isDarkMode,
              activeThumbColor: _kCherry,
              onChanged: (v) {
                setState(() => _isDarkMode = v);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Dark mode coming soon!',
                      style: GoogleFonts.poppins(fontSize: 13)),
                  backgroundColor: Colors.grey.shade700,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 2),
                ));
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ── ACCOUNT ACTIONS ───────────────────────────────────────────────────────
  Widget _buildAccountActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: _kWhite,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(children: [
          _ActionTile(
            icon: Icons.lock_outline_rounded,
            label: 'Change Password',
            iconColor: Colors.blue.shade400,
            onTap: _handleChangePassword,
          ),
          _Divider(),
          _ActionTile(
            icon: Icons.logout_rounded,
            label: 'Logout',
            iconColor: _kCherry,
            labelColor: _kCherry,
            onTap: _handleLogout,
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  REUSABLE WIDGETS
// ─────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  const _InfoRow(
      {required this.icon,
        required this.label,
        required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: _kCherryBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: _kCherry),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey.shade400)),
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A))),
            ]),
      ),
    ]),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String   label, subtitle;
  final Widget   trailing;
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: _kCherryBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: _kCherry),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A))),
              Text(subtitle,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey.shade400)),
            ]),
      ),
      trailing,
    ]),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        iconColor;
  final Color        labelColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
    this.labelColor = const Color(0xFF1A1A1A),
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: labelColor)),
        const Spacer(),
        Icon(Icons.chevron_right_rounded,
            color: Colors.grey.shade300, size: 20),
      ]),
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _SummaryRow(
      {required this.label,
        required this.value,
        required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 12, color: Colors.grey.shade500)),
      Text(value,
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color)),
    ],
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
      color: Colors.grey.shade100, thickness: 1, height: 1);
}

class _PwField extends StatelessWidget {
  final String                label;
  final TextEditingController controller;
  final bool                  obscure;
  final VoidCallback          onToggle;
  const _PwField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(
          fontSize: 13, color: Colors.grey.shade500),
      filled: true,
      fillColor: _kBg,
      suffixIcon: IconButton(
        icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.grey,
            size: 18),
        onPressed: onToggle,
      ),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: _kCherry, width: 1.5)),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Could not load profile',
              style: GoogleFonts.poppins(color: Colors.grey.shade400)),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _kCherry),
            onPressed: onRetry,
            child: Text('Retry',
                style: GoogleFonts.poppins(color: _kWhite)),
          ),
        ]),
  );
}

class _RingPainter extends CustomPainter {
  final double percentage;
  _RingPainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final c  = Offset(size.width / 2, size.height / 2);
    final r  = size.width / 2 - 8;
    const sw = 8.0;
    const start = -pi * 0.5;
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start, pi * 2, false,
        Paint()
          ..color       = Colors.grey.shade200
          ..style       = PaintingStyle.stroke
          ..strokeWidth = sw);
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start, pi * 2 * percentage, false,
        Paint()
          ..color       = percentage >= 0.75 ? _kGreen : _kCherry
          ..style       = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap   = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.percentage != percentage;
}