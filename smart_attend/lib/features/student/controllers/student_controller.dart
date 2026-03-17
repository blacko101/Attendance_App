import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/student/models/course_model.dart';

class StudentController {
  // ── FETCH ENROLLED COURSES ────────────────────────────────────────
  // Derived from the student's own attendance history.
  // GET /api/attendance/student/:studentId
  // Groups unique course codes into CourseModel entries so the
  // dashboard "Today's Classes" section shows real data.
  Future<List<CourseModel>> fetchEnrolledCourses(String studentId) async {
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

      // Deduplicate by courseCode — each unique course becomes one entry
      final Map<String, Map<String, dynamic>> seen = {};
      for (final r in records) {
        final sess = r['sessionId'];
        if (sess == null) continue;
        final code = (sess is Map ? sess['courseCode'] : null) as String? ?? '';
        if (code.isNotEmpty && !seen.containsKey(code)) {
          seen[code] = r;
        }
      }

      return seen.entries.map((e) {
        final r = e.value;
        final sess = r['sessionId'] as Map<String, dynamic>? ?? {};
        final code = sess['courseCode'] as String? ?? e.key;
        final name = sess['courseName'] as String? ?? code;

        return CourseModel(
          id: r['_id'] as String? ?? code,
          courseCode: code,
          courseName: name,
          instructor: '',
          // No schedule data in the attendance record — use placeholders
          // until a dedicated /courses endpoint exists on the backend.
          startTime: const TimeOfDay(hour: 8, minute: 0),
          endTime: const TimeOfDay(hour: 9, minute: 30),
          weekdays: [],
          room: '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── FILTER TODAY'S UPCOMING COURSES ──────────────────────────────
  List<CourseModel> getUpcomingToday(List<CourseModel> allCourses) {
    final upcoming = allCourses.where((c) => c.isUpcomingToday).toList();
    upcoming.sort((a, b) {
      final aMin = a.startTime.hour * 60 + a.startTime.minute;
      final bMin = b.startTime.hour * 60 + b.startTime.minute;
      return aMin.compareTo(bMin);
    });
    return upcoming;
  }
}
