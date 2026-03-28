import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/core/config/school_data.dart';
import 'package:smart_attend/features/admin/controllers/admin_controller.dart';
import 'package:smart_attend/features/admin/models/admin_model.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/auth/views/mobile/login_screen.dart';

// ── Theme constants ────────────────────────────────────────────────
const _kCherry = Color(0xFF9B1B42);
const _kCherryBg = Color(0xFFFFEEF2);
const _kGreen = Color(0xFF4CAF50);
const _kGreenBg = Color(0xFFE8F5E9);
const _kOrange = Color(0xFFFF9800);
const _kOrangeBg = Color(0xFFFFF3E0);
const _kBlue = Color(0xFF2196F3);
const _kBlueBg = Color(0xFFE3F2FD);
const _kPurple = Color(0xFF9C27B0);
const _kPurpleBg = Color(0xFFF3E5F5);
const _kBg = Color(0xFFEEEEF3);
const _kCard = Color(0xFFF5F5F8);
const _kWhite = Color(0xFFFFFFFF);
const _kText = Color(0xFF1A1A1A);
const _kSubtext = Color(0xFF888888);

class AdminDashboard extends StatefulWidget {
  static String id = 'admin_dashboard';
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _ctrl = AdminController();
  int _navIndex = 0;

  SchoolAnalyticsModel? _analytics;
  List<ManagedUserModel> _users = [];
  List<AdminCourseModel> _courses = [];
  List<TimetableSlotModel> _timetable = [];
  List<SemesterModel> _semesters = [];
  List<ManagedUserModel> _lecturers = [];
  bool _loading = true;

