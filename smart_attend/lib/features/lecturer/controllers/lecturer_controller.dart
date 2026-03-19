import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/auth/services/location_service.dart';
import 'package:smart_attend/features/lecturer/models/lecturer_model.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';

class LecturerController {
  static const int refreshInPerson = 20;
  static const int refreshOnline = 20;

  // ── FETCH LECTURER PROFILE ────────────────────────────────────────
  // GET /api/auth/me — returns the authenticated user's own record.
  Future<LecturerModel> fetchProfile(String lecturerId) async {
    final session = await SessionService.getSession();
    if (session == null) throw Exception('Not authenticated.');

    final response = await http
        .get(
      Uri.parse('${AppConfig.authUrl}/me'),
      headers: {'Authorization': 'Bearer ${session.token}'},
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final u = body['user'] as Map<String, dynamic>;
      return LecturerModel(
        id: u['_id'] as String? ?? '',
        fullName: u['fullName'] as String? ?? '',
        email: u['email'] as String? ?? '',
        staffId: u['staffId'] as String? ?? '',
        department: u['department'] as String? ?? '',
        role: u['role'] as String? ?? 'lecturer',
        courseIds: [], // courses fetched separately
      );
    }

    // Fallback — build from saved session so the UI still works offline
    return LecturerModel(
      id: session.id,
      fullName: session.fullName,
      email: session.email,
      staffId: session.staffId ?? '',
      department: session.department ?? '',
      role: session.role,
      courseIds: [],
    );
  }

