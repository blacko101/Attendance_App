import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
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
  Future<Map<String, int>> fetchTodayStats(String lecturerId) async {
    final session = await SessionService.getSession();
    if (session == null) return _emptyStats();

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.attendanceUrl}/sessions'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return _emptyStats();

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final sessions = (body['sessions'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      // Filter to today only
      final today = DateTime.now();
      final todaySess = sessions.where((s) {
        final created = DateTime.tryParse(s['createdAt'] as String? ?? '');
        if (created == null) return false;
        return created.year == today.year &&
            created.month == today.month &&
            created.day == today.day;
      }).toList();

      final held = todaySess.where((s) => s['isActive'] == false).length;
      final active = todaySess.where((s) => s['isActive'] == true).length;
      final inPerson = todaySess.where((s) => s['type'] == 'inPerson').length;
      final online = todaySess.where((s) => s['type'] == 'online').length;

      return {
        'scheduled': todaySess.length,
        'attended': held,
        'missed': 0, // backend doesn't track "missed" yet
        'inPerson': inPerson,
        'online': online,
        'active': active,
      };
    } catch (_) {
      return _emptyStats();
    }
  }

  Map<String, int> _emptyStats() => {
    'scheduled': 0,
    'attended': 0,
    'missed': 0,
    'inPerson': 0,
    'online': 0,
    'active': 0,
  };

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
            Uri.parse('${AppConfig.attendanceUrl}/sessions?limit=100'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final sessions = (body['sessions'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      // Deduplicate by courseCode — keep the most recent entry per code
      final Map<String, Map<String, dynamic>> byCode = {};
      for (final s in sessions) {
        final code = s['courseCode'] as String? ?? '';
        if (code.isNotEmpty && !byCode.containsKey(code)) {
          byCode[code] = s;
        }
      }

      return byCode.entries.map((e) {
        final s = e.value;
        return LecturerCourseModel(
          id: s['_id'] as String? ?? e.key,
          courseCode: s['courseCode'] as String? ?? '',
          courseName: s['courseName'] as String? ?? '',
          department: session.department ?? '',
          totalStudents: 0, // enrollment count not yet in backend
          weekdays: [],
          schedule: '',
          room: '',
          startTime: '',
          endTime: '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── FETCH WEEKLY SCHEDULE ─────────────────────────────────────────
  // GET /api/attendance/sessions — returns the lecturer's own sessions
  // for the current week, mapped to WeeklySessionModel.
  Future<List<WeeklySessionModel>> fetchWeeklySchedule(
    String lecturerId,
  ) async {
    final session = await SessionService.getSession();
    if (session == null) return [];

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.attendanceUrl}/sessions?limit=50'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final sessions = (body['sessions'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      // Filter to current week
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));

      final weekSessions = sessions.where((s) {
        final created = DateTime.tryParse(s['createdAt'] as String? ?? '');
        if (created == null) return false;
        final d = DateTime(created.year, created.month, created.day);
        return !d.isBefore(DateTime(monday.year, monday.month, monday.day)) &&
            !d.isAfter(DateTime(sunday.year, sunday.month, sunday.day));
      }).toList();

      return weekSessions.map((s) {
        final isActive = s['isActive'] as bool? ?? false;
        final expiresAt = DateTime.tryParse(s['expiresAt'] as String? ?? '');
        final createdAt =
            DateTime.tryParse(s['createdAt'] as String? ?? '') ?? now;
        final expired = expiresAt != null && expiresAt.isBefore(now);

        SessionStatus status;
        if (isActive && !expired) {
          status = SessionStatus.active;
        } else if (!isActive) {
          status = SessionStatus.held;
        } else {
          // isActive=true but expired — ended by timer, not manually
          status = SessionStatus.held;
        }

        return WeeklySessionModel(
          id: s['_id'] as String? ?? '',
          courseCode: s['courseCode'] as String? ?? '',
          courseName: s['courseName'] as String? ?? '',
          room: '',
          date: createdAt,
          startTime: _fmtTime(createdAt),
          endTime: expiresAt != null ? _fmtTime(expiresAt) : '',
          status: status,
          totalStudents: 0,
        );
      }).toList();
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

  // ── GET LOCATION ──────────────────────────────────────────────────
  Future<Position?> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever)
      return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return last;
      } catch (_) {}
      return null;
    }
  }

  // ── GENERATE 6-DIGIT CODE ─────────────────────────────────────────
  String generateSixDigitCode() {
    final rng = Random.secure();
    return (100000 + rng.nextInt(900000)).toString();
  }

  // ── START AN ATTENDANCE SESSION ───────────────────────────────────
  // POST /api/attendance/sessions
  Future<ActiveSessionModel?> startSession({
    required LecturerCourseModel course,
    required AttendanceType type,
    required int durationSeconds,
  }) async {
    Position? pos;
    if (type == AttendanceType.inPerson) {
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

      return ActiveSessionModel(
        sessionId: sessionId,
        courseCode: course.courseCode,
        courseName: course.courseName,
        type: type,
        qrData: qrData,
        sixDigitCode: generateSixDigitCode(),
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

  // ── REFRESH 6-DIGIT CODE ONLY ─────────────────────────────────────
  ActiveSessionModel refreshCodes(ActiveSessionModel session) {
    return session.copyWith(sixDigitCode: generateSixDigitCode());
  }
}
