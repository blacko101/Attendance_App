import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/auth/services/location_service.dart';
import 'package:smart_attend/features/lecturer/controllers/lecturer_controller.dart';
import 'package:smart_attend/features/lecturer/models/lecturer_model.dart';
import 'package:smart_attend/features/lecturer/views/active_session_screen.dart';
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
  WeeklyStats _weeklyStats = WeeklyStats.empty();
  List<LecturerCourseModel> _courses = [];
  List<WeeklySessionModel> _schedule = [];
  // Track which course codes have had attendance marked this week
  // so the button switches to "Class Held"
  final Set<String> _heldThisWeek = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
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
      _ctrl.fetchWeeklyStats(userId),
      _ctrl.fetchCourses(userId),
      _ctrl.fetchWeeklySchedule(userId),
    ]);
    if (!mounted) return;

    final schedule = results[3] as List<WeeklySessionModel>;
    // Pre-populate held set from schedule so "Class Held" shows on reload
    final held = schedule
        .where((s) => s.status == SessionStatus.held)
        .map((s) => s.courseCode)
        .toSet();

    setState(() {
      _lecturer = results[0] as LecturerModel;
      _weeklyStats = results[1] as WeeklyStats;
      _courses = results[2] as List<LecturerCourseModel>;
      _schedule = schedule;
      _heldThisWeek.addAll(held);
      _loading = false;
    });
  }

  // ── START SESSION ──────────────────────────────────────────────────────
  Future<void> _startSession(
    LecturerCourseModel course,
    AttendanceType type,
    AttendanceMethod method,
    int durationSeconds,
  ) async {
    // Fetch location ONCE here for in-person sessions and pass it
    // directly to startSession() — avoids a second GPS call inside
    // the controller that can fail independently.
    Position? position;
    if (type == AttendanceType.inPerson) {
      try {
        position = await LocationService.getCurrentLocation();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().replaceFirst('Exception: ', ''),
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              backgroundColor: _kCherry,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }
    }

    final session = await _ctrl.startSession(
      course: course,
      type: type,
      method: method,
      durationSeconds: durationSeconds,
      position: position,
    );

    if (session == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to start session. Check your connection and try again.',
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
      }
      return;
    }

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveSessionScreen(
            session: session,
            ctrl: _ctrl,
            onEnded: () => _loadAll(),
          ),
        ),
      );
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
          subtitle: 'Your teaching overview for this week',
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
                    // Weekly stats row
                    _buildWeeklyStatsRow(wide),
                    const SizedBox(height: 28),

                    // Mark Attendance — pending on top, held at bottom
                    Text(
                      'Mark Attendance',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pending classes appear on top. '
                      'Held classes move to the bottom.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _kSubtext,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...() {
                      // Sort: pending first, held at bottom
                      final sorted = [..._courses];
                      sorted.sort((a, b) {
                        final aHeld = _heldThisWeek.contains(a.courseCode);
                        final bHeld = _heldThisWeek.contains(b.courseCode);
                        if (aHeld == bHeld) return 0;
                        return aHeld ? 1 : -1;
                      });
                      return sorted.map(
                        (c) => _CourseAttendanceCard(
                          course: c,
                          isHeld: _heldThisWeek.contains(c.courseCode),
                          onStart: _heldThisWeek.contains(c.courseCode)
                              ? null
                              : (type, method, secs) =>
                                    _startSession(c, type, method, secs),
                        ),
                      );
                    }(),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyStatsRow(bool wide) {
    final stats = [
      _StatDef(
        'Scheduled',
        '${_weeklyStats.scheduled}',
        Icons.event_rounded,
        _kCherry,
        _kCherryBg,
      ),
      _StatDef(
        'Held',
        '${_weeklyStats.held}',
        Icons.check_circle_rounded,
        _kGreen,
        _kGreenBg,
      ),
      _StatDef(
        'Not Held',
        '${_weeklyStats.notHeld}',
        Icons.cancel_rounded,
        Colors.red,
        const Color(0xFFFFEBEE),
      ),
      _StatDef(
        'In-Person',
        '${_weeklyStats.inPerson}',
        Icons.location_on_rounded,
        _kOrange,
        _kOrangeBg,
      ),
      _StatDef(
        'Online',
        '${_weeklyStats.online}',
        Icons.wifi_rounded,
        const Color(0xFF1565C0),
        const Color(0xFFE3F2FD),
      ),
    ];

    if (wide) {
      return Row(
        children: stats
            .map(
              (s) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _StatCard(def: s),
                ),
              ),
            )
            .toList(),
      );
    }
    // Mobile: 2 columns, but wrap last item if count is odd
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
          subtitle: 'Your timetable for this week',
        ),
        Expanded(
          child: _schedule.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 60,
                          color: _kSubtext,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No timetable found',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _kText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your scheduled classes will appear here once\n'
                          'a timetable has been set up by the admin.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: _kSubtext,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kCherry,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          onPressed: _loadAll,
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: _kWhite,
                            size: 18,
                          ),
                          label: Text(
                            'Refresh',
                            style: GoogleFonts.poppins(
                              color: _kWhite,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: _kCherry,
                  onRefresh: _loadAll,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: _schedule.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
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
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  //  PAGE 2 — COURSES (with Summary sub-tab)
  // ══════════════════════════════════════════════
  Widget _buildCoursesPage() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const _PageHeader(
            title: 'My Courses',
            subtitle: 'Courses assigned this semester',
          ),
          Container(
            color: _kWhite,
            child: TabBar(
              labelColor: _kCherry,
              unselectedLabelColor: _kSubtext,
              indicatorColor: _kCherry,
              labelStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Courses'),
                Tab(text: 'Summary'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // ── Courses tab ──
                ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: _courses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _CourseInfoCard(course: _courses[i]),
                ),
                // ── Summary tab ──
                _SummaryTab(ctrl: _ctrl),
              ],
            ),
          ),
        ],
      ),
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
//  COURSE ATTENDANCE CARD (Mark Attendance button)
// ══════════════════════════════════════════════
class _CourseAttendanceCard extends StatelessWidget {
  final LecturerCourseModel course;
  final bool isHeld;
  final void Function(AttendanceType, AttendanceMethod, int)? onStart;
  const _CourseAttendanceCard({
    required this.course,
    required this.isHeld,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
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
                  if (course.room.isNotEmpty) ...[
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
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        isHeld
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _kGreenBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: _kGreen,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Class Held',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kGreen,
                      ),
                    ),
                  ],
                ),
              )
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kCherry,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                onPressed: () => _showMarkDialog(context),
                child: Text(
                  'Mark Attendance',
                  style: GoogleFonts.poppins(
                    color: _kWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ],
    ),
  );

  void _showMarkDialog(BuildContext context) {
    AttendanceType selectedType = AttendanceType.inPerson;
    AttendanceMethod selectedMethod = AttendanceMethod.qrCode;
    double durationMins = 3;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Mark Attendance — ${course.courseCode}',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Class type ────────────────────────────────
                Text(
                  'Class Type',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 10),
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

                // ── Duration ──────────────────────────────────
                Text(
                  'Duration: ${durationMins.toInt()} min',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                Slider(
                  value: durationMins,
                  min: 3,
                  max: 6,
                  divisions: 3, // 3, 4, 5, 6
                  activeColor: _kCherry,
                  label: '${durationMins.toInt()} min',
                  onChanged: (v) => setD(() {
                    durationMins = v.roundToDouble();
                  }),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '3 min',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: _kSubtext,
                      ),
                    ),
                    Text(
                      '6 min',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: _kSubtext,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Attendance method ─────────────────────────
                Text(
                  'Check-in Method',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 10),

                _MethodCard(
                  icon: Icons.qr_code_rounded,
                  title: 'QR Code',
                  subtitle: 'Students scan — rotates every 15s',
                  selected: selectedMethod == AttendanceMethod.qrCode,
                  onTap: () =>
                      setD(() => selectedMethod = AttendanceMethod.qrCode),
                ),
                const SizedBox(height: 8),
                _MethodCard(
                  icon: Icons.pin_rounded,
                  title: '6-Digit Code',
                  subtitle: 'Students type the code — changes every 20s',
                  selected: selectedMethod == AttendanceMethod.sixDigitCode,
                  onTap: () => setD(
                    () => selectedMethod = AttendanceMethod.sixDigitCode,
                  ),
                ),
              ],
            ),
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
              onPressed: onStart == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      onStart!(
                        selectedType,
                        selectedMethod,
                        (durationMins * 60).toInt(),
                      );
                    },
              child: Text(
                'Start',
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

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? _kCherryBg : _kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? _kCherry : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: selected ? _kCherry : _kSubtext.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: selected ? _kWhite : _kSubtext),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? _kCherry : _kText,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: selected
                        ? _kCherry.withValues(alpha: 0.7)
                        : _kSubtext,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle_rounded, color: _kCherry, size: 20),
        ],
      ),
    ),
  );
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

