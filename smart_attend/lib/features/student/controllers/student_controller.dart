import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/student/models/course_model.dart';

class StudentController {
  // ── FETCH DASHBOARD STATS ─────────────────────────────────────────
  // GET /api/attendance/my-dashboard-stats
  // Returns attended/absent counts + student name from DB.
  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final session = await SessionService.getSession();
    if (session == null) return {};

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.attendanceUrl}/my-dashboard-stats'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  // ── FETCH ENROLLED COURSES ────────────────────────────────────────
  // GET /api/attendance/my-enrolled-courses
  // Returns the courses the student is registered for this semester.
  Future<List<CourseModel>> fetchEnrolledCourses(String studentId) async {
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

      return courses
          .map(
            (c) => CourseModel(
              id: c['_id']?.toString() ?? c['courseCode'] as String? ?? '',
              courseCode: c['courseCode'] as String? ?? '',
              courseName: c['courseName'] as String? ?? '',
              instructor: c['assignedLecturerName'] as String? ?? '',
              startTime: const TimeOfDay(hour: 8, minute: 0),
              endTime: const TimeOfDay(hour: 9, minute: 30),
              weekdays: [],
              room: '',
            ),
          )
          .toList();
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
