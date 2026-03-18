import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  ENUMS
// ─────────────────────────────────────────────
enum UserRole { student, lecturer, dean, admin }

enum UserStatus { active, inactive, suspended }

enum TimetableDay { mon, tue, wed, thu, fri, sat }

extension UserRoleExt on UserRole {
  String get label {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.lecturer:
        return 'Lecturer';
      case UserRole.dean:
        return 'Dean';
      case UserRole.admin:
        return 'Super Admin';
    }
  }

  Color get color {
    switch (this) {
      case UserRole.student:
        return const Color(0xFF2196F3);
      case UserRole.lecturer:
        return const Color(0xFF9B1B42);
      case UserRole.dean:
        return const Color(0xFF9C27B0);
      case UserRole.admin:
        return const Color(0xFFFF9800);
    }
  }

  Color get bg {
    switch (this) {
      case UserRole.student:
        return const Color(0xFFE3F2FD);
      case UserRole.lecturer:
        return const Color(0xFFFFEEF2);
      case UserRole.dean:
        return const Color(0xFFF3E5F5);
      case UserRole.admin:
        return const Color(0xFFFFF3E0);
    }
  }
}

extension UserStatusExt on UserStatus {
  String get label {
    switch (this) {
      case UserStatus.active:
        return 'Active';
      case UserStatus.inactive:
        return 'Inactive';
      case UserStatus.suspended:
        return 'Suspended';
    }
  }

  Color get color {
    switch (this) {
      case UserStatus.active:
        return const Color(0xFF4CAF50);
      case UserStatus.inactive:
        return const Color(0xFF888888);
      case UserStatus.suspended:
        return const Color(0xFF9B1B42);
    }
  }

  Color get bg {
    switch (this) {
      case UserStatus.active:
        return const Color(0xFFE8F5E9);
      case UserStatus.inactive:
        return const Color(0xFFF5F5F5);
      case UserStatus.suspended:
        return const Color(0xFFFFEEF2);
    }
  }
}

extension TimetableDayExt on TimetableDay {
  String get label {
    switch (this) {
      case TimetableDay.mon:
        return 'Mon';
      case TimetableDay.tue:
        return 'Tue';
      case TimetableDay.wed:
        return 'Wed';
      case TimetableDay.thu:
        return 'Thu';
      case TimetableDay.fri:
        return 'Fri';
      case TimetableDay.sat:
        return 'Sat';
    }
  }
}

// ─────────────────────────────────────────────
//  ADMIN MODEL
// ─────────────────────────────────────────────
class AdminModel {
  final String id;
  final String fullName;
  final String email;
  final String staffId;

  const AdminModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.staffId,
  });

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A';
  }

  String get firstName =>
      fullName.isNotEmpty ? fullName.split(' ').first : 'Admin';
}

// ─────────────────────────────────────────────
//  USER MODEL (students & lecturers)
// ─────────────────────────────────────────────
class ManagedUserModel {
  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final UserStatus status;
  final String? indexNumber;
  final String? staffId;
  final String? programme;
  final String? level;
  final String? faculty;
  final String? department;
  final List<String> departments; // lecturers can have multiple
  final DateTime createdAt;

  const ManagedUserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
    this.indexNumber,
    this.staffId,
    this.programme,
    this.level,
    this.faculty,
    this.department,
    this.departments = const [],
  });

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';
  }

  String get subtitle {
    if (role == UserRole.student) {
      return [
        if (indexNumber != null) indexNumber!,
        if (programme != null) programme!,
        if (level != null) 'Level $level',
      ].join(' · ');
    }
    final deptDisplay = departments.isNotEmpty
        ? departments.join(', ')
        : (department ?? '');
    return [
      if (staffId != null) staffId!,
      if (deptDisplay.isNotEmpty) deptDisplay,
    ].join(' · ');
  }

  ManagedUserModel copyWith({
    String? fullName,
    String? email,
    UserRole? role,
    UserStatus? status,
    String? indexNumber,
    String? staffId,
    String? programme,
    String? level,
    String? faculty,
    String? department,
    List<String>? departments,
  }) => ManagedUserModel(
    id: id,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    role: role ?? this.role,
    status: status ?? this.status,
    createdAt: createdAt,
    indexNumber: indexNumber ?? this.indexNumber,
    staffId: staffId ?? this.staffId,
    programme: programme ?? this.programme,
    level: level ?? this.level,
    faculty: faculty ?? this.faculty,
    department: department ?? this.department,
    departments: departments ?? this.departments,
  );
}