// ══════════════════════════════════════════════
//  SUMMARY TAB
//  Shows all assigned courses with aggregate stats.
//  Tap a course → session history list.
// ══════════════════════════════════════════════
class _SummaryTab extends StatefulWidget {
  final LecturerController ctrl;
  const _SummaryTab({required this.ctrl});

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
  List<CourseSummaryModel> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await widget.ctrl.fetchCourseSummary();
    if (mounted)
      setState(() {
        _courses = data;
        _loading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kCherry));
    }
    if (_courses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_rounded, size: 56, color: _kSubtext),
              const SizedBox(height: 12),
              Text(
                'No course history yet',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Hold a class to see your summary here.',
                style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
              ),
            ],
          ),
        ),
      );
    }

    // Overall totals
    final totalHeld = _courses.fold(0, (s, c) => s + c.held);
    final totalInPerson = _courses.fold(0, (s, c) => s + c.inPerson);
    final totalOnline = _courses.fold(0, (s, c) => s + c.online);

    return RefreshIndicator(
      color: _kCherry,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Overall summary card ──────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _kCherry,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Semester Overview',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: _kWhite.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _SummaryPill(
                      '${_courses.length}',
                      'Courses',
                      Colors.white.withValues(alpha: 0.25),
                      _kWhite,
                    ),
                    const SizedBox(width: 10),
                    _SummaryPill(
                      '$totalHeld',
                      'Total Held',
                      Colors.white.withValues(alpha: 0.25),
                      _kWhite,
                    ),
                    const SizedBox(width: 10),
                    _SummaryPill(
                      '$totalInPerson',
                      'In-Person',
                      Colors.white.withValues(alpha: 0.25),
                      _kWhite,
                    ),
                    const SizedBox(width: 10),
                    _SummaryPill(
                      '$totalOnline',
                      'Online',
                      Colors.white.withValues(alpha: 0.25),
                      _kWhite,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Course list ───────────────────────────────
          ..._courses.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SummaryCourseCard(
                course: c,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        _CourseHistoryScreen(course: c, ctrl: widget.ctrl),
                  ),
                ).then((_) => _load()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String value, label;
  final Color bg, fg;
  const _SummaryPill(this.value, this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: fg)),
      ],
    ),
  );
}

