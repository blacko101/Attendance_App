import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/lecturer/controllers/lecturer_controller.dart';
import 'package:smart_attend/features/lecturer/models/lecturer_model.dart';
import 'package:smart_attend/features/auth/views/mobile/login_screen.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';

// ── Theme ──────────────────────────────────────
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

class LecturerDashboard extends StatefulWidget {
  static String id = 'lecturer_dashboard';
  const LecturerDashboard({super.key});

  @override
  State<LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard> {
  final _ctrl = LecturerController();

  int _navIndex = 0; // 0=Home 1=Schedule 2=Courses 3=Profile

  LecturerModel? _lecturer;
  Map<String, int> _todayStats = {};
  List<LecturerCourseModel> _courses = [];
  List<WeeklySessionModel> _schedule = [];
  bool _loading = true;

  // ── Active session state ──
  ActiveSessionModel? _activeSession;
  Timer? _countdownTimer;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    // FIX: load the real authenticated user's ID from the persisted
    // session instead of the hardcoded placeholder 'lec_001'.
    final authSession = await SessionService.getSession();
    final userId = authSession?.id ?? '';

    final results = await Future.wait([
      _ctrl.fetchProfile(userId),
      _ctrl.fetchTodayStats(userId),
      _ctrl.fetchCourses(userId),
      _ctrl.fetchWeeklySchedule(userId),
    ]);
    if (!mounted) return;
    setState(() {
      _lecturer = results[0] as LecturerModel;
      _todayStats = results[1] as Map<String, int>;
      _courses = results[2] as List<LecturerCourseModel>;
      _schedule = results[3] as List<WeeklySessionModel>;
      _loading = false;
    });
  }

