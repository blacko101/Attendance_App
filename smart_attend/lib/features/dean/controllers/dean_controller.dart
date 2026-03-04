import 'package:smart_attend/features/dean/models/dean_model.dart';

class DeanController {
  // ── FETCH ALL DEPARTMENTS (for dean access page dropdown) ──────────────
  // TODO: GET /api/departments
  Future<List<DepartmentModel>> fetchDepartments() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return const [
      DepartmentModel(
        id:      'dept_cs',
        name:    'Computer Science & Engineering',
        faculty: 'Faculty of Engineering',
      ),
      DepartmentModel(
        id:      'dept_law',
        name:    'Law',
        faculty: 'Faculty of Law',
      ),
      DepartmentModel(
        id:      'dept_med',
        name:    'Medicine & Surgery',
        faculty: 'College of Health Sciences',
      ),
      DepartmentModel(
        id:      'dept_econ',
        name:    'Economics',
        faculty: 'Faculty of Social Sciences',
      ),
      DepartmentModel(
        id:      'dept_elec',
        name:    'Electrical Engineering',
        faculty: 'Faculty of Engineering',
      ),
      DepartmentModel(
        id:      'dept_bio',
        name:    'Biological Sciences',
        faculty: 'College of Health Sciences',
      ),
      DepartmentModel(
        id:      'dept_bus',
        name:    'Business Administration',
        faculty: 'Faculty of Business',
      ),
      DepartmentModel(
        id:      'dept_arch',
        name:    'Architecture',
        faculty: 'Faculty of Built Environment',
      ),
    ];
  }

  // ── DEAN LOGIN ─────────────────────────────────────────────────────────
  // TODO: POST /api/auth/dean-login  { departmentId, password }
  // Returns JWT with role=dean + departmentId
  Future<DeanModel?> deanLogin({
    required String departmentId,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    // Mock: accept any department with password 'dean123'
    if (password != 'dean123') {
      throw Exception('Invalid department selection or password');
    }

    final depts = await fetchDepartments();
    final dept  = depts.firstWhere(
          (d) => d.id == departmentId,
      orElse: () => throw Exception(
          'Invalid department selection or password'),
    );

    return DeanModel(
      id:             'dean_001',
      fullName:       'Prof. Akosua Boateng',
      email:          'a.boateng@university.edu.gh',
      staffId:        'STF/2015/0004',
      departmentId:   dept.id,
      departmentName: dept.name,
      faculty:        dept.faculty,
    );
  }

  // ── FETCH DEPARTMENT STATS ─────────────────────────────────────────────
  // TODO: GET /api/dean/:departmentId/stats
  Future<DepartmentStatsModel> fetchDepartmentStats(
      String departmentId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const DepartmentStatsModel(
      totalStudents:         342,
      totalLecturers:         18,
      totalCourses:           24,
      overallAttendanceRate:  71.4,
      classHoldingRate:       84.2,
      classesScheduled:       312,
      classesHeld:            263,
      classesNotHeld:          49,
    );
  }

  // ── FETCH COURSE ANALYTICS ─────────────────────────────────────────────
  // TODO: GET /api/dean/:departmentId/courses/analytics
  Future<List<CourseAnalyticsModel>> fetchCourseAnalytics(
      String departmentId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const [
      CourseAnalyticsModel(
        id:               'ca1',
        courseCode:       'CS 301',
        courseName:       'Data Structures & Algorithms',
        lecturerName:     'Dr. Kwame Asante',
        totalStudents:    45,
        classesHeld:      18,
        classesScheduled: 20,
        attendanceRate:   82.3,
      ),
      CourseAnalyticsModel(
        id:               'ca2',
        courseCode:       'CS 201',
        courseName:       'Object Oriented Programming',
        lecturerName:     'Dr. Kwame Asante',
        totalStudents:    60,
        classesHeld:      17,
        classesScheduled: 20,
        attendanceRate:   68.5,
      ),
      CourseAnalyticsModel(
        id:               'ca3',
        courseCode:       'CS 401',
        courseName:       'Software Engineering',
        lecturerName:     'Dr. Kwame Asante',
        totalStudents:    38,
        classesHeld:      14,
        classesScheduled: 20,
        attendanceRate:   55.0,
      ),
      CourseAnalyticsModel(
        id:               'ca4',
        courseCode:       'CS 101',
        courseName:       'Introduction to Computing',
        lecturerName:     'Mrs. Abena Mensah',
        totalStudents:    120,
        classesHeld:      20,
        classesScheduled: 20,
        attendanceRate:   79.1,
      ),
      CourseAnalyticsModel(
        id:               'ca5',
        courseCode:       'CS 302',
        courseName:       'Database Systems',
        lecturerName:     'Dr. Kofi Darko',
        totalStudents:    55,
        classesHeld:      12,
        classesScheduled: 20,
        attendanceRate:   61.8,
      ),
      CourseAnalyticsModel(
        id:               'ca6',
        courseCode:       'CS 402',
        courseName:       'Artificial Intelligence',
        lecturerName:     'Prof. Yaw Acheampong',
        totalStudents:    42,
        classesHeld:      19,
        classesScheduled: 20,
        attendanceRate:   88.7,
      ),
    ];
  }

  // ── FETCH LOW ATTENDANCE STUDENTS ─────────────────────────────────────
  // TODO: GET /api/dean/:departmentId/students/low-attendance?threshold=75
  Future<List<LowAttendanceStudentModel>> fetchLowAttendanceStudents(
      String departmentId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const [
      LowAttendanceStudentModel(
        id:              'stu_01',
        fullName:        'Kwesi Appiah',
        indexNumber:     'UG/2022/0145',
        programme:       'BSc. Computer Science',
        level:           '200',
        attendanceRate:  42.0,
        coursesAtRisk:   4,
      ),
      LowAttendanceStudentModel(
        id:              'stu_02',
        fullName:        'Abena Sarpong',
        indexNumber:     'UG/2022/0087',
        programme:       'BSc. Computer Science',
        level:           '200',
        attendanceRate:  55.5,
        coursesAtRisk:   3,
      ),
      LowAttendanceStudentModel(
        id:              'stu_03',
        fullName:        'Fiifi Mensah',
        indexNumber:     'UG/2021/0312',
        programme:       'BSc. Computer Science',
        level:           '300',
        attendanceRate:  61.0,
        coursesAtRisk:   2,
      ),
      LowAttendanceStudentModel(
        id:              'stu_04',
        fullName:        'Ama Owusu',
        indexNumber:     'UG/2023/0056',
        programme:       'BSc. Computer Science',
        level:           '100',
        attendanceRate:  64.2,
        coursesAtRisk:   2,
      ),
      LowAttendanceStudentModel(
        id:              'stu_05',
        fullName:        'Nana Boateng',
        indexNumber:     'UG/2021/0198',
        programme:       'BSc. Computer Science',
        level:           '300',
        attendanceRate:  68.8,
        coursesAtRisk:   1,
      ),
      LowAttendanceStudentModel(
        id:              'stu_06',
        fullName:        'Kofi Asiedu',
        indexNumber:     'UG/2022/0234',
        programme:       'BSc. Computer Science',
        level:           '200',
        attendanceRate:  71.3,
        coursesAtRisk:   1,
      ),
    ];
  }

  // ── FETCH LECTURER PERFORMANCE ─────────────────────────────────────────
  // TODO: GET /api/dean/:departmentId/lecturers/performance
  Future<List<LecturerPerformanceModel>> fetchLecturerPerformance(
      String departmentId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const [
      LecturerPerformanceModel(
        id:               'lec_01',
        fullName:         'Dr. Kwame Asante',
        staffId:          'STF/2018/0012',
        coursesAssigned:  3,
        classesScheduled: 60,
        classesHeld:      49,
        holdingRate:      81.7,
      ),
      LecturerPerformanceModel(
        id:               'lec_02',
        fullName:         'Mrs. Abena Mensah',
        staffId:          'STF/2019/0031',
        coursesAssigned:  2,
        classesScheduled: 40,
        classesHeld:      40,
        holdingRate:      100.0,
      ),
      LecturerPerformanceModel(
        id:               'lec_03',
        fullName:         'Dr. Kofi Darko',
        staffId:          'STF/2017/0008',
        coursesAssigned:  2,
        classesScheduled: 40,
        classesHeld:      26,
        holdingRate:      65.0,
      ),
      LecturerPerformanceModel(
        id:               'lec_04',
        fullName:         'Prof. Yaw Acheampong',
        staffId:          'STF/2012/0002',
        coursesAssigned:  1,
        classesScheduled: 20,
        classesHeld:      19,
        holdingRate:      95.0,
      ),
      LecturerPerformanceModel(
        id:               'lec_05',
        fullName:         'Dr. Efua Quansah',
        staffId:          'STF/2020/0045',
        coursesAssigned:  2,
        classesScheduled: 40,
        classesHeld:      25,
        holdingRate:      62.5,
      ),
    ];
  }
}