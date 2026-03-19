import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/auth/models/auth_model.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/dean/models/dean_model.dart';

class DeanController {
  // ── FETCH DEPARTMENTS ─────────────────────────────────────────────
  // Before login: falls back to the seeded list so the dropdown is
  // never empty. After login (dean session exists): tries to load
  // dean accounts from the DB so new faculties appear dynamically.
  Future<List<DepartmentModel>> fetchDepartments() async {
    try {
      final session = await SessionService.getSession();
      if (session != null && session.role == 'dean') {
        final response = await http
            .get(
              Uri.parse('${AppConfig.adminUrl}/users?role=dean&limit=50'),
              headers: {'Authorization': 'Bearer ${session.token}'},
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final users = (body['users'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          final depts =
              users
                  .where(
                    (u) =>
                        (u['department'] as String? ?? '').isNotEmpty &&
                        (u['email'] as String? ?? '').isNotEmpty,
                  )
                  .map(
                    (u) => DepartmentModel(
                      id: u['_id'] as String,
                      name: u['department'] as String,
                      email: u['email'] as String,
                      faculty: u['faculty'] as String? ?? '',
                    ),
                  )
                  .toList()
                ..sort((a, b) => a.name.compareTo(b.name));
          if (depts.isNotEmpty) return depts;
        }
      }
      return _seededDepartments();
    } catch (_) {
      return _seededDepartments();
    }
  }

  List<DepartmentModel> _seededDepartments() => [
    const DepartmentModel(
      id: 'dean_set',
      name: 'School of Engineering & Technology',
      email: 'dean.set@central.edu.gh',
      faculty: 'School of Engineering & Technology',
    ),
    const DepartmentModel(
      id: 'dean_sad',
      name: 'School of Architecture & Design',
      email: 'dean.sad@central.edu.gh',
      faculty: 'School of Architecture & Design',
    ),
    const DepartmentModel(
      id: 'dean_snm',
      name: 'School of Nursing & Midwifery',
      email: 'dean.snm@central.edu.gh',
      faculty: 'School of Nursing & Midwifery',
    ),
    const DepartmentModel(
      id: 'dean_fass',
      name: 'Faculty of Arts & Social Sciences',
      email: 'dean.fass@central.edu.gh',
      faculty: 'Faculty of Arts & Social Sciences',
    ),
    const DepartmentModel(
      id: 'dean_cbs',
      name: 'Central Business School',
      email: 'dean.cbs@central.edu.gh',
      faculty: 'Central Business School',
    ),
    const DepartmentModel(
      id: 'dean_sms',
      name: 'School of Medical Sciences',
      email: 'dean.sms@central.edu.gh',
      faculty: 'School of Medical Sciences',
    ),
    const DepartmentModel(
      id: 'dean_sop',
      name: 'School of Pharmacy',
      email: 'dean.sop@central.edu.gh',
      faculty: 'School of Pharmacy',
    ),
    const DepartmentModel(
      id: 'dean_law',
      name: 'Central Law School',
      email: 'dean.law@central.edu.gh',
      faculty: 'Central Law School',
    ),
    const DepartmentModel(
      id: 'dean_sgsr',
      name: 'School of Graduate Studies & Research',
      email: 'dean.sgsr@central.edu.gh',
      faculty: 'School of Graduate Studies & Research',
    ),
    const DepartmentModel(
      id: 'dean_cdpe',
      name: 'Centre for Distance & Professional Education',
      email: 'dean.cdpe@central.edu.gh',
      faculty: 'Centre for Distance & Professional Education',
    ),
  ];

  // ── DEAN LOGIN ────────────────────────────────────────────────────
  // POST /api/auth/login with the department's dean email + password.
  Future<DeanModel> deanLogin({
    required DepartmentModel department,
    required String password,
  }) async {
    if (department.email.isEmpty) {
      throw Exception('No account found for this department. Contact admin.');
    }

    final response = await http
        .post(
          Uri.parse('${AppConfig.authUrl}/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': department.email, 'password': password}),
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () =>
              throw Exception('Connection timed out. Check your internet.'),
        );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final token = body['token'] as String;
      final userData = body['user'] as Map<String, dynamic>? ?? {};
      final role = userData['role'] as String? ?? '';

      if (role != 'dean') {
        throw Exception('This account does not have dean access.');
      }

      final authUser = AuthModel.fromLoginResponse(
        token: token,
        role: role,
        id: userData['_id'] as String? ?? '',
        fullName: userData['fullName'] as String? ?? '',
        email: userData['email'] as String? ?? '',
        mustChangePassword:
            body['mustChangePassword'] as bool? ??
            userData['mustChangePassword'] as bool? ??
            false,
        staffId: userData['staffId'] as String?,
        department: userData['department'] as String?,
      );
      await SessionService.saveSession(authUser);

      if (authUser.mustChangePassword) {
        throw Exception('__MUST_CHANGE_PASSWORD__');
      }

      return DeanModel(
        id: authUser.id,
        fullName: authUser.fullName,
        email: authUser.email,
        staffId: userData['staffId'] as String? ?? '',
        departmentId: department.id,
        departmentName: department.name,
        faculty: department.faculty,
      );
    } else if (response.statusCode == 401) {
      throw Exception('Incorrect password. Please try again.');
    } else if (response.statusCode == 403) {
      throw Exception('This account has been suspended. Contact admin.');
    } else if (response.statusCode == 429) {
      throw Exception(
        body['message'] as String? ??
            'Too many attempts. Please try again later.',
      );
    } else {
      throw Exception(
        body['message'] as String? ?? 'Login failed. Please try again.',
      );
    }
  }

