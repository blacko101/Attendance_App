import 'package:smart_attend/features/student/models/course_model.dart';
import 'package:flutter/material.dart';

class StudentController {
  // ── In production, inject studentId from your AuthController/session ──
  // e.g. final String studentId;
  // StudentController({required this.studentId});

  /// Fetches enrolled courses for the current semester.
  /// TODO: Replace mock with real API call:
  /// GET /api/students/:studentId/courses?semester=current
  Future<List<CourseModel>> fetchEnrolledCourses(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 600)); // simulate network

    // TODO: Replace with:
    // final res = await http.get(Uri.parse('$baseUrl/students/$studentId/courses'));
    // final List data = jsonDecode(res.body);
    // return data.map((e) => CourseModel.fromJson(e)).toList();

    return [
      CourseModel(
        id: 'c1',
        courseCode: 'MATH 101',
        courseName: 'Mathematics',
        instructor: 'Dr. Mensah',
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 11, minute: 30),
        weekdays: [1, 3, 5],
        room: 'Block A - Room 12',
      ),
      CourseModel(
        id: 'c2',
        courseCode: 'PHY 201',
        courseName: 'Physics Lab',
        instructor: 'Prof. Asante',
        startTime: const TimeOfDay(hour: 12, minute: 0),
        endTime: const TimeOfDay(hour: 13, minute: 30),
        weekdays: [1, 2, 4],
        room: 'Science Block - Lab 3',
      ),
      CourseModel(
        id: 'c3',
        courseCode: 'HIS 101',
        courseName: 'History',
        instructor: 'Dr. Acheampong',
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 15, minute: 30),
        weekdays: [2, 4],
        room: 'Block C - Room 5',
      ),
      CourseModel(
        id: 'c4',
        courseCode: 'ENG 102',
        courseName: 'English Composition',
        instructor: 'Mrs. Darko',
        startTime: const TimeOfDay(hour: 8, minute: 0),
        endTime: const TimeOfDay(hour: 9, minute: 30),
        weekdays: [1, 3, 5],
        room: 'Block B - Room 7',
      ),
      CourseModel(
        id: 'c5',
        courseCode: 'CS 301',
        courseName: 'Data Structures',
        instructor: 'Dr. Boateng',
        startTime: const TimeOfDay(hour: 15, minute: 30),
        endTime: const TimeOfDay(hour: 17, minute: 0),
        weekdays: [2, 5],
        room: 'ICT Block - Lab 1',
      ),
    ];
  }

  /// Filters and sorts today's upcoming courses from a full course list
  List<CourseModel> getUpcomingToday(List<CourseModel> allCourses) {
    final upcoming = allCourses.where((c) => c.isUpcomingToday).toList();
    upcoming.sort((a, b) {
      final aMin = a.startTime.hour * 60 + a.startTime.minute;
      final bMin = b.startTime.hour * 60 + b.startTime.minute;
      return aMin.compareTo(bMin);
    });
    return upcoming;
  }
}