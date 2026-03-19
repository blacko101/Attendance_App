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
  final List<int> weekdays; // 1=Mon…7=Sun
  final String schedule; // "Mon, Wed, Fri"
  final String room;
  final String startTime; // "10:00 AM"
  final String endTime; // "11:30 AM"

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

// ── A single class session in the weekly schedule
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
