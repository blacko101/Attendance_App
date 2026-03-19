import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/core/theme/app_colors.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/student/controllers/courses_controller.dart';
import 'package:smart_attend/features/student/models/course_detail_model.dart';

class CoursesScreen extends StatefulWidget {
  static String id = 'courses_screen';
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final _controller = CoursesController();

  // View state — 'my' = enrolled courses, 'available' = registration
  String _view = 'my';
  String _sortBy = 'absences';

  List<CourseAttendanceModel> _myCourses = [];
  List<AvailableCourseModel> _availableCourses = [];
  bool _loadingMy = true;
  bool _loadingAvailable = false;

  // Enrollment selection state
  final Set<String> _selectedForEnroll = {};

  @override
  void initState() {
    super.initState();
    _loadMyCourses();
  }

  // ── LOADERS ─────────────────────────────────────────────────────
  Future<void> _loadMyCourses() async {
    setState(() => _loadingMy = true);
    final session = await SessionService.getSession();
    final data = await _controller.fetchCoursesAttendance(session?.id ?? '');
    if (mounted) {
      setState(() {
        _myCourses = _controller.sortByMostAbsences(data);
        _loadingMy = false;
      });
    }
  }

  Future<void> _loadAvailableCourses() async {
    setState(() => _loadingAvailable = true);
    final data = await _controller.fetchAvailableCourses();
    if (mounted) {
      setState(() {
        _availableCourses = data;
        _loadingAvailable = false;
        // Pre-select already-enrolled courses
        _selectedForEnroll
          ..clear()
          ..addAll(data.where((c) => c.isEnrolled).map((c) => c.courseCode));
      });
    }
  }

  // ── SWITCH VIEW ──────────────────────────────────────────────────
  void _switchToMyCourses() {
    setState(() => _view = 'my');
    _loadMyCourses();
  }

  void _switchToEnroll() {
    setState(() => _view = 'available');
    _loadAvailableCourses();
  }

  // ── SORT ─────────────────────────────────────────────────────────
  void _toggleSort() {
    setState(() {
      if (_sortBy == 'absences') {
        _sortBy = 'name';
        _myCourses.sort((a, b) => a.courseCode.compareTo(b.courseCode));
      } else {
        _sortBy = 'absences';
        _myCourses = _controller.sortByMostAbsences(_myCourses);
      }
    });
  }

  // ── OVERALL RATE ─────────────────────────────────────────────────
  double get _overallRate {
    if (_myCourses.isEmpty) return 0;
    final total = _myCourses.fold(0, (s, c) => s + c.totalClasses);
    final attended = _myCourses.fold(0, (s, c) => s + c.attended);
    return total == 0 ? 0 : (attended / total) * 100;
  }

  int get _warningCount =>
      _myCourses.where((c) => c.isWarning || c.isDanger).length;