// ─────────────────────────────────────────────
//  COURSE MODEL (admin view)
// ─────────────────────────────────────────────
class AdminCourseModel {
  final String id;
  final String courseCode;
  final String courseName;
  final String departmentId;
  final String departmentName;
  final int creditHours;
  final String? assignedLecturerId;
  final String? assignedLecturerName;
  final int enrolledStudents;
  final String semester; // e.g. "2025/2026 Semester 2"

  const AdminCourseModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.departmentId,
    required this.departmentName,
    required this.creditHours,
    required this.enrolledStudents,
    required this.semester,
    this.assignedLecturerId,
    this.assignedLecturerName,
  });

  bool get hasLecturer => assignedLecturerId != null;

  AdminCourseModel copyWith({
    String? assignedLecturerId,
    String? assignedLecturerName,
  }) => AdminCourseModel(
    id: id,
    courseCode: courseCode,
    courseName: courseName,
    departmentId: departmentId,
    departmentName: departmentName,
    creditHours: creditHours,
    enrolledStudents: enrolledStudents,
    semester: semester,
    assignedLecturerId: assignedLecturerId ?? this.assignedLecturerId,
    assignedLecturerName: assignedLecturerName ?? this.assignedLecturerName,
  );
}

// ─────────────────────────────────────────────
//  TIMETABLE SLOT MODEL
// ─────────────────────────────────────────────
class TimetableSlotModel {
  final String id;
  final String courseId;
  final String courseCode;
  final String courseName;
  final String lecturerName;
  final TimetableDay day;
  final String startTime; // "10:00 AM"
  final String endTime; // "11:30 AM"
  final String room;
  final String level; // "100", "200"…
  final String programme;
  final String semester;

  const TimetableSlotModel({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.lecturerName,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.level,
    required this.programme,
    required this.semester,
  });
}

// ─────────────────────────────────────────────
//  SEMESTER PARAMETERS
// ─────────────────────────────────────────────
class SemesterModel {
  final String id;
  final String name; // "2025/2026 Semester 2"
  final DateTime startDate;
  final DateTime endDate;
  final int teachingWeeks;
  final bool isCurrent;

  const SemesterModel({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.teachingWeeks,
    required this.isCurrent,
  });

  SemesterModel copyWith({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    int? teachingWeeks,
    bool? isCurrent,
  }) => SemesterModel(
    id: id,
    name: name ?? this.name,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    teachingWeeks: teachingWeeks ?? this.teachingWeeks,
    isCurrent: isCurrent ?? this.isCurrent,
  );
}

// ─────────────────────────────────────────────
//  SCHOOL-WIDE ANALYTICS
// ─────────────────────────────────────────────
class SchoolAnalyticsModel {
  final int totalStudents;
  final int totalLecturers;
  final int totalCourses;
  final int totalDepartments;
  final double schoolAttendanceRate;
  final double schoolHoldingRate;
  final int classesScheduled;
  final int classesHeld;
  final List<DeptAnalyticsSummary> byDepartment;

  const SchoolAnalyticsModel({
    required this.totalStudents,
    required this.totalLecturers,
    required this.totalCourses,
    required this.totalDepartments,
    required this.schoolAttendanceRate,
    required this.schoolHoldingRate,
    required this.classesScheduled,
    required this.classesHeld,
    required this.byDepartment,
  });
}

class DeptAnalyticsSummary {
  final String departmentName;
  final double attendanceRate;
  final double holdingRate;
  final int totalStudents;

  const DeptAnalyticsSummary({
    required this.departmentName,
    required this.attendanceRate,
    required this.holdingRate,
    required this.totalStudents,
  });

  Color get attendanceColor {
    if (attendanceRate >= 75) return const Color(0xFF4CAF50);
    if (attendanceRate >= 60) return const Color(0xFFFF9800);
    return const Color(0xFF9B1B42);
  }
}

// ─────────────────────────────────────────────
//  CSV UPLOAD RESULT
// ─────────────────────────────────────────────
class CsvUploadResult {
  final int totalRows;
  final int successCount;
  final int errorCount;
  final List<String> errors;

  const CsvUploadResult({
    required this.totalRows,
    required this.successCount,
    required this.errorCount,
    required this.errors,
  });
}