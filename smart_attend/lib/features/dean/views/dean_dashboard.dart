import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/dean/controllers/dean_controller.dart';
import 'package:smart_attend/features/dean/models/dean_model.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/dean/views/dean_access_screen.dart';

const _kCherry = Color(0xFF9B1B42);
const _kCherryBg = Color(0xFFFFEEF2);
const _kGreen = Color(0xFF4CAF50);
const _kGreenBg = Color(0xFFE8F5E9);
const _kOrange = Color(0xFFFF9800);
const _kOrangeBg = Color(0xFFFFF3E0);
const _kBlue = Color(0xFF2196F3);
const _kBlueBg = Color(0xFFE3F2FD);
const _kBg = Color(0xFFEEEEF3);
const _kWhite = Color(0xFFFFFFFF);
const _kText = Color(0xFF1A1A1A);
const _kSubtext = Color(0xFF888888);

class DeanDashboard extends StatefulWidget {
  static String id = 'dean_dashboard';
  const DeanDashboard({super.key});

  @override
  State<DeanDashboard> createState() => _DeanDashboardState();
}

class _DeanDashboardState extends State<DeanDashboard> {
  final _ctrl = DeanController();
  int _navIndex = 0;

  DeanModel? _dean;

  DepartmentStatsModel? _stats;
  List<CourseAnalyticsModel> _courses = [];
  List<LowAttendanceStudentModel> _students = [];
  List<LecturerPerformanceModel> _lecturers = [];
  bool _loading = true;

