import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_attend/core/theme/app_colors.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/student/controllers/student_controller.dart';
import 'package:smart_attend/features/student/models/course_model.dart';
import 'package:smart_attend/features/student/views/mobile/calendar_screen.dart';
import 'package:smart_attend/features/student/views/mobile/courses_screen.dart';
import 'package:smart_attend/features/student/views/mobile/profile_screen.dart';
import 'package:smart_attend/features/student/widgets/attendance_options_sheet.dart';

class StudentDashboard extends StatefulWidget {
  static String id = 'student_dashboard';
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const _HomeTab(),
      const CalendarScreen(),
      const CoursesScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.cherry,
        elevation: 6,
        onPressed: () => showAttendanceOptions(context),
        child: const Icon(
          Icons.qr_code_scanner_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i >= 0 && i < _screens.length) {
            setState(() => _currentIndex = i);
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HOME TAB — pulls real data from DB
// ─────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  const _HomeTab();
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _controller = StudentController();

  String _firstName = '';
  int _totalAttended = 0;
  int _totalMissed = 0;
  List<CourseModel> _allCourses = [];
  bool _loading = true;

  double get _attendanceRate {
    final total = _totalAttended + _totalMissed;
    return total == 0 ? 0 : _totalAttended / total;
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      // Get real session — use real student ID, never hardcode
      final session = await SessionService.getSession();
      if (session == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Fetch dashboard stats + enrolled courses in parallel
      final results = await Future.wait([
        _controller.fetchDashboardStats(),
        _controller.fetchEnrolledCourses(session.id),
      ]);

      final stats = results[0] as Map<String, dynamic>;
      final courses = results[1] as List<CourseModel>;

      if (mounted) {
        setState(() {
          _firstName = (stats['fullName'] as String? ?? session.fullName)
              .split(' ')
              .first;
          _totalAttended = (stats['attended'] as int?) ?? 0;
          _totalMissed = (stats['absent'] as int?) ?? 0;
          _allCourses = courses;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<CourseModel> get _upcomingToday =>
      _controller.getUpcomingToday(_allCourses);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // ── Greeting ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _loading ? 'Hi 👋' : 'Hi, $_firstName 👋',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                  ),
                ),
                _NotifBtn(onTap: () {}),
              ],
            ),
          ),

          Text(
            'Overall Attendance',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 24),

          _AttendanceRing(percentage: _attendanceRate),
          const SizedBox(height: 28),

          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.cherry),
                  )
                : RefreshIndicator(
                    color: AppColors.cherry,
                    onRefresh: _loadAll,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          _TotalClassesCard(
                            attended: _totalAttended,
                            missed: _totalMissed,
                          ),
                          const SizedBox(height: 16),
                          _UpcomingClassesCard(courses: _upcomingToday),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BOTTOM NAV
// ─────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) => BottomAppBar(
    shape: const CircularNotchedRectangle(),
    notchMargin: 8,
    color: AppColors.card(context),
    elevation: 12,
    padding: EdgeInsets.zero,
    child: SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            index: 0,
            ci: currentIndex,
            onTap: onTap,
          ),
          _NavItem(
            icon: Icons.calendar_month_rounded,
            label: 'Schedule',
            index: 1,
            ci: currentIndex,
            onTap: onTap,
          ),
          const SizedBox(width: 56),
          _NavItem(
            icon: Icons.book_outlined,
            label: 'Courses',
            index: 2,
            ci: currentIndex,
            onTap: onTap,
          ),
          _NavItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            index: 3,
            ci: currentIndex,
            onTap: onTap,
          ),
        ],
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, ci;
  final ValueChanged<int> onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.ci,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = ci == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? AppColors.cherry : AppColors.subtext(context),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.cherry : AppColors.subtext(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  WIDGETS
// ─────────────────────────────────────────────
class _NotifBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _NotifBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.bg(context),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.isDark(context)
                    ? Colors.black.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.85),
                offset: const Offset(-3, -3),
                blurRadius: 6,
              ),
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: AppColors.isDark(context) ? 0.3 : 0.12,
                ),
                offset: const Offset(3, 3),
                blurRadius: 6,
              ),
            ],
          ),
          child: Icon(
            Icons.notifications_outlined,
            color: AppColors.subtext(context),
            size: 22,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFE53935),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AttendanceRing extends StatelessWidget {
  final double percentage;
  const _AttendanceRing({required this.percentage});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    height: 180,
    child: CustomPaint(
      painter: _RingPainter(percentage: percentage),
      child: Center(
        child: Text(
          '${(percentage * 100).toInt()}%',
          style: GoogleFonts.poppins(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: AppColors.text(context),
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  final double percentage;
  _RingPainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 12;
    const sw = 14.0;
    const start = -pi * 0.75;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      pi * 1.5,
      false,
      Paint()
        ..color = const Color(0xFFE8B4BE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      pi * 1.5 * percentage,
      false,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF9B1B42), Color(0xFFB84060)],
        ).createShader(Rect.fromCircle(center: c, radius: r))
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.percentage != percentage;
}

class _TotalClassesCard extends StatelessWidget {
  final int attended, missed;
  const _TotalClassesCard({required this.attended, required this.missed});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.cherry,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total Classes',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _Stat(label: 'Attended', value: attended),
            const SizedBox(width: 48),
            _Stat(label: 'Missed', value: missed),
          ],
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '$value',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _UpcomingClassesCard extends StatelessWidget {
  final List<CourseModel> courses;
  const _UpcomingClassesCard({required this.courses});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.cardAlt(context),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Classes',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text(context),
              ),
            ),
            Text(
              '${courses.length} left',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.cherry.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (courses.isEmpty)
          const _EmptyClassesState()
        else
          ...courses.map((c) => _ClassRow(course: c)),
      ],
    ),
  );
}

class _EmptyClassesState extends StatelessWidget {
  const _EmptyClassesState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          color: AppColors.cherry.withValues(alpha: 0.5),
          size: 40,
        ),
        const SizedBox(height: 8),
        Text(
          'No more classes today 🎉',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.subtext(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class _ClassRow extends StatelessWidget {
  final CourseModel course;
  const _ClassRow({required this.course});

  @override
  Widget build(BuildContext context) {
    final parts = course.courseCode.split(' ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: AppColors.text(context),
                    ),
                    children: [
                      TextSpan(
                        text: '${parts.first} ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text:
                            '${parts.length > 1 ? parts.sublist(1).join(" ") : ""}'
                            ' - ${course.formattedStart}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  course.room,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.subtext(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: course.dotColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
