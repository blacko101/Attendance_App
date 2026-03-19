import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/student/models/course_detail_model.dart';

class CoursesController {
  // ── FETCH MY COURSE ATTENDANCE BREAKDOWN ──────────────────────────
  // GET /api/attendance/my-enrolled-courses
  // Returns each enrolled course with attendance stats from the DB.
  Future<List<CourseAttendanceModel>> fetchCoursesAttendance(
    String studentId,
  ) async {
    final session = await SessionService.getSession();
    if (session == null) return [];

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.attendanceUrl}/my-enrolled-courses'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final courses = (body['courses'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      return courses.map((c) {
        final total = (c['totalClasses'] as num?)?.toInt() ?? 0;
        final attended = (c['attended'] as num?)?.toInt() ?? 0;
        final absent = (c['absent'] as num?)?.toInt() ?? 0;

        // Build per-session history from the attendance records if present
        final rawHistory = (c['history'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        final history = rawHistory.map((h) {
          final date =
              DateTime.tryParse(h['checkedInAt'] as String? ?? '') ??
              DateTime.now();
          return CourseSessionHistory(
            date: date,
            attended: (h['status'] as String? ?? '') == 'present',
          );
        }).toList()..sort((a, b) => b.date.compareTo(a.date));

        return CourseAttendanceModel(
          id: c['_id']?.toString() ?? c['courseCode'] as String? ?? '',
          courseCode: c['courseCode'] as String? ?? '',
          courseName: c['courseName'] as String? ?? '',
          instructor: c['assignedLecturerName'] as String? ?? '',
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

  // ── FETCH AVAILABLE COURSES FOR ENROLLMENT ────────────────────────
  // GET /api/attendance/available-courses
  // Returns all courses for this student's programme/faculty.
  Future<List<AvailableCourseModel>> fetchAvailableCourses() async {
    final session = await SessionService.getSession();
    if (session == null) return [];

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.attendanceUrl}/available-courses'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final courses = (body['courses'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      return courses
          .map(
            (c) => AvailableCourseModel(
              id: c['_id']?.toString() ?? '',
              courseCode: c['courseCode'] as String? ?? '',
              courseName: c['courseName'] as String? ?? '',
              creditHours: (c['creditHours'] as num?)?.toInt() ?? 3,
              level: c['level'] as String? ?? '',
              lecturer: c['assignedLecturerName'] as String? ?? '',
              isEnrolled: c['isEnrolled'] as bool? ?? false,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── ENROLL IN COURSES ─────────────────────────────────────────────
  // POST /api/attendance/enroll
  // Sends selected course codes + password to backend for verification.
  // Returns null on success, or an error message string on failure.
  Future<String?> enrollCourses({
    required List<String> courseCodes,
    required String password,
  }) async {
    final session = await SessionService.getSession();
    if (session == null) return 'Session expired. Please log in again.';

    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.attendanceUrl}/enroll'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.token}',
            },
            body: jsonEncode({
              'courseCodes': courseCodes,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) return null; // success
      return body['message'] as String? ?? 'Enrollment failed.';
    } catch (_) {
      return 'Connection error. Check your internet.';
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

// ── Model for a course available for enrollment ───────────────────
class AvailableCourseModel {
  final String id;
  final String courseCode;
  final String courseName;
  final int creditHours;
  final String level;
  final String lecturer;
  final bool isEnrolled;

  const AvailableCourseModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.creditHours,
    required this.level,
    required this.lecturer,
    required this.isEnrolled,
  });
}
