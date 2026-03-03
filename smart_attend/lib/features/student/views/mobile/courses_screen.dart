import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_attend/features/student/controllers/courses_controller.dart';
import 'package:smart_attend/features/student/models/course_detail_model.dart';

const _kCherry   = Color(0xFF9B1B42);
const _kCherryBg = Color(0xFFFFEEF2);
const _kGreen    = Color(0xFF4CAF50);
const _kBg       = Color(0xFFEEEEF3);
const _kCard     = Color(0xFFF5F5F8);
const _kWhite    = Color(0xFFFFFFFF);

class CoursesScreen extends StatefulWidget {
  static String id = 'courses_screen';
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final _controller = CoursesController();
  List<CourseAttendanceModel> _courses = [];
  bool _loading = true;
  String _sortBy = 'absences';

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _loading = true);
    final data = await _controller.fetchCoursesAttendance('student_001');
    if (mounted) {
      setState(() {
        _courses = _controller.sortByMostAbsences(data);
        _loading = false;
      });
    }
  }

  void _toggleSort() {
    setState(() {
      if (_sortBy == 'absences') {
        _sortBy = 'name';
        _courses.sort((a, b) => a.courseCode.compareTo(b.courseCode));
      } else {
        _sortBy = 'absences';
        _courses = _controller.sortByMostAbsences(_courses);
      }
    });
  }

  double get _overallRate {
    if (_courses.isEmpty) return 0;
    final total    = _courses.fold(0, (s, c) => s + c.totalClasses);
    final attended = _courses.fold(0, (s, c) => s + c.attended);
    return total == 0 ? 0 : (attended / total) * 100;
  }

  int get _warningCount =>
      _courses.where((c) => c.isWarning || c.isDanger).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(children: [

          // ── Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Courses',
                    style: GoogleFonts.poppins(
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A))),
                GestureDetector(
                  onTap: _toggleSort,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kCherryBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.sort_rounded, size: 14, color: _kCherry),
                      const SizedBox(width: 4),
                      Text(
                          _sortBy == 'absences' ? 'By Risk' : 'By Name',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: _kCherry,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          if (!_loading) _buildSummaryCard(),
          const SizedBox(height: 16),

          Expanded(
            child: _loading
                ? const Center(
                child: CircularProgressIndicator(color: _kCherry))
                : RefreshIndicator(
              color: _kCherry,
              onRefresh: _loadCourses,
              child: ListView.separated(
                // FIX 7: Bottom padding clears the FAB + nav bar
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                itemCount: _courses.length,
                separatorBuilder: (_, _) =>
                const SizedBox(height: 12),
                itemBuilder: (context, i) => _CourseCard(
                  course: _courses[i],
                  onTap: () => _showCourseDetail(_courses[i]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCherry,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          SizedBox(
            width: 70, height: 70,
            child: CustomPaint(
              painter: _MiniRingPainter(percentage: _overallRate / 100),
              child: Center(
                child: Text('${_overallRate.toInt()}%',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: _kWhite)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overall Attendance',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: _kWhite.withValues(alpha: 0.85))),
                  Text('${_courses.length} courses this semester',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: _kWhite.withValues(alpha: 0.65))),
                  const SizedBox(height: 8),
                  if (_warningCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.warning_rounded,
                            size: 12, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                            '$_warningCount course${_warningCount > 1 ? "s" : ""} need attention',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: _kWhite,
                                fontWeight: FontWeight.w600)),
                      ]),
                    )
                  else
                    Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 14, color: Colors.greenAccent),
                      const SizedBox(width: 4),
                      Text('All courses on track!',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: _kWhite,
                              fontWeight: FontWeight.w500)),
                    ]),
                ]),
          ),
        ]),
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
//  COURSE CARD
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
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(course.courseCode,
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A1A1A))),
                        Text(course.courseName,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey.shade500)),
                      ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: course.statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(course.statusIcon,
                        size: 12, color: course.statusColor),
                    const SizedBox(width: 4),
                    Text(course.statusLabel,
                        style: GoogleFonts.poppins(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: course.statusColor)),
                  ]),
                ),
              ]),

              const SizedBox(height: 12),

              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: course.attendanceRate / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(course.statusColor),
                  minHeight: 8,
                ),
              ),

              const SizedBox(height: 10),

              Row(children: [
                _InfoChip(
                    icon: Icons.check_rounded,
                    label: '${course.attended} attended',
                    color: _kGreen),
                const SizedBox(width: 8),
                _InfoChip(
                    icon: Icons.close_rounded,
                    label: '${course.absent} absent',
                    color: _kCherry),
                const Spacer(),
                Text('${course.attendancePercent}%',
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: course.statusColor)),
              ]),

              const SizedBox(height: 10),

              Row(children: [
                Icon(Icons.person_outline_rounded,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(course.instructor,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey.shade500)),
                ),
                const SizedBox(width: 12),
                Icon(Icons.schedule_rounded,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(course.schedule,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey.shade500)),
                ),
              ]),

              if (course.isWarning || course.isDanger) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: course.statusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_rounded,
                        size: 14, color: course.statusColor),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                          course.isDanger
                              ? '⚠️ Critical! Attend next class immediately.'
                              : '${course.absencesBeforeWarning} more absence${course.absencesBeforeWarning == 1 ? "" : "s"} before penalty.',
                          style: GoogleFonts.poppins(
                              fontSize: 11, fontWeight: FontWeight.w500,
                              color: course.statusColor)),
                    ),
                  ]),
                ),
              ],
            ]),
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
      minChildSize:     0.5,
      maxChildSize:     0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: _kWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [

          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.courseCode,
                          style: GoogleFonts.poppins(
                              fontSize: 18, fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A))),
                      Text(course.courseName,
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.grey.shade500)),
                    ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _kCherry,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${course.attendancePercent}%',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _kWhite)),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _SheetStat(label: 'Total',
                  value: '${course.totalClasses}',
                  color: Colors.grey.shade600),
              _SheetStat(label: 'Attended',
                  value: '${course.attended}', color: _kGreen),
              _SheetStat(label: 'Absent',
                  value: '${course.absent}', color: _kCherry),
            ]),
          ),

          const SizedBox(height: 8),
          Divider(color: Colors.grey.shade100, thickness: 1),

          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 8),
            child: Row(children: [
              Text('Attendance History',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A))),
              const Spacer(),
              Text('${course.history.length} sessions',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade400)),
            ]),
          ),

          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: course.history.length,
              separatorBuilder: (_, _) => Divider(
                  color: Colors.grey.shade100,
                  thickness: 1, height: 1),
              itemBuilder: (_, i) {
                final h = course.history[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: h.attended
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEEF2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        h.attended
                            ? Icons.check_rounded
                            : Icons.close_rounded,
                        size: 18,
                        color: h.attended ? _kGreen : _kCherry,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h.formattedDate,
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1A1A1A))),
                            if (h.reason != null)
                              Text(h.reason!,
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic)),
                          ]),
                    ),
                    Text(h.attended ? 'Present' : 'Absent',
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: h.attended ? _kGreen : _kCherry)),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SMALL WIDGETS
// ─────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text(label,
          style: GoogleFonts.poppins(fontSize: 11, color: color)),
    ],
  );
}

class _SheetStat extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _SheetStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value,
          style: GoogleFonts.poppins(
              fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11, color: Colors.grey.shade400)),
    ]),
  );
}

class _MiniRingPainter extends CustomPainter {
  final double percentage;
  _MiniRingPainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final c  = Offset(size.width / 2, size.height / 2);
    final r  = size.width / 2 - 6;
    const sw = 6.0;
    const start = -pi * 0.5;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        start, pi * 2, false,
        Paint()
          ..color       = Colors.white.withValues(alpha: 0.3)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = sw);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        start, pi * 2 * percentage, false,
        Paint()
          ..color       = Colors.white
          ..style       = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap   = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_MiniRingPainter o) => o.percentage != percentage;
}