  // ── FETCH TODAY'S STATS ───────────────────────────────────────────
  // GET /api/attendance/sessions?isActive=false — counts today's
  // sessions that belong to this lecturer.
  // ── FETCH WEEKLY STATS ────────────────────────────────────────────
  // GET /api/attendance/my-weekly-stats
  Future<WeeklyStats> fetchWeeklyStats(String lecturerId) async {
    final session = await SessionService.getSession();
    if (session == null) return WeeklyStats.empty();

    try {
      final response = await http
          .get(
        Uri.parse('${AppConfig.attendanceUrl}/my-weekly-stats'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return WeeklyStats.empty();

      final b = jsonDecode(response.body) as Map<String, dynamic>;
      return WeeklyStats(
        scheduled: (b['scheduled'] as num?)?.toInt() ?? 0,
        held: (b['held'] as num?)?.toInt() ?? 0,
        notHeld: (b['notHeld'] as num?)?.toInt() ?? 0,
        inPerson: (b['inPerson'] as num?)?.toInt() ?? 0,
        online: (b['online'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return WeeklyStats.empty();
    }
  }

  // ── FETCH ASSIGNED COURSES ────────────────────────────────────────
  // Derived from the lecturer's own past sessions — groups unique
  // course codes so the lecturer can start a new session for any
  // course they have taught.
  //
  // GET /api/attendance/sessions (all own sessions, deduplicated by courseCode)
  Future<List<LecturerCourseModel>> fetchCourses(String lecturerId) async {
    final session = await SessionService.getSession();
    if (session == null) return [];

    try {
      final response = await http
          .get(
        Uri.parse('${AppConfig.attendanceUrl}/my-courses'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final courses = (body['courses'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      return courses
          .map(
            (c) => LecturerCourseModel(
          id: c['_id'] as String? ?? '',
          courseCode: c['courseCode'] as String? ?? '',
          courseName: c['courseName'] as String? ?? '',
          department:
          c['department'] as String? ?? c['faculty'] as String? ?? '',
          totalStudents: (c['enrolledStudents'] as num?)?.toInt() ?? 0,
          weekdays: [],
          schedule: '',
          room: '',
          startTime: '',
          endTime: '',
        ),
      )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── FETCH WEEKLY SCHEDULE ─────────────────────────────────────────
  // GET /api/attendance/my-timetable — returns the lecturer's timetable
  // slots, then overlays session status from this week's past sessions.
  Future<List<WeeklySessionModel>> fetchWeeklySchedule(
      String lecturerId,
      ) async {
    final session = await SessionService.getSession();
    if (session == null) return [];

    try {
      // Fetch timetable and recent sessions in parallel
      final responses = await Future.wait([
        http
            .get(
          Uri.parse('${AppConfig.attendanceUrl}/my-timetable'),
          headers: {'Authorization': 'Bearer ${session.token}'},
        )
            .timeout(const Duration(seconds: 10)),
        http
            .get(
          Uri.parse('${AppConfig.attendanceUrl}/sessions?limit=50'),
          headers: {'Authorization': 'Bearer ${session.token}'},
        )
            .timeout(const Duration(seconds: 10)),
      ]);

      final timetableResp = responses[0];
      final sessionsResp = responses[1];

      if (timetableResp.statusCode != 200) return [];

      final slots = (jsonDecode(timetableResp.body)['slots'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      if (slots.isEmpty) return [];

      // Build courseCode → session map for this week
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));

      final Map<String, Map<String, dynamic>> sessionByCode = {};
      if (sessionsResp.statusCode == 200) {
        final allSessions =
        (jsonDecode(sessionsResp.body)['sessions'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        for (final s in allSessions) {
          final created = DateTime.tryParse(s['createdAt'] as String? ?? '');
          if (created == null) continue;
          final d = DateTime(created.year, created.month, created.day);
          final inWeek =
              !d.isBefore(DateTime(monday.year, monday.month, monday.day)) &&
                  !d.isAfter(DateTime(sunday.year, sunday.month, sunday.day));
          if (!inWeek) continue;
          final code = s['courseCode'] as String? ?? '';
          // keep the most recent session per course
          if (code.isNotEmpty && !sessionByCode.containsKey(code)) {
            sessionByCode[code] = s;
          }
        }
      }

      const dayOrder = {
        'Mon': 1,
        'Tue': 2,
        'Wed': 3,
        'Thu': 4,
        'Fri': 5,
        'Sat': 6,
      };

      DateTime _dateForDay(String day) {
        final offset = (dayOrder[day] ?? 1) - 1;
        return monday.add(Duration(days: offset));
      }

      final result = slots.map((slot) {
        final day = slot['day'] as String? ?? 'Mon';
        final code = slot['courseCode'] as String? ?? '';
        final slotDate = _dateForDay(day);
        final startTime = slot['startTime'] as String? ?? '';
        final endTime = slot['endTime'] as String? ?? '';

        // Determine status
        SessionStatus status = SessionStatus.upcoming;
        int? studentsAttended;
        final dayDate = DateTime(slotDate.year, slotDate.month, slotDate.day);
        final today = DateTime(now.year, now.month, now.day);

        if (dayDate.isBefore(today)) {
          // Past day
          final s = sessionByCode[code];
          if (s != null) {
            status = SessionStatus.held;
          } else {
            status = SessionStatus.notHeld;
          }
        } else if (dayDate.isAtSameMomentAs(today)) {
          // Today
          final s = sessionByCode[code];
          if (s != null) {
            final isActive = s['isActive'] as bool? ?? false;
            final expiresAt = DateTime.tryParse(
              s['expiresAt'] as String? ?? '',
            );
            final expired = expiresAt != null && expiresAt.isBefore(now);
            status = (isActive && !expired)
                ? SessionStatus.active
                : SessionStatus.held;
          }
          // else stays upcoming
        }

        return WeeklySessionModel(
          id: slot['_id'] as String? ?? '',
          courseCode: code,
          courseName: slot['courseName'] as String? ?? '',
          room: slot['room'] as String? ?? '',
          date: slotDate,
          startTime: startTime,
          endTime: endTime,
          status: status,
          studentsAttended: studentsAttended,
          totalStudents: (slot['enrolledStudents'] as num?)?.toInt(),
        );
      }).toList();

      // Sort by day order then startTime
      result.sort((a, b) {
        final da = dayOrder[a.dayLabel] ?? 7;
        final db = dayOrder[b.dayLabel] ?? 7;
        if (da != db) return da.compareTo(db);
        return a.startTime.compareTo(b.startTime);
      });

      return result;
    } catch (_) {
      return [];
    }
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }

  // ── FETCH COURSE SUMMARY ──────────────────────────────────────────
  // GET /api/attendance/my-course-summary
  Future<List<CourseSummaryModel>> fetchCourseSummary() async {
    final session = await SessionService.getSession();
    if (session == null) return [];

    try {
      final response = await http
          .get(
        Uri.parse('${AppConfig.attendanceUrl}/my-course-summary'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final courses = (body['courses'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      return courses.map((c) {
        final rawHistory = (c['sessionHistory'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        final history = rawHistory
            .map(
              (s) => SessionHistoryModel(
            sessionId: s['sessionId']?.toString() ?? '',
            date:
            DateTime.tryParse(s['date'] as String? ?? '') ??
                DateTime.now(),
            type: s['type'] as String? ?? 'inPerson',
            studentsPresent: (s['studentsPresent'] as num?)?.toInt() ?? 0,
            studentsAbsent: (s['studentsAbsent'] as num?)?.toInt() ?? 0,
            totalStudents: (s['totalStudents'] as num?)?.toInt() ?? 0,
          ),
        )
            .toList();

        return CourseSummaryModel(
          id: c['_id']?.toString() ?? '',
          courseCode: c['courseCode'] as String? ?? '',
          courseName: c['courseName'] as String? ?? '',
          department:
          c['department'] as String? ?? c['faculty'] as String? ?? '',
          totalStudents: (c['totalStudents'] as num?)?.toInt() ?? 0,
          held: (c['held'] as num?)?.toInt() ?? 0,
          inPerson: (c['inPerson'] as num?)?.toInt() ?? 0,
          online: (c['online'] as num?)?.toInt() ?? 0,
          sessionHistory: history,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── FETCH SESSION DETAIL ──────────────────────────────────────────
  // GET /api/attendance/sessions/:sessionId/detail
  Future<Map<String, dynamic>?> fetchSessionDetail(String sessionId) async {
    final session = await SessionService.getSession();
    if (session == null) return null;

    try {
      final response = await http
          .get(
        Uri.parse('${AppConfig.attendanceUrl}/sessions/$sessionId/detail'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── GET LOCATION ──────────────────────────────────────────────────
  // Uses the shared LocationService which handles all permission
  // checking and throws descriptive exceptions on failure.
  Future<Position?> getCurrentPosition() async {
    try {
      return await LocationService.getCurrentLocation();
    } catch (_) {
      return null;
    }
  }

  // ── REFRESH 6-DIGIT CODE FROM BACKEND ────────────────────────────
  // POST /api/attendance/sessions/:sessionId/refresh-code
  // Called every _kCodeRotateSeconds by the active session screen.
  // Returns the new code string, or null if the request fails.
  Future<String?> refreshCode({required String sessionId}) async {
    final session = await SessionService.getSession();
    if (session == null) return null;

    try {
      final response = await http
          .post(
        Uri.parse(
          '${AppConfig.attendanceUrl}/sessions/$sessionId/refresh-code',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.token}',
        },
      )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['code'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── START AN ATTENDANCE SESSION ───────────────────────────────────
  // POST /api/attendance/sessions
  Future<ActiveSessionModel?> startSession({
    required LecturerCourseModel course,
    required AttendanceType type,
    required AttendanceMethod method,
    required int durationSeconds,
    Position? position, // pre-fetched by caller — avoids double GPS call
  }) async {
    Position? pos = position;

    // Only fetch location if not already provided and type is in-person
    if (type == AttendanceType.inPerson && pos == null) {
      pos = await getCurrentPosition();
      if (pos == null) return null;
    }

    final session = await SessionService.getSession();
    if (session == null) return null;

    try {
      final response = await http
          .post(
        Uri.parse('${AppConfig.attendanceUrl}/sessions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.token}',
        },
        body: jsonEncode({
          'courseCode': course.courseCode,
          'courseName': course.courseName,
          'type': type == AttendanceType.inPerson ? 'inPerson' : 'online',
          'durationSeconds': durationSeconds,
          if (pos != null) 'lecturerLat': pos.latitude,
          if (pos != null) 'lecturerLng': pos.longitude,
        }),
      )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 201) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final sessionId = body['sessionId'] as String;
      final qrPayload = body['qrPayload'] as Map<String, dynamic>;
      final qrData = jsonEncode({
        ...qrPayload,
        'courseName': course.courseName,
      });

      // Code is now generated server-side and returned in the response.
      // Never generate it locally — the backend must always know the
      // current code so students can check in against it.
      final sixDigitCode = body['code'] as String? ?? '';

      return ActiveSessionModel(
        sessionId: sessionId,
        courseCode: course.courseCode,
        courseName: course.courseName,
        type: type,
        method: method,
        qrData: qrData,
        sixDigitCode: sixDigitCode,
        totalSeconds: durationSeconds,
        secondsLeft: durationSeconds,
        studentsMarked: 0,
        totalStudents: course.totalStudents,
        lecturerLat: pos?.latitude,
        lecturerLng: pos?.longitude,
      );
    } catch (_) {
      return null;
    }
  }

  // ── END SESSION ON BACKEND ────────────────────────────────────────
  // PATCH /api/attendance/sessions/:id/end
  Future<bool> endSessionOnBackend(String sessionId) async {
    final session = await SessionService.getSession();
    if (session == null) return false;

    try {
      final response = await http
          .patch(
        Uri.parse('${AppConfig.attendanceUrl}/sessions/$sessionId/end'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.token}',
        },
      )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── REFRESH QR PAYLOAD ───────────────────────────────────────────
  // POST /api/attendance/sessions/:sessionId/refresh-qr
  // Returns a fresh short-lived (20s) signed QR payload for an
  // active session. Called every 15s by the active session screen.
  Future<Map<String, dynamic>?> refreshQrPayload({
    required String sessionId,
    required String courseName,
  }) async {
    final session = await SessionService.getSession();
    if (session == null) return null;

    try {
      final response = await http
          .post(
        Uri.parse(
          '${AppConfig.attendanceUrl}/sessions/$sessionId/refresh-qr',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.token}',
        },
      )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final qrPayload = body['qrPayload'] as Map<String, dynamic>;

      // Embed courseName for student-side display
      return {...qrPayload, 'courseName': courseName};
    } catch (_) {
      return null;
    }
  }

  // ── GET LIVE STUDENT COUNT ────────────────────────────────────────
  // GET /api/attendance/sessions/:sessionId/count
  Future<int> getSessionCount(String sessionId) async {
    final session = await SessionService.getSession();
    if (session == null) return 0;

    try {
      final response = await http
          .get(
        Uri.parse('${AppConfig.attendanceUrl}/sessions/$sessionId/count'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return 0;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

}