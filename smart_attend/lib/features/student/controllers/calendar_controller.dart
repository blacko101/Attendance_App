import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/student/models/attendance_model.dart';

class CalendarController {
  // ── FETCH ATTENDANCE DATA FOR A GIVEN MONTH ───────────────────────
  // Uses the real student ID from session — never hardcoded.
  // GET /api/attendance/student/:studentId
  Future<Map<String, DayAttendanceModel>> fetchMonthAttendance(
    String studentId, // kept for API compatibility but we override with session
    int month,
    int year,
  ) async {
    final session = await SessionService.getSession();
    if (session == null) return {};

    // Always use the authenticated user's real ID
    final realId = session.id;

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.attendanceUrl}/student/$realId'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return {};

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final records = (body['records'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      final Map<String, DayAttendanceModel> data = {};

      for (final r in records) {
        final checkedInRaw = r['checkedInAt'] as String? ?? '';
        final checkedIn = DateTime.tryParse(checkedInRaw);
        if (checkedIn == null) continue;

        // Filter to requested month/year only
        if (checkedIn.month != month || checkedIn.year != year) continue;

        final sess = r['sessionId'] as Map<String, dynamic>? ?? {};
        final courseCode =
            sess['courseCode'] as String? ?? r['courseCode'] as String? ?? '';
        final courseName = sess['courseName'] as String? ?? courseCode;
        final type = sess['type'] as String? ?? 'inPerson';
        final status = r['status'] as String? ?? 'present';

        final sessionModel = ClassSessionModel(
          id: r['_id'] as String? ?? '',
          courseCode: courseCode,
          courseName: courseName,
          instructor: '',
          room: type == 'online' ? 'Online' : '',
          startTime: TimeOfDay(hour: checkedIn.hour, minute: checkedIn.minute),
          endTime: TimeOfDay(
            hour: (checkedIn.hour + 1) % 24,
            minute: checkedIn.minute,
          ),
          status: status == 'present'
              ? AttendanceStatus.present
              : AttendanceStatus.absent,
        );

        final key = _key(checkedIn);
        final dayDate = DateTime(
          checkedIn.year,
          checkedIn.month,
          checkedIn.day,
        );

        if (data.containsKey(key)) {
          final existing = data[key]!;
          data[key] = DayAttendanceModel(
            date: existing.date,
            sessions: [...existing.sessions, sessionModel],
          );
        } else {
          data[key] = DayAttendanceModel(
            date: dayDate,
            sessions: [sessionModel],
          );
        }
      }

      return data;
    } catch (_) {
      return {};
    }
  }

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';
  String keyFromDate(DateTime d) => _key(d);

  int countPresent(Map<String, DayAttendanceModel> data) => data.values
      .expand((d) => d.sessions)
      .where((s) => s.status == AttendanceStatus.present)
      .length;

  int countAbsent(Map<String, DayAttendanceModel> data) => data.values
      .expand((d) => d.sessions)
      .where((s) => s.status == AttendanceStatus.absent)
      .length;
}
