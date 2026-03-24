class AuthModel {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String token;
  final bool mustChangePassword;
  final bool faceRegistered;
  final String? indexNumber;
  final String? programme;
  final String? level;
  final String? staffId;
  final String? department;

  const AuthModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.token,
    this.mustChangePassword = false,
    this.faceRegistered = false,
    this.indexNumber,
    this.programme,
    this.level,
    this.staffId,
    this.department,
  });

  factory AuthModel.fromLoginResponse({
    required String token,
    required String role,
    required String id,
    String fullName = '',
    String email = '',
    bool mustChangePassword = false,
    bool faceRegistered = false,
    String? indexNumber,
    String? programme,
    String? level,
    String? staffId,
    String? department,
  }) {
    return AuthModel(
      id: id,
      fullName: fullName,
      email: email,
      role: role,
      token: token,
      mustChangePassword: mustChangePassword,
      faceRegistered: faceRegistered,
      indexNumber: indexNumber,
      programme: programme,
      level: level,
      staffId: staffId,
      department: department,
    );
  }

  factory AuthModel.fromJson(Map<String, dynamic> json) => AuthModel(
    id: json['id'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'student',
    token: json['token'] as String? ?? '',
    mustChangePassword: json['mustChangePassword'] as bool? ?? false,
    faceRegistered: json['faceRegistered'] as bool? ?? false,
    indexNumber: json['indexNumber'] as String?,
    programme: json['programme'] as String?,
    level: json['level'] as String?,
    staffId: json['staffId'] as String?,
    department: json['department'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'role': role,
    'token': token,
    'mustChangePassword': mustChangePassword,
    'faceRegistered': faceRegistered,
    'indexNumber': indexNumber,
    'programme': programme,
    'level': level,
    'staffId': staffId,
    'department': department,
  };

  AuthModel copyWithPasswordChanged() => AuthModel(
    id: id,
    fullName: fullName,
    email: email,
    role: role,
    token: token,
    mustChangePassword: false,
    faceRegistered: faceRegistered,
    indexNumber: indexNumber,
    programme: programme,
    level: level,
    staffId: staffId,
    department: department,
  );

  AuthModel copyWithFaceRegistered() => AuthModel(
    id: id,
    fullName: fullName,
    email: email,
    role: role,
    token: token,
    mustChangePassword: mustChangePassword,
    faceRegistered: true,
    indexNumber: indexNumber,
    programme: programme,
    level: level,
    staffId: staffId,
    department: department,
  );

  bool get isStudent  => role == 'student';
  bool get isLecturer => role == 'lecturer';
  bool get isAdmin    => role == 'admin';

  String get firstName =>
      fullName.isNotEmpty ? fullName.split(' ').first : 'User';

  @override
  String toString() =>
      'AuthModel(id: $id, email: $email, role: $role, '
          'mustChangePassword: $mustChangePassword, '
          'faceRegistered: $faceRegistered)';
}