import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_attend/features/auth/controllers/auth_controller.dart';
import 'package:smart_attend/features/auth/views/mobile/login_screen.dart';
import 'package:smart_attend/features/super_admin/controllers/super_admin_controller.dart';
import 'package:smart_attend/features/super_admin/models/super_admin_model.dart';

// ── Theme ──────────────────────────────────────
const _kCherry = Color(0xFF9B1B42);
const _kCherryBg = Color(0xFFFFEEF2);
const _kGreen = Color(0xFF4CAF50);
const _kGreenBg = Color(0xFFE8F5E9);
const _kBlue = Color(0xFF1565C0);
const _kBlueBg = Color(0xFFE3F2FD);
const _kOrange = Color(0xFFFF9800);
const _kOrangeBg = Color(0xFFFFF3E0);
const _kBg = Color(0xFFEEEEF3);
const _kWhite = Color(0xFFFFFFFF);
const _kText = Color(0xFF1A1A1A);
const _kSubtext = Color(0xFF888888);

// ══════════════════════════════════════════════
//  SUPER ADMIN DASHBOARD
// ══════════════════════════════════════════════
class SuperAdminDashboard extends StatefulWidget {
  static String id = 'super_admin_dashboard';
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  final _ctrl = SuperAdminController();
  final _authCtrl = AuthController();

