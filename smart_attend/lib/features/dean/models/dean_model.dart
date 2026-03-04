import 'package:flutter/material.dart';

// ── Available departments for dean access page ─
class DepartmentModel {
  final String id;
  final String name;
  final String faculty;

  const DepartmentModel({
    required this.id,
    required this.name,
    required this.faculty,
  });
}

// ── Dean profile ───────────────────────────────
class DeanModel {
  final String id;
  final String fullName;
  final String email;
  final String staffId;
  final String departmentId;
  final String departmentName;
  final String faculty;

  const DeanModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.staffId,
    required this.departmentId,
    required this.departmentName,
    required this.faculty,
  });

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'D';
  }

  String get firstName =>
      fullName.isNotEmpty ? fullName.split(' ').first : 'Dean';
}

// ── Department overview stats ──────────────────
class DepartmentStatsModel {
  final int    totalStudents;
  final int    totalLecturers;
  final int    totalCourses;
  final double overallAttendanceRate;  // 0–100
  final double classHoldingRate;       // 0–100
  final int    classesScheduled;
  final int    classesHeld;
  final int    classesNotHeld;

  const DepartmentStatsModel({
    required this.totalStudents,
    required this.totalLecturers,
    required this.totalCourses,
    required this.overallAttendanceRate,
    required this.classHoldingRate,
    required this.classesScheduled,
    required this.classesHeld,
    required this.classesNotHeld,
  });
}

// ── Per-course analytics ───────────────────────
class CourseAnalyticsModel {
  final String id;
  final String courseCode;
  final String courseName;
  final String lecturerName;
  final int    totalStudents;
  final int    classesHeld;
  final int    classesScheduled;
  final double attendanceRate;   // avg across students 0–100

  const CourseAnalyticsModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.lecturerName,
    required this.totalStudents,
    required this.classesHeld,
    required this.classesScheduled,
    required this.attendanceRate,
  });

  double get holdingRate =>
      classesScheduled == 0
          ? 0
          : (classesHeld / classesScheduled) * 100;

  bool get isLowAttendance => attendanceRate < 75;
  bool get isLowHolding    => holdingRate    < 70;

  Color get attendanceColor {
    if (attendanceRate >= 75) return const Color(0xFF4CAF50);
    if (attendanceRate >= 60) return const Color(0xFFFF9800);
    return const Color(0xFF9B1B42);
  }

  Color get holdingColor {
    if (holdingRate >= 80) return const Color(0xFF4CAF50);
    if (holdingRate >= 65) return const Color(0xFFFF9800);
    return const Color(0xFF9B1B42);
  }
}

// ── Student with low attendance ────────────────
class LowAttendanceStudentModel {
  final String id;
  final String fullName;
  final String indexNumber;
  final String programme;
  final String level;
  final double attendanceRate;
  final int    coursesAtRisk;

  const LowAttendanceStudentModel({
    required this.id,
    required this.fullName,
    required this.indexNumber,
    required this.programme,
    required this.level,
    required this.attendanceRate,
    required this.coursesAtRisk,
  });

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S';
  }

  Color get statusColor {
    if (attendanceRate >= 75) return const Color(0xFF4CAF50);
    if (attendanceRate >= 60) return const Color(0xFFFF9800);
    return const Color(0xFF9B1B42);
  }

  Color get statusBg {
    if (attendanceRate >= 75) return const Color(0xFFE8F5E9);
    if (attendanceRate >= 60) return const Color(0xFFFFF3E0);
    return const Color(0xFFFFEEF2);
  }

  String get statusLabel {
    if (attendanceRate >= 75) return 'Good';
    if (attendanceRate >= 60) return 'Warning';
    return 'Critical';
  }
}

// ── Lecturer class-holding performance ─────────
class LecturerPerformanceModel {
  final String id;
  final String fullName;
  final String staffId;
  final int    coursesAssigned;
  final int    classesScheduled;
  final int    classesHeld;
  final double holdingRate;

  const LecturerPerformanceModel({
    required this.id,
    required this.fullName,
    required this.staffId,
    required this.coursesAssigned,
    required this.classesScheduled,
    required this.classesHeld,
    required this.holdingRate,
  });

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'L';
  }

  bool get isLowHolding => holdingRate < 70;

  Color get holdingColor {
    if (holdingRate >= 80) return const Color(0xFF4CAF50);
    if (holdingRate >= 65) return const Color(0xFFFF9800);
    return const Color(0xFF9B1B42);
  }

  Color get holdingBg {
    if (holdingRate >= 80) return const Color(0xFFE8F5E9);
    if (holdingRate >= 65) return const Color(0xFFFFF3E0);
    return const Color(0xFFFFEEF2);
  }
}