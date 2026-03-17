import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/student/models/course_detail_model.dart';

class CoursesController {
  // ── FETCH COURSES WITH ATTENDANCE BREAKDOWN ───────────────────────
  // GET /api/attendance/student/:studentId
  // Groups the student's attendance records by courseCode and computes
  // present/absent counts — no hardcoded values.
  Future<List<CourseAttendanceModel>> fetchCoursesAttendance(
    String studentId,
  ) async {
    final session = await SessionService.getSession();
    if (session == null) return [];

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.attendanceUrl}/student/$studentId'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final records = (body['records'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      // Group records by courseCode
      final Map<String, List<Map<String, dynamic>>> byCode = {};
      for (final r in records) {
        final sess = r['sessionId'];
        final code =
            (sess is Map ? sess['courseCode'] : null) as String? ??
            r['courseCode'] as String? ??
            '';
        if (code.isEmpty) continue;
        byCode.putIfAbsent(code, () => []).add(r);
      }

      return byCode.entries.map((e) {
        final code = e.key;
        final recs = e.value;
        final first = recs.first;
        final sess = first['sessionId'] as Map<String, dynamic>? ?? {};
        final name = sess['courseName'] as String? ?? code;

        // Build per-session history — one entry per attendance record
        final history = recs.map((r) {
          final checkedIn =
              DateTime.tryParse(r['checkedInAt'] as String? ?? '') ??
              DateTime.now();
          final status = r['status'] as String? ?? 'present';
          return CourseSessionHistory(
            date: checkedIn,
            attended: status == 'present',
          );
        }).toList()..sort((a, b) => b.date.compareTo(a.date)); // newest first

        final attended = recs
            .where((r) => (r['status'] as String? ?? '') == 'present')
            .length;
        final total = recs.length;
        final absent = total - attended;

        return CourseAttendanceModel(
          id: code,
          courseCode: code,
          courseName: name,
          instructor: '',
          room: '',
          schedule: '',
          totalClasses: total,
          attended: attended,
          absent: absent,
          history: history,
        );
      }).toList()..sort((a, b) => a.attendanceRate.compareTo(b.attendanceRate));
    } catch (_) {
      return [];
    }
  }

  // ── Sort by most absences (worst first) ──────────────────────────
  List<CourseAttendanceModel> sortByMostAbsences(
    List<CourseAttendanceModel> courses,
  ) {
    final sorted = [...courses];
    sorted.sort((a, b) => a.attendanceRate.compareTo(b.attendanceRate));
    return sorted;
  }
}
