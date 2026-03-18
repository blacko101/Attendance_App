/**
 * seed.js — Smart-Attend database seeder
 *
 * ─────────────────────────────────────────────────────────────────
 *  USAGE
 * ─────────────────────────────────────────────────────────────────
 *  node seed.js               — seed (safe — skips existing records)
 *  node seed.js --wipe        — drop all collections first, then seed
 *  node seed.js --wipe-only   — drop only, no seeding
 *
 * ─────────────────────────────────────────────────────────────────
 *  DEFAULT PASSWORD  (all seeded users)
 * ─────────────────────────────────────────────────────────────────
 *  Central@123
 *  Every account has mustChangePassword: true so the user is forced
 *  to set a personal password on first login.
 *
 * ─────────────────────────────────────────────────────────────────
 *  COLLECTIONS SEEDED
 * ─────────────────────────────────────────────────────────────────
 *  users               — admin, deans (one per faculty), lecturers, students
 *  courses             — course catalogue with lecturer assignment
 *  timetable           — weekly schedule slots per course
 *  semesters           — academic calendar entries
 *  attendancesessions  — past & live attendance windows
 *  attendances         — student check-in records
 *
 * ⚠️  Never run --wipe against a production database.
 */

"use strict";

require("dotenv").config();

const mongoose = require("mongoose");
const bcrypt   = require("bcryptjs");
const crypto   = require("crypto");

// ══════════════════════════════════════════════════════════════════
//  MODELS
// ══════════════════════════════════════════════════════════════════

const User              = require("./src/models/User");
const AttendanceSession = require("./src/models/AttendanceSession");
const Attendance        = require("./src/models/Attendance");

