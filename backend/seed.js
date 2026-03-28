/**
 * seed.js — Smart-Attend database seeder
 * Central University Ghana
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
 *  Central@123   (mustChangePassword: true on all accounts)
 *
 * ─────────────────────────────────────────────────────────────────
 *  COLLECTIONS SEEDED
 * ─────────────────────────────────────────────────────────────────
 *  users               — super_admin, per-faculty admins, deans,
 *                        lecturers, students
 *  courses             — full course catalogue for every programme
 *  timetable           — weekly slots per course
 *  semesters           — academic calendar
 *  attendancesessions  — sample past & live sessions (with codes)
 *  attendances         — sample check-in records
 *
 * ⚠️  Never run --wipe against a production database.
 */

"use strict";

require("dotenv").config();

const mongoose = require("mongoose");
const bcrypt   = require("bcryptjs");
const crypto   = require("crypto");

// ══════════════════════════════════════════════════════════════════
//  MODELS (from the app)
// ══════════════════════════════════════════════════════════════════
const User              = require("./src/models/User");
const AttendanceSession = require("./src/models/AttendanceSession");
const Attendance        = require("./src/models/Attendance");

// ── Course ────────────────────────────────────────────────────────
const courseSchema = new mongoose.Schema({
  courseCode:           { type: String, required: true, unique: true, trim: true },
  courseName:           { type: String, required: true, trim: true },
  department:           { type: String, required: true, trim: true },
  faculty:              { type: String, trim: true },
  programme:            { type: String, trim: true },
  level:                { type: String, trim: true },
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
  startDate:     { type: Date, required: true },
  endDate:       { type: Date, required: true },
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

/** Generate HMAC signature matching the app's QR verification logic */
function hmacSignature(sessionId, courseCode, expiresAtMs) {
  const secret = process.env.QR_SECRET || "smart_attend_qr_secret";
  return crypto
    .createHmac("sha256", secret)
    .update(`${sessionId}:${courseCode}:${expiresAtMs}`)
    .digest("hex");
}

/** Generate a random 6-digit attendance code */
function randomCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

/** Slightly perturb a GPS coordinate for realistic student check-in data */
function nearbyCoord(base, maxDeg = 0.0005) {
  return base + (Math.random() * 2 - 1) * maxDeg;
}

// ══════════════════════════════════════════════════════════════════
//  SCHOOL STRUCTURE
//  Mirrors school_data.dart exactly.
// ══════════════════════════════════════════════════════════════════
const PROGRAMME_TO_FACULTY = {
  // School of Engineering & Technology
  "BSc Computer Science":             "School of Engineering & Technology",
  "BSc Information Technology":       "School of Engineering & Technology",
  "BSc Civil Engineering":            "School of Engineering & Technology",
  // School of Architecture & Design
  "BSc Fashion Design":               "School of Architecture & Design",
  "BSc Interior Design":              "School of Architecture & Design",
  "BSc Landscape Design":             "School of Architecture & Design",
  "BSc Graphic Design":               "School of Architecture & Design",
  "BSc Real Estate":                  "School of Architecture & Design",
  "BSc Architecture":                 "School of Architecture & Design",
  "BSc Planning":                     "School of Architecture & Design",
  // School of Nursing & Midwifery
  "BSc Nursing":                      "School of Nursing & Midwifery",
  // Faculty of Arts & Social Sciences
  "BA Communication Studies":         "Faculty of Arts & Social Sciences",
  "BA Economics":                     "Faculty of Arts & Social Sciences",
  "BA Development Studies":           "Faculty of Arts & Social Sciences",
  "BA Social Sciences":               "Faculty of Arts & Social Sciences",
  "BA Religious Studies":             "Faculty of Arts & Social Sciences",
  // Central Business School
  "BSc Accounting":                   "Central Business School",
  "BSc Banking & Finance":            "Central Business School",
  "BSc Marketing":                    "Central Business School",
  "BSc Human Resource Management":    "Central Business School",
  "BSc Business Administration":      "Central Business School",
  // School of Medical Sciences
  "MBChB (Medicine)":                 "School of Medical Sciences",
  "BSc Physician Assistantship":      "School of Medical Sciences",
  // School of Pharmacy
  "Doctor of Pharmacy (PharmD)":      "School of Pharmacy",
  // Central Law School
  "LLB (Bachelor of Laws)":           "Central Law School",
  // Graduate
  "MSc Accounting":                   "School of Graduate Studies & Research",
  "MPhil Accounting":                 "School of Graduate Studies & Research",
  "MA Religious Studies":             "School of Graduate Studies & Research",
  "MPhil Theology":                   "School of Graduate Studies & Research",
  "MBA Finance":                      "School of Graduate Studies & Research",
  "MBA General Management":           "School of Graduate Studies & Research",
  "MBA Human Resource Management":    "School of Graduate Studies & Research",
  "MBA Marketing":                    "School of Graduate Studies & Research",
  "MBA Project Management":           "School of Graduate Studies & Research",
  "MBA Agribusiness":                 "School of Graduate Studies & Research",
  "MPhil Economics":                  "School of Graduate Studies & Research",
  "Master of Public Health":          "School of Graduate Studies & Research",
  "MA Development Policy":            "School of Graduate Studies & Research",
  "MPhil Development Policy":         "School of Graduate Studies & Research",
  "PhD Finance":                      "School of Graduate Studies & Research",
  "DBA (Doctor of Business Administration)": "School of Graduate Studies & Research",
  // Distance
  "Distance Business Programs":              "Centre for Distance & Professional Education",
  "Distance Theology Programs":             "Centre for Distance & Professional Education",
  "Professional / Diploma Programs (ATHE)": "Centre for Distance & Professional Education",
};

// ══════════════════════════════════════════════════════════════════
//  CONSTANTS
// ══════════════════════════════════════════════════════════════════
// Central University Ghana campus coordinates (Miotso, Accra)
const LAT              = 5.7172;
const LNG              = -0.0747;
const CURRENT_SEMESTER = "2025/2026 Semester 2";

// ══════════════════════════════════════════════════════════════════
//  SEMESTERS
// ══════════════════════════════════════════════════════════════════
const SEMESTERS = [
  { name: "2025/2026 Semester 2", startDate: new Date("2026-01-13"), endDate: new Date("2026-05-23"), teachingWeeks: 15, isCurrent: true  },
  { name: "2025/2026 Semester 1", startDate: new Date("2025-08-25"), endDate: new Date("2025-12-20"), teachingWeeks: 15, isCurrent: false },
  { name: "2024/2025 Semester 2", startDate: new Date("2025-01-13"), endDate: new Date("2025-05-23"), teachingWeeks: 15, isCurrent: false },
];

// ══════════════════════════════════════════════════════════════════
//  SUPER ADMIN
//  The top-level system owner — can create / manage faculty admins.
// ══════════════════════════════════════════════════════════════════
const SUPER_ADMIN = {
  fullName: "Super Administrator",
  email:    "superadmin@central.edu.gh",
  role:     "super_admin",
  staffId:  "STF/SA/001",
  department: "University Management",
  departments: ["University Management"],
  faculty:  "University Management",
  isActive: true,
  mustChangePassword: true,
};

// ══════════════════════════════════════════════════════════════════
//  ADMINS — one per faculty (matches super_admin dashboard logic)
//  Admin role is scoped to a single faculty/department.
// ══════════════════════════════════════════════════════════════════
const ADMINS = [
  {
    fullName: "Mr. Bright Acheampong",
    email:    "admin.set@central.edu.gh",
    staffId:  "STF/ADMIN/001",
    faculty:  "School of Engineering & Technology",
    department: "School of Engineering & Technology",
    departments: ["School of Engineering & Technology"],
  },
  {
    fullName: "Mrs. Cynthia Osei",
    email:    "admin.sad@central.edu.gh",
    staffId:  "STF/ADMIN/002",
    faculty:  "School of Architecture & Design",
    department: "School of Architecture & Design",
    departments: ["School of Architecture & Design"],
  },
  {
    fullName: "Mrs. Patience Asante",
    email:    "admin.snm@central.edu.gh",
    staffId:  "STF/ADMIN/003",
    faculty:  "School of Nursing & Midwifery",
    department: "School of Nursing & Midwifery",
    departments: ["School of Nursing & Midwifery"],
  },
  {
    fullName: "Mr. Daniel Frimpong",
    email:    "admin.fass@central.edu.gh",
    staffId:  "STF/ADMIN/004",
    faculty:  "Faculty of Arts & Social Sciences",
    department: "Faculty of Arts & Social Sciences",
    departments: ["Faculty of Arts & Social Sciences"],
  },
  {
    fullName: "Mrs. Janet Antwi",
    email:    "admin.cbs@central.edu.gh",
    staffId:  "STF/ADMIN/005",
    faculty:  "Central Business School",
    department: "Central Business School",
    departments: ["Central Business School"],
  },
  {
    fullName: "Mr. Francis Tetteh",
    email:    "admin.sms@central.edu.gh",
    staffId:  "STF/ADMIN/006",
    faculty:  "School of Medical Sciences",
    department: "School of Medical Sciences",
    departments: ["School of Medical Sciences"],
  },
  {
    fullName: "Mrs. Grace Owusu",
    email:    "admin.sop@central.edu.gh",
    staffId:  "STF/ADMIN/007",
    faculty:  "School of Pharmacy",
    department: "School of Pharmacy",
    departments: ["School of Pharmacy"],
  },
  {
    fullName: "Mr. Joseph Mensah",
    email:    "admin.law@central.edu.gh",
    staffId:  "STF/ADMIN/008",
    faculty:  "Central Law School",
    department: "Central Law School",
    departments: ["Central Law School"],
  },
  {
    fullName: "Dr. Rita Quaye",
    email:    "admin.sgsr@central.edu.gh",
    staffId:  "STF/ADMIN/009",
    faculty:  "School of Graduate Studies & Research",
    department: "School of Graduate Studies & Research",
    departments: ["School of Graduate Studies & Research"],
  },
  {
    fullName: "Mr. Emmanuel Darku",
    email:    "admin.cdpe@central.edu.gh",
    staffId:  "STF/ADMIN/010",
    faculty:  "Centre for Distance & Professional Education",
    department: "Centre for Distance & Professional Education",
    departments: ["Centre for Distance & Professional Education"],
  },
];

// ══════════════════════════════════════════════════════════════════
//  DEANS — one per faculty (10 total)
// ══════════════════════════════════════════════════════════════════
const DEANS = [
  { fullName: "Prof. Emmanuel Darko",  email: "dean.set@central.edu.gh",  staffId: "STF/DEAN/001", faculty: "School of Engineering & Technology" },
  { fullName: "Prof. Grace Osei",      email: "dean.sad@central.edu.gh",  staffId: "STF/DEAN/002", faculty: "School of Architecture & Design" },
  { fullName: "Prof. Ama Fordjour",    email: "dean.snm@central.edu.gh",  staffId: "STF/DEAN/003", faculty: "School of Nursing & Midwifery" },
  { fullName: "Prof. Kofi Antwi",      email: "dean.fass@central.edu.gh", staffId: "STF/DEAN/004", faculty: "Faculty of Arts & Social Sciences" },
  { fullName: "Prof. Akua Boateng",    email: "dean.cbs@central.edu.gh",  staffId: "STF/DEAN/005", faculty: "Central Business School" },
  { fullName: "Prof. Samuel Nyarko",   email: "dean.sms@central.edu.gh",  staffId: "STF/DEAN/006", faculty: "School of Medical Sciences" },
  { fullName: "Prof. Adwoa Asante",    email: "dean.sop@central.edu.gh",  staffId: "STF/DEAN/007", faculty: "School of Pharmacy" },
  { fullName: "Prof. Nana Kusi",       email: "dean.law@central.edu.gh",  staffId: "STF/DEAN/008", faculty: "Central Law School" },
  { fullName: "Prof. Yaw Mensah",      email: "dean.sgsr@central.edu.gh", staffId: "STF/DEAN/009", faculty: "School of Graduate Studies & Research" },
  { fullName: "Prof. Efua Quaye",      email: "dean.cdpe@central.edu.gh", staffId: "STF/DEAN/010", faculty: "Centre for Distance & Professional Education" },
];

// ══════════════════════════════════════════════════════════════════
//  LECTURERS
//  `teaches` — course codes assigned to this lecturer.
//  `departments` — all faculties this person teaches across.
// ══════════════════════════════════════════════════════════════════
const LECTURERS = [
  // ── School of Engineering & Technology ───────────────────────
  {
    fullName: "Dr. Kwame Asante",
    email:    "kwame.asante@central.edu.gh",
    staffId:  "STF/2018/0012",
    faculty:  "School of Engineering & Technology",
    departments: ["School of Engineering & Technology"],
    teaches:  ["CS101","CS201","CS202","CS301","CS401","CS402"],
  },
  {
    fullName: "Mr. Kofi Owusu",
    email:    "kofi.owusu@central.edu.gh",
    staffId:  "STF/2020/0056",
    faculty:  "School of Engineering & Technology",
    departments: ["School of Engineering & Technology"],
    teaches:  ["CS102","CS103","CS303","IT101","IT201","IT301"],
  },
  {
    fullName: "Dr. Abena Mensah",
    email:    "abena.mensah@central.edu.gh",
    staffId:  "STF/2019/0034",
    faculty:  "School of Engineering & Technology",
    departments: ["School of Engineering & Technology", "Central Business School"],
    teaches:  ["MATH101","MATH201","MATH301","CE101","CE201","CE301"],
  },
  // ── Central Business School ───────────────────────────────────
  {
    fullName: "Dr. Esi Ankomah",
    email:    "esi.ankomah@central.edu.gh",
    staffId:  "STF/2017/0021",
    faculty:  "Central Business School",
    departments: ["Central Business School"],
    teaches:  ["ACC101","ACC201","ACC301","BFN101","BFN201"],
  },
  {
    fullName: "Mr. Nii Armah",
    email:    "nii.armah@central.edu.gh",
    staffId:  "STF/2021/0078",
    faculty:  "Central Business School",
    departments: ["Central Business School"],
    teaches:  ["MKT101","MKT201","HRM101","HRM201","BUS101","BUS201"],
  },
  // ── Faculty of Arts & Social Sciences ────────────────────────
  {
    fullName: "Dr. Akosua Frimpong",
    email:    "akosua.frimpong@central.edu.gh",
    staffId:  "STF/2016/0009",
    faculty:  "Faculty of Arts & Social Sciences",
    departments: ["Faculty of Arts & Social Sciences"],
    teaches:  ["COMM101","COMM201","COMM301","ECON101","ECON201","ECON301"],
  },
  {
    fullName: "Mr. Yaw Boateng",
    email:    "yaw.boateng@central.edu.gh",
    staffId:  "STF/2022/0091",
    faculty:  "Faculty of Arts & Social Sciences",
    departments: ["Faculty of Arts & Social Sciences"],
    teaches:  ["DEV101","DEV201","SOC101","SOC201","REL101","REL201"],
  },
  // ── School of Nursing & Midwifery ─────────────────────────────
  {
    fullName: "Dr. Efua Asante",
    email:    "efua.asante@central.edu.gh",
    staffId:  "STF/2015/0003",
    faculty:  "School of Nursing & Midwifery",
    departments: ["School of Nursing & Midwifery"],
    teaches:  ["NUR101","NUR201","NUR301","NUR401"],
  },
  // ── Central Law School ────────────────────────────────────────
  {
    fullName: "Dr. Kwesi Mensah",
    email:    "kwesi.mensah@central.edu.gh",
    staffId:  "STF/2014/0002",
    faculty:  "Central Law School",
    departments: ["Central Law School"],
    teaches:  ["LAW101","LAW201","LAW301","LAW401"],
  },
];

// ══════════════════════════════════════════════════════════════════
//  STUDENTS
//  `enrolledIn` — course codes pre-loaded into enrolledCourses.
//  One `isActive: false` entry tests the suspended-account flow.
// ══════════════════════════════════════════════════════════════════
const STUDENTS = [
  // ── BSc Computer Science ─────────────────────────────────────
  { fullName: "Ama Boateng",     email: "ama.boateng@central.edu.gh",       indexNumber: "CU/CS/2022/001", programme: "BSc Computer Science",          level: "300", isActive: true,  enrolledIn: ["CS301","CS201","CS401","MATH201"] },
  { fullName: "Yaw Darko",       email: "yaw.darko@central.edu.gh",         indexNumber: "CU/CS/2022/002", programme: "BSc Computer Science",          level: "300", isActive: true,  enrolledIn: ["CS301","CS201","CS401","MATH201"] },
  { fullName: "Efua Asante",     email: "efua.student@central.edu.gh",      indexNumber: "CU/CS/2022/003", programme: "BSc Computer Science",          level: "300", isActive: true,  enrolledIn: ["CS301","CS201","CS401"] },
  { fullName: "Kweku Frimpong",  email: "kweku.frimpong@central.edu.gh",    indexNumber: "CU/CS/2022/004", programme: "BSc Computer Science",          level: "300", isActive: true,  enrolledIn: ["CS301","CS201","MATH201"] },
  { fullName: "Akosua Nkrumah",  email: "akosua.nkrumah@central.edu.gh",   indexNumber: "CU/CS/2023/001", programme: "BSc Computer Science",          level: "200", isActive: true,  enrolledIn: ["CS201","CS202","MATH201"] },
  { fullName: "Kobina Aidoo",    email: "kobina.aidoo@central.edu.gh",      indexNumber: "CU/CS/2022/005", programme: "BSc Computer Science",          level: "300", isActive: false, enrolledIn: ["CS301","CS201"] },  // SUSPENDED
  // ── BSc Information Technology ───────────────────────────────
  { fullName: "Ato Quaye",       email: "ato.quaye@central.edu.gh",         indexNumber: "CU/IT/2022/001", programme: "BSc Information Technology",    level: "300", isActive: true,  enrolledIn: ["IT301","IT201","MATH201"] },
  { fullName: "Nana Esi Appiah", email: "nana.appiah@central.edu.gh",       indexNumber: "CU/IT/2023/001", programme: "BSc Information Technology",    level: "200", isActive: true,  enrolledIn: ["IT201","IT101","MATH101"] },
  // ── BSc Civil Engineering ────────────────────────────────────
  { fullName: "Kofi Asare",      email: "kofi.asare@central.edu.gh",        indexNumber: "CU/CE/2022/001", programme: "BSc Civil Engineering",         level: "300", isActive: true,  enrolledIn: ["CE301","CE201","MATH301"] },
  // ── Central Business School ───────────────────────────────────
  { fullName: "Adwoa Poku",      email: "adwoa.poku@central.edu.gh",        indexNumber: "CU/ACC/2022/001", programme: "BSc Accounting",               level: "300", isActive: true,  enrolledIn: ["ACC301","ACC201","BUS201"] },
  { fullName: "Fiifi Mensah",    email: "fiifi.mensah@central.edu.gh",      indexNumber: "CU/ACC/2022/002", programme: "BSc Accounting",               level: "300", isActive: true,  enrolledIn: ["ACC301","ACC201"] },
  { fullName: "Abena Owusu",     email: "abena.owusu@central.edu.gh",       indexNumber: "CU/MKT/2022/001", programme: "BSc Marketing",                level: "300", isActive: true,  enrolledIn: ["MKT201","MKT101","BUS201"] },
  { fullName: "Kwame Asante",    email: "kwame.student@central.edu.gh",     indexNumber: "CU/HRM/2022/001", programme: "BSc Human Resource Management", level: "200", isActive: true,  enrolledIn: ["HRM201","HRM101","BUS101"] },
  { fullName: "Akua Nyarko",     email: "akua.nyarko@central.edu.gh",       indexNumber: "CU/BFN/2022/001", programme: "BSc Banking & Finance",         level: "300", isActive: true,  enrolledIn: ["BFN201","BFN101","ACC201"] },
  // ── Faculty of Arts & Social Sciences ────────────────────────
  { fullName: "Akua Owusu",      email: "akua.owusu@central.edu.gh",        indexNumber: "CU/COMM/2022/001", programme: "BA Communication Studies",     level: "200", isActive: true,  enrolledIn: ["COMM201","COMM101","ECON101"] },
  { fullName: "Kojo Darko",      email: "kojo.darko@central.edu.gh",        indexNumber: "CU/ECON/2022/001", programme: "BA Economics",                 level: "300", isActive: true,  enrolledIn: ["ECON301","ECON201","DEV201"] },
  { fullName: "Esi Boateng",     email: "esi.boateng@central.edu.gh",       indexNumber: "CU/SOC/2022/001",  programme: "BA Social Sciences",           level: "200", isActive: true,  enrolledIn: ["SOC201","SOC101","DEV101"] },
  // ── School of Nursing & Midwifery ─────────────────────────────
  { fullName: "Abena Frimpong",  email: "abena.frimpong@central.edu.gh",    indexNumber: "CU/NUR/2022/001", programme: "BSc Nursing",                   level: "300", isActive: true,  enrolledIn: ["NUR301","NUR201","NUR101"] },
  // ── Central Law School ────────────────────────────────────────
  { fullName: "Kwesi Appiah",    email: "kwesi.appiah@central.edu.gh",      indexNumber: "CU/LAW/2022/001", programme: "LLB (Bachelor of Laws)",         level: "300", isActive: true,  enrolledIn: ["LAW301","LAW201","LAW101"] },
];

// ══════════════════════════════════════════════════════════════════
//  COURSES — full catalogue per programme, per level
//  department field = faculty name (mirrors Flutter/backend convention)
// ══════════════════════════════════════════════════════════════════
const COURSES = [

  // ────────────────────────────────────────────────────────────────
  //  SCHOOL OF ENGINEERING & TECHNOLOGY
  // ────────────────────────────────────────────────────────────────

  // ── BSc Computer Science ──────────────────────────────────────
  { courseCode:"CS101",  courseName:"Introduction to Programming",       faculty:"School of Engineering & Technology", programme:"BSc Computer Science", level:"100", creditHours:3 },
  { courseCode:"CS102",  courseName:"Computer Organisation",             faculty:"School of Engineering & Technology", programme:"BSc Computer Science", level:"100", creditHours:3 },
  { courseCode:"CS103",  courseName:"Discrete Mathematics",              faculty:"School of Engineering & Technology", programme:"BSc Computer Science", level:"100", creditHours:3 },
  { courseCode:"MATH101",courseName:"Calculus I",                        faculty:"School of Engineering & Technology", programme:"BSc Computer Science", level:"100", creditHours:3 },
  { courseCode:"CS201",  courseName:"Object Oriented Programming",       faculty:"School of Engineering & Technology", programme:"BSc Computer Science", level:"200", creditHours:3 },
  { courseCode:"CS202",  courseName:"Database Systems",                  faculty:"School of Engineering & Technology", programme:"BSc Computer Science", level:"200", creditHours:3 },
  { courseCode:"CS203",  courseName:"Data Structures",                   faculty:"School of Engineering & Technology", programme:"BSc Computer Science", level:"200", creditHours:3 },
  { courseCode:"MATH201",courseName:"Linear Algebra",                    faculty:"School of Engineering & Technology", programme:"BSc Computer Science", level:"200", creditHours:3 },
  { courseCode:"CS301",  courseName:"Data Structures & Algorithms",      faculty:"School of Engineering & Technology", programme:"BSc Computer Science", level:"300", creditHours:3 },
  { courseCode:"CS302",  courseName:"Operating Systems",                 faculty:"School of Engineering & Technology", programme:"BSc Computer Science", level:"300", creditHours:3 },
  { courseCode:"CS303",  courseName:"Computer Networks",                 faculty:"School of Engineering & Technology", programme:"BSc Computer Science", level:"300", creditHours:3 },
  { courseCode:"MATH301",courseName:"Numerical Methods",                 faculty:"School of Engineering & Technology", programme:"BSc Computer Science", level:"300", creditHours:3 },
  { courseCode:"CS401",  courseName:"Software Engineering",              faculty:"School of Engineering & Technology", programme:"BSc Computer Science", level:"400", creditHours:3 },
  { courseCode:"CS402",  courseName:"Artificial Intelligence",           faculty:"School of Engineering & Technology", programme:"BSc Computer Science", level:"400", creditHours:3 },
  { courseCode:"CS403",  courseName:"Final Year Project I",              faculty:"School of Engineering & Technology", programme:"BSc Computer Science", level:"400", creditHours:6 },

  // ── BSc Information Technology ────────────────────────────────
  { courseCode:"IT101",  courseName:"Fundamentals of IT",                faculty:"School of Engineering & Technology", programme:"BSc Information Technology", level:"100", creditHours:3 },
  { courseCode:"IT102",  courseName:"Introduction to Web Design",        faculty:"School of Engineering & Technology", programme:"BSc Information Technology", level:"100", creditHours:3 },
  { courseCode:"IT201",  courseName:"Systems Analysis & Design",         faculty:"School of Engineering & Technology", programme:"BSc Information Technology", level:"200", creditHours:3 },
  { courseCode:"IT202",  courseName:"Network Fundamentals",              faculty:"School of Engineering & Technology", programme:"BSc Information Technology", level:"200", creditHours:3 },
  { courseCode:"IT301",  courseName:"Information Security",              faculty:"School of Engineering & Technology", programme:"BSc Information Technology", level:"300", creditHours:3 },
  { courseCode:"IT302",  courseName:"Cloud Computing",                   faculty:"School of Engineering & Technology", programme:"BSc Information Technology", level:"300", creditHours:3 },
  { courseCode:"IT401",  courseName:"IT Project Management",             faculty:"School of Engineering & Technology", programme:"BSc Information Technology", level:"400", creditHours:3 },
  { courseCode:"IT402",  courseName:"Final Year Project I",              faculty:"School of Engineering & Technology", programme:"BSc Information Technology", level:"400", creditHours:6 },

  // ── BSc Civil Engineering ─────────────────────────────────────
  { courseCode:"CE101",  courseName:"Engineering Mathematics I",         faculty:"School of Engineering & Technology", programme:"BSc Civil Engineering", level:"100", creditHours:3 },
  { courseCode:"CE102",  courseName:"Engineering Drawing",               faculty:"School of Engineering & Technology", programme:"BSc Civil Engineering", level:"100", creditHours:3 },
  { courseCode:"CE201",  courseName:"Structural Analysis I",             faculty:"School of Engineering & Technology", programme:"BSc Civil Engineering", level:"200", creditHours:3 },
  { courseCode:"CE202",  courseName:"Fluid Mechanics",                   faculty:"School of Engineering & Technology", programme:"BSc Civil Engineering", level:"200", creditHours:3 },
  { courseCode:"CE301",  courseName:"Structural Analysis II",            faculty:"School of Engineering & Technology", programme:"BSc Civil Engineering", level:"300", creditHours:3 },
  { courseCode:"CE302",  courseName:"Geotechnical Engineering",          faculty:"School of Engineering & Technology", programme:"BSc Civil Engineering", level:"300", creditHours:3 },
  { courseCode:"CE401",  courseName:"Construction Management",           faculty:"School of Engineering & Technology", programme:"BSc Civil Engineering", level:"400", creditHours:3 },
  { courseCode:"CE402",  courseName:"Final Year Project I",              faculty:"School of Engineering & Technology", programme:"BSc Civil Engineering", level:"400", creditHours:6 },

  // ────────────────────────────────────────────────────────────────
  //  CENTRAL BUSINESS SCHOOL
  // ────────────────────────────────────────────────────────────────
  { courseCode:"ACC101", courseName:"Principles of Accounting",          faculty:"Central Business School", programme:"BSc Accounting",            level:"100", creditHours:3 },
  { courseCode:"ACC102", courseName:"Business Mathematics",              faculty:"Central Business School", programme:"BSc Accounting",            level:"100", creditHours:3 },
  { courseCode:"ACC201", courseName:"Intermediate Accounting",           faculty:"Central Business School", programme:"BSc Accounting",            level:"200", creditHours:3 },
  { courseCode:"ACC202", courseName:"Cost Accounting",                   faculty:"Central Business School", programme:"BSc Accounting",            level:"200", creditHours:3 },
  { courseCode:"ACC301", courseName:"Advanced Financial Accounting",     faculty:"Central Business School", programme:"BSc Accounting",            level:"300", creditHours:3 },
  { courseCode:"ACC302", courseName:"Taxation",                          faculty:"Central Business School", programme:"BSc Accounting",            level:"300", creditHours:3 },
  { courseCode:"ACC401", courseName:"Auditing & Assurance",              faculty:"Central Business School", programme:"BSc Accounting",            level:"400", creditHours:3 },
  { courseCode:"ACC402", courseName:"Final Year Project I",              faculty:"Central Business School", programme:"BSc Accounting",            level:"400", creditHours:6 },

  { courseCode:"BUS101", courseName:"Introduction to Business",          faculty:"Central Business School", programme:"BSc Business Administration", level:"100", creditHours:3 },
  { courseCode:"BUS102", courseName:"Business Communication",            faculty:"Central Business School", programme:"BSc Business Administration", level:"100", creditHours:3 },
  { courseCode:"BUS201", courseName:"Principles of Management",          faculty:"Central Business School", programme:"BSc Business Administration", level:"200", creditHours:3 },
  { courseCode:"BUS202", courseName:"Organisational Behaviour",          faculty:"Central Business School", programme:"BSc Business Administration", level:"200", creditHours:3 },
  { courseCode:"BUS301", courseName:"Strategic Management",              faculty:"Central Business School", programme:"BSc Business Administration", level:"300", creditHours:3 },
  { courseCode:"BUS401", courseName:"Entrepreneurship",                  faculty:"Central Business School", programme:"BSc Business Administration", level:"400", creditHours:3 },

  { courseCode:"BFN101", courseName:"Introduction to Banking",           faculty:"Central Business School", programme:"BSc Banking & Finance",      level:"100", creditHours:3 },
  { courseCode:"BFN201", courseName:"Financial Management",              faculty:"Central Business School", programme:"BSc Banking & Finance",      level:"200", creditHours:3 },
  { courseCode:"BFN301", courseName:"Investment Analysis",               faculty:"Central Business School", programme:"BSc Banking & Finance",      level:"300", creditHours:3 },
  { courseCode:"BFN401", courseName:"International Finance",             faculty:"Central Business School", programme:"BSc Banking & Finance",      level:"400", creditHours:3 },

  { courseCode:"MKT101", courseName:"Principles of Marketing",           faculty:"Central Business School", programme:"BSc Marketing",             level:"100", creditHours:3 },
  { courseCode:"MKT201", courseName:"Consumer Behaviour",                faculty:"Central Business School", programme:"BSc Marketing",             level:"200", creditHours:3 },
  { courseCode:"MKT301", courseName:"Digital Marketing",                 faculty:"Central Business School", programme:"BSc Marketing",             level:"300", creditHours:3 },
  { courseCode:"MKT401", courseName:"Brand Management",                  faculty:"Central Business School", programme:"BSc Marketing",             level:"400", creditHours:3 },

  { courseCode:"HRM101", courseName:"Introduction to HRM",               faculty:"Central Business School", programme:"BSc Human Resource Management", level:"100", creditHours:3 },
  { courseCode:"HRM201", courseName:"Employee Relations",                faculty:"Central Business School", programme:"BSc Human Resource Management", level:"200", creditHours:3 },
  { courseCode:"HRM301", courseName:"Training & Development",            faculty:"Central Business School", programme:"BSc Human Resource Management", level:"300", creditHours:3 },
  { courseCode:"HRM401", courseName:"Strategic HRM",                     faculty:"Central Business School", programme:"BSc Human Resource Management", level:"400", creditHours:3 },

  // ────────────────────────────────────────────────────────────────
  //  FACULTY OF ARTS & SOCIAL SCIENCES
  // ────────────────────────────────────────────────────────────────
  { courseCode:"COMM101", courseName:"Introduction to Communication",    faculty:"Faculty of Arts & Social Sciences", programme:"BA Communication Studies", level:"100", creditHours:3 },
  { courseCode:"COMM102", courseName:"Writing for Mass Media",            faculty:"Faculty of Arts & Social Sciences", programme:"BA Communication Studies", level:"100", creditHours:3 },
  { courseCode:"COMM201", courseName:"Media & Communication Theory",      faculty:"Faculty of Arts & Social Sciences", programme:"BA Communication Studies", level:"200", creditHours:3 },
  { courseCode:"COMM202", courseName:"Broadcast Journalism",              faculty:"Faculty of Arts & Social Sciences", programme:"BA Communication Studies", level:"200", creditHours:3 },
  { courseCode:"COMM301", courseName:"Public Relations",                  faculty:"Faculty of Arts & Social Sciences", programme:"BA Communication Studies", level:"300", creditHours:3 },
  { courseCode:"COMM401", courseName:"Media Management",                  faculty:"Faculty of Arts & Social Sciences", programme:"BA Communication Studies", level:"400", creditHours:3 },

  { courseCode:"ECON101", courseName:"Principles of Economics",           faculty:"Faculty of Arts & Social Sciences", programme:"BA Economics", level:"100", creditHours:3 },
  { courseCode:"ECON201", courseName:"Microeconomics",                    faculty:"Faculty of Arts & Social Sciences", programme:"BA Economics", level:"200", creditHours:3 },
  { courseCode:"ECON301", courseName:"Macroeconomics",                    faculty:"Faculty of Arts & Social Sciences", programme:"BA Economics", level:"300", creditHours:3 },
  { courseCode:"ECON401", courseName:"Development Economics",             faculty:"Faculty of Arts & Social Sciences", programme:"BA Economics", level:"400", creditHours:3 },

  { courseCode:"DEV101",  courseName:"Introduction to Development",       faculty:"Faculty of Arts & Social Sciences", programme:"BA Development Studies", level:"100", creditHours:3 },
  { courseCode:"DEV201",  courseName:"Development Policy & Planning",     faculty:"Faculty of Arts & Social Sciences", programme:"BA Development Studies", level:"200", creditHours:3 },
  { courseCode:"DEV301",  courseName:"Community Development",             faculty:"Faculty of Arts & Social Sciences", programme:"BA Development Studies", level:"300", creditHours:3 },

  { courseCode:"SOC101",  courseName:"Introduction to Sociology",         faculty:"Faculty of Arts & Social Sciences", programme:"BA Social Sciences", level:"100", creditHours:3 },
  { courseCode:"SOC201",  courseName:"Social Research Methods",           faculty:"Faculty of Arts & Social Sciences", programme:"BA Social Sciences", level:"200", creditHours:3 },
  { courseCode:"SOC301",  courseName:"African Social Thought",            faculty:"Faculty of Arts & Social Sciences", programme:"BA Social Sciences", level:"300", creditHours:3 },

  { courseCode:"REL101",  courseName:"Introduction to World Religions",   faculty:"Faculty of Arts & Social Sciences", programme:"BA Religious Studies", level:"100", creditHours:3 },
  { courseCode:"REL201",  courseName:"African Traditional Religion",      faculty:"Faculty of Arts & Social Sciences", programme:"BA Religious Studies", level:"200", creditHours:3 },

  // ────────────────────────────────────────────────────────────────
  //  SCHOOL OF NURSING & MIDWIFERY
  // ────────────────────────────────────────────────────────────────
  { courseCode:"NUR101",  courseName:"Anatomy & Physiology I",            faculty:"School of Nursing & Midwifery", programme:"BSc Nursing", level:"100", creditHours:3 },
  { courseCode:"NUR102",  courseName:"Foundations of Nursing Practice",   faculty:"School of Nursing & Midwifery", programme:"BSc Nursing", level:"100", creditHours:3 },
  { courseCode:"NUR201",  courseName:"Medical-Surgical Nursing I",        faculty:"School of Nursing & Midwifery", programme:"BSc Nursing", level:"200", creditHours:3 },
  { courseCode:"NUR202",  courseName:"Pharmacology",                      faculty:"School of Nursing & Midwifery", programme:"BSc Nursing", level:"200", creditHours:3 },
  { courseCode:"NUR301",  courseName:"Medical-Surgical Nursing II",       faculty:"School of Nursing & Midwifery", programme:"BSc Nursing", level:"300", creditHours:3 },
  { courseCode:"NUR302",  courseName:"Community Health Nursing",          faculty:"School of Nursing & Midwifery", programme:"BSc Nursing", level:"300", creditHours:3 },
  { courseCode:"NUR401",  courseName:"Nursing Research & Management",     faculty:"School of Nursing & Midwifery", programme:"BSc Nursing", level:"400", creditHours:3 },

  // ────────────────────────────────────────────────────────────────
  //  CENTRAL LAW SCHOOL
  // ────────────────────────────────────────────────────────────────
  { courseCode:"LAW101",  courseName:"Introduction to Law",               faculty:"Central Law School", programme:"LLB (Bachelor of Laws)", level:"100", creditHours:3 },
  { courseCode:"LAW102",  courseName:"Constitutional Law",                faculty:"Central Law School", programme:"LLB (Bachelor of Laws)", level:"100", creditHours:3 },
  { courseCode:"LAW201",  courseName:"Contract Law",                      faculty:"Central Law School", programme:"LLB (Bachelor of Laws)", level:"200", creditHours:3 },
  { courseCode:"LAW202",  courseName:"Law of Tort",                       faculty:"Central Law School", programme:"LLB (Bachelor of Laws)", level:"200", creditHours:3 },
  { courseCode:"LAW301",  courseName:"Criminal Law",                      faculty:"Central Law School", programme:"LLB (Bachelor of Laws)", level:"300", creditHours:3 },
  { courseCode:"LAW302",  courseName:"Land Law",                          faculty:"Central Law School", programme:"LLB (Bachelor of Laws)", level:"300", creditHours:3 },
  { courseCode:"LAW401",  courseName:"Legal Practice",                    faculty:"Central Law School", programme:"LLB (Bachelor of Laws)", level:"400", creditHours:3 },
  { courseCode:"LAW402",  courseName:"Moot Court",                        faculty:"Central Law School", programme:"LLB (Bachelor of Laws)", level:"400", creditHours:3 },
];

// ══════════════════════════════════════════════════════════════════
//  TIMETABLE SLOTS
//  Two days per week per course.  Rooms assigned per faculty block.
// ══════════════════════════════════════════════════════════════════
const DAYS_A = [["Mon","Wed"], ["Tue","Thu"], ["Wed","Fri"], ["Mon","Thu"], ["Tue","Fri"]];
const TIMES  = ["8:00 AM","10:00 AM","12:00 PM","2:00 PM","4:00 PM"];
const ROOMS  = {
  "School of Engineering & Technology":          ["ICT Block - LH1","ICT Block - LH2","ICT Block - Lab1","ICT Block - Lab2","ICT Block - Room3"],
  "Central Business School":                     ["CBS Block - Room1","CBS Block - Room2","CBS Block - Room3","CBS Block - LH1"],
  "Faculty of Arts & Social Sciences":           ["Arts Block - Room1","Arts Block - Room2","Arts Block - Room3","Arts Block - LH1"],
  "School of Nursing & Midwifery":               ["Nursing Block - Room1","Nursing Block - Room2","Nursing Block - Lab1"],
  "Central Law School":                          ["Law Block - Room1","Law Block - Room2","Law Block - Moot Court"],
  "School of Architecture & Design":             ["Design Block - Studio1","Design Block - Room1"],
  "School of Medical Sciences":                  ["Medical Block - LH1","Medical Block - Lab1"],
  "School of Pharmacy":                          ["Pharmacy Block - Lab1","Pharmacy Block - Room1"],
  "School of Graduate Studies & Research":       ["Postgrad Block - Room1","Postgrad Block - Room2"],
  "Centre for Distance & Professional Education":["CDPE Block - Room1"],
};

function slotFor(course, idx) {
  const dayPair  = DAYS_A[idx % DAYS_A.length];
  const time     = TIMES[idx % TIMES.length];
  const endHour  = parseInt(time) + 1;
  const endTime  = `${endHour}:30 ${(time.includes("PM") || endHour >= 12) ? "PM" : "AM"}`;
  const roomList = ROOMS[course.faculty] || ["Main Block - Room1"];
  const room     = roomList[idx % roomList.length];
  return dayPair.map(day => ({ courseCode: course.courseCode, day, startTime: time, endTime, room }));
}

const TIMETABLE_SLOTS = [];
COURSES.forEach((c, i) => TIMETABLE_SLOTS.push(...slotFor(c, i)));

// ══════════════════════════════════════════════════════════════════
//  MAIN
// ══════════════════════════════════════════════════════════════════
async function main() {
  console.log("\n🌱  Smart-Attend Seeder — Central University Ghana");
  console.log("──────────────────────────────────────────────────");
  console.log(`   MONGO_URI  : ${process.env.MONGO_URI}`);
  console.log(`   Mode       : ${WIPE_ONLY ? "wipe-only" : WIPE ? "wipe + seed" : "seed only"}`);
  console.log(`   Default pw : ${DEFAULT_PASSWORD}`);
  console.log("──────────────────────────────────────────────────\n");

  await mongoose.connect(process.env.MONGO_URI, {
    serverSelectionTimeoutMS: 8000,
    family: 4,
  });
  console.log("✅  Connected to MongoDB\n");

  // ── Wipe ──────────────────────────────────────────────────────────
  if (WIPE) {
    console.log("🗑   Wiping collections…");
    const db      = mongoose.connection.db;
    const cols    = (await db.listCollections().toArray()).map(c => c.name);
    const targets = ["users","courses","timetables","semesters","attendancesessions","attendances"];
    await Promise.all(
      targets.filter(t => cols.includes(t)).map(t => db.collection(t).drop())
    );
    console.log("    ✓ All collections dropped\n");
  }
  if (WIPE_ONLY) {
    console.log("✅  Wipe complete.");
    await mongoose.disconnect();
    process.exit(0);
  }

  const hashedPw = await hash(DEFAULT_PASSWORD);

  // ── 1. Semesters ──────────────────────────────────────────────────
  console.log("📅  Creating semesters…");
  for (const data of SEMESTERS) {
    if (await Semester.findOne({ name: data.name })) {
      console.log(`    ⚠️  "${data.name}" already exists — skipping`);
    } else {
      const s = await Semester.create(data);
      console.log(`    ✓ ${s.name}${s.isCurrent ? "  [CURRENT]" : ""}`);
    }
  }

  // ── 2. Super Admin ────────────────────────────────────────────────
  console.log("\n🔐  Creating super admin…");
  if (await User.findOne({ email: SUPER_ADMIN.email })) {
    console.log("    ⚠️  Super admin already exists — skipping");
  } else {
    await User.create({ ...SUPER_ADMIN, password: hashedPw });
    console.log(`    ✓ ${SUPER_ADMIN.email}`);
  }

  // ── 3. Faculty Admins ─────────────────────────────────────────────
  console.log("\n🏛   Creating faculty admins…");
  for (const a of ADMINS) {
    if (await User.findOne({ email: a.email })) {
      console.log(`    ⚠️  ${a.email} already exists — skipping`);
    } else {
      await User.create({
        ...a,
        role: "admin",
        password: hashedPw,
        isActive: true,
        mustChangePassword: true,
      });
      console.log(`    ✓ ${a.email}  →  ${a.faculty}`);
    }
  }

  // ── 4. Deans ──────────────────────────────────────────────────────
  console.log("\n🎓  Creating deans…");
  for (const d of DEANS) {
    if (await User.findOne({ email: d.email })) {
      console.log(`    ⚠️  ${d.email} already exists — skipping`);
    } else {
      await User.create({
        ...d,
        role: "dean",
        password: hashedPw,
        department: d.faculty,
        departments: [d.faculty],
        isActive: true,
        mustChangePassword: true,
      });
      console.log(`    ✓ ${d.email}  →  ${d.faculty}`);
    }
  }

  // ── 5. Lecturers ──────────────────────────────────────────────────
  console.log("\n👨‍🏫  Creating lecturers…");
  const lecturerDocs = [];
  for (const data of LECTURERS) {
    const { teaches, ...userData } = data;
    let doc = await User.findOne({ email: userData.email });
    if (doc) {
      console.log(`    ⚠️  ${userData.email} already exists — skipping`);
    } else {
      doc = await User.create({
        ...userData,
        role: "lecturer",
        password: hashedPw,
        department: userData.departments[0],
        isActive: true,
        mustChangePassword: true,
      });
      console.log(`    ✓ ${doc.fullName}  (${doc.staffId})`);
    }
    lecturerDocs.push({ doc, teaches });
  }

  // Build courseCode → lecturerDoc lookup
  const lecturerByCode = {};
  for (const { doc, teaches } of lecturerDocs) {
    for (const code of teaches) lecturerByCode[code] = doc;
  }

  // ── 6. Students ───────────────────────────────────────────────────
  console.log("\n🎒  Creating students…");
  const studentDocs = [];
  for (const data of STUDENTS) {
    const { enrolledIn, ...userData } = data;
    const faculty = PROGRAMME_TO_FACULTY[userData.programme] || "";
    let doc = await User.findOne({ email: userData.email });
    if (doc) {
      console.log(`    ⚠️  ${userData.email} already exists — skipping`);
    } else {
      doc = await User.create({
        ...userData,
        role: "student",
        faculty,
        password: hashedPw,
        mustChangePassword: true,
        enrolledCourses: enrolledIn,
      });
      const tag = !userData.isActive ? "  ⛔ SUSPENDED" : "";
      console.log(`    ✓ ${doc.fullName}  (${doc.indexNumber})  →  ${faculty}${tag}`);
    }
    studentDocs.push({ doc, enrolledIn });
  }

  // ── 7. Courses ────────────────────────────────────────────────────
  console.log("\n📚  Creating courses…");
  const courseDocs = {};
  for (const data of COURSES) {
    let doc = await Course.findOne({ courseCode: data.courseCode });
    if (doc) {
      console.log(`    ⚠️  ${data.courseCode} already exists — skipping`);
    } else {
      const lect      = lecturerByCode[data.courseCode];
      const enrolCount = STUDENTS.filter(s => s.enrolledIn.includes(data.courseCode)).length;
      doc = await Course.create({
        courseCode:           data.courseCode,
        courseName:           data.courseName,
        department:           data.faculty,
        faculty:              data.faculty,
        programme:            data.programme,
        level:                data.level,
        creditHours:          data.creditHours,
        semester:             CURRENT_SEMESTER,
        assignedLecturerId:   lect?._id     ?? null,
        assignedLecturerName: lect?.fullName ?? null,
        enrolledStudents:     enrolCount,
      });
      console.log(`    ✓ ${doc.courseCode}  [${data.programme} L${data.level}]${lect ? "  →  " + lect.fullName : ""}`);
    }
    courseDocs[data.courseCode] = doc;
  }

  // ── 8. Timetable ──────────────────────────────────────────────────
  console.log("\n🗓   Creating timetable slots…");
  let ttCreated = 0;
  for (const slot of TIMETABLE_SLOTS) {
    const course = courseDocs[slot.courseCode];
    if (!course) continue;
    const exists = await Timetable.findOne({
      courseCode: slot.courseCode,
      day:        slot.day,
      startTime:  slot.startTime,
      semester:   CURRENT_SEMESTER,
    });
    if (exists) continue;
    const lect  = lecturerByCode[slot.courseCode];
    const cData = COURSES.find(c => c.courseCode === slot.courseCode);
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
    ttCreated++;
  }
  console.log(`    ✓ ${ttCreated} timetable slots created`);

  // ── 9. Attendance Sessions ────────────────────────────────────────
  console.log("\n📋  Creating sample attendance sessions…");

  const lec1 = lecturerDocs[0].doc;  // Dr. Kwame Asante   (SET)
  const lec2 = lecturerDocs[3].doc;  // Dr. Esi Ankomah    (CBS)
  const lec3 = lecturerDocs[5].doc;  // Dr. Akosua Frimpong (FASS)

  const now         = new Date();
  const twoHoursAgo = new Date(now - 120 * 60_000);
  const oneHourAgo  = new Date(now -  60 * 60_000);
  const in30Mins    = new Date(now +  30 * 60_000);
  const in45Mins    = new Date(now +  45 * 60_000);
  const fiveMinsAgo = new Date(now -   5 * 60_000);

  /**
   * Creates an AttendanceSession and stamps it with the correct HMAC
   * signature and a 6-digit attendance code — exactly as the live
   * POST /api/attendance/sessions endpoint does.
   */
  async function makeSession(data, label) {
    const existing = await AttendanceSession.findOne({
      courseCode: data.courseCode,
      lecturerId: data.lecturerId,
      isActive:   data.isActive,
      expiresAt:  data.expiresAt,
    });
    if (existing) {
      console.log(`    ⚠️  ${label} — skipping`);
      return existing;
    }

    const s = await AttendanceSession.create({
      ...data,
      code:      randomCode(),
      signature: "",
    });

    // Stamp the HMAC signature post-insert (mirrors server behaviour)
    s.signature = hmacSignature(s._id.toString(), s.courseCode, s.expiresAt.getTime());
    await s.save();

    console.log(`    ✓ ${label}  [code: ${s.code}]`);
    return s;
  }

  // ── Session catalogue ─────────────────────────────────────────
  //  sessA  — past ENDED   CS301 (in-person)
  //  sessB  — ACTIVE       CS301 (in-person, expires in 30 min)
  //  sessC  — past ENDED   ACC201 (in-person)
  //  sessD  — ACTIVE       ACC301 (in-person, expires in 45 min)
  //  sessE  — past ENDED   COMM201 (online)
  //  sessF  — ACTIVE but past expiry — CS101 (isActive true, expiresAt past)
  //  sessG  — ACTIVE       IT301 (code-only scenario)
  const sessA = await makeSession({ courseCode:"CS301",   courseName:"Data Structures & Algorithms",  lecturerId:lec1._id, type:"inPerson", lecturerLat:LAT,  lecturerLng:LNG,  expiresAt:oneHourAgo,  isActive:false }, "[ENDED]   CS301");
  const sessB = await makeSession({ courseCode:"CS301",   courseName:"Data Structures & Algorithms",  lecturerId:lec1._id, type:"inPerson", lecturerLat:LAT,  lecturerLng:LNG,  expiresAt:in30Mins,    isActive:true  }, "[ACTIVE]  CS301  (in-person, 30 min remaining)");
  const sessC = await makeSession({ courseCode:"ACC201",  courseName:"Intermediate Accounting",        lecturerId:lec2._id, type:"inPerson", lecturerLat:LAT,  lecturerLng:LNG,  expiresAt:twoHoursAgo, isActive:false }, "[ENDED]   ACC201");
  const sessD = await makeSession({ courseCode:"ACC301",  courseName:"Advanced Financial Accounting",  lecturerId:lec2._id, type:"inPerson", lecturerLat:LAT,  lecturerLng:LNG,  expiresAt:in45Mins,    isActive:true  }, "[ACTIVE]  ACC301 (in-person, 45 min remaining)");
  const sessE = await makeSession({ courseCode:"COMM201", courseName:"Media & Communication Theory",   lecturerId:lec3._id, type:"online",   lecturerLat:null, lecturerLng:null, expiresAt:twoHoursAgo, isActive:false }, "[ENDED]   COMM201 (online)");
  const sessF = await makeSession({ courseCode:"CS101",   courseName:"Introduction to Programming",    lecturerId:lec1._id, type:"inPerson", lecturerLat:LAT,  lecturerLng:LNG,  expiresAt:fiveMinsAgo, isActive:true  }, "[EXPIRED] CS101  (isActive=true but past expiresAt)");
  const sessG = await makeSession({ courseCode:"IT301",   courseName:"Information Security",            lecturerId:lecturerDocs[1].doc._id, type:"online", lecturerLat:null, lecturerLng:null, expiresAt:in30Mins, isActive:true }, "[ACTIVE]  IT301  (online, code entry)");

  // ── 10. Attendance Records ────────────────────────────────────────
  console.log("\n✅  Creating attendance records…");

  // Build courseCode → active student docs map
  const byCode = {};
  for (const { doc, enrolledIn } of studentDocs) {
    for (const code of enrolledIn) {
      if (!byCode[code]) byCode[code] = [];
      if (doc.isActive) byCode[code].push(doc);
    }
  }

  /**
   * Mark a list of students present for a given session.
   * minsBeforeExpiry — how many minutes before expiresAt the check-in occurred.
   * methodOverride   — "qr" | "code" (default "qr")
   */
  async function markPresent(session, students, minsBeforeExpiry = 25, methodOverride = "qr") {
    let n = 0;
    for (const student of students) {
      const exists = await Attendance.findOne({
        sessionId: session._id,
        studentId: student._id,
      });
      if (exists) continue;

      await Attendance.create({
        sessionId:      session._id,
        studentId:      student._id,
        courseCode:     session.courseCode,
        status:         "present",
        method:         methodOverride,
        distanceMetres: Math.floor(Math.random() * 40) + 5,
        studentLat:     nearbyCoord(LAT),
        studentLng:     nearbyCoord(LNG),
        checkedInAt:    new Date(session.expiresAt.getTime() - minsBeforeExpiry * 60_000),
      });
      n++;
    }
    if (n > 0) console.log(`    ✓ ${n} record(s) → ${session.courseCode} (${methodOverride})`);
  }

  // Ended sessions — all enrolled active students present
  await markPresent(sessA, byCode["CS301"]   ?? []);
  await markPresent(sessC, byCode["ACC201"]  ?? []);
  await markPresent(sessE, byCode["COMM201"] ?? [], 25, "qr");

  // Active sessions — partial attendance (realistic mid-session state)
  await markPresent(sessB, (byCode["CS301"]  ?? []).slice(0, 2), 10, "qr");
  await markPresent(sessD, (byCode["ACC301"] ?? []).slice(0, 1), 10, "qr");

  // Online session — a couple of students used the code
  await markPresent(sessG, (byCode["IT301"]  ?? []).slice(0, 1), 15, "code");

  // ── 11. Summary ───────────────────────────────────────────────────
  const [uC, crC, ttC, semC, sC, aC] = await Promise.all([
    User.countDocuments(),
    Course.countDocuments(),
    Timetable.countDocuments(),
    Semester.countDocuments(),
    AttendanceSession.countDocuments(),
    Attendance.countDocuments(),
  ]);

  console.log("\n──────────────────────────────────────────────────");
  console.log("🌱  Seed complete!\n");
  console.log(`   Users                : ${uC}`);
  console.log(`   Courses              : ${crC}`);
  console.log(`   Timetable slots      : ${ttC}`);
  console.log(`   Semesters            : ${semC}`);
  console.log(`   Attendance sessions  : ${sC}`);
  console.log(`   Attendance records   : ${aC}`);

  const pad = (s, n) => String(s).padEnd(n);

  console.log("\n📋  Login credentials (password: Central@123)\n");
  console.log(`   ${pad("Role", 12)}  ${pad("Email", 46)}  Notes`);
  console.log(`   ${"-".repeat(12)}  ${"-".repeat(46)}  ${"-".repeat(40)}`);

  console.log(`   ${pad("super_admin", 12)}  ${pad(SUPER_ADMIN.email, 46)}  University-wide access`);

  for (const a of ADMINS)
    console.log(`   ${pad("admin", 12)}  ${pad(a.email, 46)}  ${a.faculty}`);

  for (const d of DEANS)
    console.log(`   ${pad("dean", 12)}  ${pad(d.email, 46)}  ${d.faculty}`);

  for (const l of LECTURERS)
    console.log(`   ${pad("lecturer", 12)}  ${pad(l.email, 46)}  ${l.departments.join(", ")}`);

  for (const s of STUDENTS) {
    const note = !s.isActive ? "⛔ SUSPENDED" : s.programme;
    console.log(`   ${pad("student", 12)}  ${pad(s.email, 46)}  ${note}`);
  }

  console.log("\n📌  Attendance sessions seeded:");
  console.log("   [ENDED]    CS301  (in-person)  — Dr. Kwame Asante");
  console.log("   [ACTIVE]   CS301  (in-person)  — Dr. Kwame Asante   30 min remaining");
  console.log("   [ENDED]    ACC201 (in-person)  — Dr. Esi Ankomah");
  console.log("   [ACTIVE]   ACC301 (in-person)  — Dr. Esi Ankomah    45 min remaining");
  console.log("   [ENDED]    COMM201 (online)    — Dr. Akosua Frimpong");
  console.log("   [EXPIRED]  CS101  (in-person)  — isActive=true but expiresAt in past");
  console.log("   [ACTIVE]   IT301  (online)     — Mr. Kofi Owusu      30 min remaining");
  console.log("──────────────────────────────────────────────────\n");

  await mongoose.disconnect();
  process.exit(0);
}

main().catch(err => {
  console.error("\n❌  Seeder error:", err.message);
  console.error(err);
  mongoose.disconnect();
  process.exit(1);
});