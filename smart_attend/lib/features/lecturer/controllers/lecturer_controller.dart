import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/lecturer/models/lecturer_model.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';

// ─────────────────────────────────────────────────────────────────
//  LecturerController
//
//  KEY CHANGES from the old version:
//
//  1. startSession() now calls POST /api/attendance/sessions.
//     Old code generated a fake local sessionId
//     ('sess_${DateTime.now().millisecondsSinceEpoch}') and computed
//     its own HMAC signature. That signature would never match what
//     the backend expected because:
//       a) The session didn't exist in MongoDB.
//       b) The backend signs using the real MongoDB _id, not a
//          client-generated string.
//     Result: every student check-in would fail HMAC verification.
//
//  2. generateQrData() no longer computes signatures.
//     The QR data is now built directly from the qrPayload returned
//     by the backend — which contains the server-generated HMAC.
//     The client encodes it as JSON but does NOT alter the signature.
//
//  3. refreshCodes() only refreshes the 6-digit code.
//     The QR payload is FIXED for the session lifetime because the
//     HMAC binds: sessionId + courseCode + expiresAt.  Changing any
//     of these would produce a QR that fails verification.  The
//     backend's expiresAt is the authoritative expiry — there is no
//     "rolling window" on the QR.  The UI timer is cosmetic.
//     The 6-digit code (backup entry method) is safe to refresh
//     because it's not cryptographically bound to a server-side
//     value in this version.
// ─────────────────────────────────────────────────────────────────
class LecturerController {
  static const int refreshInPerson = 20; // seconds — 6-digit code refresh
  static const int refreshOnline = 20;

  // ── FETCH LECTURER PROFILE ────────────────────────────────────────
  // TODO: GET /api/auth/me — use the authenticated user's profile
  Future<LecturerModel> fetchProfile(String lecturerId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return const LecturerModel(
      id: 'lec_001',
      fullName: 'Kwame Asante',
      email: 'k.asante@university.edu.gh',
      staffId: 'STF/2018/0012',
      department: 'Computer Science & Engineering',
      role: 'lecturer',
      courseIds: ['c1', 'c2', 'c3'],
    );
  }