// ── Course ────────────────────────────────────────────────────────
const courseSchema = new mongoose.Schema({
  courseCode:           { type: String, required: true, unique: true, trim: true },
  courseName:           { type: String, required: true, trim: true },
  department:           { type: String, required: true, trim: true },  // faculty name
  faculty:              { type: String, trim: true },
  creditHours:          { type: Number, default: 3 },
  semester:             { type: String, required: true },
  assignedLecturerId:   { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
  assignedLecturerName: { type: String, default: null },
  enrolledStudents:     { type: Number, default: 0 },
}, { timestamps: true });

const Course = mongoose.models.Course || mongoose.model("Course", courseSchema);

// ── Timetable ─────────────────────────────────────────────────────
const timetableSchema = new mongoose.Schema({
  courseId:     { type: mongoose.Schema.Types.ObjectId, ref: "Course", required: true },
  courseCode:   { type: String, required: true, trim: true },
  courseName:   { type: String, required: true, trim: true },
  lecturerId:   { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
  lecturerName: { type: String, default: "" },
  day:          { type: String, enum: ["Mon","Tue","Wed","Thu","Fri","Sat"], required: true },
  startTime:    { type: String, required: true },
  endTime:      { type: String, required: true },
  room:         { type: String, default: "" },
  level:        { type: String, default: "" },
  programme:    { type: String, default: "" },
  semester:     { type: String, required: true },
}, { timestamps: true });

const Timetable = mongoose.models.Timetable || mongoose.model("Timetable", timetableSchema);

// ── Semester ──────────────────────────────────────────────────────
const semesterSchema = new mongoose.Schema({
  name:          { type: String, required: true, unique: true, trim: true },
  startDate:     { type: Date,   required: true },
  endDate:       { type: Date,   required: true },
  teachingWeeks: { type: Number, required: true },
  isCurrent:     { type: Boolean, default: false },
}, { timestamps: true });

const Semester = mongoose.models.Semester || mongoose.model("Semester", semesterSchema);

// ══════════════════════════════════════════════════════════════════
//  CLI FLAGS
// ══════════════════════════════════════════════════════════════════
const args      = process.argv.slice(2);
const WIPE      = args.includes("--wipe") || args.includes("--wipe-only");
const WIPE_ONLY = args.includes("--wipe-only");

// ══════════════════════════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════════════════════════
const DEFAULT_PASSWORD = "Central@123";
const hash = (pw) => bcrypt.hash(pw, 10);

function hmac(sessionId, courseCode, expiresAtMs) {
  const secret = process.env.QR_SECRET || "smart_attend_qr_secret";
  return crypto
    .createHmac("sha256", secret)
    .update(`${sessionId}:${courseCode}:${expiresAtMs}`)
    .digest("hex");
}

function nearbyCoord(base, maxDeg = 0.0005) {
  return base + (Math.random() * 2 - 1) * maxDeg;
}

// ══════════════════════════════════════════════════════════════════
//  SCHOOL STRUCTURE
//  Mirrors school_data.dart exactly — single source of truth.
// ══════════════════════════════════════════════════════════════════

// programme → faculty lookup
const PROGRAMME_TO_FACULTY = {
  // School of Engineering & Technology
  "BSc Computer Science":          "School of Engineering & Technology",
  "BSc Information Technology":    "School of Engineering & Technology",
  "BSc Civil Engineering":         "School of Engineering & Technology",
  // School of Architecture & Design
  "BSc Fashion Design":            "School of Architecture & Design",
  "BSc Interior Design":           "School of Architecture & Design",
  "BSc Landscape Design":          "School of Architecture & Design",
  "BSc Graphic Design":            "School of Architecture & Design",
  "BSc Real Estate":               "School of Architecture & Design",
  // School of Nursing & Midwifery
  "BSc Nursing":                   "School of Nursing & Midwifery",
  // Faculty of Arts & Social Sciences
  "BA Communication Studies":      "Faculty of Arts & Social Sciences",
  "BA Economics":                  "Faculty of Arts & Social Sciences",
  "BA Development Studies":        "Faculty of Arts & Social Sciences",
  "BA Social Sciences":            "Faculty of Arts & Social Sciences",
  "BA Religious Studies":          "Faculty of Arts & Social Sciences",
  // Central Business School
  "BSc Accounting":                "Central Business School",
  "BSc Banking & Finance":         "Central Business School",
  "BSc Marketing":                 "Central Business School",
  "BSc Human Resource Management": "Central Business School",
  "BSc Business Administration":   "Central Business School",
  // School of Medical Sciences
  "MBChB (Medicine)":              "School of Medical Sciences",
  "BSc Physician Assistantship":   "School of Medical Sciences",
  // School of Pharmacy
  "Doctor of Pharmacy (PharmD)":   "School of Pharmacy",
  // Central Law School
  "LLB (Bachelor of Laws)":        "Central Law School",
  // School of Graduate Studies & Research
  "MSc Accounting":                "School of Graduate Studies & Research",
  "MPhil Accounting":              "School of Graduate Studies & Research",
  "MA Religious Studies":          "School of Graduate Studies & Research",
  "MPhil Theology":                "School of Graduate Studies & Research",
  "MBA Finance":                   "School of Graduate Studies & Research",
  "MBA General Management":        "School of Graduate Studies & Research",
  "MBA Human Resource Management": "School of Graduate Studies & Research",
  "MBA Marketing":                 "School of Graduate Studies & Research",
  "MBA Project Management":        "School of Graduate Studies & Research",
  "MBA Agribusiness":              "School of Graduate Studies & Research",
  "MPhil Economics":               "School of Graduate Studies & Research",
  "Master of Public Health":       "School of Graduate Studies & Research",
  "MA Development Policy":         "School of Graduate Studies & Research",
  "MPhil Development Policy":      "School of Graduate Studies & Research",
  "PhD Finance":                   "School of Graduate Studies & Research",
  "DBA (Doctor of Business Administration)": "School of Graduate Studies & Research",
  // Centre for Distance & Professional Education
  "Distance Business Programs":             "Centre for Distance & Professional Education",
  "Distance Theology Programs":             "Centre for Distance & Professional Education",
  "Professional / Diploma Programs (ATHE)": "Centre for Distance & Professional Education",
};

// ══════════════════════════════════════════════════════════════════
//  SEED DATA
// ══════════════════════════════════════════════════════════════════

const LAT = 5.7172;
const LNG = -0.0747;
const CURRENT_SEMESTER = "2025/2026 Semester 2";

// ── Semesters ─────────────────────────────────────────────────────
const SEMESTERS = [
  { name: "2025/2026 Semester 2", startDate: new Date("2026-01-13"), endDate: new Date("2026-05-23"), teachingWeeks: 15, isCurrent: true  },
  { name: "2025/2026 Semester 1", startDate: new Date("2025-08-25"), endDate: new Date("2025-12-20"), teachingWeeks: 15, isCurrent: false },
  { name: "2024/2025 Semester 2", startDate: new Date("2025-01-13"), endDate: new Date("2025-05-23"), teachingWeeks: 15, isCurrent: false },
];

// ── Admin ─────────────────────────────────────────────────────────
const ADMIN = {
  fullName:           "System Administrator",
  email:              "admin@central.edu.gh",
  role:               "admin",
  staffId:            "STF/ADMIN/001",
  department:         "IT Services",
  departments:        ["IT Services"],
  faculty:            "IT Services",
  isActive:           true,
  mustChangePassword: true,
};

// ── Deans — one per faculty ───────────────────────────────────────
// Email prefix: dean.<short-code>@central.edu.gh
// These match the _seededDepartments() list in dean_controller.dart
const DEANS = [
  {
    fullName:           "Prof. Emmanuel Darko",
    email:              "dean.set@central.edu.gh",
    staffId:            "STF/DEAN/001",
    faculty:            "School of Engineering & Technology",
    department:         "School of Engineering & Technology",
    departments:        ["School of Engineering & Technology"],
  },
  {
    fullName:           "Prof. Grace Osei",
    email:              "dean.sad@central.edu.gh",
    staffId:            "STF/DEAN/002",
    faculty:            "School of Architecture & Design",
    department:         "School of Architecture & Design",
    departments:        ["School of Architecture & Design"],
  },
  {
    fullName:           "Prof. Ama Fordjour",
    email:              "dean.snm@central.edu.gh",
    staffId:            "STF/DEAN/003",
    faculty:            "School of Nursing & Midwifery",
    department:         "School of Nursing & Midwifery",
    departments:        ["School of Nursing & Midwifery"],
  },
  {
    fullName:           "Prof. Kofi Antwi",
    email:              "dean.fass@central.edu.gh",
    staffId:            "STF/DEAN/004",
    faculty:            "Faculty of Arts & Social Sciences",
    department:         "Faculty of Arts & Social Sciences",
    departments:        ["Faculty of Arts & Social Sciences"],
  },
  {
    fullName:           "Prof. Akua Boateng",
    email:              "dean.cbs@central.edu.gh",
    staffId:            "STF/DEAN/005",
    faculty:            "Central Business School",
    department:         "Central Business School",
    departments:        ["Central Business School"],
  },
  {
    fullName:           "Prof. Samuel Nyarko",
    email:              "dean.sms@central.edu.gh",
    staffId:            "STF/DEAN/006",
    faculty:            "School of Medical Sciences",
    department:         "School of Medical Sciences",
    departments:        ["School of Medical Sciences"],
  },
  {
    fullName:           "Prof. Adwoa Asante",
    email:              "dean.sop@central.edu.gh",
    staffId:            "STF/DEAN/007",
    faculty:            "School of Pharmacy",
    department:         "School of Pharmacy",
    departments:        ["School of Pharmacy"],
  },
  {
    fullName:           "Prof. Nana Kusi",
    email:              "dean.law@central.edu.gh",
    staffId:            "STF/DEAN/008",
    faculty:            "Central Law School",
    department:         "Central Law School",
    departments:        ["Central Law School"],
  },
  {
    fullName:           "Prof. Yaw Mensah",
    email:              "dean.sgsr@central.edu.gh",
    staffId:            "STF/DEAN/009",
    faculty:            "School of Graduate Studies & Research",
    department:         "School of Graduate Studies & Research",
    departments:        ["School of Graduate Studies & Research"],
  },
  {
    fullName:           "Prof. Efua Quaye",
    email:              "dean.cdpe@central.edu.gh",
    staffId:            "STF/DEAN/010",
    faculty:            "Centre for Distance & Professional Education",
    department:         "Centre for Distance & Professional Education",
    departments:        ["Centre for Distance & Professional Education"],
  },
];

// ── Lecturers ─────────────────────────────────────────────────────
// departments[] is the authoritative multi-department list.
// A lecturer whose courses span two faculties lists both.
const LECTURERS = [
  {
    fullName:    "Dr. Kwame Asante",
    email:       "kwame.asante@central.edu.gh",
    staffId:     "STF/2018/0012",
    faculty:     "School of Engineering & Technology",
    department:  "School of Engineering & Technology",
    departments: ["School of Engineering & Technology"],
    isActive:    true,
    mustChangePassword: true,
    teaches:     ["CS301", "CS201", "CS401"],
  },
  {
    fullName:    "Dr. Abena Mensah",
    email:       "abena.mensah@central.edu.gh",
    staffId:     "STF/2019/0034",
    // Teaches Maths — assigned to both SET and CBS (cross-faculty)
    faculty:     "School of Engineering & Technology",
    department:  "School of Engineering & Technology",
    departments: ["School of Engineering & Technology", "Central Business School"],
    isActive:    true,
    mustChangePassword: true,
    teaches:     ["MATH201", "MATH301"],
  },
  {
    fullName:    "Mr. Kofi Owusu",
    email:       "kofi.owusu@central.edu.gh",
    staffId:     "STF/2020/0056",
    faculty:     "School of Engineering & Technology",
    department:  "School of Engineering & Technology",
    departments: ["School of Engineering & Technology"],
    isActive:    true,
    mustChangePassword: true,
    teaches:     ["CS101", "CS202"],
  },
  {
    fullName:    "Dr. Esi Ankomah",
    email:       "esi.ankomah@central.edu.gh",
    staffId:     "STF/2017/0021",
    faculty:     "Central Business School",
    department:  "Central Business School",
    departments: ["Central Business School"],
    isActive:    true,
    mustChangePassword: true,
    teaches:     ["ACC201", "ACC301"],
  },
  {
    fullName:    "Mr. Nii Armah",
    email:       "nii.armah@central.edu.gh",
    staffId:     "STF/2021/0078",
    faculty:     "Faculty of Arts & Social Sciences",
    department:  "Faculty of Arts & Social Sciences",
    departments: ["Faculty of Arts & Social Sciences"],
    isActive:    true,
    mustChangePassword: true,
    teaches:     ["COMM201", "ECON201"],
  },
];

// ── Students ──────────────────────────────────────────────────────
// faculty is auto-derived from programme via PROGRAMME_TO_FACULTY.
const STUDENTS = [
  {
    fullName:    "Ama Boateng",
    email:       "ama.boateng@central.edu.gh",
    indexNumber: "CU/CS/2022/001",
    programme:   "BSc Computer Science",
    level:       "300",
    isActive:    true,
    mustChangePassword: true,
    enrolledIn:  ["CS301", "CS201", "CS401", "MATH201"],
  },
  {
    fullName:    "Yaw Darko",
    email:       "yaw.darko@central.edu.gh",
    indexNumber: "CU/CS/2022/002",
    programme:   "BSc Computer Science",
    level:       "300",
    isActive:    true,
    mustChangePassword: true,
    enrolledIn:  ["CS301", "CS201", "CS401", "MATH201"],
  },
  {
    fullName:    "Efua Asante",
    email:       "efua.asante@central.edu.gh",
    indexNumber: "CU/CS/2022/003",
    programme:   "BSc Computer Science",
    level:       "300",
    isActive:    true,
    mustChangePassword: true,
    enrolledIn:  ["CS301", "CS201", "CS401"],
  },
  {
    fullName:    "Kweku Frimpong",
    email:       "kweku.frimpong@central.edu.gh",
    indexNumber: "CU/CS/2022/004",
    programme:   "BSc Computer Science",
    level:       "300",
    isActive:    true,
    mustChangePassword: true,
    enrolledIn:  ["CS301", "CS201", "MATH201"],
  },
  {
    fullName:    "Akosua Nkrumah",
    email:       "akosua.nkrumah@central.edu.gh",
    indexNumber: "CU/CS/2023/001",
    programme:   "BSc Computer Science",
    level:       "200",
    isActive:    true,
    mustChangePassword: true,
    enrolledIn:  ["CS101", "CS202", "MATH201"],
  },
  {
    fullName:    "Kobina Aidoo",
    email:       "kobina.aidoo@central.edu.gh",
    indexNumber: "CU/CS/2022/005",
    programme:   "BSc Computer Science",
    level:       "300",
    isActive:    false,        // SUSPENDED — tests auth guard
    mustChangePassword: true,
    enrolledIn:  ["CS301", "CS201"],
  },
  {
    fullName:    "Nana Esi Appiah",
    email:       "nana.appiah@central.edu.gh",
    indexNumber: "CU/CS/2023/002",
    programme:   "BSc Computer Science",
    level:       "200",
    isActive:    true,
    mustChangePassword: true,
    enrolledIn:  ["CS101", "CS202"],
  },
  {
    fullName:    "Ato Quaye",
    email:       "ato.quaye@central.edu.gh",
    indexNumber: "CU/IT/2022/001",
    programme:   "BSc Information Technology",
    level:       "300",
    isActive:    true,
    mustChangePassword: true,
    enrolledIn:  ["CS301", "CS202", "MATH201"],
  },
  // Central Business School students
  {
    fullName:    "Adwoa Poku",
    email:       "adwoa.poku@central.edu.gh",
    indexNumber: "CU/ACC/2022/001",
    programme:   "BSc Accounting",
    level:       "300",
    isActive:    true,
    mustChangePassword: true,
    enrolledIn:  ["ACC201", "ACC301", "MATH201"],
  },
  {
    fullName:    "Fiifi Mensah",
    email:       "fiifi.mensah@central.edu.gh",
    indexNumber: "CU/ACC/2022/002",
    programme:   "BSc Accounting",
    level:       "300",
    isActive:    true,
    mustChangePassword: true,
    enrolledIn:  ["ACC201", "ACC301"],
  },
  // Faculty of Arts & Social Sciences students
  {
    fullName:    "Akua Owusu",
    email:       "akua.owusu@central.edu.gh",
    indexNumber: "CU/COMM/2022/001",
    programme:   "BA Communication Studies",
    level:       "200",
    isActive:    true,
    mustChangePassword: true,
    enrolledIn:  ["COMM201", "ECON201"],
  },
];

// ── Courses ───────────────────────────────────────────────────────
// department = faculty name (mirrors the Flutter model).
const COURSES = [
  // School of Engineering & Technology ─────────────────────────
  {
    courseCode:  "CS101",
    courseName:  "Introduction to Programming",
    faculty:     "School of Engineering & Technology",
    creditHours: 3, level: "100", programme: "BSc Computer Science",
  },
  {
    courseCode:  "CS201",
    courseName:  "Object Oriented Programming",
    faculty:     "School of Engineering & Technology",
    creditHours: 3, level: "200", programme: "BSc Computer Science",
  },
  {
    courseCode:  "CS202",
    courseName:  "Database Systems",
    faculty:     "School of Engineering & Technology",
    creditHours: 3, level: "200", programme: "BSc Computer Science",
  },
  {
    courseCode:  "CS301",
    courseName:  "Data Structures & Algorithms",
    faculty:     "School of Engineering & Technology",
    creditHours: 3, level: "300", programme: "BSc Computer Science",
  },
  {
    courseCode:  "CS401",
    courseName:  "Software Engineering",
    faculty:     "School of Engineering & Technology",
    creditHours: 3, level: "400", programme: "BSc Computer Science",
  },
  {
    courseCode:  "MATH201",
    courseName:  "Linear Algebra",
    faculty:     "School of Engineering & Technology",
    creditHours: 3, level: "200", programme: "BSc Computer Science",
  },
  {
    courseCode:  "MATH301",
    courseName:  "Numerical Methods",
    faculty:     "School of Engineering & Technology",
    creditHours: 3, level: "300", programme: "BSc Computer Science",
  },
  // Central Business School ────────────────────────────────────
  {
    courseCode:  "ACC201",
    courseName:  "Intermediate Accounting",
    faculty:     "Central Business School",
    creditHours: 3, level: "200", programme: "BSc Accounting",
  },
  {
    courseCode:  "ACC301",
    courseName:  "Advanced Financial Accounting",
    faculty:     "Central Business School",
    creditHours: 3, level: "300", programme: "BSc Accounting",
  },
  // Faculty of Arts & Social Sciences ─────────────────────────
  {
    courseCode:  "COMM201",
    courseName:  "Media & Communication Theory",
    faculty:     "Faculty of Arts & Social Sciences",
    creditHours: 3, level: "200", programme: "BA Communication Studies",
  },
  {
    courseCode:  "ECON201",
    courseName:  "Microeconomics",
    faculty:     "Faculty of Arts & Social Sciences",
    creditHours: 3, level: "200", programme: "BA Economics",
  },
];

// ── Timetable slots ───────────────────────────────────────────────
const TIMETABLE_SLOTS = [
  // School of Engineering & Technology
  { courseCode: "CS101",  day: "Mon", startTime: "8:00 AM",  endTime: "9:30 AM",  room: "ICT Block - LH 1" },
  { courseCode: "CS101",  day: "Wed", startTime: "8:00 AM",  endTime: "9:30 AM",  room: "ICT Block - LH 1" },
  { courseCode: "CS201",  day: "Mon", startTime: "10:00 AM", endTime: "11:30 AM", room: "ICT Block - Room 3" },
  { courseCode: "CS201",  day: "Wed", startTime: "10:00 AM", endTime: "11:30 AM", room: "ICT Block - Room 3" },
  { courseCode: "CS202",  day: "Tue", startTime: "12:00 PM", endTime: "1:30 PM",  room: "ICT Block - Lab 2" },
  { courseCode: "CS202",  day: "Thu", startTime: "12:00 PM", endTime: "1:30 PM",  room: "ICT Block - Lab 2" },
  { courseCode: "CS301",  day: "Tue", startTime: "10:00 AM", endTime: "11:30 AM", room: "ICT Block - Lab 1" },
  { courseCode: "CS301",  day: "Fri", startTime: "10:00 AM", endTime: "11:30 AM", room: "ICT Block - Lab 1" },
  { courseCode: "CS401",  day: "Wed", startTime: "2:00 PM",  endTime: "3:30 PM",  room: "Block A - Room 7" },
  { courseCode: "CS401",  day: "Fri", startTime: "2:00 PM",  endTime: "3:30 PM",  room: "Block A - Room 7" },
  { courseCode: "MATH201",day: "Mon", startTime: "12:00 PM", endTime: "1:30 PM",  room: "Science Block - Room 2" },
  { courseCode: "MATH201",day: "Thu", startTime: "12:00 PM", endTime: "1:30 PM",  room: "Science Block - Room 2" },
  { courseCode: "MATH301",day: "Tue", startTime: "2:00 PM",  endTime: "3:30 PM",  room: "Science Block - Room 5" },
  { courseCode: "MATH301",day: "Thu", startTime: "2:00 PM",  endTime: "3:30 PM",  room: "Science Block - Room 5" },
  // Central Business School
  { courseCode: "ACC201", day: "Mon", startTime: "8:00 AM",  endTime: "9:30 AM",  room: "CBS Block - Room 1" },
  { courseCode: "ACC201", day: "Wed", startTime: "8:00 AM",  endTime: "9:30 AM",  room: "CBS Block - Room 1" },
  { courseCode: "ACC301", day: "Tue", startTime: "10:00 AM", endTime: "11:30 AM", room: "CBS Block - Room 3" },
  { courseCode: "ACC301", day: "Thu", startTime: "10:00 AM", endTime: "11:30 AM", room: "CBS Block - Room 3" },
  // Faculty of Arts & Social Sciences
  { courseCode: "COMM201",day: "Mon", startTime: "2:00 PM",  endTime: "3:30 PM",  room: "Arts Block - Room 2" },
  { courseCode: "COMM201",day: "Wed", startTime: "2:00 PM",  endTime: "3:30 PM",  room: "Arts Block - Room 2" },
  { courseCode: "ECON201", day: "Tue", startTime: "8:00 AM",  endTime: "9:30 AM",  room: "Arts Block - Room 5" },
  { courseCode: "ECON201", day: "Thu", startTime: "8:00 AM",  endTime: "9:30 AM",  room: "Arts Block - Room 5" },
];

// ══════════════════════════════════════════════════════════════════
//  MAIN
// ══════════════════════════════════════════════════════════════════
async function main() {
  console.log("\n🌱  Smart-Attend Seeder — Central University");
  console.log("──────────────────────────────────────────────");
  console.log(`   MONGO_URI  : ${process.env.MONGO_URI}`);
  console.log(`   Mode       : ${WIPE_ONLY ? "wipe-only" : WIPE ? "wipe + seed" : "seed only"}`);
  console.log(`   Default pw : ${DEFAULT_PASSWORD}`);
  console.log("──────────────────────────────────────────────\n");

  await mongoose.connect(process.env.MONGO_URI, {
    serverSelectionTimeoutMS: 8000,
    family: 4,
  });
  console.log("✅  Connected to MongoDB\n");

  // ── Wipe ─────────────────────────────────────────────────────────
  if (WIPE) {
    console.log("🗑   Wiping collections…");
    const db   = mongoose.connection.db;
    const cols = (await db.listCollections().toArray()).map((c) => c.name);
    const targets = ["users", "courses", "timetables", "semesters", "attendancesessions", "attendances"];
    await Promise.all(targets.filter((t) => cols.includes(t)).map((t) => db.collection(t).drop()));
    console.log("    ✓ All collections dropped (indexes cleared)\n");
  }

  if (WIPE_ONLY) {
    console.log("✅  Wipe complete. Exiting.");
    await mongoose.disconnect();
    process.exit(0);
  }

  const hashedPw = await hash(DEFAULT_PASSWORD);

  // ─── 1. Semesters ────────────────────────────────────────────────
  console.log("📅  Creating semesters…");
  for (const data of SEMESTERS) {
    let doc = await Semester.findOne({ name: data.name });
    if (doc) { console.log(`    ⚠️  "${data.name}" already exists — skipping`); continue; }
    doc = await Semester.create(data);
    console.log(`    ✓ ${doc.name}${doc.isCurrent ? "  [CURRENT]" : ""}`);
  }

  // ─── 2. Admin ────────────────────────────────────────────────────
  console.log("\n👤  Creating admin…");
  let admin = await User.findOne({ email: ADMIN.email });
  if (admin) {
    console.log("    ⚠️  Admin already exists — skipping");
  } else {
    admin = await User.create({ ...ADMIN, role: "admin", password: hashedPw });
    console.log(`    ✓ ${admin.fullName}  (${admin.email})`);
  }

  // ─── 3. Deans — one per faculty ──────────────────────────────────
  console.log("\n🎓  Creating deans…");
  const deanDocs = [];
  for (const data of DEANS) {
    let doc = await User.findOne({ email: data.email });
    if (doc) {
      console.log(`    ⚠️  ${data.email} already exists — skipping`);
    } else {
      doc = await User.create({
        ...data,
        role:               "dean",
        password:           hashedPw,
        mustChangePassword: true,
        isActive:           true,
      });
      console.log(`    ✓ ${doc.fullName}  →  ${doc.faculty}`);
    }
    deanDocs.push(doc);
  }

  // ─── 4. Lecturers ────────────────────────────────────────────────
  console.log("\n👨‍🏫  Creating lecturers…");
  const lecturerDocs = [];
  for (const data of LECTURERS) {
    const { teaches, ...userData } = data;
    let doc = await User.findOne({ email: userData.email });
    if (doc) {
      console.log(`    ⚠️  ${userData.email} already exists — skipping`);
    } else {
      doc = await User.create({ ...userData, role: "lecturer", password: hashedPw });
      const depts = userData.departments.join(", ");
      console.log(`    ✓ ${doc.fullName}  (${doc.staffId})  →  ${depts}`);
    }
    lecturerDocs.push({ doc, teaches });
  }

  // ─── 5. Students ─────────────────────────────────────────────────
  console.log("\n🎒  Creating students…");
  const studentDocs = [];
  for (const data of STUDENTS) {
    const { enrolledIn, ...userData } = data;
    // Auto-derive faculty from programme
    const faculty = PROGRAMME_TO_FACULTY[userData.programme] || "";
    let doc = await User.findOne({ email: userData.email });
    if (doc) {
      console.log(`    ⚠️  ${userData.email} already exists — skipping`);
    } else {
      doc = await User.create({ ...userData, role: "student", faculty, password: hashedPw });
      const tag = !userData.isActive ? "  ⛔ SUSPENDED" : "";
      console.log(`    ✓ ${doc.fullName}  (${doc.indexNumber})  →  ${faculty}${tag}`);
    }
    studentDocs.push({ doc, enrolledIn });
  }

  // Build lookup maps
  const lecturerByCode = {};
  for (const { doc, teaches } of lecturerDocs) {
    for (const code of teaches) lecturerByCode[code] = doc;
  }

  // ─── 6. Courses ──────────────────────────────────────────────────
  console.log("\n📚  Creating courses…");
  const courseDocs = {};

  for (const data of COURSES) {
    let doc = await Course.findOne({ courseCode: data.courseCode });
    if (doc) {
      console.log(`    ⚠️  ${data.courseCode} already exists — skipping`);
    } else {
      const lect       = lecturerByCode[data.courseCode];
      const enrolCount = STUDENTS.filter((s) => s.enrolledIn.includes(data.courseCode)).length;

      doc = await Course.create({
        courseCode:           data.courseCode,
        courseName:           data.courseName,
        department:           data.faculty,   // department = faculty name
        faculty:              data.faculty,
        creditHours:          data.creditHours,
        semester:             CURRENT_SEMESTER,
        assignedLecturerId:   lect?._id    ?? null,
        assignedLecturerName: lect?.fullName ?? null,
        enrolledStudents:     enrolCount,
      });
      const lectLabel = lect ? `  →  ${lect.fullName}` : "  →  (unassigned)";
      console.log(`    ✓ ${doc.courseCode}  ${doc.courseName}  [${data.faculty}]${lectLabel}`);
    }
    courseDocs[data.courseCode] = doc;
  }

  // ─── 7. Timetable ────────────────────────────────────────────────
  console.log("\n🗓   Creating timetable slots…");
  for (const slot of TIMETABLE_SLOTS) {
    const course = courseDocs[slot.courseCode];
    if (!course) continue;

    const exists = await Timetable.findOne({
      courseCode: slot.courseCode, day: slot.day,
      startTime: slot.startTime,  semester: CURRENT_SEMESTER,
    });
    if (exists) {
      console.log(`    ⚠️  ${slot.courseCode} ${slot.day} ${slot.startTime} already exists — skipping`);
      continue;
    }

    const lect  = lecturerByCode[slot.courseCode];
    const cData = COURSES.find((c) => c.courseCode === slot.courseCode);

    await Timetable.create({
      courseId:     course._id,
      courseCode:   slot.courseCode,
      courseName:   course.courseName,
      lecturerId:   lect?._id     ?? null,
      lecturerName: lect?.fullName ?? "",
      day:          slot.day,
      startTime:    slot.startTime,
      endTime:      slot.endTime,
      room:         slot.room,
      level:        cData?.level     ?? "",
      programme:    cData?.programme ?? "",
      semester:     CURRENT_SEMESTER,
    });
    console.log(`    ✓ ${slot.courseCode}  ${slot.day}  ${slot.startTime}–${slot.endTime}  (${slot.room})`);
  }

  // ─── 8. Attendance sessions ───────────────────────────────────────
  console.log("\n📋  Creating attendance sessions…");

  const lec1 = lecturerDocs[0].doc;   // Dr. Kwame Asante
  const lec2 = lecturerDocs[1].doc;   // Dr. Abena Mensah
  const lec3 = lecturerDocs[2].doc;   // Mr. Kofi Owusu
  const lec4 = lecturerDocs[3].doc;   // Dr. Esi Ankomah
  const lec5 = lecturerDocs[4].doc;   // Mr. Nii Armah

  const twoHoursAgo = new Date(Date.now() - 120 * 60 * 1000);
  const oneHourAgo  = new Date(Date.now() -  60 * 60 * 1000);
  const in30Mins    = new Date(Date.now() +  30 * 60 * 1000);
  const in45Mins    = new Date(Date.now() +  45 * 60 * 1000);
  const fiveMinsAgo = new Date(Date.now() -   5 * 60 * 1000);

  async function makeSession(data, label) {
    const existing = await AttendanceSession.findOne({
      courseCode: data.courseCode,
      lecturerId: data.lecturerId,
      isActive:   data.isActive,
      expiresAt:  data.expiresAt,
    });
    if (existing) { console.log(`    ⚠️  ${label} already exists — skipping`); return existing; }
    const s = await AttendanceSession.create({ ...data, signature: "pending" });
    s.signature = hmac(s._id.toString(), s.courseCode, s.expiresAt.getTime());
    await s.save();
    console.log(`    ✓ ${label}`);
    return s;
  }

  // SET sessions
  const sessA = await makeSession({ courseCode: "CS301", courseName: "Data Structures & Algorithms", lecturerId: lec1._id, type: "inPerson", lecturerLat: LAT,         lecturerLng: LNG,         expiresAt: oneHourAgo,   isActive: false }, "[ENDED]   CS301  (Dr. Kwame Asante)");
  const sessB = await makeSession({ courseCode: "CS301", courseName: "Data Structures & Algorithms", lecturerId: lec1._id, type: "inPerson", lecturerLat: LAT,         lecturerLng: LNG,         expiresAt: in30Mins,     isActive: true  }, "[ACTIVE]  CS301  (Dr. Kwame Asante)  — 30 min");
  const sessC = await makeSession({ courseCode: "CS201", courseName: "Object Oriented Programming",  lecturerId: lec1._id, type: "inPerson", lecturerLat: LAT + 0.001, lecturerLng: LNG + 0.001, expiresAt: twoHoursAgo,  isActive: false }, "[ENDED]   CS201  (Dr. Kwame Asante)");
  const sessD = await makeSession({ courseCode: "CS401", courseName: "Software Engineering",          lecturerId: lec1._id, type: "inPerson", lecturerLat: LAT,         lecturerLng: LNG,         expiresAt: twoHoursAgo,  isActive: false }, "[ENDED]   CS401  (Dr. Kwame Asante)");
  const sessE = await makeSession({ courseCode: "MATH201",courseName: "Linear Algebra",              lecturerId: lec2._id, type: "online",   lecturerLat: null,        lecturerLng: null,        expiresAt: in45Mins,     isActive: true  }, "[ACTIVE]  MATH201 (Dr. Abena Mensah)  [ONLINE]");
  const sessF = await makeSession({ courseCode: "MATH301",courseName: "Numerical Methods",           lecturerId: lec2._id, type: "inPerson", lecturerLat: LAT - 0.001, lecturerLng: LNG - 0.001, expiresAt: twoHoursAgo,  isActive: false }, "[ENDED]   MATH301 (Dr. Abena Mensah)");
  const sessG = await makeSession({ courseCode: "CS101",  courseName: "Introduction to Programming", lecturerId: lec3._id, type: "inPerson", lecturerLat: LAT - 0.001, lecturerLng: LNG - 0.001, expiresAt: fiveMinsAgo,  isActive: true  }, "[EXPIRED] CS101  (Mr. Kofi Owusu)  — isActive=true but QR expired");
  const sessH = await makeSession({ courseCode: "CS202",  courseName: "Database Systems",            lecturerId: lec3._id, type: "inPerson", lecturerLat: LAT,         lecturerLng: LNG,         expiresAt: oneHourAgo,   isActive: false }, "[ENDED]   CS202  (Mr. Kofi Owusu)");

  // CBS sessions
  const sessI = await makeSession({ courseCode: "ACC201", courseName: "Intermediate Accounting",         lecturerId: lec4._id, type: "inPerson", lecturerLat: LAT + 0.002, lecturerLng: LNG + 0.002, expiresAt: twoHoursAgo, isActive: false }, "[ENDED]   ACC201 (Dr. Esi Ankomah)");
  const sessJ = await makeSession({ courseCode: "ACC301", courseName: "Advanced Financial Accounting",   lecturerId: lec4._id, type: "inPerson", lecturerLat: LAT + 0.002, lecturerLng: LNG + 0.002, expiresAt: in30Mins,    isActive: true  }, "[ACTIVE]  ACC301 (Dr. Esi Ankomah)");

  // FASS sessions
  const sessK = await makeSession({ courseCode: "COMM201",courseName: "Media & Communication Theory",    lecturerId: lec5._id, type: "inPerson", lecturerLat: LAT - 0.002, lecturerLng: LNG - 0.002, expiresAt: twoHoursAgo, isActive: false }, "[ENDED]   COMM201 (Mr. Nii Armah)");

  // ─── 9. Attendance records ────────────────────────────────────────
  console.log("\n✅  Creating attendance records…");

  async function markPresent(session, students, options = {}) {
    const { lat = LAT, lng = LNG, method = "qr", minsBeforeExpiry = 25 } = options;
    let created = 0;
    for (const student of students) {
      const exists = await Attendance.findOne({ sessionId: session._id, studentId: student._id });
      if (exists) continue;
      await Attendance.create({
        sessionId:      session._id,
        studentId:      student._id,
        courseCode:     session.courseCode,
        status:         "present",
        method,
        distanceMetres: Math.floor(Math.random() * 85) + 3,
        studentLat:     lat != null ? nearbyCoord(lat) : null,
        studentLng:     lng != null ? nearbyCoord(lng) : null,
        checkedInAt:    new Date(session.expiresAt.getTime() - minsBeforeExpiry * 60 * 1000),
      });
      created++;
    }
    if (created > 0) console.log(`    ✓ ${created} record(s)  →  ${session.courseCode}`);
  }

  // Build courseCode → [studentDoc] map
  const byCode = {};
  for (const { doc, enrolledIn } of studentDocs) {
    for (const code of enrolledIn) {
      if (!byCode[code]) byCode[code] = [];
      if (doc.isActive) byCode[code].push(doc);
    }
  }

  // SET attendance
  await markPresent(sessA, byCode["CS301"] ?? []);
  await markPresent(sessC, (byCode["CS201"] ?? []).slice(0, 3));
  await markPresent(sessD, byCode["CS401"] ?? []);
  await markPresent(sessF, (byCode["MATH301"] ?? []).slice(0, 2));
  await markPresent(sessH, (byCode["CS202"] ?? []).slice(0, 3));
  await markPresent(sessB, (byCode["CS301"] ?? []).slice(0, 2), { minsBeforeExpiry: 10 });
  await markPresent(sessE, (byCode["MATH201"] ?? []).slice(0, 1), { lat: null, lng: null, method: "qr", minsBeforeExpiry: 5 });

  // CBS attendance
  await markPresent(sessI, byCode["ACC201"] ?? []);
  await markPresent(sessJ, (byCode["ACC301"] ?? []).slice(0, 1), { minsBeforeExpiry: 10 });

  // FASS attendance
  await markPresent(sessK, byCode["COMM201"] ?? []);

  // ─── 10. Summary ─────────────────────────────────────────────────
  const [uCount, crCount, ttCount, semCount, sCount, aCount] =
    await Promise.all([
      User.countDocuments(),
      Course.countDocuments(),
      Timetable.countDocuments(),
      Semester.countDocuments(),
      AttendanceSession.countDocuments(),
      Attendance.countDocuments(),
    ]);

  console.log("\n──────────────────────────────────────────────");
  console.log("🌱  Seed complete!\n");
  console.log(`   Users                : ${uCount}`);
  console.log(`   Courses              : ${crCount}`);
  console.log(`   Timetable slots      : ${ttCount}`);
  console.log(`   Semesters            : ${semCount}`);
  console.log(`   Attendance sessions  : ${sCount}`);
  console.log(`   Attendance records   : ${aCount}`);

  const pad = (s, n) => String(s).padEnd(n);
  console.log("\n📋  Login credentials  (default password: Central@123)\n");
  console.log(`   ${pad("Role", 12)}  ${pad("Email", 46)}  Notes`);
  console.log(`   ${pad("────────────",12)}  ${pad("──────────────────────────────────────────────",46)}  ───────────────────────`);
  console.log(`   ${pad("Admin",      12)}  ${pad(ADMIN.email,  46)}  mustChangePassword: true`);
  for (const d of DEANS) {
    console.log(`   ${pad("Dean",     12)}  ${pad(d.email,      46)}  ${d.faculty}`);
  }
  for (const l of LECTURERS) {
    console.log(`   ${pad("Lecturer", 12)}  ${pad(l.email,      46)}  ${l.departments.join(", ")}`);
  }
  for (const s of STUDENTS) {
    const fac  = PROGRAMME_TO_FACULTY[s.programme] || s.programme;
    const note = !s.isActive ? "⛔ SUSPENDED" : fac;
    console.log(`   ${pad("Student",  12)}  ${pad(s.email,      46)}  ${note}`);
  }

  console.log("\n📌  Sessions:");
  console.log("   [ENDED]   CS301, CS201, CS401, MATH301, CS202, ACC201, COMM201");
  console.log("   [ACTIVE]  CS301, MATH201 (online), ACC301");
  console.log("   [EXPIRED] CS101 — isActive=true but QR expired (tests guard)");
  console.log("──────────────────────────────────────────────\n");

  await mongoose.disconnect();
  process.exit(0);
}

main().catch((err) => {
  console.error("\n❌  Seeder error:", err.message);
  console.error(err);
  mongoose.disconnect();
  process.exit(1);
});