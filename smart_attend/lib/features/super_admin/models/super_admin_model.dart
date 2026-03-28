// ─────────────────────────────────────────────
//  SUPER ADMIN MODELS
//  features/super_admin/models/super_admin_model.dart
// ─────────────────────────────────────────────

// ── A department admin card shown on the Super Admin dashboard ──
class DepartmentAdminModel {
  final String id;
  final String fullName;
  final String email;
  final String department; // faculty name
  final String staffId;
  final int students;
  final int lecturers;
  final DateTime createdAt;

  const DepartmentAdminModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.department,
    required this.staffId,
    required this.students,
    required this.lecturers,
    required this.createdAt,
  });

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A';
  }

  factory DepartmentAdminModel.fromJson(Map<String, dynamic> j) =>
      DepartmentAdminModel(
        id: j['id']?.toString() ?? '',
        fullName: j['fullName'] as String? ?? '',
        email: j['email'] as String? ?? '',
        department: j['department'] as String? ?? '',
        staffId: j['staffId'] as String? ?? '',
        students: (j['students'] as num?)?.toInt() ?? 0,
        lecturers: (j['lecturers'] as num?)?.toInt() ?? 0,
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ── Overall system totals shown at the top of the dashboard ─────
class SuperAdminTotals {
  final int totalStudents;
  final int totalLecturers;
  final int totalAdmins;

  const SuperAdminTotals({
    required this.totalStudents,
    required this.totalLecturers,
    required this.totalAdmins,
  });

  factory SuperAdminTotals.empty() => const SuperAdminTotals(
    totalStudents: 0,
    totalLecturers: 0,
    totalAdmins: 0,
  );

  factory SuperAdminTotals.fromJson(Map<String, dynamic> j) => SuperAdminTotals(
    totalStudents: (j['totalStudents'] as num?)?.toInt() ?? 0,
    totalLecturers: (j['totalLecturers'] as num?)?.toInt() ?? 0,
    totalAdmins: (j['totalAdmins'] as num?)?.toInt() ?? 0,
  );
}

// ── Admin detail drill-down ──────────────────────────────────────
class AdminDetailModel {
  final DepartmentAdminModel admin;
  final List<LevelCountModel> studentsByLevel;
  final int totalStudents;
  final List<LecturerBriefModel> lecturers;
  final List<CourseDetailModel> courses;

  const AdminDetailModel({
    required this.admin,
    required this.studentsByLevel,
    required this.totalStudents,
    required this.lecturers,
    required this.courses,
  });

  factory AdminDetailModel.fromJson(Map<String, dynamic> j) {
    final adminMap = j['admin'] as Map<String, dynamic>? ?? {};
    return AdminDetailModel(
      admin: DepartmentAdminModel.fromJson({
        ...adminMap,
        'students': j['totalStudents'] ?? 0,
        'lecturers': (j['lecturers'] as List? ?? []).length,
      }),
      totalStudents: (j['totalStudents'] as num?)?.toInt() ?? 0,
      studentsByLevel: (j['studentsByLevel'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(LevelCountModel.fromJson)
          .toList(),
      lecturers: (j['lecturers'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(LecturerBriefModel.fromJson)
          .toList(),
      courses: (j['courses'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(CourseDetailModel.fromJson)
          .toList(),
    );
  }
}

class LevelCountModel {
  final String level;
  final int count;
  const LevelCountModel({required this.level, required this.count});

  factory LevelCountModel.fromJson(Map<String, dynamic> j) => LevelCountModel(
    level: j['level'] as String? ?? '',
    count: (j['count'] as num?)?.toInt() ?? 0,
  );
}

class LecturerBriefModel {
  final String id;
  final String fullName;
  final String email;
  final String staffId;
  const LecturerBriefModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.staffId,
  });

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'L';
  }

  factory LecturerBriefModel.fromJson(Map<String, dynamic> j) =>
      LecturerBriefModel(
        id: j['_id']?.toString() ?? '',
        fullName: j['fullName'] as String? ?? '',
        email: j['email'] as String? ?? '',
        staffId: j['staffId'] as String? ?? '',
      );
}

class CourseDetailModel {
  final String courseCode;
  final String courseName;
  final String level;
  final String programme;
  final int enrolledStudents;
  final String assignedLecturerName;

  const CourseDetailModel({
    required this.courseCode,
    required this.courseName,
    required this.level,
    required this.programme,
    required this.enrolledStudents,
    required this.assignedLecturerName,
  });

  factory CourseDetailModel.fromJson(Map<String, dynamic> j) =>
      CourseDetailModel(
        courseCode: j['courseCode'] as String? ?? '',
        courseName: j['courseName'] as String? ?? '',
        level: j['level'] as String? ?? '',
        programme: j['programme'] as String? ?? '',
        enrolledStudents: (j['enrolledStudents'] as num?)?.toInt() ?? 0,
        assignedLecturerName: j['assignedLecturerName'] as String? ?? 'TBA',
      );
}

// ── Faculty model ────────────────────────────────────────────────
class FacultyModel {
  final String name;
  final List<String> programmes;

  const FacultyModel({required this.name, required this.programmes});

  factory FacultyModel.fromJson(Map<String, dynamic> j) => FacultyModel(
    name: j['name'] as String? ?? '',
    programmes: (j['programmes'] as List? ?? []).cast<String>(),
  );
}