  UserRole? _userRoleFilter;
  UserStatus? _userStatusFilter;
  String _userSearch = '';
  String _courseSearch = '';
  String _courseDeptFilter = '';
  String _ttLevel = '';
  String _ttProgramme = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _ctrl.fetchSchoolAnalytics(),
      _ctrl.fetchUsers(),
      _ctrl.fetchCourses(),
      _ctrl.fetchTimetable(),
      _ctrl.fetchSemesters(),
      _ctrl.fetchLecturers(),
    ]);
    if (!mounted) return;
    setState(() {
      _analytics = results[0] as SchoolAnalyticsModel;
      _users = results[1] as List<ManagedUserModel>;
      _courses = results[2] as List<AdminCourseModel>;
      _timetable = results[3] as List<TimetableSlotModel>;
      _semesters = results[4] as List<SemesterModel>;
      _lecturers = results[5] as List<ManagedUserModel>;
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
                _AdminPwField(
                  label: 'Current Password',
                  controller: currentPwCtrl,
                  obscure: obscure1,
                  onToggle: () => setSheetState(() => obscure1 = !obscure1),
                ),
                const SizedBox(height: 14),
                _AdminPwField(
                  label: 'New Password',
                  controller: newPwCtrl,
                  obscure: obscure2,
                  onToggle: () => setSheetState(() => obscure2 = !obscure2),
                ),
                const SizedBox(height: 14),
                _AdminPwField(
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
      builder: (_) => _ConfirmDialog(
        title: 'Logout',
        message: 'Return to the main login page?',
        onConfirm: () async {
          await SessionService.clearSession();
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              LoginScreen.id,
              (_) => false,
            );
          }
        },
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

    final isWide = MediaQuery.of(context).size.width >= 960;
    return Scaffold(
      backgroundColor: _kBg,
      body: isWide
          ? Row(
              children: [
                _SideNav(
                  index: _navIndex,
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
          _bnItem(0, Icons.bar_chart_rounded, 'Analytics'),
          _bnItem(1, Icons.people_outline_rounded, 'Users'),
          _bnItem(2, Icons.book_outlined, 'Courses'),
          _bnItem(3, Icons.table_chart_outlined, 'Timetable'),
          _bnItem(4, Icons.calendar_today_rounded, 'Semesters'),
        ],
      ),
    ),
  );

  Widget _bnItem(int i, IconData icon, String label) {
    final active = _navIndex == i;
    return GestureDetector(
      onTap: () => setState(() => _navIndex = i),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? _kCherry : _kSubtext, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 9,
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
        return _buildAnalyticsPage();
      case 1:
        return _buildUsersPage();
      case 2:
        return _buildCoursesPage();
      case 3:
        return _buildTimetablePage();
      case 4:
        return _buildSemestersPage();
      default:
        return _buildAnalyticsPage();
    }
  }

  // ══════════════════════════════════════════════
  //  PAGE 0 — ANALYTICS
  // ══════════════════════════════════════════════
  Widget _buildAnalyticsPage() {
    final a = _analytics!;
    return Column(
      children: [
        _PageHeader(
          title: 'Department Analytics',
          subtitle:
              'Your department overview · '
              '${a.totalDepartments} departments',
          action: MediaQuery.of(context).size.width < 960
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
                builder: (ctx, box) {
                  final wide = box.maxWidth >= 700;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAnalyticsTopStats(a, wide),
                      const SizedBox(height: 24),
                      _buildGaugeRow(a, wide),
                      const SizedBox(height: 24),
                      _buildDeptTable(a),
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

  Widget _buildAnalyticsTopStats(SchoolAnalyticsModel a, bool wide) {
    final items = [
      _Stat(
        'Students',
        '${a.totalStudents}',
        Icons.school_rounded,
        _kBlue,
        _kBlueBg,
      ),
      _Stat(
        'Lecturers',
        '${a.totalLecturers}',
        Icons.people_rounded,
        _kCherry,
        _kCherryBg,
      ),
      _Stat(
        'Courses',
        '${a.totalCourses}',
        Icons.book_rounded,
        _kOrange,
        _kOrangeBg,
      ),
      _Stat(
        'Departments',
        '${a.totalDepartments}',
        Icons.account_balance_rounded,
        _kPurple,
        _kPurpleBg,
      ),
    ];
    return _statsGrid(items, wide);
  }

  Widget _buildGaugeRow(SchoolAnalyticsModel a, bool wide) {
    final gauges = [
      _Gauge(
        'School Attendance Rate',
        a.schoolAttendanceRate,
        Icons.how_to_reg_rounded,
        a.schoolAttendanceRate >= 75
            ? _kGreen
            : a.schoolAttendanceRate >= 60
            ? _kOrange
            : _kCherry,
      ),
      _Gauge(
        'Class Holding Rate',
        a.schoolHoldingRate,
        Icons.event_available_rounded,
        a.schoolHoldingRate >= 80
            ? _kGreen
            : a.schoolHoldingRate >= 65
            ? _kOrange
            : _kCherry,
      ),
      _Gauge(
        'Classes Held',
        a.classesScheduled == 0
            ? 0
            : (a.classesHeld / a.classesScheduled) * 100,
        Icons.check_circle_rounded,
        _kGreen,
        extra: '${a.classesHeld}/${a.classesScheduled}',
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
                  padding: EdgeInsets.only(
                    right: e.key < gauges.length - 1 ? 14 : 0,
                  ),
                  child: _GaugeCard(gauge: e.value),
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
              child: _GaugeCard(gauge: g),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDeptTable(SchoolAnalyticsModel a) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: _card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SecTitle('Department Comparison'),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(flex: 3, child: _th('Department')),
              Expanded(flex: 1, child: _th('Students')),
              Expanded(flex: 2, child: _th('Attendance')),
              Expanded(flex: 2, child: _th('Class Holding')),
            ],
          ),
        ),
        const Divider(),
        ...a.byDepartment.map(
          (d) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    d.departmentName,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _kText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '${d.totalStudents}',
                    style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _RateChip(
                    value: d.attendanceRate,
                    color: d.attendanceColor,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _RateChip(
                    value: d.holdingRate,
                    color: d.holdingRate >= 80
                        ? _kGreen
                        : d.holdingRate >= 65
                        ? _kOrange
                        : _kCherry,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  // ══════════════════════════════════════════════
  //  PAGE 1 — USERS
  // ══════════════════════════════════════════════
  Widget _buildUsersPage() {
    var filtered = _users.where((u) {
      if (_userRoleFilter != null && u.role != _userRoleFilter) return false;
      if (_userStatusFilter != null && u.status != _userStatusFilter)
        return false;
      if (_userSearch.isNotEmpty) {
        final q = _userSearch.toLowerCase();
        if (!u.fullName.toLowerCase().contains(q) &&
            !u.email.toLowerCase().contains(q) &&
            !(u.indexNumber?.toLowerCase().contains(q) ?? false) &&
            !(u.staffId?.toLowerCase().contains(q) ?? false)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Column(
      children: [
        _PageHeader(
          title: 'User Management',
          subtitle: '${_users.length} total users',
          action: _ActionButton(
            label: 'Add User',
            icon: Icons.person_add_rounded,
            onTap: () => _showAddUserDialog(),
          ),
        ),
        Container(
          color: _kWhite,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _userSearch = v),
                style: GoogleFonts.poppins(fontSize: 13, color: _kText),
                decoration: _searchDecoration('Search name, email, ID...'),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Chip(
                      'All Roles',
                      _userRoleFilter == null,
                      () => setState(() => _userRoleFilter = null),
                    ),
                    const SizedBox(width: 6),
                    ...UserRole.values.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _Chip(
                          r.label,
                          _userRoleFilter == r,
                          () => setState(() => _userRoleFilter = r),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _Chip(
                      'All Status',
                      _userStatusFilter == null,
                      () => setState(() => _userStatusFilter = null),
                    ),
                    const SizedBox(width: 6),
                    ...UserStatus.values.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _Chip(
                          s.label,
                          _userStatusFilter == s,
                          () => setState(() => _userStatusFilter = s),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _empty('No users match your filters')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _UserCard(
                    user: filtered[i],
                    lecturers: _lecturers,
                    onUpdated: (updated) {
                      final idx = _users.indexWhere((u) => u.id == updated.id);
                      if (idx >= 0) {
                        setState(() => _users[idx] = updated);
                      }
                    },
                    onStatusChange: (userId, status) async {
                      await _ctrl.updateUserStatus(userId, status);
                      final idx = _users.indexWhere((u) => u.id == userId);
                      if (idx >= 0) {
                        setState(
                          () => _users[idx] = _users[idx].copyWith(
                            status: status,
                          ),
                        );
                      }
                    },
                    ctrl: _ctrl,
                  ),
                ),
        ),
        Container(
          color: _kWhite,
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kCherry),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(
                  Icons.upload_file_rounded,
                  color: _kCherry,
                  size: 18,
                ),
                label: Text(
                  'Bulk Upload Students (CSV)',
                  style: GoogleFonts.poppins(
                    color: _kCherry,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                onPressed: () => _showCsvUploadDialog(UserRole.student),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kPurple),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(
                  Icons.upload_file_rounded,
                  color: _kPurple,
                  size: 18,
                ),
                label: Text(
                  'Bulk Upload Lecturers (CSV)',
                  style: GoogleFonts.poppins(
                    color: _kPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                onPressed: () => _showCsvUploadDialog(UserRole.lecturer),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  //  PAGE 2 — COURSES
  // ══════════════════════════════════════════════
  Widget _buildCoursesPage() {
    final depts = _courses.map((c) => c.departmentName).toSet().toList()
      ..sort();

    final filtered = _courses.where((c) {
      if (_courseDeptFilter.isNotEmpty && c.departmentName != _courseDeptFilter)
        return false;
      if (_courseSearch.isNotEmpty) {
        final q = _courseSearch.toLowerCase();
        if (!c.courseCode.toLowerCase().contains(q) &&
            !c.courseName.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    final unassigned = filtered.where((c) => !c.hasLecturer).length;

    return Column(
      children: [
        _PageHeader(
          title: 'Course Management',
          subtitle:
              '${_courses.length} courses · '
              '$unassigned unassigned',
          action: _ActionButton(
            label: 'Add Course',
            icon: Icons.add_rounded,
            onTap: () => _showAddCourseDialog(),
          ),
        ),
        Container(
          color: _kWhite,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _courseSearch = v),
                style: GoogleFonts.poppins(fontSize: 13, color: _kText),
                decoration: _searchDecoration('Search course code or name...'),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Chip(
                      'All Departments',
                      _courseDeptFilter.isEmpty,
                      () => setState(() => _courseDeptFilter = ''),
                    ),
                    const SizedBox(width: 6),
                    ...depts.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _Chip(
                          d.split(' ').first,
                          _courseDeptFilter == d,
                          () => setState(() => _courseDeptFilter = d),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _empty('No courses match your filters')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _CourseCard(
                    course: filtered[i],
                    lecturers: _lecturers,
                    onAssign: (course) async {
                      final updated = await _ctrl.assignLecturer(
                        course,
                        _lecturers.firstWhere(
                          (l) => l.id == course.assignedLecturerId,
                        ),
                      );
                      final idx = _courses.indexWhere(
                        (c) => c.id == updated.id,
                      );
                      if (idx >= 0) {
                        setState(() => _courses[idx] = updated);
                      }
                    },
                    onDelete: (courseId) {
                      setState(
                        () => _courses.removeWhere((c) => c.id == courseId),
                      );
                    },
                    ctrl: _ctrl,
                  ),
                ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  //  PAGE 3 — TIMETABLE
  // ══════════════════════════════════════════════
  Widget _buildTimetablePage() {
    final programmes = _timetable.map((s) => s.programme).toSet().toList()
      ..sort();
    final levels = _timetable.map((s) => s.level).toSet().toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    final filtered = _timetable.where((s) {
      if (_ttProgramme.isNotEmpty && s.programme != _ttProgramme) return false;
      if (_ttLevel.isNotEmpty && s.level != _ttLevel) {
        return false;
      }
      return true;
    }).toList();

    final Map<TimetableDay, List<TimetableSlotModel>> byDay = {};
    for (final d in TimetableDay.values) {
      byDay[d] = filtered.where((s) => s.day == d).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    return Column(
      children: [
        _PageHeader(
          title: 'Timetable Management',
          subtitle: '${_timetable.length} scheduled slots',
          action: _ActionButton(
            label: 'Add Slot',
            icon: Icons.add_rounded,
            onTap: () => _showAddSlotDialog(),
          ),
        ),
        Container(
          color: _kWhite,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Programme:',
                  style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
                ),
                const SizedBox(width: 8),
                _Chip(
                  'All',
                  _ttProgramme.isEmpty,
                  () => setState(() => _ttProgramme = ''),
                ),
                const SizedBox(width: 6),
                ...programmes.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _Chip(
                      p.replaceAll('BSc. ', ''),
                      _ttProgramme == p,
                      () => setState(() => _ttProgramme = p),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Level:',
                  style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
                ),
                const SizedBox(width: 8),
                _Chip(
                  'All',
                  _ttLevel.isEmpty,
                  () => setState(() => _ttLevel = ''),
                ),
                const SizedBox(width: 6),
                ...levels.map(
                  (l) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _Chip(
                      'Level $l',
                      _ttLevel == l,
                      () => setState(() => _ttLevel = l),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...TimetableDay.values.map((day) {
                final slots = byDay[day]!;
                if (slots.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _kCherryBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          day.label,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _kCherry,
                          ),
                        ),
                      ),
                    ),
                    ...slots.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TimetableSlotCard(
                          slot: s,
                          onDelete: (id) {
                            setState(
                              () => _timetable.removeWhere((s) => s.id == id),
                            );
                          },
                          ctrl: _ctrl,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  //  PAGE 4 — SEMESTERS
  // ══════════════════════════════════════════════
  Widget _buildSemestersPage() => Column(
    children: [
      _PageHeader(
        title: 'Semester Management',
        subtitle: 'Academic calendar & teaching parameters',
        action: _ActionButton(
          label: 'New Semester',
          icon: Icons.add_rounded,
          onTap: () => _showAddSemesterDialog(),
        ),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: _semesters.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _SemesterCard(
            semester: _semesters[i],
            onSetCurrent: (id) async {
              await _ctrl.setCurrentSemester(id);
              setState(() {
                for (int j = 0; j < _semesters.length; j++) {
                  _semesters[j] = _semesters[j].copyWith(
                    isCurrent: _semesters[j].id == id,
                  );
                }
              });
            },
          ),
        ),
      ),
    ],
  );

  // ── Dialogs ───────────────────────────────────
  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddUserDialog(
        ctrl: _ctrl,
        onCreated: (user) {
          setState(() => _users.insert(0, user));
        },
      ),
    );
  }

  void _showAddCourseDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddCourseDialog(
        ctrl: _ctrl,
        lecturers: _lecturers,
        onCreated: (course) {
          setState(() => _courses.insert(0, course));
        },
      ),
    );
  }

  void _showAddSlotDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddSlotDialog(
        courses: _courses,
        lecturers: _lecturers,
        onCreated: (slot) {
          setState(() => _timetable.insert(0, slot));
        },
        ctrl: _ctrl,
      ),
    );
  }

  void _showAddSemesterDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddSemesterDialog(
        ctrl: _ctrl,
        onCreated: (sem) {
          setState(() => _semesters.insert(0, sem));
        },
      ),
    );
  }

  void _showCsvUploadDialog(UserRole role) {
    showDialog(
      context: context,
      builder: (_) => _CsvUploadDialog(
        role: role,
        ctrl: _ctrl,
        onUploaded: (result) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${result.successCount} users imported, '
                '${result.errorCount} errors',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              backgroundColor: result.errorCount == 0 ? _kGreen : _kOrange,
            ),
          );
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────
  Widget _statsGrid(List<_Stat> items, bool wide) {
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
                  child: _StatCard(stat: e.value),
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
      children: items.map((s) => _StatCard(stat: s)).toList(),
    );
  }

  Widget _empty(String msg) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.search_off_rounded,
          color: _kSubtext.withValues(alpha: 0.4),
          size: 48,
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
  final ValueChanged<int> onTap;
  final VoidCallback onLogout;
  final VoidCallback onChangePassword;
  const _SideNav({
    required this.index,
    required this.onTap,
    required this.onLogout,
    required this.onChangePassword,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavDef(Icons.bar_chart_rounded, 'Analytics'),
      _NavDef(Icons.people_outline_rounded, 'Users'),
      _NavDef(Icons.book_outlined, 'Courses'),
      _NavDef(Icons.table_chart_outlined, 'Timetable'),
      _NavDef(Icons.calendar_today_rounded, 'Semesters'),
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
                'Super Admin',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: _kWhite.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kWhite.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _kWhite.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: _kWhite,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kWhite,
                          ),
                        ),
                        Text(
                          'Full system access',
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
  final Widget? action;
  const _PageHeader({required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 16,
      bottom: 16,
      left: 24,
      right: 20,
    ),
    decoration: const BoxDecoration(
      color: _kWhite,
      border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
              ),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: _kCherry,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ),
    icon: Icon(icon, color: _kWhite, size: 16),
    label: Text(
      label,
      style: GoogleFonts.poppins(
        color: _kWhite,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    onPressed: onTap,
  );
}

// ══════════════════════════════════════════════
//  STAT CARD
// ══════════════════════════════════════════════
class _Stat {
  final String label, value;
  final IconData icon;
  final Color color, bg;
  const _Stat(this.label, this.value, this.icon, this.color, this.bg);
}

class _StatCard extends StatelessWidget {
  final _Stat stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _card(),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: stat.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(stat.icon, color: stat.color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.value,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _kText,
                ),
              ),
              Text(
                stat.label,
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
class _Gauge {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final String? extra;
  const _Gauge(this.label, this.value, this.icon, this.color, {this.extra});
}

class _GaugeCard extends StatelessWidget {
  final _Gauge gauge;
  const _GaugeCard({required this.gauge});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(gauge.icon, color: gauge.color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                gauge.label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
            ),
            Text(
              gauge.extra ?? '${gauge.value.toStringAsFixed(1)}%',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: gauge.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: gauge.value / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(gauge.color),
            minHeight: 8,
          ),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════
//  USER CARD
// ══════════════════════════════════════════════
class _UserCard extends StatelessWidget {
  final ManagedUserModel user;
  final List<ManagedUserModel> lecturers;
  final void Function(ManagedUserModel) onUpdated;
  final void Function(String, UserStatus) onStatusChange;
  final AdminController ctrl;
  const _UserCard({
    required this.user,
    required this.lecturers,
    required this.onUpdated,
    required this.onStatusChange,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) => Container(
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
        CircleAvatar(
          radius: 20,
          backgroundColor: user.role.bg,
          child: Text(
            user.initials,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: user.role.color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              Text(
                user.email,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
              ),
              if (user.subtitle.isNotEmpty)
                Text(
                  user.subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 10, color: _kSubtext),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: user.role.bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                user.role.label,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: user.role.color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: user.status.bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                user.status.label,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: user.status.color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: _kSubtext, size: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (v) async {
            switch (v) {
              case 'edit':
                showDialog(
                  context: context,
                  builder: (_) => _EditUserDialog(
                    ctrl: ctrl,
                    user: user,
                    onUpdated: onUpdated,
                  ),
                );
                break;
              case 'activate':
                onStatusChange(user.id, UserStatus.active);
                break;
              case 'suspend':
                onStatusChange(user.id, UserStatus.suspended);
                break;
              case 'deactivate':
                onStatusChange(user.id, UserStatus.inactive);
                break;
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined, color: _kBlue, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Edit Details',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ],
              ),
            ),
            if (user.status != UserStatus.active)
              PopupMenuItem(
                value: 'activate',
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: _kGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text('Activate', style: GoogleFonts.poppins(fontSize: 13)),
                  ],
                ),
              ),
            if (user.status != UserStatus.suspended)
              PopupMenuItem(
                value: 'suspend',
                child: Row(
                  children: [
                    const Icon(Icons.block_rounded, color: _kOrange, size: 16),
                    const SizedBox(width: 8),
                    Text('Suspend', style: GoogleFonts.poppins(fontSize: 13)),
                  ],
                ),
              ),
            if (user.status != UserStatus.inactive)
              PopupMenuItem(
                value: 'deactivate',
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_off_outlined,
                      color: _kCherry,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Deactivate',
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════
//  COURSE CARD
// ══════════════════════════════════════════════
class _CourseCard extends StatelessWidget {
  final AdminCourseModel course;
  final List<ManagedUserModel> lecturers;
  final void Function(AdminCourseModel) onAssign;
  final void Function(String) onDelete;
  final AdminController ctrl;
  const _CourseCard({
    required this.course,
    required this.lecturers,
    required this.onAssign,
    required this.onDelete,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: course.hasLecturer
            ? Colors.transparent
            : _kOrange.withValues(alpha: 0.4),
      ),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.courseName,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              Text(
                course.departmentName,
                style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
              ),
              Row(
                children: [
                  Text(
                    '${course.enrolledStudents} students',
                    style: GoogleFonts.poppins(fontSize: 10, color: _kSubtext),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${course.creditHours} credits',
                    style: GoogleFonts.poppins(fontSize: 10, color: _kSubtext),
                  ),
                ],
              ),
              if (course.hasLecturer)
                Text(
                  '👨‍🏫 ${course.assignedLecturerName}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _kGreen,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                Text(
                  '⚠️ No lecturer assigned',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _kOrange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: _kSubtext, size: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (v) {
            if (v == 'assign') _showAssignDialog(context);
            if (v == 'delete') {
              showDialog(
                context: context,
                builder: (_) => _ConfirmDialog(
                  title: 'Delete Course',
                  message:
                      'Delete ${course.courseCode}? '
                      'This cannot be undone.',
                  onConfirm: () => onDelete(course.id),
                  destructive: true,
                ),
              );
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'assign',
              child: Row(
                children: [
                  const Icon(
                    Icons.person_add_rounded,
                    color: _kCherry,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Assign Lecturer',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Delete',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  void _showAssignDialog(BuildContext context) {
    // Only show lecturers whose departments include this course's faculty
    final eligible = lecturers
        .where(
          (l) =>
              l.departments.contains(course.departmentName) ||
              l.department == course.departmentName,
        )
        .toList();
    // Fall back to all lecturers if none matched (e.g. legacy data)
    final pool = eligible.isNotEmpty ? eligible : lecturers;

    ManagedUserModel? selected = course.hasLecturer
        ? pool.firstWhere(
            (l) => l.id == course.assignedLecturerId,
            orElse: () => pool.isNotEmpty ? pool.first : lecturers.first,
          )
        : null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Assign Lecturer — ${course.courseCode}',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (eligible.isEmpty && lecturers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _kOrange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'No lecturers are assigned to "${course.departmentName}". '
                      'Showing all lecturers.',
                      style: GoogleFonts.poppins(fontSize: 11, color: _kOrange),
                    ),
                  ),
                ),
              DropdownButtonFormField<ManagedUserModel>(
                value: selected,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _kBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                hint: Text(
                  'Select a lecturer',
                  style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
                ),
                items: pool
                    .map(
                      (l) => DropdownMenuItem(
                        value: l,
                        child: Text(
                          l.fullName,
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (l) => setD(() => selected = l),
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
              onPressed: selected == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      final updated = await ctrl.assignLecturer(
                        course,
                        selected!,
                      );
                      onAssign(updated);
                    },
              child: Text(
                'Assign',
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
//  TIMETABLE SLOT CARD
// ══════════════════════════════════════════════
class _TimetableSlotCard extends StatelessWidget {
  final TimetableSlotModel slot;
  final void Function(String) onDelete;
  final AdminController ctrl;
  const _TimetableSlotCard({
    required this.slot,
    required this.onDelete,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(12),
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
        Container(
          width: 68,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: _kCherryBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                slot.startTime,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _kCherry,
                ),
              ),
              Text(
                '—',
                style: GoogleFonts.poppins(fontSize: 9, color: _kCherry),
              ),
              Text(
                slot.endTime,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _kCherry,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${slot.courseCode} · ${slot.courseName}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              Text(
                slot.lecturerName,
                style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
              ),
              Text(
                '${slot.room} · Level ${slot.level}',
                style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: _kCherry,
            size: 18,
          ),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => _ConfirmDialog(
              title: 'Remove Slot',
              message:
                  'Remove ${slot.courseCode} '
                  '${slot.day.label}?',
              onConfirm: () => onDelete(slot.id),
              destructive: true,
            ),
          ),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════
//  SEMESTER CARD
// ══════════════════════════════════════════════
class _SemesterCard extends StatelessWidget {
  final SemesterModel semester;
  final void Function(String) onSetCurrent;
  const _SemesterCard({required this.semester, required this.onSetCurrent});

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: semester.isCurrent
            ? _kGreen.withValues(alpha: 0.4)
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
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: semester.isCurrent ? _kGreenBg : _kBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.calendar_month_rounded,
            color: semester.isCurrent ? _kGreen : _kSubtext,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      semester.name,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                      ),
                    ),
                  ),
                  if (semester.isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _kGreenBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Current',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _kGreen,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.date_range_rounded, size: 13, color: _kSubtext),
                  const SizedBox(width: 4),
                  Text(
                    '${_fmt(semester.startDate)} – '
                    '${_fmt(semester.endDate)}',
                    style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.school_rounded, size: 13, color: _kSubtext),
                  const SizedBox(width: 4),
                  Text(
                    '${semester.teachingWeeks} weeks',
                    style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
                  ),
                ],
              ),
              if (!semester.isCurrent) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => onSetCurrent(semester.id),
                  child: Text(
                    'Set as current',
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
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════
//  ADD USER DIALOG
// ══════════════════════════════════════════════
class _AddUserDialog extends StatefulWidget {
  final AdminController ctrl;
  final void Function(ManagedUserModel) onCreated;
  const _AddUserDialog({required this.ctrl, required this.onCreated});

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  UserRole _role = UserRole.student;

  // ── Student fields ──────────────────────────
  String? _selectedFaculty;
  String? _programme;
  String _level = '100';

  // ── Lecturer fields ─────────────────────────
  // Multi-select: list of faculty names chosen as departments
  final Set<String> _selectedDepts = {};

  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(
      'Add New User',
      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
    ),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Default password banner ────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF2196F3),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Default password',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'Central@123',
                                style: GoogleFonts.robotoMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(
                                    const ClipboardData(text: 'Central@123'),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: const Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'The user will be prompted to change this on first login.',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Role toggle ────────────────────────
              Row(
                children: UserRole.values
                    .where((r) => r != UserRole.admin && r != UserRole.dean)
                    .map(
                      (r) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _role = r;
                              _selectedDepts.clear();
                              _selectedFaculty = null;
                              _programme = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _role == r ? _kCherry : _kBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                r.label,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _role == r ? _kWhite : _kSubtext,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),

              // ── Full Name ──────────────────────────
              _tf(
                'Full Name',
                _nameCtrl,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Full name is required'
                    : null,
              ),
              const SizedBox(height: 10),

              // ── Email ──────────────────────────────
              _tf(
                'Email',
                _emailCtrl,
                hint: 'user@central.edu.gh',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.trim().toLowerCase().endsWith('@central.edu.gh'))
                    return 'Email must end in @central.edu.gh';
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // ═══════════════════════════════════════
              //  STUDENT FIELDS
              // ═══════════════════════════════════════
              if (_role == UserRole.student) ...[
                _tf(
                  'Index Number',
                  _idCtrl,
                  hint: 'CU/2024/0001',
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Index number is required'
                      : null,
                ),
                const SizedBox(height: 10),

                // Faculty picker → filters programmes
                DropdownButtonFormField<String>(
                  value: _selectedFaculty,
                  isExpanded: true,
                  decoration: _inputDec('School / Faculty'),
                  hint: Text(
                    'Select faculty',
                    style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
                  ),
                  validator: (v) =>
                      v == null ? 'Please select a faculty' : null,
                  items: kFaculties
                      .map(
                        (f) => DropdownMenuItem(
                          value: f.name,
                          child: Text(
                            f.name,
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _selectedFaculty = v;
                    _programme = null; // reset programme when faculty changes
                  }),
                ),
                const SizedBox(height: 10),

                // Programme picker — filtered by chosen faculty
                DropdownButtonFormField<String>(
                  value: _programme,
                  isExpanded: true,
                  decoration: _inputDec('Programme'),
                  hint: Text(
                    _selectedFaculty == null
                        ? 'Select a faculty first'
                        : 'Select programme',
                    style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
                  ),
                  validator: (v) =>
                      v == null ? 'Please select a programme' : null,
                  items:
                      (_selectedFaculty == null
                              ? <String>[]
                              : programmesForFaculty(_selectedFaculty!))
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                p,
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: _selectedFaculty == null
                      ? null
                      : (v) => setState(() => _programme = v),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: _level,
                  decoration: _inputDec('Level'),
                  items: ['100', '200', '300', '400', '500']
                      .map(
                        (l) => DropdownMenuItem(
                          value: l,
                          child: Text(
                            'Level $l',
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _level = v!),
                ),

                // ═══════════════════════════════════════
                //  LECTURER FIELDS
                // ═══════════════════════════════════════
              ] else ...[
                _tf(
                  'Staff ID',
                  _idCtrl,
                  hint: 'STF/2024/0001',
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Staff ID is required'
                      : null,
                ),
                const SizedBox(height: 10),

                // Department multi-select (checkboxes inside scrollable container)
                FormField<Set<String>>(
                  validator: (_) => _selectedDepts.isEmpty
                      ? 'Select at least one department'
                      : null,
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Departments',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: _kBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: field.hasError
                                ? Colors.red
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: kFaculties.map((f) {
                              final checked = _selectedDepts.contains(f.name);
                              return CheckboxListTile(
                                dense: true,
                                activeColor: _kCherry,
                                value: checked,
                                title: Text(
                                  f.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: _kText,
                                  ),
                                ),
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedDepts.add(f.name);
                                    } else {
                                      _selectedDepts.remove(f.name);
                                    }
                                  });
                                  field.didChange(_selectedDepts);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      if (field.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Text(
                            field.errorText!,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel', style: GoogleFonts.poppins(color: _kSubtext)),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _kCherry,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: _loading
            ? null
            : () async {
                if (!_formKey.currentState!.validate()) return;
                setState(() => _loading = true);
                try {
                  final depts = _selectedDepts.toList();
                  final user = await widget.ctrl.createUser(
                    ManagedUserModel(
                      id: '',
                      fullName: _nameCtrl.text.trim(),
                      email: _emailCtrl.text.trim().toLowerCase(),
                      role: _role,
                      status: UserStatus.active,
                      indexNumber: _role == UserRole.student
                          ? _idCtrl.text.trim()
                          : null,
                      staffId: _role == UserRole.lecturer
                          ? _idCtrl.text.trim()
                          : null,
                      programme: _role == UserRole.student ? _programme : null,
                      level: _role == UserRole.student ? _level : null,
                      faculty: _role == UserRole.student
                          ? facultyForProgramme(_programme ?? '')
                          : (_selectedDepts.isNotEmpty
                                ? _selectedDepts.first
                                : null),
                      departments: _role == UserRole.lecturer ? depts : [],
                      department: _role == UserRole.lecturer && depts.isNotEmpty
                          ? depts.first
                          : null,
                      createdAt: DateTime.now(),
                    ),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    widget.onCreated(user);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          '${user.fullName} created. Default password: ',
                                    ),
                                    TextSpan(
                                      text: 'Central@123',
                                      style: GoogleFonts.robotoMono(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: _kGreen,
                        duration: const Duration(seconds: 8),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceFirst('Exception: ', ''),
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        backgroundColor: _kCherry,
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
        child: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kWhite,
                ),
              )
            : Text(
                'Create',
                style: GoogleFonts.poppins(
                  color: _kWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════
//  EDIT USER DIALOG
// ══════════════════════════════════════════════
class _EditUserDialog extends StatefulWidget {
  final AdminController ctrl;
  final ManagedUserModel user;
  final void Function(ManagedUserModel) onUpdated;
  const _EditUserDialog({
    required this.ctrl,
    required this.user,
    required this.onUpdated,
  });

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _idCtrl;

  String? _selectedFaculty;
  String? _programme;
  String _level = '100';
  final Set<String> _selectedDepts = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u.fullName);
    _idCtrl = TextEditingController(text: u.staffId ?? u.indexNumber ?? '');
    _programme = u.programme;
    _level = u.level ?? '100';
    _selectedFaculty = u.faculty?.isNotEmpty == true
        ? u.faculty
        : (u.programme != null ? facultyForProgramme(u.programme!) : null);
    if (u.departments.isNotEmpty) {
      _selectedDepts.addAll(u.departments);
    } else if (u.department != null) {
      _selectedDepts.add(u.department!);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = widget.user.role == UserRole.student;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Edit ${widget.user.fullName}',
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tf(
                  'Full Name',
                  _nameCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),

                if (isStudent) ...[
                  _tf(
                    'Index Number',
                    _idCtrl,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: _selectedFaculty,
                    isExpanded: true,
                    decoration: _inputDec('School / Faculty'),
                    hint: Text(
                      'Select faculty',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _kSubtext,
                      ),
                    ),
                    validator: (v) => v == null ? 'Required' : null,
                    items: kFaculties
                        .map(
                          (f) => DropdownMenuItem(
                            value: f.name,
                            child: Text(
                              f.name,
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedFaculty = v;
                      _programme = null;
                    }),
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: _programme,
                    isExpanded: true,
                    decoration: _inputDec('Programme'),
                    hint: Text(
                      _selectedFaculty == null
                          ? 'Select faculty first'
                          : 'Select programme',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _kSubtext,
                      ),
                    ),
                    validator: (v) => v == null ? 'Required' : null,
                    items:
                        (_selectedFaculty == null
                                ? <String>[]
                                : programmesForFaculty(_selectedFaculty!))
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p,
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: _selectedFaculty == null
                        ? null
                        : (v) => setState(() => _programme = v),
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: _level,
                    decoration: _inputDec('Level'),
                    items: ['100', '200', '300', '400', '500']
                        .map(
                          (l) => DropdownMenuItem(
                            value: l,
                            child: Text(
                              'Level $l',
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _level = v!),
                  ),
                ] else ...[
                  _tf(
                    'Staff ID',
                    _idCtrl,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),

                  FormField<Set<String>>(
                    initialValue: _selectedDepts,
                    validator: (_) => _selectedDepts.isEmpty
                        ? 'Select at least one department'
                        : null,
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Departments',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _kText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: BoxDecoration(
                            color: _kBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: field.hasError
                                  ? Colors.red
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              children: kFaculties.map((f) {
                                final checked = _selectedDepts.contains(f.name);
                                return CheckboxListTile(
                                  dense: true,
                                  activeColor: _kCherry,
                                  value: checked,
                                  title: Text(
                                    f.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: _kText,
                                    ),
                                  ),
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true)
                                        _selectedDepts.add(f.name);
                                      else
                                        _selectedDepts.remove(f.name);
                                    });
                                    field.didChange(_selectedDepts);
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        if (field.hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Text(
                              field.errorText!,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins(color: _kSubtext)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _kCherry,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _loading
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _loading = true);
                  try {
                    final depts = _selectedDepts.toList();
                    final updated = await widget.ctrl.updateUser(
                      widget.user.copyWith(
                        fullName: _nameCtrl.text.trim(),
                        indexNumber: isStudent ? _idCtrl.text.trim() : null,
                        staffId: !isStudent ? _idCtrl.text.trim() : null,
                        programme: isStudent ? _programme : null,
                        level: isStudent ? _level : null,
                        faculty: isStudent
                            ? (_programme != null
                                  ? facultyForProgramme(_programme!)
                                  : _selectedFaculty)
                            : (depts.isNotEmpty ? depts.first : null),
                        departments: !isStudent ? depts : [],
                        department: !isStudent && depts.isNotEmpty
                            ? depts.first
                            : null,
                      ),
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      widget.onUpdated(updated);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${updated.fullName} updated successfully',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: _kGreen,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                          backgroundColor: _kCherry,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kWhite,
                  ),
                )
              : Text(
                  'Save Changes',
                  style: GoogleFonts.poppins(
                    color: _kWhite,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════
//  ADD COURSE DIALOG
// ══════════════════════════════════════════════
class _AddCourseDialog extends StatefulWidget {
  final AdminController ctrl;
  final List<ManagedUserModel> lecturers;
  final void Function(AdminCourseModel) onCreated;
  const _AddCourseDialog({
    required this.ctrl,
    required this.lecturers,
    required this.onCreated,
  });

  @override
  State<_AddCourseDialog> createState() => _AddCourseDialogState();
}

class _AddCourseDialogState extends State<_AddCourseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  int _credits = 3;
  String? _selectedFaculty;
  String? _selectedProgramme;
  String? _selectedLevel;
  ManagedUserModel? _lecturer;
  bool _loading = false;

  // Lecturers eligible to teach this course — filtered by faculty
  List<ManagedUserModel> get _eligibleLecturers {
    if (_selectedFaculty == null) return [];
    return widget.lecturers
        .where(
          (l) =>
              l.departments.contains(_selectedFaculty!) ||
              l.department == _selectedFaculty,
        )
        .toList();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(
      'Add New Course',
      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
    ),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tf(
                'Course Code',
                _codeCtrl,
                hint: 'CS 401',
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              _tf(
                'Course Name',
                _nameCtrl,
                hint: 'Software Engineering',
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),

              // Faculty / Department dropdown
              DropdownButtonFormField<String>(
                value: _selectedFaculty,
                isExpanded: true,
                decoration: _inputDec('School / Faculty (Department)'),
                hint: Text(
                  'Select faculty',
                  style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
                ),
                validator: (v) => v == null ? 'Please select a faculty' : null,
                items: kFaculties
                    .map(
                      (f) => DropdownMenuItem(
                        value: f.name,
                        child: Text(
                          f.name,
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedFaculty = v;
                  _lecturer = null; // reset lecturer when faculty changes
                }),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Text(
                    'Credit Hours: $_credits',
                    style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
                  ),
                  Expanded(
                    child: Slider(
                      value: _credits.toDouble(),
                      min: 1,
                      max: 6,
                      divisions: 5,
                      activeColor: _kCherry,
                      onChanged: (v) => setState(() => _credits = v.toInt()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Lecturer dropdown — only shows lecturers in this faculty
              DropdownButtonFormField<ManagedUserModel>(
                value: _lecturer,
                isExpanded: true,
                decoration: _inputDec('Assign Lecturer (optional)'),
                hint: Text(
                  _selectedFaculty == null
                      ? 'Select a faculty first'
                      : _eligibleLecturers.isEmpty
                      ? 'No lecturers in this faculty'
                      : 'Select lecturer',
                  style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
                ),
                items: _eligibleLecturers
                    .map(
                      (l) => DropdownMenuItem(
                        value: l,
                        child: Text(
                          l.fullName,
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _eligibleLecturers.isEmpty
                    ? null
                    : (l) => setState(() => _lecturer = l),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel', style: GoogleFonts.poppins(color: _kSubtext)),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _kCherry,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: _loading
            ? null
            : () async {
                if (!_formKey.currentState!.validate()) return;
                setState(() => _loading = true);
                try {
                  final course = await widget.ctrl.createCourse(
                    AdminCourseModel(
                      id: '',
                      courseCode: _codeCtrl.text.trim(),
                      courseName: _nameCtrl.text.trim(),
                      departmentId: _selectedFaculty!.toLowerCase().replaceAll(
                        ' ',
                        '_',
                      ),
                      departmentName: _selectedFaculty!,
                      faculty: _selectedFaculty!,
                      programme: _selectedProgramme ?? '',
                      level: _selectedLevel ?? '',
                      creditHours: _credits,
                      enrolledStudents: 0,
                      semester: '2025/2026 Semester 2',
                      assignedLecturerId: _lecturer?.id,
                      assignedLecturerName: _lecturer?.fullName,
                    ),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    widget.onCreated(course);
                  }
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
        child: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kWhite,
                ),
              )
            : Text(
                'Create',
                style: GoogleFonts.poppins(
                  color: _kWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════
//  ADD TIMETABLE SLOT DIALOG
// ══════════════════════════════════════════════
class _AddSlotDialog extends StatefulWidget {
  final List<AdminCourseModel> courses;
  final List<ManagedUserModel> lecturers;
  final void Function(TimetableSlotModel) onCreated;
  final AdminController ctrl;
  const _AddSlotDialog({
    required this.courses,
    required this.lecturers,
    required this.onCreated,
    required this.ctrl,
  });

  @override
  State<_AddSlotDialog> createState() => _AddSlotDialogState();
}

class _AddSlotDialogState extends State<_AddSlotDialog> {
  final _formKey = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();

  AdminCourseModel? _course;
  TimetableDay _day = TimetableDay.mon;
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 9, minute: 30);
  String _level = '100';
  bool _loading = false;
  String _search = '';

  // Levels inferred from selected course programme, or default list
  static const _defaultLevels = ['100', '200', '300', '400'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  List<AdminCourseModel> get _filtered {
    if (_search.isEmpty) return widget.courses;
    final q = _search.toLowerCase();
    return widget.courses
        .where(
          (c) =>
              c.courseCode.toLowerCase().contains(q) ||
              c.courseName.toLowerCase().contains(q),
        )
        .toList();
  }

  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _kCherry)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
          // Auto-advance end by 1h30m
          final endMin = picked.hour * 60 + picked.minute + 90;
          _end = TimeOfDay(hour: (endMin ~/ 60) % 24, minute: endMin % 60);
        } else {
          _end = picked;
        }
      });
    }
  }

  Widget _timeBox(String label, TimeOfDay t, bool isStart) => GestureDetector(
    onTap: () => _pickTime(isStart),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEF3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded, size: 16, color: _kCherry),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _fmtTime(t),
              style: GoogleFonts.poppins(fontSize: 13, color: _kText),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10, color: _kSubtext),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(
      'Add Timetable Slot',
      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
    ),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Course (searchable dropdown) ──────────
              Text(
                'Course',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kSubtext,
                ),
              ),
              const SizedBox(height: 6),

              // Search box
              TextFormField(
                controller: _searchCtrl,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search course code or name…',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _kSubtext,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: _kSubtext,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFEEEEF3),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 6),

              // Course list
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEF3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No courses found',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _kSubtext,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final c = _filtered[i];
                          final selected = _course?.id == c.id;
                          return ListTile(
                            dense: true,
                            selected: selected,
                            selectedColor: _kCherry,
                            selectedTileColor: _kCherry.withValues(alpha: 0.07),
                            title: Text(
                              '${c.courseCode} — ${c.courseName}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                            subtitle: Text(
                              c.programme,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: _kSubtext,
                              ),
                            ),
                            trailing: selected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: _kCherry,
                                    size: 16,
                                  )
                                : null,
                            onTap: () => setState(() {
                              _course = c;
                              // Auto-set level to match course level
                              if (c.level.isNotEmpty) _level = c.level;
                            }),
                          );
                        },
                      ),
              ),
              if (_course == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    'Please select a course',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.red),
                  ),
                ),

              const SizedBox(height: 14),

              // ── Department (auto-filled) ──────────────
              Text(
                'Department',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kSubtext,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEF3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.school_rounded,
                      size: 16,
                      color: _kSubtext,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _course?.faculty.isNotEmpty == true
                            ? _course!.faculty
                            : 'Auto-filled when course is selected',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _course?.faculty.isNotEmpty == true
                              ? _kText
                              : _kSubtext,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Day ──────────────────────────────────
              Text(
                'Day',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kSubtext,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<TimetableDay>(
                value: _day,
                decoration: _inputDec(''),
                items: TimetableDay.values
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(
                          d.label,
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (d) => setState(() => _day = d!),
              ),

              const SizedBox(height: 14),

              // ── Time ─────────────────────────────────
              Text(
                'Time',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kSubtext,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _timeBox('Start', _start, true)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'to',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _kSubtext,
                      ),
                    ),
                  ),
                  Expanded(child: _timeBox('End', _end, false)),
                ],
              ),

              const SizedBox(height: 14),

              // ── Room / Classroom ─────────────────────
              Text(
                'Classroom',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kSubtext,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _roomCtrl,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: _inputDec('e.g. ICT Block - Lab 1'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 14),

              // ── Level ────────────────────────────────
              Text(
                'Level',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kSubtext,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _level,
                decoration: _inputDec(''),
                items: _defaultLevels
                    .map(
                      (l) => DropdownMenuItem(
                        value: l,
                        child: Text(
                          'Level $l',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _level = v!),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel', style: GoogleFonts.poppins(color: _kSubtext)),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _kCherry,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: _loading ? null : _submit,
        child: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kWhite,
                ),
              )
            : Text(
                'Add Slot',
                style: GoogleFonts.poppins(
                  color: _kWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    ],
  );

  Future<void> _submit() async {
    if (_course == null) {
      setState(() {});
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final slot = await widget.ctrl.createTimetableSlot(
        TimetableSlotModel(
          id: '',
          courseId: _course!.id,
          courseCode: _course!.courseCode,
          courseName: _course!.courseName,
          lecturerName: _course!.assignedLecturerName ?? 'TBA',
          day: _day,
          startTime: _fmtTime(_start),
          endTime: _fmtTime(_end),
          room: _roomCtrl.text.trim(),
          level: _level,
          programme: _course!.programme,
          semester: _course!.semester,
        ),
      );
      if (context.mounted) {
        Navigator.pop(context);
        widget.onCreated(slot);
      }
    } catch (e) {
      if (context.mounted) {
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
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ══════════════════════════════════════════════
//  ADD SEMESTER DIALOG
// ══════════════════════════════════════════════
class _AddSemesterDialog extends StatefulWidget {
  final AdminController ctrl;
  final void Function(SemesterModel) onCreated;
  const _AddSemesterDialog({required this.ctrl, required this.onCreated});

  @override
  State<_AddSemesterDialog> createState() => _AddSemesterDialogState();
}

class _AddSemesterDialogState extends State<_AddSemesterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 105));
  int _weeks = 15;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _kCherry)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          _start = picked;
        else
          _end = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(
      'New Semester',
      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
    ),
    content: SizedBox(
      width: 380,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tf(
              'Semester Name',
              _nameCtrl,
              hint: '2026/2027 Semester 1',
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateTile(
                    label: 'Start Date',
                    value: _fmt(_start),
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateTile(
                    label: 'End Date',
                    value: _fmt(_end),
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Teaching Weeks: $_weeks',
                  style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
                ),
                Expanded(
                  child: Slider(
                    value: _weeks.toDouble(),
                    min: 10,
                    max: 20,
                    divisions: 10,
                    activeColor: _kCherry,
                    onChanged: (v) => setState(() => _weeks = v.toInt()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel', style: GoogleFonts.poppins(color: _kSubtext)),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _kCherry,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: _loading
            ? null
            : () async {
                if (!_formKey.currentState!.validate()) {
                  return;
                }
                setState(() => _loading = true);
                try {
                  final sem = await widget.ctrl.createSemester(
                    SemesterModel(
                      id: '',
                      name: _nameCtrl.text.trim(),
                      startDate: _start,
                      endDate: _end,
                      teachingWeeks: _weeks,
                      isCurrent: false,
                    ),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    widget.onCreated(sem);
                  }
                } finally {
                  if (mounted) {
                    setState(() => _loading = false);
                  }
                }
              },
        child: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kWhite,
                ),
              )
            : Text(
                'Create',
                style: GoogleFonts.poppins(
                  color: _kWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════
//  CSV UPLOAD DIALOG
// ══════════════════════════════════════════════
class _CsvUploadDialog extends StatefulWidget {
  final UserRole role;
  final AdminController ctrl;
  final void Function(CsvUploadResult) onUploaded;
  const _CsvUploadDialog({
    required this.role,
    required this.ctrl,
    required this.onUploaded,
  });

  @override
  State<_CsvUploadDialog> createState() => _CsvUploadDialogState();
}

class _CsvUploadDialogState extends State<_CsvUploadDialog> {
  final _csvCtrl = TextEditingController();
  CsvUploadResult? _result;
  bool _loading = false;

  String get _template => widget.role == UserRole.student
      ? 'fullName,email,indexNumber,programme,level\n'
            'Kofi Mensah,kofi@uni.edu.gh,UG/2024/0001,'
            'BSc. Computer Science,100'
      : 'fullName,email,staffId\n'
            'Dr. Kwame Asante,k.asante@uni.edu.gh,'
            'STF/2024/0001';

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(
      'Bulk Upload ${widget.role.label}s',
      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
    ),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Expected CSV format:',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kSubtext,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _csvCtrl.text = _template;
                        setState(() {});
                      },
                      child: Text(
                        'Use template',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: _kCherry,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _template.split('\n').first,
                  style: GoogleFonts.robotoMono(fontSize: 11, color: _kText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _csvCtrl,
            maxLines: 8,
            style: GoogleFonts.robotoMono(fontSize: 12, color: _kText),
            decoration: InputDecoration(
              filled: true,
              fillColor: _kBg,
              hintText: 'Paste CSV content here...',
              hintStyle: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kCherry, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _result!.errorCount == 0 ? _kGreenBg : _kOrangeBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ ${_result!.successCount} '
                    'imported  '
                    '❌ ${_result!.errorCount} errors',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _result!.errorCount == 0 ? _kGreen : _kOrange,
                    ),
                  ),
                  if (_result!.errors.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ..._result!.errors
                        .take(3)
                        .map(
                          (e) => Text(
                            '• $e',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                    if (_result!.errors.length > 3)
                      Text(
                        '...and '
                        '${_result!.errors.length - 3}'
                        ' more errors',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.red.shade400,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          _result != null ? 'Done' : 'Cancel',
          style: GoogleFonts.poppins(color: _kSubtext),
        ),
      ),
      if (_result == null)
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _kCherry,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: _loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kWhite,
                  ),
                )
              : const Icon(Icons.upload_rounded, color: _kWhite, size: 16),
          label: Text(
            'Upload',
            style: GoogleFonts.poppins(
              color: _kWhite,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: _loading
              ? null
              : () async {
                  if (_csvCtrl.text.trim().isEmpty) {
                    return;
                  }
                  setState(() => _loading = true);
                  try {
                    final result = await widget.ctrl.bulkUploadUsers(
                      _csvCtrl.text,
                      widget.role,
                    );
                    setState(() => _result = result);
                    widget.onUploaded(result);
                  } finally {
                    if (mounted) {
                      setState(() => _loading = false);
                    }
                  }
                },
        ),
    ],
  );
}

// ══════════════════════════════════════════════
//  CONFIRM DIALOG
// ══════════════════════════════════════════════
class _ConfirmDialog extends StatelessWidget {
  final String title, message;
  final VoidCallback onConfirm;
  final bool destructive;
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.onConfirm,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
    content: Text(
      message,
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
          backgroundColor: destructive ? Colors.red : _kCherry,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () {
          Navigator.pop(context);
          onConfirm();
        },
        child: Text(
          destructive ? 'Delete' : 'Confirm',
          style: GoogleFonts.poppins(
            color: _kWhite,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════
//  DATE TILE
// ══════════════════════════════════════════════
class _DateTile extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10, color: _kSubtext),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: _kCherry,
              ),
              const SizedBox(width: 6),
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
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════
//  SHARED HELPERS
// ══════════════════════════════════════════════
class _SecTitle extends StatelessWidget {
  final String text;
  const _SecTitle(this.text);

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

class _RateChip extends StatelessWidget {
  final double value;
  final Color color;
  const _RateChip({required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      '${value.toStringAsFixed(1)}%',
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

Widget _th(String label) => Text(
  label,
  style: GoogleFonts.poppins(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: _kSubtext,
  ),
);

BoxDecoration _card() => BoxDecoration(
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

Widget _tf(
  String label,
  TextEditingController ctrl, {
  String? hint,
  TextInputType keyboardType = TextInputType.text,
  String? Function(String?)? validator,
}) => TextFormField(
  controller: ctrl,
  keyboardType: keyboardType,
  validator: validator,
  style: GoogleFonts.poppins(fontSize: 13, color: _kText),
  decoration: _inputDec(label, hint: hint),
);

InputDecoration _inputDec(String label, {String? hint}) => InputDecoration(
  labelText: label,
  hintText: hint,
  labelStyle: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
  hintStyle: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
  filled: true,
  fillColor: _kBg,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide.none,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: _kCherry, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Colors.red, width: 1.2),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
);

InputDecoration _searchDecoration(String hint) => InputDecoration(
  filled: true,
  fillColor: _kBg,
  hintText: hint,
  hintStyle: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
  prefixIcon: const Icon(Icons.search_rounded, color: _kSubtext, size: 20),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _kCherry, width: 1.5),
  ),
  contentPadding: const EdgeInsets.symmetric(vertical: 12),
);

Widget _Chip(String label, bool selected, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _kCherry : _kBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? _kWhite : _kSubtext,
          ),
        ),
      ),
    );

class _AdminPwField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  const _AdminPwField({
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