class _SummaryCourseCard extends StatelessWidget {
  final CourseSummaryModel course;
  final VoidCallback onTap;
  const _SummaryCourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _kCherryBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  course.courseCode,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kCherry,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                color: _kSubtext,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            course.courseName,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniStat(
                Icons.check_circle_outline_rounded,
                '${course.held} held',
                _kGreen,
              ),
              const SizedBox(width: 14),
              _MiniStat(
                Icons.location_on_outlined,
                '${course.inPerson} in-person',
                _kOrange,
              ),
              const SizedBox(width: 14),
              _MiniStat(
                Icons.wifi_outlined,
                '${course.online} online',
                const Color(0xFF1565C0),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniStat(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color)),
    ],
  );
}

// ══════════════════════════════════════════════
//  COURSE HISTORY SCREEN
//  Full screen pushed from Summary tab.
//  Lists every session held for this course.
// ══════════════════════════════════════════════
class _CourseHistoryScreen extends StatelessWidget {
  final CourseSummaryModel course;
  final LecturerController ctrl;
  const _CourseHistoryScreen({required this.course, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final inPerson = course.inPerson;
    final online = course.online;
    final history = course.sessionHistory;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCherry,
        foregroundColor: _kWhite,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course.courseCode,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kWhite,
              ),
            ),
            Text(
              course.courseName,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: _kWhite.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Stats summary ────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kWhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _HistoryStat('${course.held}', 'Total Held', _kGreen),
                _HistoryStat('$inPerson', 'In-Person', _kOrange),
                _HistoryStat('$online', 'Online', const Color(0xFF1565C0)),
                _HistoryStat('${course.totalStudents}', 'Students', _kSubtext),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (history.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Text(
                  'No sessions recorded yet.',
                  style: GoogleFonts.poppins(fontSize: 14, color: _kSubtext),
                ),
              ),
            )
          else ...[
            Text(
              'Session History',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kText,
              ),
            ),
            const SizedBox(height: 12),
            ...history.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SessionHistoryCard(
                  session: s,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _SessionDetailScreen(
                        session: s,
                        courseName: course.courseName,
                        ctrl: ctrl,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _HistoryStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      Text(label, style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext)),
    ],
  );
}