  String _studentSearch = '';
  String _courseFilter = 'all';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dean == null) {
      _dean = ModalRoute.of(context)?.settings.arguments as DeanModel?;
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    if (_dean == null) return;
    setState(() => _loading = true);
    final results = await Future.wait([
      _ctrl.fetchDepartmentStats(_dean!.departmentId),
      _ctrl.fetchCourseAnalytics(_dean!.departmentId),
      _ctrl.fetchLowAttendanceStudents(_dean!.departmentId),
      _ctrl.fetchLecturerPerformance(_dean!.departmentId),
    ]);
    if (!mounted) return;
    setState(() {
      _stats = results[0] as DepartmentStatsModel;
      _courses = results[1] as List<CourseAnalyticsModel>;
      _students = results[2] as List<LowAttendanceStudentModel>;
      _lecturers = results[3] as List<LecturerPerformanceModel>;
      _loading = false;
    });
  }

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
                _DeanPwField(
                  label: 'Current Password',
                  controller: currentPwCtrl,
                  obscure: obscure1,
                  onToggle: () => setSheetState(() => obscure1 = !obscure1),
                ),
                const SizedBox(height: 14),
                _DeanPwField(
                  label: 'New Password',
                  controller: newPwCtrl,
                  obscure: obscure2,
                  onToggle: () => setSheetState(() => obscure2 = !obscure2),
                ),
                const SizedBox(height: 14),
                _DeanPwField(
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
                                if (mounted) {
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
                                }
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
                              if (ctx.mounted) {
                                showErr(
                                  'Connection error. Check your internet.',
                                );
                              }
                            } finally {
                              if (ctx.mounted) {
                                setSheetState(() => isSubmitting = false);
                              }
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
          'Return to the dean login page?',
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
                // Return to the dean login page, not the main login
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  DeanAccessScreen.id,
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
    if (_loading || _dean == null) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kCherry)),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: _kBg,
      body: isWide
          ? Row(
              children: [
                _SideNav(
                  index: _navIndex,
                  dean: _dean!,
                  onTap: (i) => setState(() => _navIndex = i),
                  onLogout: _logout,
                  onChangePassword: _handleChangePassword,
                ),
                Expanded(child: _buildPage()),
              ],
            )
          : Scaffold(
              backgroundColor: _kBg,
              body: _buildPage(),
              bottomNavigationBar: _buildBottomNav(),
            ),
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
          _buildBNItem(0, Icons.dashboard_outlined, 'Overview'),
          _buildBNItem(1, Icons.book_outlined, 'Courses'),
          _buildBNItem(2, Icons.people_outline_rounded, 'Students'),
          _buildBNItem(3, Icons.person_outline_rounded, 'Lecturers'),
        ],
      ),
    ),
  );

  Widget _buildBNItem(int i, IconData icon, String label) {
    final active = _navIndex == i;
    return GestureDetector(
      onTap: () => setState(() => _navIndex = i),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
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
        return _buildOverviewPage();
      case 1:
        return _buildCoursesPage();
      case 2:
        return _buildStudentsPage();
      case 3:
        return _buildLecturersPage();
      default:
        return _buildOverviewPage();
    }
  }

  // ══════════════════════════════════════════════
  //  PAGE 0 — OVERVIEW
  // ══════════════════════════════════════════════
  Widget _buildOverviewPage() {
    final s = _stats!;
    return Column(
      children: [
        _PageHeader(
          title: 'Welcome, ${_dean!.firstName} 👋',
          subtitle: _dean!.departmentName,
          badge: 'Read-Only Oversight',
          action: MediaQuery.of(context).size.width < 900
              ? IconButton(
                  icon: const Icon(Icons.lock_outline_rounded, color: _kCherry),
                  tooltip: 'Change Password',
                  onPressed: _handleChangePassword,
                )
              : null,
        ),
        Expanded(
          child: RefreshIndicator(
            color: _kCherry,
            onRefresh: _loadAll,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final wide = constraints.maxWidth >= 700;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverviewStats(s, wide),
                      const SizedBox(height: 28),
                      _buildGaugeRow(s, wide),
                      const SizedBox(height: 28),
                      _buildClassesSummaryCard(s),
                      const SizedBox(height: 28),
                      _buildAlertsSection(),
                      const SizedBox(height: 80),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewStats(DepartmentStatsModel s, bool wide) {
    final items = [
      _StatDef(
        'Students',
        '${s.totalStudents}',
        Icons.school_rounded,
        _kBlue,
        _kBlueBg,
      ),
      _StatDef(
        'Lecturers',
        '${s.totalLecturers}',
        Icons.people_rounded,
        _kCherry,
        _kCherryBg,
      ),
      _StatDef(
        'Courses',
        '${s.totalCourses}',
        Icons.book_rounded,
        _kOrange,
        _kOrangeBg,
      ),
      _StatDef(
        'Classes Held',
        '${s.classesHeld}/${s.classesScheduled}',
        Icons.check_circle_rounded,
        _kGreen,
        _kGreenBg,
      ),
    ];
    if (wide) {
      return Row(
        children: items
            .asMap()
            .entries
            .map(
              (e) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: e.key < items.length - 1 ? 14 : 0,
                  ),
                  child: _StatCard(def: e.value),
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
      childAspectRatio: 1.5,
      children: items.map((s) => _StatCard(def: s)).toList(),
    );
  }

  Widget _buildGaugeRow(DepartmentStatsModel s, bool wide) {
    final gauges = [
      _GaugeDef(
        label: 'Overall Attendance Rate',
        value: s.overallAttendanceRate,
        icon: Icons.how_to_reg_rounded,
        color: s.overallAttendanceRate >= 75
            ? _kGreen
            : s.overallAttendanceRate >= 60
            ? _kOrange
            : _kCherry,
      ),
      _GaugeDef(
        label: 'Class Holding Rate',
        value: s.classHoldingRate,
        icon: Icons.event_available_rounded,
        color: s.classHoldingRate >= 80
            ? _kGreen
            : s.classHoldingRate >= 65
            ? _kOrange
            : _kCherry,
      ),
    ];
    if (wide) {
      return Row(
        children: gauges
            .asMap()
            .entries
            .map(
              (e) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: e.key == 0 ? 14 : 0),
                  child: _GaugeCard(def: e.value),
                ),
              ),
            )
            .toList(),
      );
    }
    return Column(
      children: gauges
          .map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GaugeCard(def: g),
            ),
          )
          .toList(),
    );
  }

  Widget _buildClassesSummaryCard(DepartmentStatsModel s) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Classes This Semester'),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ClassStat(
              label: 'Scheduled',
              value: '${s.classesScheduled}',
              color: _kBlue,
            ),
            _vDivider(),
            _ClassStat(
              label: 'Held',
              value: '${s.classesHeld}',
              color: _kGreen,
            ),
            _vDivider(),
            _ClassStat(
              label: 'Not Held',
              value: '${s.classesNotHeld}',
              color: _kCherry,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: s.classesScheduled == 0
                ? 0
                : s.classesHeld / s.classesScheduled,
            backgroundColor: _kCherryBg,
            valueColor: const AlwaysStoppedAnimation<Color>(_kGreen),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${s.classHoldingRate.toStringAsFixed(1)}% of '
          'scheduled classes were held',
          style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
        ),
      ],
    ),
  );

  Widget _buildAlertsSection() {
    final lowAttCourses = _courses.where((c) => c.isLowAttendance).length;
    final lowHoldLecturers = _lecturers.where((l) => l.isLowHolding).length;
    final criticalStudents = _students
        .where((s) => s.attendanceRate < 60)
        .length;

    if (lowAttCourses == 0 && lowHoldLecturers == 0 && criticalStudents == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Alerts'),
        const SizedBox(height: 12),
        if (criticalStudents > 0)
          _AlertCard(
            icon: Icons.warning_amber_rounded,
            color: _kCherry,
            bg: _kCherryBg,
            title: '$criticalStudents students below 60% attendance',
            subtitle: 'Immediate attention required',
            onTap: () => setState(() => _navIndex = 2),
          ),
        if (lowAttCourses > 0)
          _AlertCard(
            icon: Icons.trending_down_rounded,
            color: _kOrange,
            bg: _kOrangeBg,
            title: '$lowAttCourses courses with low attendance (<75%)',
            subtitle: 'View course analytics',
            onTap: () => setState(() => _navIndex = 1),
          ),
        if (lowHoldLecturers > 0)
          _AlertCard(
            icon: Icons.event_busy_rounded,
            color: _kBlue,
            bg: _kBlueBg,
            title: '$lowHoldLecturers lecturers with low class holding (<70%)',
            subtitle: 'View lecturer performance',
            onTap: () => setState(() => _navIndex = 3),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  //  PAGE 1 — COURSES
  // ══════════════════════════════════════════════
  Widget _buildCoursesPage() {
    final filtered = _courseFilter == 'low_attendance'
        ? _courses.where((c) => c.isLowAttendance).toList()
        : _courseFilter == 'low_holding'
        ? _courses.where((c) => c.isLowHolding).toList()
        : _courses;

    return Column(
      children: [
        _PageHeader(
          title: 'Course Analytics',
          subtitle: '${_courses.length} courses · ${_dean!.departmentName}',
        ),
        Container(
          color: _kWhite,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _courseFilter == 'all',
                  onTap: () => setState(() => _courseFilter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Low Attendance',
                  selected: _courseFilter == 'low_attendance',
                  onTap: () => setState(() => _courseFilter = 'low_attendance'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Low Holding',
                  selected: _courseFilter == 'low_holding',
                  onTap: () => setState(() => _courseFilter = 'low_holding'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState('No courses match this filter')
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _CourseAnalyticsCard(course: filtered[index]),
                ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  //  PAGE 2 — STUDENTS
  // ══════════════════════════════════════════════
  Widget _buildStudentsPage() {
    final filtered = _studentSearch.isEmpty
        ? _students
        : _students
              .where(
                (s) =>
                    s.fullName.toLowerCase().contains(
                      _studentSearch.toLowerCase(),
                    ) ||
                    s.indexNumber.toLowerCase().contains(
                      _studentSearch.toLowerCase(),
                    ),
              )
              .toList();

    final sorted = [...filtered]
      ..sort((a, b) => a.attendanceRate.compareTo(b.attendanceRate));

    return Column(
      children: [
        _PageHeader(
          title: 'Low Attendance Students',
          subtitle: 'Students below 75% attendance threshold',
        ),
        Container(
          color: _kWhite,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: TextField(
            onChanged: (v) => setState(() => _studentSearch = v),
            style: GoogleFonts.poppins(fontSize: 13, color: _kText),
            decoration: InputDecoration(
              filled: true,
              fillColor: _kBg,
              hintText: 'Search by name or index number...',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _kSubtext,
                size: 20,
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
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: sorted.isEmpty
              ? _buildEmptyState(
                  _studentSearch.isEmpty
                      ? 'All students are above 75% — great!'
                      : 'No students found',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: sorted.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _StudentCard(student: sorted[index]),
                ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  //  PAGE 3 — LECTURERS
  // ══════════════════════════════════════════════
  Widget _buildLecturersPage() {
    final sorted = [..._lecturers]
      ..sort((a, b) => a.holdingRate.compareTo(b.holdingRate));

    return Column(
      children: [
        _PageHeader(
          title: 'Lecturer Performance',
          subtitle: 'Class holding rates this semester',
        ),
        Expanded(
          child: sorted.isEmpty
              ? _buildEmptyState('No lecturer data available yet')
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: sorted.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _LecturerCard(lecturer: sorted[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String msg) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          color: _kGreen.withValues(alpha: 0.5),
          size: 52,
        ),
        const SizedBox(height: 12),
        Text(msg, style: GoogleFonts.poppins(fontSize: 14, color: _kSubtext)),
      ],
    ),
  );
}

// ══════════════════════════════════════════════
//  SIDE NAV
// ══════════════════════════════════════════════
class _SideNav extends StatelessWidget {
  final int index;
  final DeanModel dean;
  final ValueChanged<int> onTap;
  final VoidCallback onLogout;
  final VoidCallback onChangePassword;
  const _SideNav({
    required this.index,
    required this.dean,
    required this.onTap,
    required this.onLogout,
    required this.onChangePassword,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavDef(Icons.dashboard_outlined, 'Overview'),
      _NavDef(Icons.book_outlined, 'Courses'),
      _NavDef(Icons.people_outline_rounded, 'Students'),
      _NavDef(Icons.person_outline_rounded, 'Lecturers'),
    ];

    return Container(
      width: 240,
      color: _kCherry,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Dean Portal',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: _kWhite.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 28),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _kWhite.withValues(alpha: 0.2),
                    child: Text(
                      dean.initials,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
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
                          dean.firstName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kWhite,
                          ),
                        ),
                        Text(
                          'Department Dean',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: _kWhite.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                dean.departmentName,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: _kWhite.withValues(alpha: 0.55),
                ),
              ),
            ),

            const SizedBox(height: 24),
            Divider(color: _kWhite.withValues(alpha: 0.15)),
            const SizedBox(height: 8),

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
            GestureDetector(
              onTap: onChangePassword,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: _kWhite.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Change Password',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _kWhite.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: onLogout,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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

class _NavDef {
  final IconData icon;
  final String label;
  const _NavDef(this.icon, this.label);
}

// ══════════════════════════════════════════════
//  PAGE HEADER
// ══════════════════════════════════════════════
class _PageHeader extends StatelessWidget {
  final String title, subtitle;
  final String? badge;
  final Widget? action;
  const _PageHeader({
    required this.title,
    required this.subtitle,
    this.badge,
    this.action,
  });

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
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
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
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kBlueBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge!,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _kBlue,
              ),
            ),
          ),
        if (action != null) ...[const SizedBox(width: 8), action!],
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
    decoration: _cardDecoration(),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                def.value,
                style: GoogleFonts.poppins(
                  fontSize: 20,
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
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════
//  GAUGE CARD
// ══════════════════════════════════════════════
class _GaugeDef {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  const _GaugeDef({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _GaugeCard extends StatelessWidget {
  final _GaugeDef def;
  const _GaugeCard({required this.def});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(def.icon, color: def.color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                def.label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
            ),
            Text(
              '${def.value.toStringAsFixed(1)}%',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: def.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: def.value / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(def.color),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          def.value >= 75
              ? '✅ On track'
              : def.value >= 60
              ? '⚠️ Below target'
              : '🚨 Needs attention',
          style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════
//  COURSE ANALYTICS CARD
// ══════════════════════════════════════════════
class _CourseAnalyticsCard extends StatelessWidget {
  final CourseAnalyticsModel course;
  const _CourseAnalyticsCard({required this.course});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: course.isLowAttendance || course.isLowHolding
            ? _kCherry.withValues(alpha: 0.2)
            : Colors.transparent,
      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            if (course.isLowAttendance)
              _MiniAlert('Low Attendance', _kCherry, _kCherryBg),
            if (course.isLowHolding) ...[
              const SizedBox(width: 6),
              _MiniAlert('Low Holding', _kOrange, _kOrangeBg),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          course.courseName,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        if (course.lecturerName.isNotEmpty)
          Text(
            'by ${course.lecturerName}',
            style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _RateBar(
                label: 'Attendance',
                value: course.attendanceRate,
                color: course.attendanceColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _RateBar(
                label: 'Class Holding',
                value: course.holdingRate,
                color: course.holdingColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${course.classesHeld}/${course.classesScheduled} '
          'classes held · ${course.totalStudents} students',
          style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
        ),
      ],
    ),
  );
}

class _MiniAlert extends StatelessWidget {
  final String label;
  final Color color, bg;
  const _MiniAlert(this.label, this.color, this.bg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}

class _RateBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _RateBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10, color: _kSubtext),
          ),
          Text(
            '${value.toStringAsFixed(1)}%',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: value / 100,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 7,
        ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════
//  STUDENT CARD
// ══════════════════════════════════════════════
class _StudentCard extends StatelessWidget {
  final LowAttendanceStudentModel student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(14),
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
        CircleAvatar(
          radius: 22,
          backgroundColor: student.statusBg,
          child: Text(
            student.initials,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: student.statusColor,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              Text(
                '${student.indexNumber} · Level ${student.level}',
                style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
              ),
              Text(
                student.programme,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${student.attendanceRate.toStringAsFixed(1)}%',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: student.statusColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: student.statusBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                student.statusLabel,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: student.statusColor,
                ),
              ),
            ),
            if (student.coursesAtRisk > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${student.coursesAtRisk} course'
                '${student.coursesAtRisk > 1 ? 's' : ''} at risk',
                style: GoogleFonts.poppins(fontSize: 10, color: _kSubtext),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════
//  LECTURER CARD
// ══════════════════════════════════════════════
class _LecturerCard extends StatelessWidget {
  final LecturerPerformanceModel lecturer;
  const _LecturerCard({required this.lecturer});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: lecturer.isLowHolding
            ? _kCherry.withValues(alpha: 0.2)
            : Colors.transparent,
      ),
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
            CircleAvatar(
              radius: 22,
              backgroundColor: lecturer.holdingBg,
              child: Text(
                lecturer.initials,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: lecturer.holdingColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lecturer.fullName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                  Text(
                    '${lecturer.staffId} · '
                    '${lecturer.coursesAssigned} courses',
                    style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${lecturer.holdingRate.toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: lecturer.holdingColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: lecturer.holdingBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    lecturer.isLowHolding ? 'Low Holding' : 'Good',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: lecturer.holdingColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        _RateBar(
          label: 'Class Holding Rate',
          value: lecturer.holdingRate,
          color: lecturer.holdingColor,
        ),
        const SizedBox(height: 8),
        Text(
          '${lecturer.classesHeld}/${lecturer.classesScheduled} '
          'classes held this semester',
          style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ══════════════════════════════════════════════
class _AlertCard extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final String title, subtitle;
  final VoidCallback onTap;
  const _AlertCard({
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
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
                    color: _kText,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: color, size: 20),
        ],
      ),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: _kText,
    ),
  );
}

class _ClassStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ClassStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      Text(label, style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext)),
    ],
  );
}

Widget _vDivider() =>
    Container(height: 40, width: 1, color: Colors.grey.shade200);

BoxDecoration _cardDecoration() => BoxDecoration(
  color: _kWhite,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ],
);

class _DeanPwField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  const _DeanPwField({
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
      fillColor: _kBg,
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
