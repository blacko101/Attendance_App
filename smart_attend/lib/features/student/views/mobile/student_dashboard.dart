import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_attend/features/student/controllers/student_controller.dart';
import 'package:smart_attend/features/student/models/course_model.dart';

// ── Theme constants ──────────────────────────
const kCherry = Color(0xFF9B1B42);
const kWhite  = Color(0xFFFFFFFF);
const kBg     = Color(0xFFEEEEF3);
const kCard   = Color(0xFFF5F5F8);

class StudentDashboard extends StatefulWidget {
  static String id = 'student_dashboard'; // ← added for routing
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  // ── Controller (MVC) ──
  final _controller = StudentController();

  int _currentIndex = 0;
  List<CourseModel> _allCourses = [];
  bool _loading = true;

  // TODO: Pull these from AttendanceController in a later sprint
  static const int _totalAttended = 120;
  static const int _totalMissed   = 20;
  double get _attendanceRate => _totalAttended / (_totalAttended + _totalMissed);

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _loading = true);
    // TODO: Replace 'student_001' with logged-in user ID from AuthController
    final courses = await _controller.fetchEnrolledCourses('student_001');
    if (mounted) {
      setState(() {
        _allCourses = courses;
        _loading = false;
      });
    }
  }

  List<CourseModel> get _upcomingToday =>
      _controller.getUpcomingToday(_allCourses);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(children: [

          // ── Top Bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _NeumorphicBtn(
                icon: Icons.chevron_left_rounded,
                onTap: () => Navigator.pop(context),
              ),
              _NotifBtn(onTap: () {}),
            ]),
          ),

          Text('Overall Attendance',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
          const SizedBox(height: 24),

          _AttendanceRing(percentage: _attendanceRate),
          const SizedBox(height: 28),

          // ── Body ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kCherry))
                : RefreshIndicator(
              color: kCherry,
              onRefresh: _loadCourses,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [
                  _TotalClassesCard(
                    attended: _totalAttended,
                    missed: _totalMissed,
                  ),
                  const SizedBox(height: 16),
                  _UpcomingClassesCard(courses: _upcomingToday),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ),
        ]),
      ),

      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  WIDGETS (View only — no logic here)
// ─────────────────────────────────────────────

class _NeumorphicBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NeumorphicBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: kBg, shape: BoxShape.circle, boxShadow: [
        BoxShadow(color: Colors.white.withValues(alpha: 0.85), offset: const Offset(-3,-3), blurRadius: 6),
        BoxShadow(color: Colors.black.withValues(alpha: 0.12), offset: const Offset(3,3), blurRadius: 6),
      ]),
      child: Icon(icon, color: const Color(0xFF555555), size: 22),
    ),
  );
}

class _NotifBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _NotifBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: kBg, shape: BoxShape.circle, boxShadow: [
          BoxShadow(color: Colors.white.withValues(alpha: 0.85), offset: const Offset(-3,-3), blurRadius: 6),
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), offset: const Offset(3,3), blurRadius: 6),
        ]),
        child: const Icon(Icons.notifications_outlined, color: Color(0xFF555555), size: 22),
      ),
      Positioned(top: 8, right: 8,
          child: Container(width: 8, height: 8,
              decoration: const BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle))),
    ]),
  );
}

class _AttendanceRing extends StatelessWidget {
  final double percentage;
  const _AttendanceRing({required this.percentage});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180, height: 180,
    child: CustomPaint(
      painter: _RingPainter(percentage: percentage),
      child: Center(child: Text('${(percentage * 100).toInt()}%',
          style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)))),
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
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, pi * 1.5, false,
        Paint()..color = const Color(0xFFE8B4BE)..style = PaintingStyle.stroke..strokeWidth = sw..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, pi * 1.5 * percentage, false,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xFF9B1B42), Color(0xFFB84060)])
              .createShader(Rect.fromCircle(center: c, radius: r))
          ..style = PaintingStyle.stroke..strokeWidth = sw..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.percentage != percentage;
}

class _TotalClassesCard extends StatelessWidget {
  final int attended, missed;
  const _TotalClassesCard({required this.attended, required this.missed});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: kCherry, borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Total Classes',
          style: GoogleFonts.poppins(color: kWhite, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      Row(children: [
        _Stat(label: 'Attended', value: attended),
        const SizedBox(width: 48),
        _Stat(label: 'Missed', value: missed),
      ]),
    ]),
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
      Text(label, style: GoogleFonts.poppins(color: kWhite.withValues(alpha: 0.85), fontSize: 14)),
      const SizedBox(height: 4),
      Text('$value', style: GoogleFonts.poppins(color: kWhite, fontSize: 26, fontWeight: FontWeight.w800)),
    ],
  );
}

class _UpcomingClassesCard extends StatelessWidget {
  final List<CourseModel> courses;
  const _UpcomingClassesCard({required this.courses});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Upcoming Classes',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
        Text('${courses.length} left',
            style: GoogleFonts.poppins(fontSize: 12, color: kCherry.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
      ]),
      const SizedBox(height: 16),
      if (courses.isEmpty)
        _EmptyClassesState()
      else
        ...courses.map((c) => _ClassRow(course: c)),
    ]),
  );
}

class _EmptyClassesState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(children: [
      Icon(Icons.check_circle_outline_rounded, color: kCherry.withValues(alpha: 0.5), size: 40),
      const SizedBox(height: 8),
      Text('No more classes today 🎉',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
    ]),
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
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(text: TextSpan(
            style: GoogleFonts.poppins(fontSize: 15, color: const Color(0xFF1A1A1A)),
            children: [
              TextSpan(text: '${parts.first} ',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(
                  text: '${parts.length > 1 ? parts.sublist(1).join(" ") : ""} - ${course.formattedStart}'),
            ],
          )),
          const SizedBox(height: 2),
          Text(course.room,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
        ]),
        Container(width: 12, height: 12,
            decoration: BoxDecoration(color: course.dotColor, shape: BoxShape.circle)),
      ]),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    height: 80,
    decoration: BoxDecoration(color: kWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))]),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _NavItem(icon: Icons.home_outlined,           label: 'Home',          index: 0, ci: currentIndex, onTap: onTap),
      _NavItem(icon: Icons.grid_view_rounded,       label: 'Classes',       index: 1, ci: currentIndex, onTap: onTap),
      GestureDetector(
          onTap: () => onTap(2),
          child: Container(width: 58, height: 58,
              decoration: BoxDecoration(color: kCherry, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: kCherry.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))]),
              child: const Icon(Icons.qr_code_scanner_rounded, color: kWhite, size: 26))),
      _NavItem(icon: Icons.notifications_outlined,  label: 'Notifications', index: 3, ci: currentIndex, onTap: onTap),
      _NavItem(icon: Icons.person_outline_rounded,  label: 'Profile',       index: 4, ci: currentIndex, onTap: onTap),
    ]),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, ci;
  final ValueChanged<int> onTap;
  const _NavItem({required this.icon, required this.label, required this.index, required this.ci, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = ci == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: active ? kCherry : const Color(0xFF888888), size: 24),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 10,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? kCherry : const Color(0xFF888888))),
      ]),
    );
  }
}
