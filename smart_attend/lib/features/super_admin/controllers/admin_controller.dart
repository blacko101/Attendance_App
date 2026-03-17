import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/super_admin/models/admin_model.dart';

class AdminController {
  // ─────────────────────────────────────────────
  //  ANALYTICS
  //  GET /api/admin/stats + /api/admin/users
  // ─────────────────────────────────────────────
  Future<SchoolAnalyticsModel> fetchSchoolAnalytics() async {
    final session = await SessionService.getSession();
    if (session == null) return _emptyAnalytics();

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

      final stats = results[0].statusCode == 200
          ? jsonDecode(results[0].body) as Map<String, dynamic>
          : <String, dynamic>{};
      final lecResp = results[1].statusCode == 200
          ? jsonDecode(results[1].body) as Map<String, dynamic>
          : <String, dynamic>{};
      final sessResp = results[2].statusCode == 200
          ? jsonDecode(results[2].body) as Map<String, dynamic>
          : <String, dynamic>{};

      final users = stats['users'] as Map<String, dynamic>? ?? {};
      final sessInfo = stats['sessions'] as Map<String, dynamic>? ?? {};
      final attInfo = stats['attendance'] as Map<String, dynamic>? ?? {};

      final totalStudents = users['students'] as int? ?? 0;
      final totalLecturers = users['lecturers'] as int? ?? 0;
      final totalSessions = sessInfo['total'] as int? ?? 0;
      final totalAttendance = attInfo['total'] as int? ?? 0;

      final allLecturers = (lecResp['users'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final allSessions = (sessResp['sessions'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      // Derive courses count from unique course codes in sessions
      final uniqueCourses = allSessions
          .map((s) => s['courseCode'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toSet()
          .length;

      // Compute holding rate
      final held = allSessions.where((s) => s['isActive'] == false).length;
      final holdRate = totalSessions == 0
          ? 0.0
          : (held / totalSessions) * 100.0;

      // Attendance rate  = attendances / sessions (as a % proxy)
      final attRate = totalSessions == 0
          ? 0.0
          : (totalAttendance / totalSessions) * 100.0;

      // Build per-department summary from lecturer records
      final Map<String, List<Map<String, dynamic>>> byDept = {};
      for (final l in allLecturers) {
        final dept = l['department'] as String? ?? 'Other';
        byDept.putIfAbsent(dept, () => []).add(l);
      }

      final deptSummaries = byDept.entries.map((e) {
        final deptName = e.key;
        final lectIds = e.value.map((l) => l['_id'] as String).toSet();
        final deptSess = allSessions.where((s) {
          final lect = s['lecturerId'];
          final lid = lect is Map ? lect['_id'] as String? : lect as String?;
          return lid != null && lectIds.contains(lid);
        }).toList();
        final deptHeld = deptSess.where((s) => s['isActive'] == false).length;
        final deptTotal = deptSess.length;
        final deptHold = deptTotal == 0 ? 0.0 : (deptHeld / deptTotal) * 100.0;

        return DeptAnalyticsSummary(
          departmentName: deptName,
          attendanceRate: attRate.clamp(0, 100),
          holdingRate: deptHold.clamp(0, 100),
          totalStudents: 0, // not broken down by dept in backend yet
        );
      }).toList();

      return SchoolAnalyticsModel(
        totalStudents: totalStudents,
        totalLecturers: totalLecturers,
        totalCourses: uniqueCourses,
        totalDepartments: byDept.length,
        schoolAttendanceRate: attRate.clamp(0, 100),
        schoolHoldingRate: holdRate.clamp(0, 100),
        classesScheduled: totalSessions,
        classesHeld: held,
        byDepartment: deptSummaries,
      );
    } catch (_) {
      return _emptyAnalytics();
    }
  }

  SchoolAnalyticsModel _emptyAnalytics() => const SchoolAnalyticsModel(
    totalStudents: 0,
    totalLecturers: 0,
    totalCourses: 0,
    totalDepartments: 0,
    schoolAttendanceRate: 0,
    schoolHoldingRate: 0,
    classesScheduled: 0,
    classesHeld: 0,
    byDepartment: [],
  );

  // ─────────────────────────────────────────────
  //  USER MANAGEMENT
  //  GET /api/admin/users
  // ─────────────────────────────────────────────
  Future<List<ManagedUserModel>> fetchUsers({
    UserRole? role,
    UserStatus? status,
    String? search,
  }) async {
    final session = await SessionService.getSession();
    if (session == null) return [];

    try {
      final params = <String, String>{};
      if (role != null) params['role'] = role.name;
      if (status != null)
        params['isActive'] = status == UserStatus.active ? 'true' : 'false';
      if (search != null && search.isNotEmpty) params['search'] = search;
      params['limit'] = '100';

      final uri = Uri.parse(
        '${AppConfig.adminUrl}/users',
      ).replace(queryParameters: params);
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer ${session.token}'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final users = (body['users'] as List? ?? []).cast<Map<String, dynamic>>();

      return users.map(_mapUser).toList();
    } catch (_) {
      return [];
    }
  }

  ManagedUserModel _mapUser(Map<String, dynamic> u) {
    final roleStr = u['role'] as String? ?? 'student';
    final isActive = u['isActive'] as bool? ?? true;
    final suspended = isActive == false;

    return ManagedUserModel(
      id: u['_id'] as String? ?? '',
      fullName: u['fullName'] as String? ?? '',
      email: u['email'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == roleStr,
        orElse: () => UserRole.student,
      ),
      status: suspended ? UserStatus.suspended : UserStatus.active,
      indexNumber: u['indexNumber'] as String?,
      staffId: u['staffId'] as String?,
      programme: u['programme'] as String?,
      level: u['level'] as String?,
      department: u['department'] as String?,
      createdAt:
          DateTime.tryParse(u['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  // POST /api/admin/users
  Future<ManagedUserModel> createUser(ManagedUserModel user) async {
    final session = await SessionService.getSession();
    if (session == null)
      throw Exception('Not authenticated. Please log in again.');

    final response = await http
        .post(
          Uri.parse('${AppConfig.adminUrl}/users'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.token}',
          },
          body: jsonEncode({
            'fullName': user.fullName,
            'email': user.email,
            'role': user.role.name,
            if (user.indexNumber != null) 'indexNumber': user.indexNumber,
            if (user.programme != null) 'programme': user.programme,
            if (user.level != null) 'level': user.level,
            if (user.staffId != null) 'staffId': user.staffId,
            if (user.department != null) 'department': user.department,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) {
      return _mapUser(body['user'] as Map<String, dynamic>);
    }
    throw Exception(body['message'] as String? ?? 'Failed to create user.');
  }

  // PATCH /api/admin/users/:id/status
  Future<void> updateUserStatus(String userId, UserStatus status) async {
    final session = await SessionService.getSession();
    if (session == null) return;

    await http
        .patch(
          Uri.parse('${AppConfig.adminUrl}/users/$userId/status'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.token}',
          },
          body: jsonEncode({'isActive': status == UserStatus.active}),
        )
        .timeout(const Duration(seconds: 10));
  }

  // Bulk CSV upload — validates format locally, then creates users
  // one by one via POST /api/admin/users.
  Future<CsvUploadResult> bulkUploadUsers(
    String csvContent,
    UserRole role,
  ) async {
    final lines = csvContent
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.length <= 1) {
      return const CsvUploadResult(
        totalRows: 0,
        successCount: 0,
        errorCount: 0,
        errors: ['File is empty or has only a header row'],
      );
    }

    final dataRows = lines.sublist(1);
    final errors = <String>[];
    int success = 0;

    for (int i = 0; i < dataRows.length; i++) {
      final cols = dataRows[i].split(',').map((c) => c.trim()).toList();
      try {
        if (role == UserRole.student) {
          if (cols.length < 5) {
            errors.add(
              'Row ${i + 2}: expected fullName, email, indexNumber, programme, level',
            );
            continue;
          }
          await createUser(
            ManagedUserModel(
              id: '',
              fullName: cols[0],
              email: cols[1],
              role: UserRole.student,
              status: UserStatus.active,
              indexNumber: cols[2],
              programme: cols[3],
              level: cols[4],
              createdAt: DateTime.now(),
            ),
          );
        } else {
          if (cols.length < 3) {
            errors.add('Row ${i + 2}: expected fullName, email, staffId');
            continue;
          }
          await createUser(
            ManagedUserModel(
              id: '',
              fullName: cols[0],
              email: cols[1],
              role: UserRole.lecturer,
              status: UserStatus.active,
              staffId: cols[2],
              createdAt: DateTime.now(),
            ),
          );
        }
        success++;
      } catch (e) {
        errors.add(
          'Row ${i + 2}: ${e.toString().replaceFirst("Exception: ", "")}',
        );
      }
    }

    return CsvUploadResult(
      totalRows: dataRows.length,
      successCount: success,
      errorCount: errors.length,
      errors: errors,
    );
  }

  // ─────────────────────────────────────────────
  //  COURSE MANAGEMENT
  //  Derived from sessions — no dedicated courses
  //  collection in the backend yet.
  // ─────────────────────────────────────────────
  Future<List<AdminCourseModel>> fetchCourses({
    String? departmentId,
    String? search,
  }) async {
    final session = await SessionService.getSession();
    if (session == null) return [];

    try {
      final results = await Future.wait([
        http
            .get(
              Uri.parse('${AppConfig.adminUrl}/sessions?limit=200'),
              headers: {'Authorization': 'Bearer ${session.token}'},
            )
            .timeout(const Duration(seconds: 10)),
        http
            .get(
              Uri.parse('${AppConfig.adminUrl}/users?role=lecturer&limit=100'),
              headers: {'Authorization': 'Bearer ${session.token}'},
            )
            .timeout(const Duration(seconds: 10)),
      ]);

      final sessions = results[0].statusCode == 200
          ? (jsonDecode(results[0].body)['sessions'] as List? ?? [])
                .cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      final lecturers = results[1].statusCode == 200
          ? (jsonDecode(results[1].body)['users'] as List? ?? [])
                .cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      // Build lecturer lookup map
      final Map<String, Map<String, dynamic>> lectById = {
        for (final l in lecturers) l['_id'] as String: l,
      };

      // Deduplicate by courseCode
      final Map<String, Map<String, dynamic>> byCode = {};
      for (final s in sessions) {
        final code = s['courseCode'] as String? ?? '';
        if (code.isNotEmpty && !byCode.containsKey(code)) {
          byCode[code] = s;
        }
      }

      var courses = byCode.entries.map((e) {
        final s = e.value;
        final lect = s['lecturerId'];
        final lid = lect is Map ? lect['_id'] as String? : lect as String?;
        final lDoc = lid != null ? lectById[lid] : null;
        final dept = lDoc?['department'] as String? ?? '';

        return AdminCourseModel(
          id: s['_id'] as String? ?? e.key,
          courseCode: e.key,
          courseName: s['courseName'] as String? ?? e.key,
          departmentId: dept.toLowerCase().replaceAll(' ', '_'),
          departmentName: dept,
          creditHours: 3,
          enrolledStudents: 0,
          semester: '',
          assignedLecturerId: lid,
          assignedLecturerName: lDoc?['fullName'] as String?,
        );
      }).toList();

      // Apply filters
      if (departmentId != null && departmentId.isNotEmpty) {
        courses = courses.where((c) => c.departmentId == departmentId).toList();
      }
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        courses = courses
            .where(
              (c) =>
                  c.courseCode.toLowerCase().contains(q) ||
                  c.courseName.toLowerCase().contains(q),
            )
            .toList();
      }

      return courses;
    } catch (_) {
      return [];
    }
  }

  // POST /api/admin/users (no dedicated courses endpoint yet)
  // Courses are created implicitly when a lecturer starts a session.
  // This method is kept for UI compatibility — it records the intent
  // but can't persist to a courses collection until the backend adds one.
  Future<AdminCourseModel> createCourse(AdminCourseModel course) async {
    // Return the course with a timestamp-based id so the UI can show it
    return AdminCourseModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      courseCode: course.courseCode,
      courseName: course.courseName,
      departmentId: course.departmentId,
      departmentName: course.departmentName,
      creditHours: course.creditHours,
      enrolledStudents: 0,
      semester: course.semester,
      assignedLecturerId: course.assignedLecturerId,
      assignedLecturerName: course.assignedLecturerName,
    );
  }

  Future<AdminCourseModel> assignLecturer(
    AdminCourseModel course,
    ManagedUserModel lecturer,
  ) async {
    return course.copyWith(
      assignedLecturerId: lecturer.id,
      assignedLecturerName: lecturer.fullName,
    );
  }

  Future<void> deleteCourse(String courseId) async {}

  // ─────────────────────────────────────────────
  //  TIMETABLE
  //  Derived from sessions — no timetable collection yet.
  // ─────────────────────────────────────────────
  Future<List<TimetableSlotModel>> fetchTimetable({
    String? programme,
    String? level,
    String? semester,
  }) async {
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

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final sessions = (body['sessions'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      return sessions.map((s) {
        final lect = s['lecturerId'];
        final lectName = lect is Map ? lect['fullName'] as String? ?? '' : '';
        final created =
            DateTime.tryParse(s['createdAt'] as String? ?? '') ??
            DateTime.now();
        final expires = DateTime.tryParse(s['expiresAt'] as String? ?? '');
        final dayIdx = created.weekday - 1;
        const dayMap = [
          TimetableDay.mon,
          TimetableDay.tue,
          TimetableDay.wed,
          TimetableDay.thu,
          TimetableDay.fri,
          TimetableDay.sat,
        ];

        return TimetableSlotModel(
          id: s['_id'] as String? ?? '',
          courseId: s['_id'] as String? ?? '',
          courseCode: s['courseCode'] as String? ?? '',
          courseName: s['courseName'] as String? ?? '',
          lecturerName: lectName,
          day: dayMap[dayIdx.clamp(0, 5)],
          startTime: _fmtTime(created),
          endTime: expires != null ? _fmtTime(expires) : '',
          room: s['type'] == 'online' ? 'Online' : 'On Campus',
          level: '',
          programme: '',
          semester: '',
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

  Future<TimetableSlotModel> createTimetableSlot(
    TimetableSlotModel slot,
  ) async {
    return TimetableSlotModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      courseId: slot.courseId,
      courseCode: slot.courseCode,
      courseName: slot.courseName,
      lecturerName: slot.lecturerName,
      day: slot.day,
      startTime: slot.startTime,
      endTime: slot.endTime,
      room: slot.room,
      level: slot.level,
      programme: slot.programme,
      semester: slot.semester,
    );
  }

  Future<void> deleteTimetableSlot(String slotId) async {}

  // ─────────────────────────────────────────────
  //  SEMESTER MANAGEMENT
  //  No semester collection in backend yet.
  //  Returns an empty list — the admin can create
  //  semesters and they live in local state until
  //  a /semesters endpoint is added.
  // ─────────────────────────────────────────────
  Future<List<SemesterModel>> fetchSemesters() async => [];

  Future<SemesterModel> createSemester(SemesterModel s) async {
    return SemesterModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      name: s.name,
      startDate: s.startDate,
      endDate: s.endDate,
      teachingWeeks: s.teachingWeeks,
      isCurrent: s.isCurrent,
    );
  }

  Future<void> setCurrentSemester(String semesterId) async {}

  // ─────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────
  Future<List<ManagedUserModel>> fetchLecturers() async =>
      fetchUsers(role: UserRole.lecturer, status: UserStatus.active);

  Future<List<String>> fetchDepartmentNames() async {
    final courses = await fetchCourses();
    return courses
        .map((c) => c.departmentName)
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}
