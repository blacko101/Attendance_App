import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_attend/core/theme/app_colors.dart';
import 'package:smart_attend/features/student/controllers/calendar_controller.dart';
import 'package:smart_attend/features/student/models/attendance_model.dart';

// Brand-fixed backgrounds for stat chips — these don't change with theme
const _kGreenBg  = Color(0xFFE8F5E9);
const _kBlueBg   = Color(0xFFE3F2FD);
const _kBlue     = Color(0xFF2196F3);

class CalendarScreen extends StatefulWidget {
  static String id = 'calendar_screen';
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {

  final _controller = CalendarController();
  late TabController _tabController;

  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay  = DateTime.now();
  bool     _loading      = true;

  Map<String, DayAttendanceModel> _attendanceData = {};

  DateTime get _weekStart {
    final now = _selectedDay;
    return now.subtract(Duration(days: now.weekday - 1));
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final data = await _controller.fetchMonthAttendance(
      'student_001',
      _focusedMonth.month,
      _focusedMonth.year,
    );
    if (mounted) setState(() { _attendanceData = data; _loading = false; });
  }

  DayAttendanceModel? _dayData(DateTime d) =>
      _attendanceData[_controller.keyFromDate(d)];

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildToggleTabs(),
          const SizedBox(height: 12),
          if (!_loading) _buildStatsRow(),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(
                color: AppColors.cherry))
                : TabBarView(
              controller: _tabController,
              children: [
                _buildMonthView(),
                _buildWeekView(),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Schedule',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text(context))),
          Row(children: [
            _NeumorphicBtn(icon: Icons.chevron_left_rounded,  onTap: _prevMonth),
            const SizedBox(width: 8),
            Text(
              '${months[_focusedMonth.month - 1]} ${_focusedMonth.year}',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(context)),
            ),
            const SizedBox(width: 8),
            _NeumorphicBtn(icon: Icons.chevron_right_rounded, onTap: _nextMonth),
          ]),
        ],
      ),
    );
  }

  // ── TOGGLE TABS ───────────────────────────────────────────────────────────
  Widget _buildToggleTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.cardAlt(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppColors.cherry,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.subtext(context),
          labelStyle: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
          tabs: const [
            Tab(text: 'Monthly'),
            Tab(text: 'Weekly'),
          ],
        ),
      ),
    );
  }

  // ── STATS ROW ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final present = _controller.countPresent(_attendanceData);
    final absent  = _controller.countAbsent(_attendanceData);
    final total   = present + absent;
    final rate    = total == 0 ? 0 : ((present / total) * 100).toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        _StatChip(label: 'Present', value: '$present',
            color: AppColors.green,  bg: _kGreenBg),
        const SizedBox(width: 10),
        _StatChip(label: 'Absent',  value: '$absent',
            color: AppColors.cherry, bg: AppColors.cherryBg),
        const SizedBox(width: 10),
        _StatChip(label: 'Rate',    value: '$rate%',
            color: _kBlue,           bg: _kBlueBg),
      ]),
    );
  }

  // ── MONTHLY VIEW ──────────────────────────────────────────────────────────
  Widget _buildMonthView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        const SizedBox(height: 8),
        _buildDayLabels(),
        const SizedBox(height: 8),
        _buildMonthGrid(),
        const SizedBox(height: 16),
        _buildDayDetail(),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildDayLabels() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: days.map((d) => Expanded(
        child: Center(
          child: Text(d,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: d == 'Sun' || d == 'Sat'
                    ? AppColors.subtext(context)
                    : AppColors.subtext(context),
              )),
        ),
      )).toList(),
    );
  }

  Widget _buildMonthGrid() {
    final firstDay    = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final offset      = firstDay.weekday - 1;
    final totalCells  = offset + daysInMonth;
    final rows        = (totalCells / 7).ceil();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardAlt(context),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final cellIndex  = row * 7 + col;
              final dayNum     = cellIndex - offset + 1;

              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox(height: 44));
              }

              final date       = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
              final dayData    = _dayData(date);
              final isToday    = _isSameDay(date, DateTime.now());
              final isSelected = _isSameDay(date, _selectedDay);

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = date),
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.cherry
                          : isToday
                          ? AppColors.cherryBg
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$dayNum',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: isToday || isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? Colors.white
                                  : isToday
                                  ? AppColors.cherry
                                  : AppColors.text(context),
                            )),
                        if (dayData != null && dayData.hasClasses)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : dayData.dayColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  // ── WEEKLY VIEW ───────────────────────────────────────────────────────────
  Widget _buildWeekView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        const SizedBox(height: 8),
        _buildWeekStrip(),
        const SizedBox(height: 16),
        _buildDayDetail(),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildWeekStrip() {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardAlt(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(7, (i) {
          final date       = _weekStart.add(Duration(days: i));
          final dayData    = _dayData(date);
          final isToday    = _isSameDay(date, DateTime.now());
          final isSelected = _isSameDay(date, _selectedDay);

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDay = date),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.cherry
                      : isToday
                      ? AppColors.cherryBg
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Text(dayNames[i],
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isSelected
                            ? Colors.white
                            : AppColors.subtext(context),
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 6),
                  Text('${date.day}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : isToday
                            ? AppColors.cherry
                            : AppColors.text(context),
                      )),
                  const SizedBox(height: 4),
                  if (dayData != null && dayData.hasClasses)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : dayData.dayColor,
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(height: 5),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── DAY DETAIL ────────────────────────────────────────────────────────────
  Widget _buildDayDetail() {
    final dayData = _dayData(_selectedDay);
    const months  = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    const days    = ['Monday','Tuesday','Wednesday','Thursday',
      'Friday','Saturday','Sunday'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardAlt(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cherryBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${days[_selectedDay.weekday - 1]}, '
                  '${_selectedDay.day} '
                  '${months[_selectedDay.month - 1]}',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.cherry),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        if (dayData == null || !dayData.hasClasses)
          _EmptyDay()
        else
          ...dayData.sessions.map((s) => _SessionCard(session: s)),
      ]),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────
//  SESSION CARD
// ─────────────────────────────────────────────
class _SessionCard extends StatelessWidget {
  final ClassSessionModel session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: session.statusColor, width: 4),
        ),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(session.courseCode,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context))),
            const SizedBox(height: 2),
            Text(session.courseName,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.subtext(context))),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.schedule_rounded,
                  size: 12, color: AppColors.subtext(context)),
              const SizedBox(width: 4),
              Text(session.formattedTime,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.subtext(context))),
              const SizedBox(width: 10),
              Icon(Icons.location_on_rounded,
                  size: 12, color: AppColors.subtext(context)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(session.room,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.subtext(context))),
              ),
            ]),
            if (session.absenceReason != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.info_outline_rounded,
                    size: 12, color: AppColors.cherry),
                const SizedBox(width: 4),
                Text(session.absenceReason!,
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.cherry,
                        fontStyle: FontStyle.italic)),
              ]),
            ],
          ]),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: session.statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(session.statusIcon, size: 12, color: session.statusColor),
            const SizedBox(width: 4),
            Text(session.statusLabel,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: session.statusColor)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  EMPTY DAY
// ─────────────────────────────────────────────
class _EmptyDay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(children: [
        Icon(Icons.event_available_rounded,
            color: AppColors.subtext(context), size: 40),
        const SizedBox(height: 8),
        Text('No classes this day',
            style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.subtext(context),
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  NEUMORPHIC BUTTON
// ─────────────────────────────────────────────
class _NeumorphicBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  const _NeumorphicBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.bg(context),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.85),
                offset: const Offset(-2, -2),
                blurRadius: 4),
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.10),
                offset: const Offset(2, 2),
                blurRadius: 4),
          ],
        ),
        child: Icon(icon,
            color: AppColors.subtext(context), size: 18),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  STAT CHIP
// ─────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label, value;
  final Color  color, bg;
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color)),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11,
                color: color.withValues(alpha: 0.7))),
      ]),
    ),
  );
}