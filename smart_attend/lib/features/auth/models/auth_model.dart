// ─────────────────────────────────────────────────────────────────────────────
//  AUTH MODEL — matches actual backend User schema
//  Backend User: { fullName, email, role, indexNumber, staffId, programme, level }
// ─────────────────────────────────────────────────────────────────────────────

class AuthModel {
  final String  id;
  final String  fullName;
  final String  email;
  final String  role;          // "student" | "lecturer" | "admin"
  final String  token;         // JWT — expires in 1 day
  final String? indexNumber;   // students only  e.g. "UG/2021/0042"
  final String? programme;     // e.g. "BSc. Computer Science"
  final String? level;         // e.g. "300"
  final String? staffId;       // lecturers/admin only
  final String? department;    // lecturers/admin only

  const AuthModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.token,
    this.indexNumber,
    this.programme,
    this.level,
    this.staffId,
    this.department,
  });

  // ── Called after login ─────────────────────────────────────────────────────
  factory AuthModel.fromLoginResponse({
    required String token,
    required String role,
    required String id,
    String  fullName    = '',
    String  email       = '',
    String? indexNumber,
    String? programme,
    String? level,
    String? staffId,
    String? department,
  }) {
    return AuthModel(
      id:          id,
      fullName:    fullName,
      email:       email,
      role:        role,
      token:       token,
      indexNumber: indexNumber,
      programme:   programme,
      level:       level,
      staffId:     staffId,
      department:  department,
    );
  }

  // ── Restore session from SharedPreferences ─────────────────────────────────
  factory AuthModel.fromJson(Map<String, dynamic> json) => AuthModel(
    id:          json['id']          as String? ?? '',
    fullName:    json['fullName']    as String? ?? '',
    email:       json['email']       as String? ?? '',
    role:        json['role']        as String? ?? 'student',
    token:       json['token']       as String? ?? '',
    indexNumber: json['indexNumber'] as String?,
    programme:   json['programme']   as String?,
    level:       json['level']       as String?,
    staffId:     json['staffId']     as String?,
    department:  json['department']  as String?,
  );

  // ── Save session to SharedPreferences ──────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id':          id,
    'fullName':    fullName,
    'email':       email,
    'role':        role,
    'token':       token,
    'indexNumber': indexNumber,
    'programme':   programme,
    'level':       level,
    'staffId':     staffId,
    'department':  department,
  };

  // ── Convenience getters ────────────────────────────────────────────────────
  bool get isStudent  => role == 'student';
  bool get isLecturer => role == 'lecturer';
  bool get isAdmin    => role == 'admin';

  String get firstName =>
      fullName.isNotEmpty ? fullName.split(' ').first : 'User';

  @override
  String toString() =>
      'AuthModel(id: $id, email: $email, role: $role)';
}