class ProfileModel {
  final String  id;
  final String  fullName;
  final String  email;
  final String  indexNumber;
  final String  programme;
  final String  level;
  final String  role;
  final String? profileImageUrl;
  final String  academicYear;

  // Semester attendance summary
  final int totalClasses;
  final int attended;
  final int absent;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.indexNumber,
    required this.programme,
    required this.level,
    required this.role,
    required this.academicYear,
    required this.totalClasses,
    required this.attended,
    required this.absent,
    this.profileImageUrl,
  });

  double get attendanceRate =>
      totalClasses == 0 ? 0 : (attended / totalClasses) * 100;

  int get attendancePercent => attendanceRate.toInt();

  String get firstName =>
      fullName.isNotEmpty ? fullName.split(' ').first : 'User';

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';
  }
}