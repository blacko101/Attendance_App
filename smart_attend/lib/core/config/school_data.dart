// ─────────────────────────────────────────────────────────────────
//  school_data.dart
//  Single source of truth for Central University's faculties,
//  departments and programmes.  Import this wherever you need
//  the school structure — admin dialogs, dean login, etc.
// ─────────────────────────────────────────────────────────────────

class SchoolFaculty {
  final String name;
  final List<String> programmes;

  const SchoolFaculty({required this.name, required this.programmes});
}

// ── Ordered list of all faculties & their programmes ──────────────
const List<SchoolFaculty> kFaculties = [
  SchoolFaculty(
    name: 'School of Engineering & Technology',
    programmes: [
      'BSc Civil Engineering',
      'BSc Computer Science',
      'BSc Information Technology',
    ],
  ),
  SchoolFaculty(
    name: 'School of Architecture & Design',
    programmes: [
      'BSc Fashion Design',
      'BSc Interior Design',
      'BSc Landscape Design',
      'BSc Graphic Design',
      'BSc Real Estate',
      'BSc Architecture',
      'BSc Planning',
    ],
  ),
  SchoolFaculty(
    name: 'School of Nursing & Midwifery',
    programmes: ['BSc Nursing'],
  ),
  SchoolFaculty(
    name: 'Faculty of Arts & Social Sciences',
    programmes: [
      'BA Communication Studies',
      'BA Economics',
      'BA Development Studies',
      'BA Social Sciences',
      'BA Religious Studies',
    ],
  ),
  SchoolFaculty(
    name: 'Central Business School',
    programmes: [
      'BSc Accounting',
      'BSc Banking & Finance',
      'BSc Marketing',
      'BSc Human Resource Management',
      'BSc Business Administration',
    ],
  ),
  SchoolFaculty(
    name: 'School of Medical Sciences',
    programmes: ['MBChB (Medicine)', 'BSc Physician Assistantship'],
  ),
  SchoolFaculty(
    name: 'School of Pharmacy',
    programmes: ['Doctor of Pharmacy (PharmD)'],
  ),
  SchoolFaculty(
    name: 'Central Law School',
    programmes: ['LLB (Bachelor of Laws)'],
  ),
  SchoolFaculty(
    name: 'School of Graduate Studies & Research',
    programmes: [
      'MSc Accounting',
      'MPhil Accounting',
      'MA Religious Studies',
      'MPhil Theology',
      'MBA Finance',
      'MBA General Management',
      'MBA Human Resource Management',
      'MBA Marketing',
      'MBA Project Management',
      'MBA Agribusiness',
      'MPhil Economics',
      'Master of Public Health',
      'MA Development Policy',
      'MPhil Development Policy',
      'PhD Finance',
      'DBA (Doctor of Business Administration)',
    ],
  ),
  SchoolFaculty(
    name: 'Centre for Distance & Professional Education',
    programmes: [
      'Distance Business Programs',
      'Distance Theology Programs',
      'Professional / Diploma Programs (ATHE)',
    ],
  ),
];

// ── Flat list of all faculty names (for dropdowns) ─────────────────
List<String> get kFacultyNames => kFaculties.map((f) => f.name).toList();

// ── All programmes across all faculties ────────────────────────────
List<String> get kAllProgrammes =>
    kFaculties.expand((f) => f.programmes).toList();

// ── Look up which faculty a programme belongs to ───────────────────
String facultyForProgramme(String programme) {
  for (final f in kFaculties) {
    if (f.programmes.contains(programme)) return f.name;
  }
  return '';
}

// ── Get all programmes for a given faculty name ────────────────────
List<String> programmesForFaculty(String facultyName) {
  final match = kFaculties.where((f) => f.name == facultyName);
  if (match.isEmpty) return [];
  return match.first.programmes;
}
