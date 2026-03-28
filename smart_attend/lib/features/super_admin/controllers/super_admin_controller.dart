import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_attend/core/config/app_config.dart';
import 'package:smart_attend/features/auth/services/session_service.dart';
import 'package:smart_attend/features/super_admin/models/super_admin_model.dart';

class SuperAdminController {
  // ── FETCH DASHBOARD ───────────────────────────────────────────────
  // GET /api/super-admin/dashboard
  Future<({SuperAdminTotals totals, List<DepartmentAdminModel> admins})>
  fetchDashboard() async {
    final session = await SessionService.getSession();
    if (session == null) {
      return (
        totals: SuperAdminTotals.empty(),
        admins: <DepartmentAdminModel>[],
      );
    }

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.superAdminUrl}/dashboard'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          totals: SuperAdminTotals.empty(),
          admins: <DepartmentAdminModel>[],
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final totals = SuperAdminTotals.fromJson(
        body['totals'] as Map<String, dynamic>? ?? {},
      );
      final admins = (body['admins'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(DepartmentAdminModel.fromJson)
          .toList();

      return (totals: totals, admins: admins);
    } catch (_) {
      return (
        totals: SuperAdminTotals.empty(),
        admins: <DepartmentAdminModel>[],
      );
    }
  }

  // ── FETCH ADMIN DETAIL ────────────────────────────────────────────
  // GET /api/super-admin/admins/:id
  Future<AdminDetailModel?> fetchAdminDetail(String adminId) async {
    final session = await SessionService.getSession();
    if (session == null) return null;

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.superAdminUrl}/admins/$adminId'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;
      return AdminDetailModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  // ── CREATE ADMIN ──────────────────────────────────────────────────
  // POST /api/super-admin/admins
  // Returns the new admin + the default password (shown once)
  Future<
    ({String? error, String? defaultPassword, DepartmentAdminModel? admin})
  >
  createAdmin({
    required String fullName,
    required String email,
    required String department,
  }) async {
    final session = await SessionService.getSession();
    if (session == null)
      return (error: 'Session expired.', defaultPassword: null, admin: null);

    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.superAdminUrl}/admins'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.token}',
            },
            body: jsonEncode({
              'fullName': fullName,
              'email': email,
              'department': department,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201) {
        final adminMap = body['admin'] as Map<String, dynamic>? ?? {};
        return (
          error: null,
          defaultPassword: body['defaultPassword'] as String?,
          admin: DepartmentAdminModel.fromJson({
            ...adminMap,
            'students': 0,
            'lecturers': 0,
            'createdAt': DateTime.now().toIso8601String(),
          }),
        );
      }
      return (
        error: body['message'] as String? ?? 'Failed to create admin.',
        defaultPassword: null,
        admin: null,
      );
    } catch (e) {
      return (error: 'Connection error.', defaultPassword: null, admin: null);
    }
  }

  // ── SET ADMIN STATUS ──────────────────────────────────────────────
  // PATCH /api/super-admin/admins/:id/status
  Future<String?> setAdminStatus(String adminId, {required bool active}) async {
    final session = await SessionService.getSession();
    if (session == null) return 'Session expired.';

    try {
      final response = await http
          .patch(
            Uri.parse('${AppConfig.superAdminUrl}/admins/$adminId/status'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.token}',
            },
            body: jsonEncode({'isActive': active}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['message'] as String? ?? 'Failed to update status.';
    } catch (_) {
      return 'Connection error.';
    }
  }

  // ── LIST FACULTIES ────────────────────────────────────────────────
  // GET /api/super-admin/faculties
  Future<List<FacultyModel>> fetchFaculties() async {
    final session = await SessionService.getSession();
    if (session == null) return [];

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.superAdminUrl}/faculties'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['faculties'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(FacultyModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── CREATE FACULTY ────────────────────────────────────────────────
  // POST /api/super-admin/faculties
  Future<String?> createFaculty(String name) async {
    final session = await SessionService.getSession();
    if (session == null) return 'Session expired.';

    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.superAdminUrl}/faculties'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.token}',
            },
            body: jsonEncode({'name': name}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['message'] as String? ?? 'Failed to create faculty.';
    } catch (_) {
      return 'Connection error.';
    }
  }
}