class _SessionHistoryCard extends StatelessWidget {
  final SessionHistoryModel session;
  final VoidCallback onTap;
  const _SessionHistoryCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Date badge
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _kCherryBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  const [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ][session.date.weekday - 1],
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
                  session.formattedDate,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: session.type == 'inPerson'
                            ? _kOrangeBg
                            : const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        session.typeLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: session.type == 'inPerson'
                              ? _kOrange
                              : const Color(0xFF1565C0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.people_outline_rounded,
                      size: 12,
                      color: _kSubtext,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${session.studentsPresent} present'
                      ' · ${session.studentsAbsent} absent',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: _kSubtext,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _kSubtext, size: 18),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════
//  SESSION DETAIL SCREEN
//  Shows the full student list for one session.
//  Lecturer can filter: All / Attended / Absent.
// ══════════════════════════════════════════════
class _SessionDetailScreen extends StatefulWidget {
  final SessionHistoryModel session;
  final String courseName;
  final LecturerController ctrl;
  const _SessionDetailScreen({
    required this.session,
    required this.courseName,
    required this.ctrl,
  });

  @override
  State<_SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<_SessionDetailScreen> {
  List<SessionStudentModel> _students = [];
  bool _loading = true;
  String _filter = 'all'; // 'all' | 'attended' | 'absent'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await widget.ctrl.fetchSessionDetail(widget.session.sessionId);
    if (mounted && raw != null) {
      final present = (raw['present'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final absent = (raw['absent'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      final all = [
        ...present.map(
          (s) => SessionStudentModel(
            studentId: s['studentId']?.toString() ?? '',
            fullName: s['fullName'] as String? ?? 'Unknown',
            email: s['email'] as String? ?? '',
            indexNumber: s['indexNumber'] as String? ?? '',
            present: true,
            checkedInAt: DateTime.tryParse(s['checkedInAt'] as String? ?? ''),
          ),
        ),
        ...absent.map(
          (s) => SessionStudentModel(
            studentId: s['studentId']?.toString() ?? '',
            fullName: s['fullName'] as String? ?? 'Unknown',
            email: s['email'] as String? ?? '',
            indexNumber: s['indexNumber'] as String? ?? '',
            present: false,
          ),
        ),
      ];
      // Sort: present first, then alphabetical
      all.sort((a, b) {
        if (a.present != b.present) return a.present ? -1 : 1;
        return a.fullName.compareTo(b.fullName);
      });
      setState(() {
        _students = all;
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  List<SessionStudentModel> get _filtered {
    if (_filter == 'attended')
      return _students.where((s) => s.present).toList();
    if (_filter == 'absent') return _students.where((s) => !s.present).toList();
    return _students;
  }

  int get _presentCount => _students.where((s) => s.present).length;
  int get _absentCount => _students.where((s) => !s.present).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCherry,
        foregroundColor: _kWhite,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.courseName,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kWhite,
              ),
            ),
            Text(
              widget.session.formattedDate,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: _kWhite.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kCherry))
          : Column(
              children: [
                // ── Stats bar ─────────────────────────────
                Container(
                  color: _kWhite,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _AttendanceStat(
                          '$_presentCount',
                          'Present',
                          _kGreen,
                          _kGreenBg,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AttendanceStat(
                          '$_absentCount',
                          'Absent',
                          _kCherry,
                          _kCherryBg,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AttendanceStat(
                          '${_students.length}',
                          'Total',
                          const Color(0xFF1565C0),
                          const Color(0xFFE3F2FD),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Filter chips ──────────────────────────
                Container(
                  color: _kWhite,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      _FilterChip(
                        'All',
                        'all',
                        _filter,
                        (v) => setState(() => _filter = v),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        'Attended',
                        'attended',
                        _filter,
                        (v) => setState(() => _filter = v),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        'Absent',
                        'absent',
                        _filter,
                        (v) => setState(() => _filter = v),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFEEEEEE)),

                // ── Student list ──────────────────────────
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No students in this filter.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _kSubtext,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) =>
                              _StudentRow(student: _filtered[i]),
                        ),
                ),
              ],
            ),
    );
  }
}

class _AttendanceStat extends StatelessWidget {
  final String value, label;
  final Color color, bg;
  const _AttendanceStat(this.value, this.label, this.color, this.bg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color)),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _FilterChip(this.label, this.value, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _kCherry : _kBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? _kWhite : _kSubtext,
          ),
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final SessionStudentModel student;
  const _StudentRow({required this.student});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        // Avatar circle
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: student.present ? _kGreenBg : _kCherryBg,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              student.fullName.isNotEmpty
                  ? student.fullName
                        .trim()
                        .split(' ')
                        .map((p) => p.isNotEmpty ? p[0] : '')
                        .take(2)
                        .join()
                        .toUpperCase()
                  : '?',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: student.present ? _kGreen : _kCherry,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.fullName,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
              Text(
                student.indexNumber.isNotEmpty
                    ? student.indexNumber
                    : student.email,
                style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: student.present ? _kGreenBg : _kCherryBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            student.present ? 'Present' : 'Absent',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: student.present ? _kGreen : _kCherry,
            ),
          ),
        ),
      ],
    ),
  );
}