  SuperAdminTotals _totals = SuperAdminTotals.empty();
  List<DepartmentAdminModel> _admins = [];
  List<FacultyModel> _faculties = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _ctrl.fetchDashboard();
    final faculties = await _ctrl.fetchFaculties();
    if (mounted) {
      setState(() {
        _totals = result.totals;
        _admins = result.admins;
        _faculties = faculties;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _authCtrl.logout(context);
    if (mounted) {
      Navigator.pushReplacementNamed(context, LoginScreen.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _kCherry),
                    )
                  : RefreshIndicator(
                      color: _kCherry,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _buildTotalsRow(),
                          const SizedBox(height: 24),
                          _buildAdminListHeader(),
                          const SizedBox(height: 12),
                          ..._admins.map(
                            (a) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AdminCard(
                                admin: a,
                                onTap: () => _openDetail(a),
                                onToggle: (active) => _toggleAdmin(a, active),
                              ),
                            ),
                          ),
                          if (_admins.isEmpty)
                            _EmptyState(
                              icon: Icons.manage_accounts_rounded,
                              message:
                                  'No admins yet.\nTap + to create the first one.',
                            ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kCherry,
        icon: const Icon(Icons.person_add_rounded, color: _kWhite),
        label: Text(
          'Add Admin',
          style: GoogleFonts.poppins(
            color: _kWhite,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: () => _showCreateAdminDialog(),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
    color: _kCherry,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Super Admin',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: _kWhite.withValues(alpha: 0.75),
                ),
              ),
              Text(
                'Smart-Attend',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _kWhite,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_business_rounded, color: _kWhite),
          tooltip: 'Add Faculty',
          onPressed: () => _showAddFacultyDialog(),
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: _kWhite),
          tooltip: 'Logout',
          onPressed: _logout,
        ),
      ],
    ),
  );

  Widget _buildTotalsRow() => Row(
    children: [
      _TotalChip('${_totals.totalAdmins}', 'Admins', _kCherry, _kCherryBg),
      const SizedBox(width: 10),
      _TotalChip('${_totals.totalStudents}', 'Students', _kBlue, _kBlueBg),
      const SizedBox(width: 10),
      _TotalChip('${_totals.totalLecturers}', 'Lecturers', _kGreen, _kGreenBg),
    ],
  );

  Widget _buildAdminListHeader() => Row(
    children: [
      Text(
        'Department Admins',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _kText,
        ),
      ),
      const Spacer(),
      Text(
        '${_admins.length} total',
        style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
      ),
    ],
  );

  void _openDetail(DepartmentAdminModel admin) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AdminDetailScreen(adminId: admin.id, ctrl: _ctrl),
      ),
    );
  }

  Future<void> _toggleAdmin(DepartmentAdminModel admin, bool active) async {
    final err = await _ctrl.setAdminStatus(admin.id, active: active);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: _kCherry,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else {
      _load();
    }
  }

  // ── Create Admin Dialog ─────────────────────────────────────────
  void _showCreateAdminDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String? selectedDept;
    String? error;
    bool loading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Create Department Admin',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kCherryBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      error!,
                      style: GoogleFonts.poppins(fontSize: 12, color: _kCherry),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _DialogField(ctrl: nameCtrl, label: 'Full Name'),
                const SizedBox(height: 12),
                _DialogField(ctrl: emailCtrl, label: 'Email (@central.edu.gh)'),
                const SizedBox(height: 12),
                // Department dropdown (from DB faculties)
                DropdownButtonFormField<String>(
                  value: selectedDept,
                  isExpanded: true,
                  decoration: _inputDec('Department / Faculty'),
                  items: _faculties.isEmpty
                      ? [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('No faculties yet — add one first'),
                          ),
                        ]
                      : _faculties
                            .map(
                              (f) => DropdownMenuItem(
                                value: f.name,
                                child: Text(
                                  f.name,
                                  style: GoogleFonts.poppins(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                  onChanged: (v) => setD(() => selectedDept = v),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kBlueBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: _kBlue,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Default password: Central@123\n'
                          'Admin must change it on first login.',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _kBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: _kSubtext),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kCherry,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: loading
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty ||
                          emailCtrl.text.trim().isEmpty ||
                          selectedDept == null) {
                        setD(() => error = 'All fields are required.');
                        return;
                      }
                      setD(() {
                        loading = true;
                        error = null;
                      });
                      final result = await _ctrl.createAdmin(
                        fullName: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        department: selectedDept!,
                      );
                      if (!ctx.mounted) return;
                      if (result.error != null) {
                        setD(() {
                          loading = false;
                          error = result.error;
                        });
                      } else {
                        Navigator.pop(ctx);
                        _load();
                        // Show the default password in a snackbar
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Admin created. Default password: ${result.defaultPassword}',
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                              backgroundColor: _kGreen,
                              duration: const Duration(seconds: 8),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kWhite,
                      ),
                    )
                  : Text(
                      'Create',
                      style: GoogleFonts.poppins(
                        color: _kWhite,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add Faculty Dialog ──────────────────────────────────────────
  void _showAddFacultyDialog() {
    final nameCtrl = TextEditingController();
    String? error;
    bool loading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Add Faculty / School',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kCherryBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    error!,
                    style: GoogleFonts.poppins(fontSize: 12, color: _kCherry),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              _DialogField(
                ctrl: nameCtrl,
                label: 'Faculty name (e.g. School of Engineering & Technology)',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: _kSubtext),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kCherry,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: loading
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        setD(() => error = 'Faculty name is required.');
                        return;
                      }
                      setD(() {
                        loading = true;
                        error = null;
                      });
                      final err = await _ctrl.createFaculty(
                        nameCtrl.text.trim(),
                      );
                      if (!ctx.mounted) return;
                      if (err != null) {
                        setD(() {
                          loading = false;
                          error = err;
                        });
                      } else {
                        Navigator.pop(ctx);
                        _load();
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kWhite,
                      ),
                    )
                  : Text(
                      'Add',
                      style: GoogleFonts.poppins(
                        color: _kWhite,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  ADMIN DETAIL SCREEN
// ══════════════════════════════════════════════
class _AdminDetailScreen extends StatefulWidget {
  final String adminId;
  final SuperAdminController ctrl;
  const _AdminDetailScreen({required this.adminId, required this.ctrl});

  @override
  State<_AdminDetailScreen> createState() => _AdminDetailScreenState();
}

class _AdminDetailScreenState extends State<_AdminDetailScreen> {
  AdminDetailModel? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final detail = await widget.ctrl.fetchAdminDetail(widget.adminId);
    if (mounted)
      setState(() {
        _detail = detail;
        _loading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCherry,
        foregroundColor: _kWhite,
        elevation: 0,
        title: Text(
          d?.admin.department ?? 'Department Detail',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _kWhite,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kCherry))
          : d == null
          ? const Center(child: Text('Could not load details.'))
          : RefreshIndicator(
              color: _kCherry,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Admin info card ───────────────────────
                  _InfoCard(admin: d.admin),
                  const SizedBox(height: 20),

                  // ── Students by level ─────────────────────
                  _SectionHeader(
                    'Students by Level',
                    '${d.totalStudents} total',
                  ),
                  const SizedBox(height: 10),
                  if (d.studentsByLevel.isEmpty)
                    _EmptyState(
                      icon: Icons.school_outlined,
                      message: 'No students enrolled yet.',
                    )
                  else
                    _LevelGrid(levels: d.studentsByLevel),
                  const SizedBox(height: 24),

                  // ── Lecturers ─────────────────────────────
                  _SectionHeader('Lecturers', '${d.lecturers.length} assigned'),
                  const SizedBox(height: 10),
                  if (d.lecturers.isEmpty)
                    _EmptyState(
                      icon: Icons.person_outline_rounded,
                      message: 'No lecturers assigned yet.',
                    )
                  else
                    ...d.lecturers.map(
                      (l) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _LecturerRow(lecturer: l),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // ── Courses ───────────────────────────────
                  _SectionHeader('Courses', '${d.courses.length} in catalogue'),
                  const SizedBox(height: 10),
                  if (d.courses.isEmpty)
                    _EmptyState(
                      icon: Icons.menu_book_outlined,
                      message: 'No courses in the catalogue yet.',
                    )
                  else
                    ...d.courses.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CourseRow(course: c),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════════
//  SUPPORTING WIDGETS
// ══════════════════════════════════════════════

class _AdminCard extends StatelessWidget {
  final DepartmentAdminModel admin;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  const _AdminCard({
    required this.admin,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _kCherryBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    admin.initials,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kCherry,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      admin.fullName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                      ),
                    ),
                    Text(
                      admin.email,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: _kSubtext,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _kSubtext,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Department pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kCherryBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              admin.department,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kCherry,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Stats row
          Row(
            children: [
              _MiniStat(
                Icons.school_rounded,
                '${admin.students} students',
                _kBlue,
              ),
              const SizedBox(width: 16),
              _MiniStat(
                Icons.person_rounded,
                '${admin.lecturers} lecturers',
                _kGreen,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TotalChip extends StatelessWidget {
  final String value, label;
  final Color color, bg;
  const _TotalChip(this.value, this.label, this.color, this.bg);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color)),
        ],
      ),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniStat(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color)),
    ],
  );
}

class _InfoCard extends StatelessWidget {
  final DepartmentAdminModel admin;
  const _InfoCard({required this.admin});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kCherry,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          admin.fullName,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _kWhite,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          admin.department,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: _kWhite.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          admin.email,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: _kWhite.withValues(alpha: 0.7),
          ),
        ),
      ],
    ),
  );
}

class _LevelGrid extends StatelessWidget {
  final List<LevelCountModel> levels;
  const _LevelGrid({required this.levels});

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 4,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 1.2,
    children: levels
        .map(
          (l) => Container(
            decoration: BoxDecoration(
              color: _kBlueBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${l.count}',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kBlue,
                  ),
                ),
                Text(
                  'Lvl ${l.level}',
                  style: GoogleFonts.poppins(fontSize: 10, color: _kBlue),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );
}

class _LecturerRow extends StatelessWidget {
  final LecturerBriefModel lecturer;
  const _LecturerRow({required this.lecturer});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: _kGreenBg, shape: BoxShape.circle),
          child: Center(
            child: Text(
              lecturer.initials,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kGreen,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lecturer.fullName,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
              Text(
                lecturer.email,
                style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
              ),
            ],
          ),
        ),
        if (lecturer.staffId.isNotEmpty)
          Text(
            lecturer.staffId,
            style: GoogleFonts.poppins(fontSize: 11, color: _kSubtext),
          ),
      ],
    ),
  );
}

class _CourseRow extends StatelessWidget {
  final CourseDetailModel course;
  const _CourseRow({required this.course});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kWhite,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _kCherryBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            course.courseCode,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kCherry,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.courseName,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
              Text(
                'Level ${course.level} · ${course.assignedLecturerName}',
                style: GoogleFonts.poppins(fontSize: 10, color: _kSubtext),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _kBlueBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${course.enrolledStudents}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kBlue,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title, subtitle;
  const _SectionHeader(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _kText,
        ),
      ),
      const Spacer(),
      Text(
        subtitle,
        style: GoogleFonts.poppins(fontSize: 12, color: _kSubtext),
      ),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(30),
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: _kSubtext),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
        ),
      ],
    ),
  );
}

// ── Shared helpers ─────────────────────────────────────────────────
class _DialogField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  const _DialogField({required this.ctrl, required this.label});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    style: GoogleFonts.poppins(fontSize: 13),
    decoration: _inputDec(label),
  );
}

InputDecoration _inputDec(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
  filled: true,
  fillColor: _kBg,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _kCherry, width: 1.5),
  ),
);