  // ── FETCH DEPARTMENT STATS ────────────────────────────────────────
  // GET /api/dean/stats — scoped to the dean's own faculty.
  // This endpoint requires the dean JWT, NOT an admin JWT.
  Future<DepartmentStatsModel> fetchDepartmentStats(String departmentId) async {
    final session = await SessionService.getSession();
    if (session == null) return _emptyStats();

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.deanUrl}/stats'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return _emptyStats();

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return DepartmentStatsModel(
        totalStudents: (body['totalStudents'] as num?)?.toInt() ?? 0,
        totalLecturers: (body['totalLecturers'] as num?)?.toInt() ?? 0,
        totalCourses: (body['totalCourses'] as num?)?.toInt() ?? 0,
        overallAttendanceRate:
            (body['overallAttendanceRate'] as num?)?.toDouble() ?? 0,
        classHoldingRate: (body['classHoldingRate'] as num?)?.toDouble() ?? 0,
        classesScheduled: (body['classesScheduled'] as num?)?.toInt() ?? 0,
        classesHeld: (body['classesHeld'] as num?)?.toInt() ?? 0,
        classesNotHeld: (body['classesNotHeld'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return _emptyStats();
    }
  }

  DepartmentStatsModel _emptyStats() => const DepartmentStatsModel(
    totalStudents: 0,
    totalLecturers: 0,
    totalCourses: 0,
    overallAttendanceRate: 0,
    classHoldingRate: 0,
    classesScheduled: 0,
    classesHeld: 0,
    classesNotHeld: 0,
  );

  // ── FETCH COURSE ANALYTICS ────────────────────────────────────────
  // GET /api/dean/courses
  Future<List<CourseAnalyticsModel>> fetchCourseAnalytics(
    String departmentId,
  ) async {
    final session = await SessionService.getSession();
    if (session == null) return [];

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.deanUrl}/courses'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final courses = (jsonDecode(response.body)['courses'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      return courses
          .map(
            (c) => CourseAnalyticsModel(
              id: c['id'] as String? ?? '',
              courseCode: c['courseCode'] as String? ?? '',
              courseName: c['courseName'] as String? ?? '',
              lecturerName: c['lecturerName'] as String? ?? '',
              totalStudents: (c['totalStudents'] as num?)?.toInt() ?? 0,
              classesHeld: (c['classesHeld'] as num?)?.toInt() ?? 0,
              classesScheduled: (c['classesScheduled'] as num?)?.toInt() ?? 0,
              attendanceRate: (c['attendanceRate'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── FETCH LOW ATTENDANCE STUDENTS ─────────────────────────────────
  // GET /api/dean/students
  Future<List<LowAttendanceStudentModel>> fetchLowAttendanceStudents(
    String departmentId,
  ) async {
    final session = await SessionService.getSession();
    if (session == null) return [];

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.deanUrl}/students'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) return [];

      final students = (jsonDecode(response.body)['students'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      return students
          .map(
            (s) => LowAttendanceStudentModel(
              id: s['id']?.toString() ?? '',
              fullName: s['fullName'] as String? ?? '',
              indexNumber: s['indexNumber'] as String? ?? '',
              programme: s['programme'] as String? ?? '',
              level: s['level'] as String? ?? '',
              attendanceRate: (s['attendanceRate'] as num?)?.toDouble() ?? 0,
              coursesAtRisk: (s['coursesAtRisk'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── FETCH LECTURER PERFORMANCE ─────────────────────────────────────
  // GET /api/dean/lecturers
  Future<List<LecturerPerformanceModel>> fetchLecturerPerformance(
    String departmentId,
  ) async {
    final session = await SessionService.getSession();
    if (session == null) return [];

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.deanUrl}/lecturers'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final lecturers = (jsonDecode(response.body)['lecturers'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      return lecturers
          .map(
            (l) => LecturerPerformanceModel(
              id: l['id']?.toString() ?? '',
              fullName: l['fullName'] as String? ?? '',
              staffId: l['staffId'] as String? ?? '',
              coursesAssigned: (l['coursesAssigned'] as num?)?.toInt() ?? 0,
              classesScheduled: (l['classesScheduled'] as num?)?.toInt() ?? 0,
              classesHeld: (l['classesHeld'] as num?)?.toInt() ?? 0,
              holdingRate: (l['holdingRate'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }
}
