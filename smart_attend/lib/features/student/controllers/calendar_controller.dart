import 'package:flutter/material.dart';
import 'package:smart_attend/features/student/models/attendance_model.dart';

class CalendarController {
  // ── Fetch all attendance data for a given month ──
  // TODO: Replace with real API call:
  // GET /api/students/:id/attendance?month=3&year=2026
  Future<Map<String, DayAttendanceModel>> fetchMonthAttendance(
      String studentId,
      int month,
      int year,
      ) async {
    await Future.delayed(const Duration(milliseconds: 500));

    // Generate mock data for the month
    final Map<String, DayAttendanceModel> data = {};

    // Helper to add a day's data
    void addDay(DateTime date, List<ClassSessionModel> sessions) {
      data[_key(date)] = DayAttendanceModel(date: date, sessions: sessions);
    }

    // ── Mock sessions for March 2026 ──
    addDay(DateTime(2026, 3, 2), [
      _mockSession('s1', 'MATH 101', 'Mathematics',    AttendanceStatus.present),
      _mockSession('s2', 'PHY 201',  'Physics Lab',    AttendanceStatus.present),
    ]);
    addDay(DateTime(2026, 3, 3), [
      _mockSession('s3', 'ENG 102',  'English',        AttendanceStatus.present),
      _mockSession('s4', 'CS 301',   'Data Structures',AttendanceStatus.absent,
          reason: 'Was sick'),
    ]);
    addDay(DateTime(2026, 3, 4), [
      _mockSession('s5', 'HIS 101',  'History',        AttendanceStatus.present),
    ]);
    addDay(DateTime(2026, 3, 5), [
      _mockSession('s6', 'MATH 101', 'Mathematics',    AttendanceStatus.absent,
          reason: 'Transport issues'),
      _mockSession('s7', 'ENG 102',  'English',        AttendanceStatus.present),
    ]);
    addDay(DateTime(2026, 3, 6), [
      _mockSession('s8', 'CS 301',   'Data Structures',AttendanceStatus.present),
    ]);
    addDay(DateTime(2026, 3, 9), [
      _mockSession('s9',  'PHY 201', 'Physics Lab',    AttendanceStatus.present),
      _mockSession('s10', 'HIS 101', 'History',        AttendanceStatus.cancelled),
    ]);
    addDay(DateTime(2026, 3, 10), [
      _mockSession('s11', 'MATH 101','Mathematics',    AttendanceStatus.absent,
          reason: 'Family emergency'),
    ]);
    addDay(DateTime(2026, 3, 11), [
      _mockSession('s12', 'CS 301',  'Data Structures',AttendanceStatus.present),
      _mockSession('s13', 'ENG 102', 'English',        AttendanceStatus.present),
    ]);
    addDay(DateTime(2026, 3, 12), [
      _mockSession('s14', 'PHY 201', 'Physics Lab',    AttendanceStatus.present),
    ]);
    addDay(DateTime(2026, 3, 13), [
      _mockSession('s15', 'HIS 101', 'History',        AttendanceStatus.present),
    ]);

    // Today and upcoming
    final today = DateTime.now();
    addDay(today, [
      _mockSession('s16', 'MATH 101','Mathematics',    AttendanceStatus.upcoming),
      _mockSession('s17', 'CS 301',  'Data Structures',AttendanceStatus.upcoming),
    ]);

    return data;
  }

  // ── Helper: build key from date ──
  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';
  String keyFromDate(DateTime d) => _key(d);

  // ── Helper: build a mock session ──
  ClassSessionModel _mockSession(
      String id,
      String code,
      String name,
      AttendanceStatus status, {
        String? reason,
      }) {
    return ClassSessionModel(
      id:           id,
      courseCode:   code,
      courseName:   name,
      instructor:   'Dr. Mensah',
      room:         'Block A - Room 12',
      startTime:    const TimeOfDay(hour: 10, minute: 0),
      endTime:      const TimeOfDay(hour: 11, minute: 30),
      status:       status,
      absenceReason: reason,
    );
  }

  // ── Stats helpers ──
  int countPresent(Map<String, DayAttendanceModel> data) {
    return data.values
        .expand((d) => d.sessions)
        .where((s) => s.status == AttendanceStatus.present)
        .length;
  }

  int countAbsent(Map<String, DayAttendanceModel> data) {
    return data.values
        .expand((d) => d.sessions)
        .where((s) => s.status == AttendanceStatus.absent)
        .length;
  }
}