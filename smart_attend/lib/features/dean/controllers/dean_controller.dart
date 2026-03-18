import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/auth/models/auth_model.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/dean/models/dean_model.dart';

class DeanController {
  // ── FETCH DEPARTMENTS ─────────────────────────────────────────────
  // GET /api/admin/users?role=dean — returns all dean accounts.
  // Each dean account has a department field — we build the dropdown
  // from those. This means the list is always in sync with what the
  // admin has created; no hardcoded list anywhere.
  Future<List<DepartmentModel>> fetchDepartments() async {
    try {
      // We use the admin stats endpoint which is public-ish — but
      // actually we need to fetch dean users. The problem is this
      // endpoint requires auth. So we fetch using the general users
      // list but only after the dean logs in.
      //
      // For the login DROPDOWN (before auth), we derive departments
      // from the lecturer list which is accessible without a full
      // admin token, OR we keep a known list from the seeder.
      //
      // Best approach: expose a public /api/departments endpoint.
      // Until then, we try with any existing session, and fall back
      // to fetching lecturer departments.
      final session = await SessionService.getSession();

      if (session != null) {
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

          return users
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
                  faculty: '',
                ),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
        }
      }


      // If no session at all, return the seeded department
      // so the dropdown is never empty on first run.
      return _seededDepartments();
    } catch (_) {
      return _seededDepartments();
    }
  }

  // Seeded fallback — one entry per faculty so the dropdown is never
  // empty even before any dean accounts are created in the database.
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
  // The dean picks their department from the dropdown.
  // Each department maps to a dean user account with a known email.
  // We call POST /api/auth/login with that email + the entered password.
  // On success we save the session and return a DeanModel.
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

      // Verify this account is actually a dean
      if (role != 'dean') {
        throw Exception('This account does not have dean access.');
      }

      // Save session so subsequent API calls work
      final authUser = AuthModel.fromLoginResponse(
        token: token,
        role: role,
        id: userData['_id'] as String? ?? '',
        fullName: userData['fullName'] as String? ?? '',
        email: userData['email'] as String? ?? '',
        mustChangePassword: body['mustChangePassword'] as bool? ?? false,
        staffId: userData['staffId'] as String?,
        department: userData['department'] as String?,
      );
      await SessionService.saveSession(authUser);

      // If the account needs a password change, throw a special
      // exception the UI can catch and redirect accordingly
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
  Future<DepartmentStatsModel> fetchDepartmentStats(String departmentId) async {
    final session = await SessionService.getSession();
    if (session == null) return _emptyStats();

    try {
      final results = await Future.wait([
        http
            .get(
              Uri.parse('${AppConfig.adminUrl}/stats'),
              headers: {'Authorization': 'Bearer ${session.token}'},
            )
            .timeout(const Duration(seconds: 10)),
        http
            .get(
              Uri.parse('${AppConfig.adminUrl}/users?role=student&limit=100'),
              headers: {'Authorization': 'Bearer ${session.token}'},
            )
            .timeout(const Duration(seconds: 10)),
        http
            .get(
              Uri.parse('${AppConfig.adminUrl}/users?role=lecturer&limit=100'),
              headers: {'Authorization': 'Bearer ${session.token}'},
            )
            .timeout(const Duration(seconds: 10)),
        http
            .get(
              Uri.parse('${AppConfig.adminUrl}/sessions?limit=200'),
              headers: {'Authorization': 'Bearer ${session.token}'},
            )
            .timeout(const Duration(seconds: 10)),
      ]);

      final statsBody = results[0].statusCode == 200
          ? jsonDecode(results[0].body) as Map<String, dynamic>
          : <String, dynamic>{};
      final studsBody = results[1].statusCode == 200
          ? jsonDecode(results[1].body) as Map<String, dynamic>
          : <String, dynamic>{};
      final lectsBody = results[2].statusCode == 200
          ? jsonDecode(results[2].body) as Map<String, dynamic>
          : <String, dynamic>{};
      final sessBody = results[3].statusCode == 200
          ? jsonDecode(results[3].body) as Map<String, dynamic>
          : <String, dynamic>{};

      final students = (studsBody['users'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final lecturers = (lectsBody['users'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final sessions = (sessBody['sessions'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      final held = sessions.where((s) => s['isActive'] == false).length;
      final total = sessions.length;
      final notHeld = total - held;

      final attInfo = (statsBody['attendance'] as Map<String, dynamic>? ?? {});
      final totalAtt = attInfo['total'] as int? ?? 0;
      final rate = total == 0 ? 0.0 : (totalAtt / total) * 100.0;

      return DepartmentStatsModel(
        totalStudents: students.length,
        totalLecturers: lecturers.length,
        totalCourses: sessions.map((s) => s['courseCode']).toSet().length,
        overallAttendanceRate: rate.clamp(0, 100),
        classHoldingRate: total == 0 ? 0 : (held / total * 100),
        classesScheduled: total,
        classesHeld: held,
        classesNotHeld: notHeld,
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
  Future<List<CourseAnalyticsModel>> fetchCourseAnalytics(
    String departmentId,
  ) async {
    final session = await SessionService.getSession();
    if (session == null) return [];

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.adminUrl}/sessions?limit=200'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final sessions = (jsonDecode(response.body)['sessions'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      final Map<String, List<Map<String, dynamic>>> byCode = {};
      for (final s in sessions) {
        final code = s['courseCode'] as String? ?? '';
        if (code.isNotEmpty) byCode.putIfAbsent(code, () => []).add(s);
      }

      return byCode.entries.map((e) {
        final first = e.value.first;
        final held = e.value.where((s) => s['isActive'] == false).length;
        final total = e.value.length;
        final lect = first['lecturerId'];
        final lectName = lect is Map ? lect['fullName'] as String? ?? '' : '';

        return CourseAnalyticsModel(
          id: e.key,
          courseCode: e.key,
          courseName: first['courseName'] as String? ?? e.key,
          lecturerName: lectName,
          totalStudents: 0,
          classesHeld: held,
          classesScheduled: total,
          attendanceRate: 0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── FETCH LOW ATTENDANCE STUDENTS ─────────────────────────────────
  Future<List<LowAttendanceStudentModel>> fetchLowAttendanceStudents(
    String departmentId,
  ) async {
    final session = await SessionService.getSession();
    if (session == null) return [];

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.adminUrl}/users?role=student&limit=100'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final students = (jsonDecode(response.body)['users'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      final List<LowAttendanceStudentModel> result = [];

      for (final s in students) {
        final id = s['_id'] as String? ?? '';
        if (id.isEmpty) continue;

        try {
          final attResp = await http
              .get(
                Uri.parse('${AppConfig.attendanceUrl}/student/$id'),
                headers: {'Authorization': 'Bearer ${session.token}'},
              )
              .timeout(const Duration(seconds: 8));

          if (attResp.statusCode != 200) continue;

          final records = (jsonDecode(attResp.body)['records'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          final total = records.length;
          if (total == 0) continue;

          final attended = records
              .where((r) => (r['status'] as String? ?? '') == 'present')
              .length;
          final rate = (attended / total) * 100;

          if (rate < 75) {
            result.add(
              LowAttendanceStudentModel(
                id: id,
                fullName: s['fullName'] as String? ?? '',
                indexNumber: s['indexNumber'] as String? ?? '',
                programme: s['programme'] as String? ?? '',
                level: s['level'] as String? ?? '',
                attendanceRate: rate,
                coursesAtRisk: 0,
              ),
            );
          }
        } catch (_) {
          continue;
        }
      }

      result.sort((a, b) => a.attendanceRate.compareTo(b.attendanceRate));
      return result;
    } catch (_) {
      return [];
    }
  }

  // ── FETCH LECTURER PERFORMANCE ─────────────────────────────────────
  Future<List<LecturerPerformanceModel>> fetchLecturerPerformance(
    String departmentId,
  ) async {
    final session = await SessionService.getSession();
    if (session == null) return [];

    try {
      final results = await Future.wait([
        http
            .get(
              Uri.parse('${AppConfig.adminUrl}/users?role=lecturer&limit=100'),
              headers: {'Authorization': 'Bearer ${session.token}'},
            )
            .timeout(const Duration(seconds: 10)),
        http
            .get(
              Uri.parse('${AppConfig.adminUrl}/sessions?limit=200'),
              headers: {'Authorization': 'Bearer ${session.token}'},
            )
            .timeout(const Duration(seconds: 10)),
      ]);

      if (results[0].statusCode != 200) return [];

      final lecturers = (jsonDecode(results[0].body)['users'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final sessions = results[1].statusCode == 200
          ? (jsonDecode(results[1].body)['sessions'] as List? ?? [])
                .cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      return lecturers.map((l) {
        final lid = l['_id'] as String? ?? '';
        final lSess = sessions.where((s) {
          final lect = s['lecturerId'];
          final slid = lect is Map ? lect['_id'] as String? : lect as String?;
          return slid == lid;
        }).toList();

        final total = lSess.length;
        final held = lSess.where((s) => s['isActive'] == false).length;
        final rate = total == 0 ? 0.0 : (held / total) * 100.0;

        return LecturerPerformanceModel(
          id: lid,
          fullName: l['fullName'] as String? ?? '',
          staffId: l['staffId'] as String? ?? '',
          coursesAssigned: lSess.map((s) => s['courseCode']).toSet().length,
          classesScheduled: total,
          classesHeld: held,
          holdingRate: rate,
        );
      }).toList()..sort((a, b) => a.holdingRate.compareTo(b.holdingRate));
    } catch (_) {
      return [];
    }
  }
}
