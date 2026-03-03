import 'package:smart_attend/features/student/models/course_detail_model.dart';

class CoursesController {
  // TODO: Replace with real API call:
  // GET /api/students/:id/courses/attendance?semester=current
  Future<List<CourseAttendanceModel>> fetchCoursesAttendance(
      String studentId) async {
    await Future.delayed(const Duration(milliseconds: 600));

    return [
      CourseAttendanceModel(
        id:           'c1',
        courseCode:   'MATH 101',
        courseName:   'Mathematics',
        instructor:   'Dr. Mensah',
        room:         'Block A - Room 12',
        schedule:     'Mon, Wed, Fri',
        totalClasses: 20,
        attended:     17,
        absent:       3,
        history: [
          CourseSessionHistory(date: DateTime(2026, 2, 2),  attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 5),  attended: false, reason: 'Sick'),
          CourseSessionHistory(date: DateTime(2026, 2, 9),  attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 12), attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 16), attended: false, reason: 'Transport'),
          CourseSessionHistory(date: DateTime(2026, 2, 19), attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 23), attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 26), attended: false, reason: 'Family emergency'),
          CourseSessionHistory(date: DateTime(2026, 3, 2),  attended: true),
          CourseSessionHistory(date: DateTime(2026, 3, 5),  attended: true),
        ],
      ),
      CourseAttendanceModel(
        id:           'c2',
        courseCode:   'PHY 201',
        courseName:   'Physics Lab',
        instructor:   'Prof. Asante',
        room:         'Science Block - Lab 3',
        schedule:     'Mon, Tue, Thu',
        totalClasses: 18,
        attended:     11,
        absent:       7,
        history: [
          CourseSessionHistory(date: DateTime(2026, 2, 2),  attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 3),  attended: false, reason: 'Sick'),
          CourseSessionHistory(date: DateTime(2026, 2, 9),  attended: false),
          CourseSessionHistory(date: DateTime(2026, 2, 10), attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 16), attended: false, reason: 'Personal'),
          CourseSessionHistory(date: DateTime(2026, 2, 17), attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 23), attended: false),
          CourseSessionHistory(date: DateTime(2026, 2, 24), attended: true),
          CourseSessionHistory(date: DateTime(2026, 3, 2),  attended: true),
          CourseSessionHistory(date: DateTime(2026, 3, 3),  attended: false),
        ],
      ),
      CourseAttendanceModel(
        id:           'c3',
        courseCode:   'HIS 101',
        courseName:   'History',
        instructor:   'Dr. Acheampong',
        room:         'Block C - Room 5',
        schedule:     'Tue, Thu',
        totalClasses: 14,
        attended:     14,
        absent:       0,
        history: [
          CourseSessionHistory(date: DateTime(2026, 2, 3),  attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 5),  attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 10), attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 12), attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 17), attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 19), attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 24), attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 26), attended: true),
        ],
      ),
      CourseAttendanceModel(
        id:           'c4',
        courseCode:   'ENG 102',
        courseName:   'English Composition',
        instructor:   'Mrs. Darko',
        room:         'Block B - Room 7',
        schedule:     'Mon, Wed, Fri',
        totalClasses: 20,
        attended:     13,
        absent:       7,
        history: [
          CourseSessionHistory(date: DateTime(2026, 2, 2),  attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 5),  attended: false),
          CourseSessionHistory(date: DateTime(2026, 2, 9),  attended: false, reason: 'Sick'),
          CourseSessionHistory(date: DateTime(2026, 2, 12), attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 16), attended: false),
          CourseSessionHistory(date: DateTime(2026, 2, 19), attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 23), attended: false, reason: 'Personal'),
          CourseSessionHistory(date: DateTime(2026, 2, 26), attended: true),
          CourseSessionHistory(date: DateTime(2026, 3, 2),  attended: false),
          CourseSessionHistory(date: DateTime(2026, 3, 5),  attended: true),
        ],
      ),
      CourseAttendanceModel(
        id:           'c5',
        courseCode:   'CS 301',
        courseName:   'Data Structures',
        instructor:   'Dr. Boateng',
        room:         'ICT Block - Lab 1',
        schedule:     'Tue, Fri',
        totalClasses: 16,
        attended:     15,
        absent:       1,
        history: [
          CourseSessionHistory(date: DateTime(2026, 2, 3),  attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 6),  attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 10), attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 13), attended: false, reason: 'Sick'),
          CourseSessionHistory(date: DateTime(2026, 2, 17), attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 20), attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 24), attended: true),
          CourseSessionHistory(date: DateTime(2026, 2, 27), attended: true),
        ],
      ),
    ];
  }

  // ── Sort by most absences (worst first) ──
  List<CourseAttendanceModel> sortByMostAbsences(
      List<CourseAttendanceModel> courses) {
    final sorted = [...courses];
    sorted.sort((a, b) => a.attendanceRate.compareTo(b.attendanceRate));
    return sorted;
  }
}