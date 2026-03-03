import 'package:flutter/material.dart';

class CourseModel {
  final String id;
  final String courseCode;
  final String courseName;
  final String instructor;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final List<int> weekdays; // 1=Mon … 7=Sun (DateTime.weekday)
  final String room;

  const CourseModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.instructor,
    required this.startTime,
    required this.endTime,
    required this.weekdays,
    required this.room,
  });

  /// Display label e.g. "10:00 AM"
  String get formattedStart {
    final h = startTime.hourOfPeriod == 0 ? 12 : startTime.hourOfPeriod;
    final m = startTime.minute.toString().padLeft(2, '0');
    final period = startTime.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  /// True if this course runs today AND hasn't ended yet
  bool get isUpcomingToday {
    final now = TimeOfDay.now();
    final todayWeekday = DateTime.now().weekday;
    if (!weekdays.contains(todayWeekday)) return false;
    final nowMins = now.hour * 60 + now.minute;
    final endMins = endTime.hour * 60 + endTime.minute;
    return nowMins < endMins;
  }

  /// Dot color cycles per course for visual variety
  Color get dotColor {
    const palette = [Color(0xFF9B1B42), Color(0xFFB84060), Color(0xFF7A1535)];
    return palette[id.hashCode % palette.length];
  }
}