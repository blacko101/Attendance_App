import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/auth/models/auth_model.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/student/models/profile_model.dart';

class ProfileController {
  // ── FETCH STUDENT PROFILE WITH ATTENDANCE SUMMARY ────────────────
  // Combines:
  //   GET /api/auth/me                        — user details
  //   GET /api/attendance/student/:studentId  — attendance records
  //
  // The profile screen shows the student's personal info plus a
  // semester-level attendance summary (total classes, attended, absent).
  Future<ProfileModel> fetchProfile(AuthModel authUser) async {
    final session = await SessionService.getSession();
    if (session == null) {
      return _fallback(authUser, 0, 0, 0);
    }

    try {
      // Run both requests in parallel
      final results = await Future.wait([
        http
            .get(
              Uri.parse('${AppConfig.authUrl}/me'),
              headers: {'Authorization': 'Bearer ${session.token}'},
            )
            .timeout(const Duration(seconds: 10)),
        http
            .get(
              Uri.parse('${AppConfig.attendanceUrl}/student/${authUser.id}'),
              headers: {'Authorization': 'Bearer ${session.token}'},
            )
            .timeout(const Duration(seconds: 10)),
      ]);

      final meResp = results[0];
      final attResp = results[1];

      // ── Parse user details ─────────────────────
      String fullName = authUser.fullName;
      String email = authUser.email;
      String indexNumber = authUser.indexNumber ?? '';
      String programme = authUser.programme ?? '';
      String level = authUser.level ?? '';

      if (meResp.statusCode == 200) {
        final body = jsonDecode(meResp.body) as Map<String, dynamic>;
        final u = body['user'] as Map<String, dynamic>? ?? {};
        fullName = u['fullName'] as String? ?? fullName;
        email = u['email'] as String? ?? email;
        indexNumber = u['indexNumber'] as String? ?? indexNumber;
        programme = u['programme'] as String? ?? programme;
        level = u['level'] as String? ?? level;
      }

      // ── Compute attendance summary ─────────────
      int total = 0;
      int attended = 0;

      if (attResp.statusCode == 200) {
        final body = jsonDecode(attResp.body) as Map<String, dynamic>;
        final records = (body['records'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        total = records.length;
        attended = records
            .where((r) => (r['status'] as String? ?? '') == 'present')
            .length;
      }

      final absent = total - attended;

      return ProfileModel(
        id: authUser.id,
        fullName: fullName,
        email: email,
        indexNumber: indexNumber,
        programme: programme,
        level: level,
        role: authUser.role,
        academicYear: _currentAcademicYear(),
        totalClasses: total,
        attended: attended,
        absent: absent,
      );
    } catch (_) {
      return _fallback(authUser, 0, 0, 0);
    }
  }

  ProfileModel _fallback(AuthModel u, int total, int attended, int absent) =>
      ProfileModel(
        id: u.id,
        fullName: u.fullName,
        email: u.email,
        indexNumber: u.indexNumber ?? '',
        programme: u.programme ?? '',
        level: u.level ?? '',
        role: u.role,
        academicYear: _currentAcademicYear(),
        totalClasses: total,
        attended: attended,
        absent: absent,
      );

  String _currentAcademicYear() {
    final now = DateTime.now();
    final year = now.month >= 8 ? now.year : now.year - 1;
    return '$year/${year + 1}';
  }
}
