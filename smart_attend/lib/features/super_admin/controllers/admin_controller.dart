import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/super_admin/models/admin_model.dart';

class AdminController {
  // ─────────────────────────────────────────────
  //  ANALYTICS
  // ─────────────────────────────────────────────

  Future<SchoolAnalyticsModel> fetchSchoolAnalytics() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const SchoolAnalyticsModel(
      totalStudents: 2847,
      totalLecturers: 98,
      totalCourses: 186,
      totalDepartments: 12,
      schoolAttendanceRate: 72.4,
      schoolHoldingRate: 85.1,
      classesScheduled: 3120,
      classesHeld: 2655,
      byDepartment: [
        DeptAnalyticsSummary(
          departmentName: 'Computer Science',
          attendanceRate: 71.4,
          holdingRate: 84.2,
          totalStudents: 342,
        ),
        DeptAnalyticsSummary(
          departmentName: 'Electrical Engineering',
          attendanceRate: 78.9,
          holdingRate: 91.0,
          totalStudents: 287,
        ),
        DeptAnalyticsSummary(
          departmentName: 'Medicine & Surgery',
          attendanceRate: 88.2,
          holdingRate: 96.5,
          totalStudents: 412,
        ),
        DeptAnalyticsSummary(
          departmentName: 'Law',
          attendanceRate: 65.3,
          holdingRate: 79.8,
          totalStudents: 198,
        ),
        DeptAnalyticsSummary(
          departmentName: 'Economics',
          attendanceRate: 70.1,
          holdingRate: 82.3,
          totalStudents: 254,
        ),
        DeptAnalyticsSummary(
          departmentName: 'Architecture',
          attendanceRate: 74.6,
          holdingRate: 88.7,
          totalStudents: 165,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  USER MANAGEMENT
  // ─────────────────────────────────────────────

  Future<List<ManagedUserModel>> fetchUsers({
    UserRole? role,
    UserStatus? status,
    String? search,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final all = _mockUsers();
    return all.where((u) {
      if (role != null && u.role != role) return false;
      if (status != null && u.status != status) return false;
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        if (!u.fullName.toLowerCase().contains(q) &&
            !u.email.toLowerCase().contains(q) &&
            !(u.indexNumber?.toLowerCase().contains(q) ?? false) &&
            !(u.staffId?.toLowerCase().contains(q) ?? false)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // POST /api/admin/users — creates a real user in MongoDB
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
      final u = body['user'] as Map<String, dynamic>;
      return ManagedUserModel(
        id: u['_id'] as String,
        fullName: u['fullName'] as String,
        email: u['email'] as String,
        role: UserRole.values.firstWhere(
          (r) => r.name == (u['role'] as String? ?? 'student'),
          orElse: () => UserRole.student,
        ),
        status: (u['isActive'] as bool? ?? true)
            ? UserStatus.active
            : UserStatus.inactive,
        indexNumber: u['indexNumber'] as String?,
        programme: u['programme'] as String?,
        level: u['level'] as String?,
        staffId: u['staffId'] as String?,
        department: u['department'] as String?,
        createdAt:
            DateTime.tryParse(u['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
    }

    final msg = body['message'] as String? ?? 'Failed to create user.';
    throw Exception(msg);
  }

  Future<ManagedUserModel> updateUser(ManagedUserModel user) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return user;
  }

  Future<void> updateUserStatus(String userId, UserStatus status) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> deactivateUser(String userId) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<CsvUploadResult> bulkUploadUsers(
    String csvContent,
    UserRole role,
  ) async {
    await Future.delayed(const Duration(milliseconds: 1200));

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
      final cols = dataRows[i].split(',');
      if (role == UserRole.student && cols.length < 5) {
        errors.add(
          'Row ${i + 2}: expected fullName, email, '
          'indexNumber, programme, level',
        );
      } else if (role == UserRole.lecturer && cols.length < 3) {
        errors.add('Row ${i + 2}: expected fullName, email, staffId');
      } else {
        success++;
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
  // ─────────────────────────────────────────────

  Future<List<AdminCourseModel>> fetchCourses({
    String? departmentId,
    String? search,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final all = _mockCourses();
    return all.where((c) {
      if (departmentId != null &&
          departmentId.isNotEmpty &&
          c.departmentId != departmentId)
        return false;
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        if (!c.courseCode.toLowerCase().contains(q) &&
            !c.courseName.toLowerCase().contains(q))
          return false;
      }
      return true;
    }).toList();
  }

  Future<AdminCourseModel> createCourse(AdminCourseModel course) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return AdminCourseModel(
      id: 'crs_${DateTime.now().millisecondsSinceEpoch}',
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
    await Future.delayed(const Duration(milliseconds: 400));
    return course.copyWith(
      assignedLecturerId: lecturer.id,
      assignedLecturerName: lecturer.fullName,
    );
  }

  Future<void> deleteCourse(String courseId) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  // ─────────────────────────────────────────────
  //  TIMETABLE
  // ─────────────────────────────────────────────

  Future<List<TimetableSlotModel>> fetchTimetable({
    String? programme,
    String? level,
    String? semester,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final all = _mockTimetable();
    return all.where((s) {
      if (programme != null && programme.isNotEmpty && s.programme != programme)
        return false;
      if (level != null && level.isNotEmpty && s.level != level) return false;
      return true;
    }).toList();
  }

  Future<TimetableSlotModel> createTimetableSlot(
    TimetableSlotModel slot,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return TimetableSlotModel(
      id: 'slot_${DateTime.now().millisecondsSinceEpoch}',
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

  Future<void> deleteTimetableSlot(String slotId) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  // ─────────────────────────────────────────────
  //  SEMESTER MANAGEMENT
  // ─────────────────────────────────────────────

  Future<List<SemesterModel>> fetchSemesters() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      SemesterModel(
        id: 'sem_001',
        name: '2025/2026 Semester 2',
        startDate: DateTime(2026, 1, 13),
        endDate: DateTime(2026, 5, 23),
        teachingWeeks: 15,
        isCurrent: true,
      ),
      SemesterModel(
        id: 'sem_002',
        name: '2025/2026 Semester 1',
        startDate: DateTime(2025, 8, 25),
        endDate: DateTime(2025, 12, 20),
        teachingWeeks: 15,
        isCurrent: false,
      ),
      SemesterModel(
        id: 'sem_003',
        name: '2024/2025 Semester 2',
        startDate: DateTime(2025, 1, 13),
        endDate: DateTime(2025, 5, 23),
        teachingWeeks: 15,
        isCurrent: false,
      ),
    ];
  }

  Future<SemesterModel> createSemester(SemesterModel s) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return SemesterModel(
      id: 'sem_${DateTime.now().millisecondsSinceEpoch}',
      name: s.name,
      startDate: s.startDate,
      endDate: s.endDate,
      teachingWeeks: s.teachingWeeks,
      isCurrent: s.isCurrent,
    );
  }

  Future<void> setCurrentSemester(String semesterId) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  // ─────────────────────────────────────────────
  //  FETCH HELPERS
  // ─────────────────────────────────────────────

  Future<List<ManagedUserModel>> fetchLecturers() async {
    return fetchUsers(role: UserRole.lecturer, status: UserStatus.active);
  }

  Future<List<String>> fetchDepartmentNames() async {
    final courses = await fetchCourses();
    return courses.map((c) => c.departmentName).toSet().toList()..sort();
  }

  // ─────────────────────────────────────────────
  //  MOCK DATA
  // ─────────────────────────────────────────────

  List<ManagedUserModel> _mockUsers() => [
    ManagedUserModel(
      id: 'u1',
      fullName: 'Kofi Mensah',
      email: 'kofi.m@university.edu.gh',
      role: UserRole.student,
      status: UserStatus.active,
      indexNumber: 'UG/2021/0042',
      programme: 'BSc. Computer Science',
      level: '300',
      department: 'Computer Science',
      createdAt: DateTime(2021, 9, 1),
    ),
    ManagedUserModel(
      id: 'u2',
      fullName: 'Abena Asante',
      email: 'abena.a@university.edu.gh',
      role: UserRole.student,
      status: UserStatus.active,
      indexNumber: 'UG/2022/0087',
      programme: 'BSc. Computer Science',
      level: '200',
      department: 'Computer Science',
      createdAt: DateTime(2022, 9, 1),
    ),
    ManagedUserModel(
      id: 'u3',
      fullName: 'Kwesi Boateng',
      email: 'kwesi.b@university.edu.gh',
      role: UserRole.student,
      status: UserStatus.suspended,
      indexNumber: 'UG/2023/0145',
      programme: 'BSc. Electrical Engineering',
      level: '100',
      department: 'Electrical Engineering',
      createdAt: DateTime(2023, 9, 1),
    ),
    ManagedUserModel(
      id: 'u4',
      fullName: 'Efua Darko',
      email: 'efua.d@university.edu.gh',
      role: UserRole.student,
      status: UserStatus.inactive,
      indexNumber: 'UG/2020/0023',
      programme: 'BSc. Computer Science',
      level: '400',
      department: 'Computer Science',
      createdAt: DateTime(2020, 9, 1),
    ),
    ManagedUserModel(
      id: 'u5',
      fullName: 'Dr. Kwame Asante',
      email: 'k.asante@university.edu.gh',
      role: UserRole.lecturer,
      status: UserStatus.active,
      staffId: 'STF/2018/0012',
      department: 'Computer Science',
      createdAt: DateTime(2018, 1, 15),
    ),
    ManagedUserModel(
      id: 'u6',
      fullName: 'Mrs. Abena Mensah',
      email: 'a.mensah@university.edu.gh',
      role: UserRole.lecturer,
      status: UserStatus.active,
      staffId: 'STF/2019/0031',
      department: 'Computer Science',
      createdAt: DateTime(2019, 3, 1),
    ),
    ManagedUserModel(
      id: 'u7',
      fullName: 'Dr. Kofi Darko',
      email: 'k.darko@university.edu.gh',
      role: UserRole.lecturer,
      status: UserStatus.active,
      staffId: 'STF/2017/0008',
      department: 'Computer Science',
      createdAt: DateTime(2017, 8, 1),
    ),
    ManagedUserModel(
      id: 'u8',
      fullName: 'Prof. Yaw Acheampong',
      email: 'y.acheampong@university.edu.gh',
      role: UserRole.lecturer,
      status: UserStatus.inactive,
      staffId: 'STF/2012/0002',
      department: 'Computer Science',
      createdAt: DateTime(2012, 1, 10),
    ),
  ];

  List<AdminCourseModel> _mockCourses() => [
    AdminCourseModel(
      id: 'c1',
      courseCode: 'CS 101',
      courseName: 'Introduction to Computing',
      departmentId: 'dept_cs',
      departmentName: 'Computer Science & Engineering',
      creditHours: 3,
      enrolledStudents: 120,
      semester: '2025/2026 Semester 2',
      assignedLecturerId: 'u6',
      assignedLecturerName: 'Mrs. Abena Mensah',
    ),
    AdminCourseModel(
      id: 'c2',
      courseCode: 'CS 201',
      courseName: 'Object Oriented Programming',
      departmentId: 'dept_cs',
      departmentName: 'Computer Science & Engineering',
      creditHours: 3,
      enrolledStudents: 60,
      semester: '2025/2026 Semester 2',
      assignedLecturerId: 'u5',
      assignedLecturerName: 'Dr. Kwame Asante',
    ),
    AdminCourseModel(
      id: 'c3',
      courseCode: 'CS 301',
      courseName: 'Data Structures & Algorithms',
      departmentId: 'dept_cs',
      departmentName: 'Computer Science & Engineering',
      creditHours: 3,
      enrolledStudents: 45,
      semester: '2025/2026 Semester 2',
      assignedLecturerId: 'u5',
      assignedLecturerName: 'Dr. Kwame Asante',
    ),
    AdminCourseModel(
      id: 'c4',
      courseCode: 'CS 302',
      courseName: 'Database Systems',
      departmentId: 'dept_cs',
      departmentName: 'Computer Science & Engineering',
      creditHours: 3,
      enrolledStudents: 55,
      semester: '2025/2026 Semester 2',
      assignedLecturerId: 'u7',
      assignedLecturerName: 'Dr. Kofi Darko',
    ),
    AdminCourseModel(
      id: 'c5',
      courseCode: 'CS 401',
      courseName: 'Software Engineering',
      departmentId: 'dept_cs',
      departmentName: 'Computer Science & Engineering',
      creditHours: 3,
      enrolledStudents: 38,
      semester: '2025/2026 Semester 2',
      assignedLecturerId: 'u5',
      assignedLecturerName: 'Dr. Kwame Asante',
    ),
    AdminCourseModel(
      id: 'c6',
      courseCode: 'CS 402',
      courseName: 'Artificial Intelligence',
      departmentId: 'dept_cs',
      departmentName: 'Computer Science & Engineering',
      creditHours: 3,
      enrolledStudents: 42,
      semester: '2025/2026 Semester 2',
    ),
    AdminCourseModel(
      id: 'c7',
      courseCode: 'EE 201',
      courseName: 'Circuit Theory',
      departmentId: 'dept_elec',
      departmentName: 'Electrical Engineering',
      creditHours: 3,
      enrolledStudents: 78,
      semester: '2025/2026 Semester 2',
    ),
  ];

  List<TimetableSlotModel> _mockTimetable() => [
    TimetableSlotModel(
      id: 't1',
      courseId: 'c1',
      courseCode: 'CS 101',
      courseName: 'Introduction to Computing',
      lecturerName: 'Mrs. Abena Mensah',
      day: TimetableDay.mon,
      startTime: '8:00 AM',
      endTime: '9:30 AM',
      room: 'ICT Block - Lecture Hall 1',
      level: '100',
      programme: 'BSc. Computer Science',
      semester: '2025/2026 Semester 2',
    ),
    TimetableSlotModel(
      id: 't2',
      courseId: 'c1',
      courseCode: 'CS 101',
      courseName: 'Introduction to Computing',
      lecturerName: 'Mrs. Abena Mensah',
      day: TimetableDay.wed,
      startTime: '8:00 AM',
      endTime: '9:30 AM',
      room: 'ICT Block - Lecture Hall 1',
      level: '100',
      programme: 'BSc. Computer Science',
      semester: '2025/2026 Semester 2',
    ),
    TimetableSlotModel(
      id: 't3',
      courseId: 'c2',
      courseCode: 'CS 201',
      courseName: 'Object Oriented Programming',
      lecturerName: 'Dr. Kwame Asante',
      day: TimetableDay.mon,
      startTime: '10:00 AM',
      endTime: '11:30 AM',
      room: 'ICT Block - Room 3',
      level: '200',
      programme: 'BSc. Computer Science',
      semester: '2025/2026 Semester 2',
    ),
    TimetableSlotModel(
      id: 't4',
      courseId: 'c2',
      courseCode: 'CS 201',
      courseName: 'Object Oriented Programming',
      lecturerName: 'Dr. Kwame Asante',
      day: TimetableDay.wed,
      startTime: '10:00 AM',
      endTime: '11:30 AM',
      room: 'ICT Block - Room 3',
      level: '200',
      programme: 'BSc. Computer Science',
      semester: '2025/2026 Semester 2',
    ),
    TimetableSlotModel(
      id: 't5',
      courseId: 'c3',
      courseCode: 'CS 301',
      courseName: 'Data Structures & Algorithms',
      lecturerName: 'Dr. Kwame Asante',
      day: TimetableDay.tue,
      startTime: '10:00 AM',
      endTime: '11:30 AM',
      room: 'ICT Block - Lab 1',
      level: '300',
      programme: 'BSc. Computer Science',
      semester: '2025/2026 Semester 2',
    ),
    TimetableSlotModel(
      id: 't6',
      courseId: 'c3',
      courseCode: 'CS 301',
      courseName: 'Data Structures & Algorithms',
      lecturerName: 'Dr. Kwame Asante',
      day: TimetableDay.fri,
      startTime: '10:00 AM',
      endTime: '11:30 AM',
      room: 'ICT Block - Lab 1',
      level: '300',
      programme: 'BSc. Computer Science',
      semester: '2025/2026 Semester 2',
    ),
    TimetableSlotModel(
      id: 't7',
      courseId: 'c5',
      courseCode: 'CS 401',
      courseName: 'Software Engineering',
      lecturerName: 'Dr. Kwame Asante',
      day: TimetableDay.thu,
      startTime: '2:00 PM',
      endTime: '3:30 PM',
      room: 'Block A - Room 7',
      level: '400',
      programme: 'BSc. Computer Science',
      semester: '2025/2026 Semester 2',
    ),
  ];
}
