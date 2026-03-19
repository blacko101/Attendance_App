import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_attend/features/auth/views/mobile/change_password_screen.dart';
import 'package:smart_attend/features/dean/controllers/dean_controller.dart';
import 'package:smart_attend/features/dean/models/dean_model.dart';
import 'package:smart_attend/features/dean/views/dean_dashboard.dart';

const _kCherry = Color(0xFF9B1B42);
const _kBg = Color(0xFFEEEEF3);
const _kWhite = Color(0xFFFFFFFF);
const _kText = Color(0xFF1A1A1A);
const _kSubtext = Color(0xFF888888);

class DeanAccessScreen extends StatefulWidget {
  static String id = '/dean';
  const DeanAccessScreen({super.key});

  @override
  State<DeanAccessScreen> createState() => _DeanAccessScreenState();
}

class _DeanAccessScreenState extends State<DeanAccessScreen> {
  final _ctrl = DeanController();
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();

  List<DepartmentModel> _departments = [];
  DepartmentModel? _selectedDept;
  bool _loadingDepts = true;
  bool _isObscure = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final depts = await _ctrl.fetchDepartments();
      if (mounted) {
        setState(() {
          _departments = depts;
          _loadingDepts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDepts = false);
    }
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMsg = null);

    if (_selectedDept == null) {
      setState(() => _errorMsg = 'Please select your department.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final dean = await _ctrl.deanLogin(
        department: _selectedDept!,
        password: _passwordCtrl.text,
      );
      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        DeanDashboard.id,
        arguments: dean,
      );
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().replaceFirst('Exception: ', '');

      if (msg == '__MUST_CHANGE_PASSWORD__') {
        Navigator.pushReplacementNamed(
          context,
          ChangePasswordScreen.id,
          arguments: DeanDashboard.id,
        );
        return;
      }

      setState(() => _errorMsg = msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Scaffold(
      backgroundColor: _kBg,
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            color: _kCherry,
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _kWhite.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: _kWhite,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'SmartAttend',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _kWhite,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),

                Text(
                  'Department\nDean Portal',
                  style: GoogleFonts.poppins(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: _kWhite,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Secure access for department heads.\n'
                  'Monitor attendance, track performance,\n'
                  'and gain insights across your department.',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: _kWhite.withValues(alpha: 0.8),
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 48),

                ...[
                  ('📊', 'Department-wide analytics'),
                  ('🎓', 'Student attendance monitoring'),
                  ('👨‍🏫', 'Lecturer performance tracking'),
                  ('📋', 'Class holding rate overview'),
                ].map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Text(item.$1, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Text(
                          item.$2,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _kWhite.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          flex: 3,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _buildForm(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: _kCherry,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 32,
              bottom: 36,
              left: 24,
              right: 24,
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _kWhite.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: _kWhite,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'SmartAttend',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _kWhite,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Department Dean Portal',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _kWhite.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(24), child: _buildForm()),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dean Login',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select your department and enter your password',
            style: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
          ),
          const SizedBox(height: 32),

          // ── Department dropdown ───────────────────────────────
          Text(
            'Department',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
          const SizedBox(height: 8),

          if (_loadingDepts)
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: _kWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kCherry,
                  ),
                ),
              ),
            )
          else if (_departments.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kCherry.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: _kCherry,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No departments found. '
                      'Ask your admin to create department accounts.',
                      style: GoogleFonts.poppins(fontSize: 12, color: _kCherry),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: _kWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedDept == null && _errorMsg != null
                      ? Colors.red
                      : Colors.transparent,
                ),
              ),
              child: DropdownButtonFormField<DepartmentModel>(
                // FIX: `value` not `initialValue` — prevents compile error
                // and ensures the selected item renders correctly
                value: _selectedDept,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _kSubtext,
                ),
                // FIX overflow: set menuMaxHeight so the popup doesn't
                // overflow small screens when all 10 departments are shown
                menuMaxHeight: 320,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.account_balance_rounded,
                    color: _kCherry,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 4,
                  ),
                  hintText: 'Select your department',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: _kSubtext,
                  ),
                ),
                style: GoogleFonts.poppins(fontSize: 13, color: _kText),
                // FIX overflow: each item is a single line — no Column
                // with two Text widgets that overflow the popup item height
                items: _departments
                    .map(
                      (dept) => DropdownMenuItem<DepartmentModel>(
                        value: dept,
                        child: Text(
                          dept.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _kText,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (dept) {
                  setState(() {
                    _selectedDept = dept;
                    _errorMsg = null;
                  });
                },
              ),
            ),

          const SizedBox(height: 20),

          // ── Password ──────────────────────────────────────────
          Text(
            'Password',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            obscureText: _isObscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter your password';
              if (v.length < 8) return 'Password must be at least 8 characters';
              return null;
            },
            style: GoogleFonts.poppins(fontSize: 14, color: _kText),
            decoration: InputDecoration(
              filled: true,
              fillColor: _kWhite,
              hintText: 'Enter your password',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: _kSubtext),
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                color: _kCherry,
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isObscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _kSubtext,
                  size: 20,
                ),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kCherry, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1.2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          // ── Error message ─────────────────────────────────────
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kCherry.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: _kCherry,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: GoogleFonts.poppins(fontSize: 12, color: _kCherry),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // ── Submit ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kCherry,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _kWhite,
                      ),
                    )
                  : Text(
                      'Access Dashboard',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kWhite,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              'This portal is only accessible via the dean link.\n'
              'Contact IT if you need the URL.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: _kSubtext.withValues(alpha: 0.6),
              ),
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