  // ── START SESSION ──────────────────────────────────────────────────────
  Future<void> _startSession(
    LecturerCourseModel course,
    AttendanceType type,
    int durationSeconds,
  ) async {
    final session = await _ctrl.startSession(
      course: course,
      type: type,
      durationSeconds: durationSeconds,
    );
    if (session == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get location. Enable GPS and retry.'),
            backgroundColor: _kCherry,
          ),
        );
      }
      return;
    }

    setState(() => _activeSession = session);
    _startTimers();
  }

  void _startTimers() {
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();

    final refreshEvery = _activeSession!.type == AttendanceType.inPerson
        ? LecturerController.refreshInPerson
        : LecturerController.refreshOnline;

    // Countdown — tick every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_activeSession == null) {
          t.cancel();
          return;
        }
        final left = _activeSession!.secondsLeft - 1;
        if (left <= 0) {
          t.cancel();
          _refreshTimer?.cancel();
          _activeSession = null; // session ended
        } else {
          _activeSession = _activeSession!.copyWith(secondsLeft: left);
        }
      });
    });

    // QR + code refresh
    _refreshTimer = Timer.periodic(Duration(seconds: refreshEvery), (t) {
      if (!mounted || _activeSession == null) {
        t.cancel();
        return;
      }
      setState(() {
        _activeSession = _ctrl.refreshCodes(_activeSession!);
      });
    });
  }

  // FIX: call the backend PATCH endpoint to mark the session
  // isActive:false before clearing local state. Without this,
  // the session stays open in MongoDB indefinitely — students
  // could continue checking in after the lecturer pressed End.
  Future<void> _endSession() async {
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();

    final sessionId = _activeSession?.sessionId;
    setState(() => _activeSession = null);

    if (sessionId != null) {
      // Fire-and-forget: if the API call fails, the session will
      // still auto-expire via expiresAt on the backend.
      await _ctrl.endSessionOnBackend(sessionId);
    }
  }

  // ── LOGOUT ─────────────────────────────────────────────────────────────
  void _logout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade500),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kCherry,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await SessionService.clearSession();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  LoginScreen.id,
                  (_) => false,
                );
              }
            },
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(
                color: _kWhite,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kCherry)),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: _kBg,
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  // ── WIDE LAYOUT (web / tablet ≥900px) ─────────────────────────────────
  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left sidebar nav
        _SideNav(
          index: _navIndex,
          lecturer: _lecturer!,
          onTap: (i) => setState(() => _navIndex = i),
          onLogout: _logout,
        ),
        // Main content
        Expanded(child: _buildPage()),
      ],
    );
  }

  // ── NARROW LAYOUT (mobile) ─────────────────────────────────────────────
  Widget _buildNarrowLayout() {
    return Scaffold(
      backgroundColor: _kBg,
      body: _buildPage(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() => BottomAppBar(
    color: _kWhite,
    elevation: 12,
    padding: EdgeInsets.zero,
    child: SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomNavItem(0, Icons.dashboard_outlined, 'Home'),
          _buildBottomNavItem(1, Icons.calendar_month_rounded, 'Schedule'),
          _buildBottomNavItem(2, Icons.book_outlined, 'Courses'),
          _buildBottomNavItem(3, Icons.person_outline_rounded, 'Profile'),
        ],
      ),
    ),
  );

  Widget _buildBottomNavItem(int i, IconData icon, String label) {
    final active = _navIndex == i;
    return GestureDetector(
      onTap: () => setState(() => _navIndex = i),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? _kCherry : _kSubtext, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? _kCherry : _kSubtext,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage() {
    switch (_navIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return _buildSchedulePage();
      case 2:
        return _buildCoursesPage();
      case 3:
        return _buildProfilePage();
      default:
        return _buildHomePage();
    }
  }

  // ══════════════════════════════════════════════
  //  PAGE 0 — HOME
  // ══════════════════════════════════════════════
  Widget _buildHomePage() {
    return Column(
      children: [
        _PageHeader(
          title: 'Welcome, ${_lecturer!.firstName} 👋',
          subtitle: 'Here\'s your teaching overview for today',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final wide = constraints.maxWidth >= 700;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Today's stats row
                    _buildTodayStatsRow(wide),
                    const SizedBox(height: 28),

                    // Active session banner (if any)
                    if (_activeSession != null) ...[
                      _ActiveSessionBanner(
                        session: _activeSession!,
                        onEnd: _endSession,
                      ),
                      const SizedBox(height: 28),
                    ],

                    // Generate attendance section
                    Text(
                      'Generate Attendance',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ..._courses.map(
                      (c) => _CourseAttendanceCard(
                        course: c,
                        isActive: _activeSession?.courseCode == c.courseCode,
                        onStart: _activeSession == null
                            ? (type, secs) => _startSession(c, type, secs)
                            : null,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayStatsRow(bool wide) {
    final stats = [
      _StatDef(
        'Scheduled',
        '${_todayStats['scheduled'] ?? 0}',
        Icons.event_rounded,
        _kCherry,
        _kCherryBg,
      ),
      _StatDef(
        'Attended',
        '${_todayStats['attended'] ?? 0}',
        Icons.check_circle_rounded,
        _kGreen,
        _kGreenBg,
      ),
      _StatDef(
        'Missed',
        '${_todayStats['missed'] ?? 0}',
        Icons.cancel_rounded,
        Colors.red,
        const Color(0xFFFFEBEE),
      ),
      _StatDef(
        'In-Person',
        '${_todayStats['inPerson'] ?? 0}',
        Icons.location_on_rounded,
        _kOrange,
        _kOrangeBg,
      ),
    ];

    if (wide) {
      return Row(
        children: stats
            .map(
              (s) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _StatCard(def: s),
                ),
              ),
            )
            .toList(),
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: stats.map((s) => _StatCard(def: s)).toList(),
    );
  }

  // ══════════════════════════════════════════════
  //  PAGE 1 — SCHEDULE
  // ══════════════════════════════════════════════
  Widget _buildSchedulePage() {
    return Column(
      children: [
        const _PageHeader(
          title: 'Weekly Schedule',
          subtitle: 'All your classes this week',
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: _schedule.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _ScheduleCard(
              session: _schedule[i],
              onMarkNotHeld: (reason) {
                setState(() {
                  _schedule[i] = WeeklySessionModel(
                    id: _schedule[i].id,
                    courseCode: _schedule[i].courseCode,
                    courseName: _schedule[i].courseName,
                    room: _schedule[i].room,
                    date: _schedule[i].date,
                    startTime: _schedule[i].startTime,
                    endTime: _schedule[i].endTime,
                    status: SessionStatus.notHeld,
                    totalStudents: _schedule[i].totalStudents,
                    notHeldReason: reason,
                  );
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  //  PAGE 2 — COURSES
  // ══════════════════════════════════════════════
  Widget _buildCoursesPage() {
    return Column(
      children: [
        const _PageHeader(
          title: 'My Courses',
          subtitle: 'Courses assigned this semester',
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: _courses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _CourseInfoCard(course: _courses[i]),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  //  PAGE 3 — PROFILE
  // ══════════════════════════════════════════════
  void _handleChangePassword() {
    final currentPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();
    final confirmPwCtrl = TextEditingController();
    bool obscure1 = true, obscure2 = true, obscure3 = true;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: _kWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Change Password',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                _LecturerPwField(
                  label: 'Current Password',
                  controller: currentPwCtrl,
                  obscure: obscure1,
                  onToggle: () => setSheetState(() => obscure1 = !obscure1),
                ),
                const SizedBox(height: 14),
                _LecturerPwField(
                  label: 'New Password',
                  controller: newPwCtrl,
                  obscure: obscure2,
                  onToggle: () => setSheetState(() => obscure2 = !obscure2),
                ),
                const SizedBox(height: 14),
                _LecturerPwField(
                  label: 'Confirm New Password',
                  controller: confirmPwCtrl,
                  obscure: obscure3,
                  onToggle: () => setSheetState(() => obscure3 = !obscure3),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kCherry,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final current = currentPwCtrl.text.trim();
                            final newPw = newPwCtrl.text;
                            final confirm = confirmPwCtrl.text;

                            void showErr(String msg) =>
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      msg,
                                      style: GoogleFonts.poppins(fontSize: 13),
                                    ),
                                    backgroundColor: _kCherry,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );

                            if (current.isEmpty ||
                                newPw.isEmpty ||
                                confirm.isEmpty) {
                              showErr('Please fill in all fields.');
                              return;
                            }
                            if (newPw.length < 8) {
                              showErr(
                                'New password must be at least 8 characters.',
                              );
                              return;
                            }
                            if (newPw != confirm) {
                              showErr('New passwords do not match.');
                              return;
                            }

                            setSheetState(() => isSubmitting = true);
                            try {
                              final session = await SessionService.getSession();
                              if (session == null) {
                                Navigator.pop(ctx);
                                return;
                              }

                              final response = await http
                                  .post(
                                    Uri.parse(
                                      '${AppConfig.authUrl}/change-password',
                                    ),
                                    headers: {
                                      'Content-Type': 'application/json',
                                      'Authorization':
                                          'Bearer ${session.token}',
                                    },
                                    body: jsonEncode({
                                      'currentPassword': current,
                                      'newPassword': newPw,
                                    }),
                                  )
                                  .timeout(const Duration(seconds: 15));

                              if (!ctx.mounted) return;
                              if (response.statusCode == 200) {
                                Navigator.pop(ctx);
                                if (mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Password updated successfully',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                        ),
                                      ),
                                      backgroundColor: _kGreen,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                              } else {
                                final body =
                                    jsonDecode(response.body)
                                        as Map<String, dynamic>;
                                showErr(
                                  body['message'] as String? ??
                                      'Failed to change password.',
                                );
                              }
                            } catch (_) {
                              if (ctx.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Connection error. Check your internet.',
                                      style: GoogleFonts.poppins(fontSize: 13),
                                    ),
                                    backgroundColor: _kCherry,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                            } finally {
                              if (ctx.mounted)
                                setSheetState(() => isSubmitting = false);
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: _kWhite,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Update Password',
                            style: GoogleFonts.poppins(
                              color: _kWhite,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePage() {
    final p = _lecturer!;
    return SingleChildScrollView(
      child: Column(
        children: [
          // Cherry header
          Container(
            width: double.infinity,
            color: _kCherry,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 40,
              left: 24,
              right: 24,
            ),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _kWhite, width: 3),
                    color: _kWhite.withValues(alpha: 0.2),
                  ),
                  child: Center(
                    child: Text(
                      p.initials,
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: _kWhite,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  p.displayTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _kWhite,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.department,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: _kWhite.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _kWhite.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'LECTURER',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kWhite,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info card
          Transform.translate(
            offset: const Offset(0, -20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _kWhite,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _ProfileInfoRow(
                      icon: Icons.badge_rounded,
                      label: 'Staff ID',
                      value: p.staffId,
                    ),
                    const _PDivider(),
                    _ProfileInfoRow(
                      icon: Icons.school_rounded,
                      label: 'Department',
                      value: p.department,
                    ),
                    const _PDivider(),
                    _ProfileInfoRow(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: p.email,
                    ),
                    const _PDivider(),
                    _ProfileInfoRow(
                      icon: Icons.book_outlined,
                      label: 'Courses',
                      value: '${_courses.length} assigned',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Change Password
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kCherry),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.lock_outline_rounded,
                  color: _kCherry,
                  size: 18,
                ),
                label: Text(
                  'Change Password',
                  style: GoogleFonts.poppins(
                    color: _kCherry,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _handleChangePassword,
              ),
            ),
          ),

          // Logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kCherry,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.logout_rounded,
                  color: _kWhite,
                  size: 18,
                ),
                label: Text(
                  'Logout',
                  style: GoogleFonts.poppins(
                    color: _kWhite,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _logout,
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  SIDE NAV (wide layout only)
// ══════════════════════════════════════════════
class _SideNav extends StatelessWidget {
  final int index;
  final LecturerModel lecturer;
  final ValueChanged<int> onTap;
  final VoidCallback onLogout;
  const _SideNav({
    required this.index,
    required this.lecturer,
    required this.onTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(Icons.dashboard_outlined, 'Dashboard'),
      _NavItem(Icons.calendar_month_rounded, 'Schedule'),
      _NavItem(Icons.book_outlined, 'Courses'),
      _NavItem(Icons.person_outline_rounded, 'Profile'),
    ];

    return Container(
      width: 240,
      color: _kCherry,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // Logo / app name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'SmartAttend',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _kWhite,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Lecturer Portal',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: _kWhite.withValues(alpha: 0.7),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Avatar + name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _kWhite.withValues(alpha: 0.2),
                    child: Text(
                      lecturer.initials,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _kWhite,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lecturer.firstName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kWhite,
                          ),
                        ),
                        Text(
                          'Lecturer',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _kWhite.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Divider(color: _kWhite.withValues(alpha: 0.15)),
            const SizedBox(height: 8),

            // Nav items
            ...List.generate(items.length, (i) {
              final active = i == index;
              return GestureDetector(
                onTap: () => onTap(i),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 3,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? _kWhite.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        items[i].icon,
                        color: active
                            ? _kWhite
                            : _kWhite.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        items[i].label,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: active
                              ? _kWhite
                              : _kWhite.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const Spacer(),
            Divider(color: _kWhite.withValues(alpha: 0.15)),

            // Logout
            GestureDetector(
              onTap: onLogout,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: _kWhite.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _kWhite.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

// ══════════════════════════════════════════════
//  PAGE HEADER
// ══════════════════════════════════════════════
class _PageHeader extends StatelessWidget {
  final String title, subtitle;
  const _PageHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 16,
      bottom: 20,
      left: 24,
      right: 24,
    ),
    decoration: const BoxDecoration(
      color: _kWhite,
      border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════
//  STAT CARD
// ══════════════════════════════════════════════
class _StatDef {
  final String label, value;
  final IconData icon;
  final Color color, bg;
  const _StatDef(this.label, this.value, this.icon, this.color, this.bg);
}

class _StatCard extends StatelessWidget {
  final _StatDef def;
  const _StatCard({required this.def});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: def.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(def.icon, color: def.color, size: 22),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              def.value,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _kText,
              ),
            ),
            Text(
              def.label,
              style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
            ),
          ],
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════
//  ACTIVE SESSION BANNER
// ══════════════════════════════════════════════
class _ActiveSessionBanner extends StatelessWidget {
  final ActiveSessionModel session;
  final VoidCallback onEnd;
  const _ActiveSessionBanner({required this.session, required this.onEnd});

  String get _timeDisplay {
    final m = (session.secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (session.secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _timerColor {
    if (session.secondsLeft > 120) return _kGreen;
    if (session.secondsLeft > 30) return _kOrange;
    return _kCherry;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCherry.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _kCherry.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isWide ? _buildWide(context) : _buildNarrow(context),
    );
  }

  Widget _buildWide(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // QR Code
      _QrPanel(session: session),
      const SizedBox(width: 28),
      // Info + code
      Expanded(
        child: _InfoPanel(
          session: session,
          timerColor: _timerColor,
          timeDisplay: _timeDisplay,
          onEnd: onEnd,
        ),
      ),
    ],
  );

  Widget _buildNarrow(BuildContext context) => Column(
    children: [
      _InfoPanel(
        session: session,
        timerColor: _timerColor,
        timeDisplay: _timeDisplay,
        onEnd: onEnd,
      ),
      const SizedBox(height: 20),
      _QrPanel(session: session),
    ],
  );
}

class _QrPanel extends StatelessWidget {
  final ActiveSessionModel session;
  const _QrPanel({required this.session});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFEEEEEE)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        QrImageView(
          data: session.qrData,
          version: QrVersions.auto,
          size: 180,
          backgroundColor: _kWhite,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: _kCherry,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Scan to mark attendance',
          style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
        ),
      ],
    ),
  );
}

class _InfoPanel extends StatelessWidget {
  final ActiveSessionModel session;
  final Color timerColor;
  final String timeDisplay;
  final VoidCallback onEnd;
  const _InfoPanel({
    required this.session,
    required this.timerColor,
    required this.timeDisplay,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Course + type badge
      Row(
        children: [
          Expanded(
            child: Text(
              session.courseName,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kText,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: session.type == AttendanceType.inPerson
                  ? _kCherryBg
                  : _kGreenBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              session.type == AttendanceType.inPerson
                  ? '📍 In-Person'
                  : '🌐 Online',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: session.type == AttendanceType.inPerson
                    ? _kCherry
                    : _kGreen,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // Timer + progress
      Row(
        children: [
          Icon(Icons.timer_rounded, size: 18, color: timerColor),
          const SizedBox(width: 8),
          Text(
            timeDisplay,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: timerColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'remaining',
            style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: session.progressFraction,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(timerColor),
          minHeight: 8,
        ),
      ),
      const SizedBox(height: 20),

      // 6-digit code
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '6-Digit Code',
                    style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.sixDigitCode,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: _kCherry,
                      letterSpacing: 6,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: _kCherry, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: session.sixDigitCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // Students marked
      Row(
        children: [
          const Icon(Icons.people_rounded, size: 16, color: _kSubtext),
          const SizedBox(width: 6),
          Text(
            '${session.studentsMarked} / ${session.totalStudents} '
            'students marked',
            style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
          ),
        ],
      ),
      const SizedBox(height: 20),

      // End session button
      SizedBox(
        width: double.infinity,
        height: 46,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _kCherry),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(
            Icons.stop_circle_outlined,
            color: _kCherry,
            size: 18,
          ),
          label: Text(
            'End Session',
            style: GoogleFonts.poppins(
              color: _kCherry,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: onEnd,
        ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════
//  COURSE ATTENDANCE CARD (generate button)
// ══════════════════════════════════════════════
class _CourseAttendanceCard extends StatelessWidget {
  final LecturerCourseModel course;
  final bool isActive;
  final void Function(AttendanceType, int)? onStart;
  const _CourseAttendanceCard({
    required this.course,
    required this.isActive,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: isActive ? _kCherry.withValues(alpha: 0.05) : _kWhite,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isActive ? _kCherry.withValues(alpha: 0.4) : Colors.transparent,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.courseCode,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              Text(
                course.courseName,
                style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 13,
                    color: _kSubtext,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${course.totalStudents} students',
                    style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.room_outlined, size: 13, color: _kSubtext),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      course.room,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: _kSubtext,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kGreenBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Active',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kGreen,
              ),
            ),
          )
        else if (onStart != null)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kCherry,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () => _showStartDialog(context),
            child: Text(
              'Start',
              style: GoogleFonts.poppins(
                color: _kWhite,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Busy',
              style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
            ),
          ),
      ],
    ),
  );

  void _showStartDialog(BuildContext context) {
    AttendanceType selectedType = AttendanceType.inPerson;
    double durationMins = 5;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Start Attendance — ${course.courseCode}',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance Type',
                style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
              ),
              const SizedBox(height: 10),

              // Type selector
              Row(
                children: [
                  _TypeChip(
                    label: '📍 In-Person',
                    selected: selectedType == AttendanceType.inPerson,
                    onTap: () =>
                        setD(() => selectedType = AttendanceType.inPerson),
                  ),
                  const SizedBox(width: 8),
                  _TypeChip(
                    label: '🌐 Online',
                    selected: selectedType == AttendanceType.online,
                    onTap: () =>
                        setD(() => selectedType = AttendanceType.online),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Text(
                'Duration: ${durationMins.toInt()} min',
                style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
              ),
              Slider(
                value: durationMins,
                min: 1,
                max: 5,
                divisions: 4,
                activeColor: _kCherry,
                label: '${durationMins.toInt()} min',
                onChanged: (v) => setD(() => durationMins = v),
              ),
              Text(
                'Max 5 minutes',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
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
              onPressed: () {
                Navigator.pop(context);
                onStart!(selectedType, (durationMins * 60).toInt());
              },
              child: Text(
                'Start Session',
                style: GoogleFonts.poppins(
                  color: _kWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? _kCherry : _kBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? _kWhite : _kSubtext,
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════
//  SCHEDULE CARD
// ══════════════════════════════════════════════
class _ScheduleCard extends StatelessWidget {
  final WeeklySessionModel session;
  final void Function(String reason) onMarkNotHeld;
  const _ScheduleCard({required this.session, required this.onMarkNotHeld});

  Color get _statusColor {
    switch (session.status) {
      case SessionStatus.held:
        return _kGreen;
      case SessionStatus.notHeld:
        return _kCherry;
      case SessionStatus.upcoming:
        return const Color(0xFF2196F3);
      case SessionStatus.active:
        return _kOrange;
      case SessionStatus.cancelled:
        return _kSubtext;
    }
  }

  Color get _statusBg {
    switch (session.status) {
      case SessionStatus.held:
        return _kGreenBg;
      case SessionStatus.notHeld:
        return _kCherryBg;
      case SessionStatus.upcoming:
        return const Color(0xFFE3F2FD);
      case SessionStatus.active:
        return _kOrangeBg;
      case SessionStatus.cancelled:
        return const Color(0xFFF5F5F5);
    }
  }

  String get _statusLabel {
    switch (session.status) {
      case SessionStatus.held:
        return 'Held';
      case SessionStatus.notHeld:
        return 'Not Held';
      case SessionStatus.upcoming:
        return 'Upcoming';
      case SessionStatus.active:
        return 'Active';
      case SessionStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Day badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _kCherryBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    session.dayLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kCherry,
                    ),
                  ),
                  Text(
                    '${session.date.day}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kCherry,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.courseCode,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                  Text(
                    session.courseName,
                    style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
                  ),
                ],
              ),
            ),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _statusBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _statusColor,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Icon(Icons.schedule_rounded, size: 13, color: _kSubtext),
            const SizedBox(width: 4),
            Text(
              '${session.startTime} – ${session.endTime}',
              style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
            ),
            const SizedBox(width: 16),
            Icon(Icons.room_outlined, size: 13, color: _kSubtext),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                session.room,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
              ),
            ),
          ],
        ),

        // Stats if held
        if (session.status == SessionStatus.held &&
            session.studentsAttended != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.people_rounded, size: 13, color: _kGreen),
              const SizedBox(width: 4),
              Text(
                '${session.studentsAttended} / '
                '${session.totalStudents} attended',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _kGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],

        // Not held reason
        if (session.status == SessionStatus.notHeld &&
            session.notHeldReason != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 13, color: _kCherry),
              const SizedBox(width: 4),
              Text(
                'Reason: ${session.notHeldReason}',
                style: GoogleFonts.poppins(fontSize: 12, color: _kCherry),
              ),
            ],
          ),
        ],

        // Mark as not held button for upcoming
        if (session.status == SessionStatus.upcoming) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showNotHeldDialog(context),
            child: Text(
              'Mark as Not Held',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _kCherry,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: _kCherry,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  void _showNotHeldDialog(BuildContext context) {
    const reasons = [
      'Public Holiday',
      'Lecturer Indisposed',
      'Emergency',
      'Venue Issue',
      'Other',
    ];
    String? selectedReason;
    final otherCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Mark as Not Held',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select a reason:',
                style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
              ),
              const SizedBox(height: 12),
              ...reasons.map(
                (r) => RadioListTile<String>(
                  value: r,
                  groupValue: selectedReason,
                  activeColor: _kCherry,
                  title: Text(r, style: GoogleFonts.poppins(fontSize: 13)),
                  onChanged: (v) => setD(() => selectedReason = v),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              if (selectedReason == 'Other') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: otherCtrl,
                  decoration: InputDecoration(
                    hintText: 'Describe reason...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _kSubtext,
                    ),
                    filled: true,
                    fillColor: _kBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
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
              onPressed: selectedReason == null
                  ? null
                  : () {
                      final reason =
                          selectedReason == 'Other' && otherCtrl.text.isNotEmpty
                          ? otherCtrl.text
                          : selectedReason!;
                      Navigator.pop(context);
                      onMarkNotHeld(reason);
                    },
              child: Text(
                'Confirm',
                style: GoogleFonts.poppins(
                  color: _kWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  COURSE INFO CARD
// ══════════════════════════════════════════════
class _CourseInfoCard extends StatelessWidget {
  final LecturerCourseModel course;
  const _CourseInfoCard({required this.course});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kCherryBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                course.courseCode,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kCherry,
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${course.totalStudents} students',
                style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          course.courseName,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        const SizedBox(height: 6),
        _CourseDetail(
          icon: Icons.schedule_rounded,
          text: '${course.startTime} – ${course.endTime}',
        ),
        _CourseDetail(
          icon: Icons.calendar_today_rounded,
          text: course.schedule,
        ),
        _CourseDetail(icon: Icons.room_outlined, text: course.room),
        _CourseDetail(icon: Icons.school_rounded, text: course.department),
      ],
    ),
  );
}

class _CourseDetail extends StatelessWidget {
  final IconData icon;
  final String text;
  const _CourseDetail({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Icon(icon, size: 13, color: _kSubtext),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
          ),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════
//  PROFILE WIDGETS
// ══════════════════════════════════════════════
class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
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
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PDivider extends StatelessWidget {
  const _PDivider();
  @override
  Widget build(BuildContext context) =>
      Divider(color: Colors.grey.shade100, thickness: 1, height: 1);
}

class _LecturerPwField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  const _LecturerPwField({
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
        fontSize: 13,
        color: Colors.grey.shade500,
      ),
      filled: true,
      fillColor: const Color(0xFFEEEEF3),
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: Colors.grey,
          size: 18,
        ),
        onPressed: onToggle,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kCherry, width: 1.5),
      ),
    ),
  );
}
