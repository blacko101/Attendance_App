import 'package:flutter/material.dart';

// ── Attendance status for a single class session ──
enum AttendanceStatus { present, absent, upcoming, cancelled }

class ClassSessionModel {
  final String   id;
  final String   courseCode;
  final String   courseName;
  final String   instructor;
  final String   room;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final AttendanceStatus status;
  final String?  absenceReason;

  const ClassSessionModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.instructor,
    required this.room,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.absenceReason,
  });

  String get formattedTime {
    String _fmt(TimeOfDay t) {
      final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
      final m = t.minute.toString().padLeft(2, '0');
      final p = t.period == DayPeriod.am ? 'AM' : 'PM';
      return '$h:$m $p';
    }
    return '${_fmt(startTime)} - ${_fmt(endTime)}';
  }

  Color get statusColor {
    switch (status) {
      case AttendanceStatus.present:   return const Color(0xFF4CAF50);
      case AttendanceStatus.absent:    return const Color(0xFF9B1B42);
      case AttendanceStatus.upcoming:  return const Color(0xFF2196F3);
      case AttendanceStatus.cancelled: return const Color(0xFF9E9E9E);
    }
  }

  String get statusLabel {
    switch (status) {
      case AttendanceStatus.present:   return 'Present';
      case AttendanceStatus.absent:    return 'Absent';
      case AttendanceStatus.upcoming:  return 'Upcoming';
      case AttendanceStatus.cancelled: return 'Cancelled';
    }
  }

  IconData get statusIcon {
    switch (status) {
      case AttendanceStatus.present:   return Icons.check_circle_rounded;
      case AttendanceStatus.absent:    return Icons.cancel_rounded;
      case AttendanceStatus.upcoming:  return Icons.schedule_rounded;
      case AttendanceStatus.cancelled: return Icons.remove_circle_rounded;
    }
  }
}

// ── Summary for a single day ──
class DayAttendanceModel {
  final DateTime           date;
  final List<ClassSessionModel> sessions;

  const DayAttendanceModel({
    required this.date,
    required this.sessions,
  });

  bool get hasClasses  => sessions.isNotEmpty;
  bool get allPresent  => sessions.isNotEmpty && sessions.every((s) => s.status == AttendanceStatus.present);
  bool get hasAbsence  => sessions.any((s) => s.status == AttendanceStatus.absent);
  bool get isUpcoming  => sessions.any((s) => s.status == AttendanceStatus.upcoming);
  bool get isCancelled => sessions.isNotEmpty && sessions.every((s) => s.status == AttendanceStatus.cancelled);

  // Color for calendar dot indicator
  Color get dayColor {
    if (!hasClasses)  return Colors.transparent;
    if (hasAbsence)   return const Color(0xFF9B1B42); // cherry
    if (isUpcoming)   return const Color(0xFF2196F3); // blue
    if (allPresent)   return const Color(0xFF4CAF50); // green
    if (isCancelled)  return const Color(0xFF9E9E9E); // grey
    return const Color(0xFF4CAF50);
  }
}