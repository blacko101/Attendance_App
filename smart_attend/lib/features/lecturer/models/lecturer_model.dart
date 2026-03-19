// ── Attendance type for a session ──────────────
enum AttendanceType { inPerson, online }

enum AttendanceMethod { qrCode, sixDigitCode }

// ── A course assigned to the lecturer ──────────
class LecturerCourseModel {
  final String id;
  final String courseCode;
  final String courseName;
  final String department;
  final int totalStudents;
  final List<int> weekdays;
  final String schedule;
  final String room;
  final String startTime;
  final String endTime;

  const LecturerCourseModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.department,
    required this.totalStudents,
    required this.weekdays,
    required this.schedule,
    required this.room,
    required this.startTime,
    required this.endTime,
  });
}

// ── A single class session in the weekly schedule ──
enum SessionStatus { upcoming, active, held, notHeld, cancelled }

class WeeklySessionModel {
  final String id;
  final String courseCode;
  final String courseName;
  final String room;
  final DateTime date;
  final String startTime;
  final String endTime;
  final SessionStatus status;
  final String? sessionType; // "inPerson" | "online" — from actual session
  final String? actualSessionId; // DB _id of the attendance session if held
  final int? studentsAttended;
  final int? totalStudents;
  final String? notHeldReason;

  const WeeklySessionModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.room,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.sessionType,
    this.actualSessionId,
    this.studentsAttended,
    this.totalStudents,
    this.notHeldReason,
  });

  String get dayLabel {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String get dateLabel {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

// ── Weekly stats ────────────────────────────────
class WeeklyStats {
  final int scheduled;
  final int held;
  final int notHeld;
  final int inPerson;
  final int online;

  const WeeklyStats({
    required this.scheduled,
    required this.held,
    required this.notHeld,
    required this.inPerson,
    required this.online,
  });

  factory WeeklyStats.empty() => const WeeklyStats(
    scheduled: 0,
    held: 0,
    notHeld: 0,
    inPerson: 0,
    online: 0,
  );
}

// ── Course summary (Summary page) ──────────────
class CourseSummaryModel {
  final String id;
  final String courseCode;
  final String courseName;
  final String department;
  final int totalStudents;
  final int held;
  final int inPerson;
  final int online;
  final List<SessionHistoryModel> sessionHistory;

  const CourseSummaryModel({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.department,
    required this.totalStudents,
    required this.held,
    required this.inPerson,
    required this.online,
    required this.sessionHistory,
  });

  int get missed => sessionHistory
      .where((s) => s.studentsPresent == 0 && s.totalStudents == 0)
      .length;
}

// ── A single session in a course's history ──────
class SessionHistoryModel {
  final String sessionId;
  final DateTime date;
  final String type; // "inPerson" | "online"
  final int studentsPresent;
  final int studentsAbsent;
  final int totalStudents;

  const SessionHistoryModel({
    required this.sessionId,
    required this.date,
    required this.type,
    required this.studentsPresent,
    required this.studentsAbsent,
    required this.totalStudents,
  });

  String get formattedDate {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String get typeLabel => type == 'inPerson' ? 'In-Person' : 'Online';
}

// ── Per-student attendance in a session ────────
class SessionStudentModel {
  final String studentId;
  final String fullName;
  final String email;
  final String indexNumber;
  final bool present;
  final DateTime? checkedInAt;

  const SessionStudentModel({
    required this.studentId,
    required this.fullName,
    required this.email,
    required this.indexNumber,
    required this.present,
    this.checkedInAt,
  });
}

// ── Lecturer profile model ──────────────────────
class LecturerModel {
  final String id;
  final String fullName;
  final String email;
  final String staffId;
  final String department;
  final String role;
  final String? profileImageUrl;
  final List<String> courseIds;

  const LecturerModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.staffId,
    required this.department,
    required this.role,
    required this.courseIds,
    this.profileImageUrl,
  });

  String get firstName =>
      fullName.isNotEmpty ? fullName.split(' ').first : 'Lecturer';

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'L';
  }

  String get displayTitle {
    if (role.toLowerCase().contains('prof')) return 'Prof. $fullName';
    return 'Dr. $fullName';
  }
}

// ── Active attendance session ───────────────────
class ActiveSessionModel {
  final String sessionId;
  final String courseCode;
  final String courseName;
  final AttendanceType type;
  final AttendanceMethod method;
  final String qrData;
  final String sixDigitCode;
  final int totalSeconds;
  final int secondsLeft;
  final int studentsMarked;
  final int totalStudents;
  final double? lecturerLat;
  final double? lecturerLng;

  const ActiveSessionModel({
    required this.sessionId,
    required this.courseCode,
    required this.courseName,
    required this.type,
    required this.method,
    required this.qrData,
    required this.sixDigitCode,
    required this.totalSeconds,
    required this.secondsLeft,
    required this.studentsMarked,
    required this.totalStudents,
    this.lecturerLat,
    this.lecturerLng,
  });

  double get progressFraction =>
      totalSeconds == 0 ? 0 : secondsLeft / totalSeconds;

  ActiveSessionModel copyWith({
    String? qrData,
    String? sixDigitCode,
    int? secondsLeft,
    int? studentsMarked,
  }) => ActiveSessionModel(
    sessionId: sessionId,
    courseCode: courseCode,
    courseName: courseName,
    type: type,
    method: method,
    qrData: qrData ?? this.qrData,
    sixDigitCode: sixDigitCode ?? this.sixDigitCode,
    totalSeconds: totalSeconds,
    secondsLeft: secondsLeft ?? this.secondsLeft,
    studentsMarked: studentsMarked ?? this.studentsMarked,
    totalStudents: totalStudents,
    lecturerLat: lecturerLat,
    lecturerLng: lecturerLng,
  );
}