  // ── PASSWORD VERIFY & ENROLL ─────────────────────────────────────
  void _showEnrollConfirmDialog() {
    final newCodes = _selectedForEnroll
        .where(
          (c) =>
              !_availableCourses.any((a) => a.courseCode == c && a.isEnrolled),
        )
        .toList();

    if (_selectedForEnroll.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Select at least one course.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppColors.cherry,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final pwCtrl = TextEditingController();
    bool obscure = true;
    bool loading = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.divider(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const Icon(
                  Icons.lock_outline_rounded,
                  size: 40,
                  color: Color(0xFF9B1B42),
                ),
                const SizedBox(height: 12),

                Text(
                  'Confirm Enrollment',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 6),

                Text(
                  'You are enrolling in '
                  '${_selectedForEnroll.length} course'
                  '${_selectedForEnroll.length > 1 ? "s" : ""}.\n'
                  'Enter your password to confirm.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.subtext(context),
                  ),
                ),
                const SizedBox(height: 16),

                // Selected course codes chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selectedForEnroll
                      .map(
                        (code) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cherryBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            code,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.cherry,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),

                // Password field
                TextField(
                  controller: pwCtrl,
                  obscureText: obscure,
                  style: GoogleFonts.poppins(color: AppColors.text(context)),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.subtext(context),
                    ),
                    filled: true,
                    fillColor: AppColors.inputFill(context),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.subtext(context),
                        size: 18,
                      ),
                      onPressed: () => setSheet(() => obscure = !obscure),
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
                      borderSide: BorderSide(
                        color: AppColors.cherry,
                        width: 1.5,
                      ),
                    ),
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 20),

                // Confirm button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cherry,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: loading
                        ? null
                        : () async {
                            if (pwCtrl.text.isEmpty) {
                              setSheet(() => error = 'Enter your password.');
                              return;
                            }
                            setSheet(() {
                              loading = true;
                              error = null;
                            });

                            final errMsg = await _controller.enrollCourses(
                              courseCodes: _selectedForEnroll.toList(),
                              password: pwCtrl.text,
                            );

                            if (!ctx.mounted) return;

                            if (errMsg == null) {
                              // Success
                              Navigator.pop(ctx);
                              setState(() => _view = 'my');
                              _loadMyCourses();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Enrolled in ${_selectedForEnroll.length} course'
                                      '${_selectedForEnroll.length > 1 ? "s" : ""} successfully! 🎉',
                                      style: GoogleFonts.poppins(fontSize: 13),
                                    ),
                                    backgroundColor: AppColors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                            } else {
                              setSheet(() {
                                loading = false;
                                error = errMsg;
                              });
                            }
                          },
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Confirm Enrollment',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
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

  // ── BUILD ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header with hamburger ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _view == 'my' ? 'My Courses' : 'Enroll in Courses',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(context),
                    ),
                  ),
                  Row(
                    children: [
                      // Sort button — only in "my courses" view
                      if (_view == 'my')
                        GestureDetector(
                          onTap: _toggleSort,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cherryBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.sort_rounded,
                                  size: 14,
                                  color: AppColors.cherry,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _sortBy == 'absences' ? 'By Risk' : 'By Name',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.cherry,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),

                      // Hamburger menu
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.menu_rounded,
                          color: AppColors.text(context),
                          size: 26,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        onSelected: (v) {
                          if (v == 'my') _switchToMyCourses();
                          if (v == 'enroll') _switchToEnroll();
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'my',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.book_outlined,
                                  color: _view == 'my'
                                      ? AppColors.cherry
                                      : AppColors.subtext(context),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'My Courses',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: _view == 'my'
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: _view == 'my'
                                        ? AppColors.cherry
                                        : AppColors.text(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'enroll',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: _view == 'available'
                                      ? AppColors.cherry
                                      : AppColors.subtext(context),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Register Courses',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: _view == 'available'
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: _view == 'available'
                                        ? AppColors.cherry
                                        : AppColors.text(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Body ──
            Expanded(
              child: _view == 'my' ? _buildMyCoursesView() : _buildEnrollView(),
            ),
          ],
        ),
      ),
    );
  }

  // ── MY COURSES VIEW ──────────────────────────────────────────────
  Widget _buildMyCoursesView() {
    if (_loadingMy) {
      return Center(child: CircularProgressIndicator(color: AppColors.cherry));
    }

    return RefreshIndicator(
      color: AppColors.cherry,
      onRefresh: _loadMyCourses,
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildSummaryCard(),
          const SizedBox(height: 12),
          Expanded(
            child: _myCourses.isEmpty
                ? _buildEmpty(
                    icon: Icons.book_outlined,
                    title: 'No courses enrolled yet',
                    subtitle:
                        'Use the ☰ menu to register for courses\nthis semester.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: _myCourses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _CourseCard(
                      course: _myCourses[i],
                      onTap: () => _showCourseDetail(_myCourses[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── ENROLL VIEW ──────────────────────────────────────────────────
  Widget _buildEnrollView() {
    if (_loadingAvailable) {
      return Center(child: CircularProgressIndicator(color: AppColors.cherry));
    }

    return Column(
      children: [
        // Info banner
        Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2196F3).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF2196F3),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Select the courses you want to register for this semester. '
                  'You\'ll confirm with your password.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF1565C0),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Selection count chip
        if (_selectedForEnroll.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cherry,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedForEnroll.length} selected',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedForEnroll.clear()),
                  child: Text(
                    'Clear all',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.subtext(context),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Course list
        Expanded(
          child: _availableCourses.isEmpty
              ? _buildEmpty(
                  icon: Icons.search_off_rounded,
                  title: 'No courses available',
                  subtitle:
                      'Courses will appear here once they are added\nby your admin.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  itemCount: _availableCourses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final c = _availableCourses[i];
                    final selected = _selectedForEnroll.contains(c.courseCode);
                    return _EnrollCard(
                      course: c,
                      selected: selected,
                      onToggle: () => setState(() {
                        if (selected) {
                          _selectedForEnroll.remove(c.courseCode);
                        } else {
                          _selectedForEnroll.add(c.courseCode);
                        }
                      }),
                    );
                  },
                ),
        ),

        // Bottom confirm button
        if (_selectedForEnroll.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cherry,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    'Confirm Enrollment (${_selectedForEnroll.length})',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _showEnrollConfirmDialog,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 56,
            color: AppColors.subtext(context).withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.subtext(context),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildSummaryCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cherry,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: CustomPaint(
                painter: _MiniRingPainter(percentage: _overallRate / 100),
                child: Center(
                  child: Text(
                    '${_overallRate.toInt()}%',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Attendance',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  Text(
                    '${_myCourses.length} courses this semester',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_warningCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_rounded,
                            size: 12,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_warningCount course'
                            '${_warningCount > 1 ? "s" : ""} need attention',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'All courses on track!',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCourseDetail(CourseAttendanceModel course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CourseDetailSheet(course: course),
    );
  }
}

// ─────────────────────────────────────────────
//  ENROLL CARD
// ─────────────────────────────────────────────
class _EnrollCard extends StatelessWidget {
  final AvailableCourseModel course;
  final bool selected;
  final VoidCallback onToggle;
  const _EnrollCard({
    required this.course,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: course.isEnrolled ? null : onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardAlt(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: course.isEnrolled
                ? AppColors.green.withValues(alpha: 0.5)
                : selected
                ? AppColors.cherry
                : Colors.transparent,
            width: 1.5,
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
            // Checkbox / enrolled badge
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: course.isEnrolled
                    ? AppColors.green
                    : selected
                    ? AppColors.cherry
                    : Colors.transparent,
                border: Border.all(
                  color: course.isEnrolled
                      ? AppColors.green
                      : selected
                      ? AppColors.cherry
                      : AppColors.subtext(context).withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: course.isEnrolled || selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cherryBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          course.courseCode,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.cherry,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.subtext(
                            context,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Level ${course.level}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.subtext(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.subtext(
                            context,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${course.creditHours} cr',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.subtext(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    course.courseName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(context),
                    ),
                  ),
                  if (course.lecturer.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 11,
                          color: AppColors.subtext(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          course.lecturer,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.subtext(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (course.isEnrolled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Enrolled',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MY COURSE CARD
// ─────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final CourseAttendanceModel course;
  final VoidCallback onTap;
  const _CourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardAlt(context),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.courseCode,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text(context),
                        ),
                      ),
                      Text(
                        course.courseName,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.subtext(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: course.statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        course.statusIcon,
                        size: 12,
                        color: course.statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        course.statusLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: course.statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: course.attendanceRate / 100,
                backgroundColor: AppColors.divider(context),
                valueColor: AlwaysStoppedAnimation<Color>(course.statusColor),
                minHeight: 8,
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                _InfoChip(
                  icon: Icons.check_rounded,
                  label: '${course.attended} attended',
                  color: AppColors.green,
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.close_rounded,
                  label: '${course.absent} absent',
                  color: AppColors.cherry,
                ),
                const Spacer(),
                Text(
                  '${course.attendancePercent}%',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: course.statusColor,
                  ),
                ),
              ],
            ),

            if (course.instructor.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 13,
                    color: AppColors.subtext(context),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      course.instructor,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.subtext(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (course.isWarning || course.isDanger) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: course.statusBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_rounded,
                      size: 14,
                      color: course.statusColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        course.isDanger
                            ? '⚠️ Critical! Attend next class immediately.'
                            : '${course.absencesBeforeWarning} more absence'
                                  '${course.absencesBeforeWarning == 1 ? "" : "s"}'
                                  ' before penalty.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: course.statusColor,
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
    );
  }
}

// ─────────────────────────────────────────────
//  COURSE DETAIL BOTTOM SHEET
// ─────────────────────────────────────────────
class _CourseDetailSheet extends StatelessWidget {
  final CourseAttendanceModel course;
  const _CourseDetailSheet({required this.course});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.courseCode,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text(context),
                          ),
                        ),
                        Text(
                          course.courseName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.subtext(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cherry,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${course.attendancePercent}%',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _SheetStat(
                    label: 'Total',
                    value: '${course.totalClasses}',
                    color: AppColors.subtext(context),
                  ),
                  _SheetStat(
                    label: 'Attended',
                    value: '${course.attended}',
                    color: AppColors.green,
                  ),
                  _SheetStat(
                    label: 'Absent',
                    value: '${course.absent}',
                    color: AppColors.cherry,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Divider(color: AppColors.divider(context), thickness: 1),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Attendance History',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(context),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${course.history.length} sessions',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.subtext(context),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: course.history.isEmpty
                  ? Center(
                      child: Text(
                        'No attendance records yet.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.subtext(context),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: course.history.length,
                      separatorBuilder: (_, __) => Divider(
                        color: AppColors.divider(context),
                        thickness: 1,
                        height: 1,
                      ),
                      itemBuilder: (_, i) {
                        final h = course.history[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: h.attended
                                      ? const Color(0xFFE8F5E9)
                                      : AppColors.cherryBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  h.attended
                                      ? Icons.check_rounded
                                      : Icons.close_rounded,
                                  size: 18,
                                  color: h.attended
                                      ? AppColors.green
                                      : AppColors.cherry,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      h.formattedDate,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text(context),
                                      ),
                                    ),
                                    if (h.reason != null)
                                      Text(
                                        h.reason!,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: AppColors.subtext(context),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                h.attended ? 'Present' : 'Absent',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: h.attended
                                      ? AppColors.green
                                      : AppColors.cherry,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SMALL WIDGETS
// ─────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color)),
    ],
  );
}

class _SheetStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SheetStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.subtext(context),
          ),
        ),
      ],
    ),
  );
}

class _MiniRingPainter extends CustomPainter {
  final double percentage;
  _MiniRingPainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;
    const sw = 6.0;
    const start = -pi * 0.5;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      pi * 2,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      pi * 2 * percentage,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_MiniRingPainter o) => o.percentage != percentage;
}