  // ── FETCH TODAY'S STATS ───────────────────────────────────────────
  // TODO: GET /api/attendance/sessions?isActive=false (count today's)
  Future<Map<String, int>> fetchTodayStats(String lecturerId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'scheduled': 3,
      'attended': 2,
      'missed': 1,
      'inPerson': 2,
      'online': 1,
    };
  }

  // ── FETCH ASSIGNED COURSES ────────────────────────────────────────
  // TODO: GET /api/lecturers/:id/courses
  Future<List<LecturerCourseModel>> fetchCourses(String lecturerId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      const LecturerCourseModel(
        id: 'c1',
        courseCode: 'CS 301',
        courseName: 'Data Structures & Algorithms',
        department: 'Computer Science',
        totalStudents: 45,
        weekdays: [2, 5],
        schedule: 'Tue, Fri',
        room: 'ICT Block - Lab 1',
        startTime: '10:00 AM',
        endTime: '11:30 AM',
      ),
      const LecturerCourseModel(
        id: 'c2',
        courseCode: 'CS 201',
        courseName: 'Object Oriented Programming',
        department: 'Computer Science',
        totalStudents: 60,
        weekdays: [1, 3],
        schedule: 'Mon, Wed',
        room: 'ICT Block - Room 3',
        startTime: '12:00 PM',
        endTime: '1:30 PM',
      ),
      const LecturerCourseModel(
        id: 'c3',
        courseCode: 'CS 401',
        courseName: 'Software Engineering',
        department: 'Computer Science',
        totalStudents: 38,
        weekdays: [3, 5],
        schedule: 'Wed, Fri',
        room: 'Block A - Room 7',
        startTime: '2:00 PM',
        endTime: '3:30 PM',
      ),
    ];
  }

  // ── FETCH WEEKLY SCHEDULE ─────────────────────────────────────────
  // TODO: GET /api/attendance/sessions (own sessions by lecturerId)
  Future<List<WeeklySessionModel>> fetchWeeklySchedule(
    String lecturerId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return [
      WeeklySessionModel(
        id: 'ws1',
        courseCode: 'CS 301',
        courseName: 'Data Structures & Algorithms',
        room: 'ICT Block - Lab 1',
        date: monday.add(const Duration(days: 1)),
        startTime: '10:00 AM',
        endTime: '11:30 AM',
        status: SessionStatus.held,
        studentsAttended: 40,
        totalStudents: 45,
      ),
      WeeklySessionModel(
        id: 'ws2',
        courseCode: 'CS 201',
        courseName: 'Object Oriented Programming',
        room: 'ICT Block - Room 3',
        date: monday,
        startTime: '12:00 PM',
        endTime: '1:30 PM',
        status: SessionStatus.held,
        studentsAttended: 55,
        totalStudents: 60,
      ),
      WeeklySessionModel(
        id: 'ws3',
        courseCode: 'CS 401',
        courseName: 'Software Engineering',
        room: 'Block A - Room 7',
        date: monday.add(const Duration(days: 2)),
        startTime: '2:00 PM',
        endTime: '3:30 PM',
        status: SessionStatus.notHeld,
        notHeldReason: 'Lecturer indisposed',
        totalStudents: 38,
      ),
      WeeklySessionModel(
        id: 'ws4',
        courseCode: 'CS 301',
        courseName: 'Data Structures & Algorithms',
        room: 'ICT Block - Lab 1',
        date: monday.add(const Duration(days: 4)),
        startTime: '10:00 AM',
        endTime: '11:30 AM',
        status: SessionStatus.upcoming,
        totalStudents: 45,
      ),
    ];
  }

  // ── GET LOCATION ──────────────────────────────────────────────────
  Future<Position?> getCurrentPosition() async {
    // Check if location services are enabled at all on the device.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever)
      return null;

    // Try with medium accuracy first (uses WiFi/cell towers — fast, works indoors).
    // Falls back to last known position if even that times out.
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // fast, works indoors & outdoors
          timeLimit: Duration(seconds: 20), // generous timeout for real devices
        ),
      );
    } catch (_) {
      // Timed out — try the last known position as a fallback.
      // This is acceptable for attendance since the lecturer is
      // physically present; exact precision isn't critical.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return last;
      } catch (_) {}
      return null;
    }
  }

  // ── GENERATE 6-DIGIT CODE ─────────────────────────────────────────
  // The 6-digit code is a backup entry method (not cryptographically
  // verified by the backend in this version). It is safe to generate
  // locally and refresh on a timer.
  String generateSixDigitCode() {
    final rng = Random.secure();
    return (100000 + rng.nextInt(900000)).toString();
  }

  // ── START AN ATTENDANCE SESSION ───────────────────────────────────
  // CHANGED: now calls POST /api/attendance/sessions and uses the
  // server-returned sessionId and HMAC signature to build the QR.
  //
  // Returns null on any failure (GPS unavailable, network error,
  // server error) so the UI can show a user-friendly message.
  Future<ActiveSessionModel?> startSession({
    required LecturerCourseModel course,
    required AttendanceType type,
    required int durationSeconds,
  }) async {
    // ── 1. Get GPS if in-person ──────────────────────────────────
    Position? pos;
    if (type == AttendanceType.inPerson) {
      pos = await getCurrentPosition();
      if (pos == null) return null; // GPS unavailable — caller shows error
    }

    // ── 2. Get auth token ────────────────────────────────────────
    final session = await SessionService.getSession();
    if (session == null) return null;

    // ── 3. Call the backend ──────────────────────────────────────
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
              // Use == null check (not !value) so a GPS coordinate of
              // exactly 0 (equator/prime meridian) is sent correctly.
              if (pos != null) 'lecturerLat': pos.latitude,
              if (pos != null) 'lecturerLng': pos.longitude,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 201) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      // ── 4. Extract the server-generated session data ─────────
      // The backend returns:
      // {
      //   sessionId: "...",
      //   expiresAt: "2026-...",
      //   qrPayload: { sessionId, courseCode, expiresAt (ms), signature }
      // }
      final serverSessionId = body['sessionId'] as String;
      final qrPayloadMap = body['qrPayload'] as Map<String, dynamic>;

      // ── 5. Build the QR data string ───────────────────────────
      // Encode the server's qrPayload as JSON, adding courseName for
      // display on the student side. courseName is NOT part of the
      // HMAC-signed data so adding it here is safe.
      final qrData = jsonEncode({
        ...qrPayloadMap,
        'courseName': course.courseName,
      });

      // ── 6. Build the active session model ────────────────────
      return ActiveSessionModel(
        sessionId: serverSessionId, // real MongoDB _id
        courseCode: course.courseCode,
        courseName: course.courseName,
        type: type,
        qrData: qrData, // JSON with server signature
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
  // CHANGED: now calls PATCH /api/attendance/sessions/:id/end.
  // Old code only cleared local state — the session stayed isActive:true
  // in MongoDB indefinitely, allowing check-ins after the lecturer
  // pressed "End Session".
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
  // The QR payload is FIXED for the session lifetime (the HMAC binds
  // sessionId + courseCode + expiresAt — none of which change).
  // Only the 6-digit backup code is refreshed on the timer.
  ActiveSessionModel refreshCodes(ActiveSessionModel session) {
    return session.copyWith(
      sixDigitCode: generateSixDigitCode(),
      // qrData is intentionally NOT regenerated here
    );
  }
}
