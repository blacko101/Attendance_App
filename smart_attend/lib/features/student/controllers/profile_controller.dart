import 'package:smart_attend/features/auth/models/auth_model.dart';
import 'package:smart_attend/features/student/models/profile_model.dart';

class ProfileController {
  // TODO: Replace with real API call:
  // GET /api/students/:id/profile
  Future<ProfileModel> fetchProfile(AuthModel authUser) async {
    await Future.delayed(const Duration(milliseconds: 400));

    return ProfileModel(
      id:             authUser.id,
      fullName:       authUser.fullName.isNotEmpty
          ? authUser.fullName
          : 'Kofi Mensah',
      email:          authUser.email,
      indexNumber:    authUser.indexNumber ?? 'UG/2021/0042',
      programme:      authUser.programme   ?? 'BSc. Computer Science',
      level:          authUser.level       ?? '300',
      role:           authUser.role,
      academicYear:   '2025/2026',
      totalClasses:   88,
      attended:       74,
      absent:         14,

    );
  }
}