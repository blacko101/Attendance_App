import 'package:flutter/material.dart';

// ── Warning threshold — below this % show warning ──
const kWarningThreshold = 75.0;
const kDangerThreshold  = 60.0;

class CourseAttendanceModel {
  final String id;
  final String courseCode;
  final String courseName;
  final String instructor;
  final String room;
  final String schedule;        // e.g. "Mon, Wed, Fri"
  final int    totalClasses;
  final int    attended;
  final int    absent;
  final List<CourseSessionHistory> history;

  const CourseAttendanceModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.instructor,
    required this.room,
    required this.schedule,
    required this.totalClasses,
    required this.attended,
    required this.absent,
    required this.history,
  });

  double get attendanceRate =>
      totalClasses == 0 ? 0 : (attended / totalClasses) * 100;

  int get attendancePercent => attendanceRate.toInt();

  // How many more absences before hitting warning threshold
  int get absencesBeforeWarning {
    final maxAbsences = (totalClasses * (1 - kWarningThreshold / 100)).floor();
    return (maxAbsences - absent).clamp(0, 999);
  }

  bool get isWarning => attendanceRate < kWarningThreshold && attendanceRate >= kDangerThreshold;
  bool get isDanger  => attendanceRate < kDangerThreshold;
  bool get isGood    => attendanceRate >= kWarningThreshold;

  Color get statusColor {
    if (isDanger)  return const Color(0xFFE53935);
    if (isWarning) return const Color(0xFFFF9800);
    return const Color(0xFF4CAF50);
  }

  Color get statusBg {
    if (isDanger)  return const Color(0xFFFFEBEE);
    if (isWarning) return const Color(0xFFFFF3E0);
    return const Color(0xFFE8F5E9);
  }

  String get statusLabel {
    if (isDanger)  return 'Critical';
    if (isWarning) return 'Warning';
    return 'Good';
  }

  IconData get statusIcon {
    if (isDanger)  return Icons.error_rounded;
    if (isWarning) return Icons.warning_rounded;
    return Icons.check_circle_rounded;
  }
}

// ── Single class session in course history ──
class CourseSessionHistory {
  final DateTime date;
  final bool     attended;
  final String?  reason;

  const CourseSessionHistory({
    required this.date,
    required this.attended,
    this.reason,
  });

  String get formattedDate {
    const months = ['Jan','Feb','Mar','Apr','May',
      'Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }
}