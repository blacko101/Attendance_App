/**
 * seed.js — Smart-Attend database seeder
 *
 * Creates every collection the app needs. Collections that do not yet
 * have a dedicated model file are defined inline here with a Mongoose
 * schema — the seeder is the single source of truth for test data.
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
 *  users               — admin, dean, lecturers, students
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
//  Existing models are loaded from their files.
//  New collections (Course, Timetable, Semester) are defined inline
//  so the seeder works without touching the src/ folder.
// ══════════════════════════════════════════════════════════════════

const User              = require("./src/models/User");
const AttendanceSession = require("./src/models/AttendanceSession");
const Attendance        = require("./src/models/Attendance");

// ── Course ────────────────────────────────────────────────────────
const courseSchema = new mongoose.Schema({
  courseCode:           { type: String, required: true, unique: true, trim: true },
  courseName:           { type: String, required: true, trim: true },
  department:           { type: String, required: true, trim: true },
  creditHours:          { type: Number, default: 3 },
  semester:             { type: String, required: true },
  assignedLecturerId:   { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
  assignedLecturerName: { type: String, default: null },
  enrolledStudents:     { type: Number, default: 0 },
}, { timestamps: true });

const Course = mongoose.models.Course
  || mongoose.model("Course", courseSchema);

// ── Timetable ─────────────────────────────────────────────────────
const timetableSchema = new mongoose.Schema({
  courseId:     { type: mongoose.Schema.Types.ObjectId, ref: "Course", required: true },
  courseCode:   { type: String, required: true, trim: true },
  courseName:   { type: String, required: true, trim: true },
  lecturerId:   { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
  lecturerName: { type: String, default: "" },
  day:          { type: String, enum: ["Mon","Tue","Wed","Thu","Fri","Sat"], required: true },
  startTime:    { type: String, required: true },   // "10:00 AM"
  endTime:      { type: String, required: true },   // "11:30 AM"
  room:         { type: String, default: "" },
  level:        { type: String, default: "" },      // "100","200","300","400","500"
  programme:    { type: String, default: "" },
  semester:     { type: String, required: true },
}, { timestamps: true });

const Timetable = mongoose.models.Timetable
  || mongoose.model("Timetable", timetableSchema);

// ── Semester ──────────────────────────────────────────────────────
const semesterSchema = new mongoose.Schema({
  name:          { type: String, required: true, unique: true, trim: true },
  startDate:     { type: Date, required: true },
  endDate:       { type: Date, required: true },
  teachingWeeks: { type: Number, required: true },
  isCurrent:     { type: Boolean, default: false },
}, { timestamps: true });

const Semester = mongoose.models.Semester
  || mongoose.model("Semester", semesterSchema);

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

// Random GPS offset — simulates students standing near the lecturer
function nearbyCoord(base, maxDeg = 0.0005) {
  return base + (Math.random() * 2 - 1) * maxDeg;
}

// ══════════════════════════════════════════════════════════════════
//  SEED DATA
//  Central University, Ghana — Miotso Campus
// ══════════════════════════════════════════════════════════════════

// Campus GPS
const LAT = 5.7172;
const LNG = -0.0747;

// ── Semesters ─────────────────────────────────────────────────────
const SEMESTERS = [
  {
    name:          "2025/2026 Semester 2",
    startDate:     new Date("2026-01-13"),
    endDate:       new Date("2026-05-23"),
    teachingWeeks: 15,
    isCurrent:     true,
  },
  {
    name:          "2025/2026 Semester 1",
    startDate:     new Date("2025-08-25"),
    endDate:       new Date("2025-12-20"),
    teachingWeeks: 15,
    isCurrent:     false,
  },
  {
    name:          "2024/2025 Semester 2",
    startDate:     new Date("2025-01-13"),
    endDate:       new Date("2025-05-23"),
    teachingWeeks: 15,
    isCurrent:     false,
  },
];

const CURRENT_SEMESTER = "2025/2026 Semester 2";

// ── Admin ─────────────────────────────────────────────────────────
const ADMIN = {
  fullName:           "System Administrator",
  email:              "admin@central.edu.gh",
  role:               "admin",
  staffId:            "STF/ADMIN/001",
  department:         "IT Services",
  isActive:           true,
  mustChangePassword: true,
};

// ── Dean ──────────────────────────────────────────────────────────
const DEAN = {
  fullName:           "Prof. Emmanuel Darko",
  email:              "dean.set@central.edu.gh",
  role:               "dean",
  staffId:            "STF/DEAN/001",
  department:         "School of Engineering & Technology",
  isActive:           true,
  mustChangePassword: true,
};

// ── Lecturers ─────────────────────────────────────────────────────
// The `teaches` array lists course codes this lecturer is assigned to.
const LECTURERS = [
  {
    fullName:           "Dr. Kwame Asante",
    email:              "kwame.asante@central.edu.gh",
    role:               "lecturer",
    staffId:            "STF/2018/0012",
    department:         "Computer Science & Engineering",
    isActive:           true,
    mustChangePassword: true,
    teaches:            ["CS301", "CS201", "CS401"],
  },
  {
    fullName:           "Dr. Abena Mensah",
    email:              "abena.mensah@central.edu.gh",
    role:               "lecturer",
    staffId:            "STF/2019/0034",
    department:         "Mathematics & Statistics",
    isActive:           true,
    mustChangePassword: true,
    teaches:            ["MATH201", "MATH301"],
  },
  {
    fullName:           "Mr. Kofi Owusu",
    email:              "kofi.owusu@central.edu.gh",
    role:               "lecturer",
    staffId:            "STF/2020/0056",
    department:         "Computer Science & Engineering",
    isActive:           true,
    mustChangePassword: true,
    teaches:            ["CS101", "CS202"],
  },
];

// ── Students ──────────────────────────────────────────────────────
const STUDENTS = [
  {
    fullName:           "Ama Boateng",
    email:              "ama.boateng@central.edu.gh",
    role:               "student",
    indexNumber:        "CU/CS/2022/001",
    programme:          "BSc. Computer Science",
    level:              "300",
    isActive:           true,
    mustChangePassword: true,
    enrolledIn:         ["CS301", "CS201", "CS401", "MATH201"],
  },
  {
    fullName:           "Yaw Darko",
    email:              "yaw.darko@central.edu.gh",
    role:               "student",
    indexNumber:        "CU/CS/2022/002",
    programme:          "BSc. Computer Science",
    level:              "300",
    isActive:           true,
    mustChangePassword: true,
    enrolledIn:         ["CS301", "CS201", "CS401", "MATH201"],
  },
  {
    fullName:           "Efua Asante",
    email:              "efua.asante@central.edu.gh",
    role:               "student",
    indexNumber:        "CU/CS/2022/003",
    programme:          "BSc. Computer Science",
    level:              "300",
    isActive:           true,
    mustChangePassword: true,
    enrolledIn:         ["CS301", "CS201", "CS401"],
  },
  {
    fullName:           "Kweku Frimpong",
    email:              "kweku.frimpong@central.edu.gh",
    role:               "student",
    indexNumber:        "CU/CS/2022/004",
    programme:          "BSc. Computer Science",
    level:              "300",
    isActive:           true,
    mustChangePassword: true,
    enrolledIn:         ["CS301", "CS201", "MATH201"],
  },
  {
    fullName:           "Akosua Nkrumah",
    email:              "akosua.nkrumah@central.edu.gh",
    role:               "student",
    indexNumber:        "CU/CS/2023/001",
    programme:          "BSc. Computer Science",
    level:              "200",
    isActive:           true,
    mustChangePassword: true,
    enrolledIn:         ["CS101", "CS202", "MATH201"],
  },
  {
    fullName:           "Kobina Aidoo",
    email:              "kobina.aidoo@central.edu.gh",
    role:               "student",
    indexNumber:        "CU/CS/2022/005",
    programme:          "BSc. Computer Science",
    level:              "300",
    isActive:           false,               // SUSPENDED — tests auth guard
    mustChangePassword: true,
    enrolledIn:         ["CS301", "CS201"],
  },
  {
    fullName:           "Adwoa Poku",
    email:              "adwoa.poku@central.edu.gh",
    role:               "student",
    indexNumber:        "CU/MATH/2022/001",
    programme:          "BSc. Mathematics",
    level:              "300",
    isActive:           true,
    mustChangePassword: true,
    enrolledIn:         ["MATH201", "MATH301"],
  },
  {
    fullName:           "Fiifi Mensah",
    email:              "fiifi.mensah@central.edu.gh",
    role:               "student",
    indexNumber:        "CU/MATH/2022/002",
    programme:          "BSc. Mathematics",
    level:              "300",
    isActive:           true,
    mustChangePassword: true,
    enrolledIn:         ["MATH201", "MATH301"],
  },
  {
    fullName:           "Nana Esi Appiah",
    email:              "nana.appiah@central.edu.gh",
    role:               "student",
    indexNumber:        "CU/CS/2023/002",
    programme:          "BSc. Computer Science",
    level:              "200",
    isActive:           true,
    mustChangePassword: true,
    enrolledIn:         ["CS101", "CS202"],
  },
  {
    fullName:           "Ato Quaye",
    email:              "ato.quaye@central.edu.gh",
    role:               "student",
    indexNumber:        "CU/IT/2022/001",
    programme:          "BSc. Information Technology",
    level:              "300",
    isActive:           true,
    mustChangePassword: true,
    enrolledIn:         ["CS301", "CS202", "MATH201"],
  },
];

// ── Course catalogue ──────────────────────────────────────────────
// assignedLecturer is resolved at runtime using LECTURERS[].teaches
const COURSES = [
  {
    courseCode:  "CS101",
    courseName:  "Introduction to Programming",
    department:  "Computer Science & Engineering",
    creditHours: 3,
    level:       "100",
    programme:   "BSc. Computer Science",
  },
  {
    courseCode:  "CS201",
    courseName:  "Object Oriented Programming",
    department:  "Computer Science & Engineering",
    creditHours: 3,
    level:       "200",
    programme:   "BSc. Computer Science",
  },
  {
    courseCode:  "CS202",
    courseName:  "Database Systems",
    department:  "Computer Science & Engineering",
    creditHours: 3,
    level:       "200",
    programme:   "BSc. Computer Science",
  },
  {
    courseCode:  "CS301",
    courseName:  "Data Structures & Algorithms",
    department:  "Computer Science & Engineering",
    creditHours: 3,
    level:       "300",
    programme:   "BSc. Computer Science",
  },
  {
    courseCode:  "CS401",
    courseName:  "Software Engineering",
    department:  "Computer Science & Engineering",
    creditHours: 3,
    level:       "400",
    programme:   "BSc. Computer Science",
  },
  {
    courseCode:  "MATH201",
    courseName:  "Linear Algebra",
    department:  "Mathematics & Statistics",
    creditHours: 3,
    level:       "200",
    programme:   "BSc. Mathematics",
  },
  {
    courseCode:  "MATH301",
    courseName:  "Numerical Methods",
    department:  "Mathematics & Statistics",
    creditHours: 3,
    level:       "300",
    programme:   "BSc. Mathematics",
  },
];

// ── Timetable slots ───────────────────────────────────────────────
// day, startTime, endTime, room — resolved per course code
const TIMETABLE_SLOTS = [
  // CS101 — Mon & Wed (Level 100)
  { courseCode: "CS101", day: "Mon", startTime: "8:00 AM",  endTime: "9:30 AM",  room: "ICT Block - Lecture Hall 1" },
  { courseCode: "CS101", day: "Wed", startTime: "8:00 AM",  endTime: "9:30 AM",  room: "ICT Block - Lecture Hall 1" },

  // CS201 — Mon & Wed (Level 200)
  { courseCode: "CS201", day: "Mon", startTime: "10:00 AM", endTime: "11:30 AM", room: "ICT Block - Room 3" },
  { courseCode: "CS201", day: "Wed", startTime: "10:00 AM", endTime: "11:30 AM", room: "ICT Block - Room 3" },

  // CS202 — Tue & Thu (Level 200)
  { courseCode: "CS202", day: "Tue", startTime: "12:00 PM", endTime: "1:30 PM",  room: "ICT Block - Lab 2" },
  { courseCode: "CS202", day: "Thu", startTime: "12:00 PM", endTime: "1:30 PM",  room: "ICT Block - Lab 2" },

  // CS301 — Tue & Fri (Level 300)
  { courseCode: "CS301", day: "Tue", startTime: "10:00 AM", endTime: "11:30 AM", room: "ICT Block - Lab 1" },
  { courseCode: "CS301", day: "Fri", startTime: "10:00 AM", endTime: "11:30 AM", room: "ICT Block - Lab 1" },

  // CS401 — Wed & Fri (Level 400)
  { courseCode: "CS401", day: "Wed", startTime: "2:00 PM",  endTime: "3:30 PM",  room: "Block A - Room 7" },
  { courseCode: "CS401", day: "Fri", startTime: "2:00 PM",  endTime: "3:30 PM",  room: "Block A - Room 7" },

  // MATH201 — Mon & Thu (Level 200)
  { courseCode: "MATH201", day: "Mon", startTime: "12:00 PM", endTime: "1:30 PM", room: "Science Block - Room 2" },
  { courseCode: "MATH201", day: "Thu", startTime: "12:00 PM", endTime: "1:30 PM", room: "Science Block - Room 2" },

  // MATH301 — Tue & Thu (Level 300)
  { courseCode: "MATH301", day: "Tue", startTime: "2:00 PM",  endTime: "3:30 PM", room: "Science Block - Room 5" },
  { courseCode: "MATH301", day: "Thu", startTime: "2:00 PM",  endTime: "3:30 PM", room: "Science Block - Room 5" },
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
  // drop() removes the collection AND its indexes so stale unique
  // indexes from schema changes don't cause E11000 on the next insert.
  if (WIPE) {
    console.log("🗑   Wiping collections…");
    const db   = mongoose.connection.db;
    const cols = (await db.listCollections().toArray()).map((c) => c.name);

    const targets = [
      "users", "courses", "timetables", "semesters",
      "attendancesessions", "attendances",
    ];
    await Promise.all(
      targets
        .filter((t) => cols.includes(t))
        .map((t) => db.collection(t).drop())
    );
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
  const semesterDocs = [];
  for (const data of SEMESTERS) {
    let doc = await Semester.findOne({ name: data.name });
    if (doc) {
      console.log(`    ⚠️  "${data.name}" already exists — skipping`);
    } else {
      doc = await Semester.create(data);
      console.log(`    ✓ ${doc.name}${doc.isCurrent ? "  [CURRENT]" : ""}`);
    }
    semesterDocs.push(doc);
  }

  // ─── 2. Admin ────────────────────────────────────────────────────
  console.log("\n👤  Creating admin…");
  let admin = await User.findOne({ email: ADMIN.email });
  if (admin) {
    console.log("    ⚠️  Admin already exists — skipping");
  } else {
    admin = await User.create({ ...ADMIN, password: hashedPw });
    console.log(`    ✓ ${admin.fullName}  (${admin.email})`);
  }

  // ─── 3. Dean ─────────────────────────────────────────────────────
  console.log("\n🎓  Creating dean…");
  let dean = await User.findOne({ email: DEAN.email });
  if (dean) {
    console.log("    ⚠️  Dean already exists — skipping");
  } else {
    dean = await User.create({ ...DEAN, password: hashedPw });
    console.log(`    ✓ ${dean.fullName}  (${dean.email})`);
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
      doc = await User.create({ ...userData, password: hashedPw });
      console.log(`    ✓ ${doc.fullName}  (${doc.staffId})`);
    }
    lecturerDocs.push({ doc, teaches });
  }

  // ─── 5. Students ─────────────────────────────────────────────────
  console.log("\n🎒  Creating students…");
  const studentDocs = [];
  for (const data of STUDENTS) {
    const { enrolledIn, ...userData } = data;
    let doc = await User.findOne({ email: userData.email });
    if (doc) {
      console.log(`    ⚠️  ${userData.email} already exists — skipping`);
    } else {
      doc = await User.create({ ...userData, password: hashedPw });
      const tag = !userData.isActive ? "  ⛔ SUSPENDED" : "";
      console.log(`    ✓ ${doc.fullName}  (${doc.indexNumber})${tag}`);
    }
    studentDocs.push({ doc, enrolledIn });
  }

  // Build lookup maps for later steps
  const lecturerByCode = {};   // courseCode → lecturerDoc
  for (const { doc, teaches } of lecturerDocs) {
    for (const code of teaches) {
      lecturerByCode[code] = doc;
    }
  }

  const studentByEmail = {};   // email → { doc, enrolledIn }
  for (const s of studentDocs) {
    studentByEmail[s.doc.email] = s;
  }

  // ─── 6. Courses ──────────────────────────────────────────────────
  console.log("\n📚  Creating courses…");
  const courseDocs = {};   // courseCode → Course document

  for (const data of COURSES) {
    let doc = await Course.findOne({ courseCode: data.courseCode });
    if (doc) {
      console.log(`    ⚠️  ${data.courseCode} already exists — skipping`);
    } else {
      const lect  = lecturerByCode[data.courseCode];
      // Count enrolled students from seed data
      const enrolCount = STUDENTS.filter((s) =>
        s.enrolledIn.includes(data.courseCode)
      ).length;

      doc = await Course.create({
        courseCode:           data.courseCode,
        courseName:           data.courseName,
        department:           data.department,
        creditHours:          data.creditHours,
        semester:             CURRENT_SEMESTER,
        assignedLecturerId:   lect?._id   ?? null,
        assignedLecturerName: lect?.fullName ?? null,
        enrolledStudents:     enrolCount,
      });
      const lectLabel = lect ? `  →  ${lect.fullName}` : "  →  (unassigned)";
      console.log(`    ✓ ${doc.courseCode}  ${doc.courseName}${lectLabel}`);
    }
    courseDocs[data.courseCode] = doc;
  }

  // ─── 7. Timetable ────────────────────────────────────────────────
  console.log("\n🗓   Creating timetable slots…");
  for (const slot of TIMETABLE_SLOTS) {
    const course = courseDocs[slot.courseCode];
    if (!course) continue;

    const exists = await Timetable.findOne({
      courseCode: slot.courseCode,
      day:        slot.day,
      startTime:  slot.startTime,
      semester:   CURRENT_SEMESTER,
    });
    if (exists) {
      console.log(`    ⚠️  ${slot.courseCode} ${slot.day} ${slot.startTime} already exists — skipping`);
      continue;
    }

    const lect = lecturerByCode[slot.courseCode];
    const cData = COURSES.find((c) => c.courseCode === slot.courseCode);

    await Timetable.create({
      courseId:     course._id,
      courseCode:   slot.courseCode,
      courseName:   course.courseName,
      lecturerId:   lect?._id    ?? null,
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

  const twoHoursAgo  = new Date(Date.now() - 120 * 60 * 1000);
  const oneHourAgo   = new Date(Date.now() -  60 * 60 * 1000);
  const in30Mins     = new Date(Date.now() +  30 * 60 * 1000);
  const in45Mins     = new Date(Date.now() +  45 * 60 * 1000);
  const fiveMinsAgo  = new Date(Date.now() -   5 * 60 * 1000);  // expired

  // Creates a session and stamps the real HMAC signature
  async function makeSession(data, label) {
    const existing = await AttendanceSession.findOne({
      courseCode: data.courseCode,
      lecturerId: data.lecturerId,
      isActive:   data.isActive,
      expiresAt:  data.expiresAt,
    });
    if (existing) {
      console.log(`    ⚠️  ${label} already exists — skipping`);
      return existing;
    }
    const s = await AttendanceSession.create({ ...data, signature: "pending" });
    s.signature = hmac(s._id.toString(), s.courseCode, s.expiresAt.getTime());
    await s.save();
    console.log(`    ✓ ${label}`);
    return s;
  }

  // ── Session A — CS301 ended (historical) ─
  const sessA = await makeSession({
    courseCode: "CS301", courseName: "Data Structures & Algorithms",
    lecturerId: lec1._id, type: "inPerson",
    lecturerLat: LAT, lecturerLng: LNG,
    expiresAt: oneHourAgo, isActive: false,
  }, "[ENDED]    CS301  (Dr. Kwame Asante)");

  // ── Session B — CS301 ACTIVE (live, in-person) ─
  const sessB = await makeSession({
    courseCode: "CS301", courseName: "Data Structures & Algorithms",
    lecturerId: lec1._id, type: "inPerson",
    lecturerLat: LAT, lecturerLng: LNG,
    expiresAt: in30Mins, isActive: true,
  }, "[ACTIVE]   CS301  (Dr. Kwame Asante)  — expires in 30 min");

  // ── Session C — CS201 ended ─
  const sessC = await makeSession({
    courseCode: "CS201", courseName: "Object Oriented Programming",
    lecturerId: lec1._id, type: "inPerson",
    lecturerLat: LAT + 0.001, lecturerLng: LNG + 0.001,
    expiresAt: twoHoursAgo, isActive: false,
  }, "[ENDED]    CS201  (Dr. Kwame Asante)");

  // ── Session D — CS401 ended ─
  const sessD = await makeSession({
    courseCode: "CS401", courseName: "Software Engineering",
    lecturerId: lec1._id, type: "inPerson",
    lecturerLat: LAT, lecturerLng: LNG,
    expiresAt: twoHoursAgo, isActive: false,
  }, "[ENDED]    CS401  (Dr. Kwame Asante)");

  // ── Session E — MATH201 ACTIVE online ─
  const sessE = await makeSession({
    courseCode: "MATH201", courseName: "Linear Algebra",
    lecturerId: lec2._id, type: "online",
    lecturerLat: null, lecturerLng: null,
    expiresAt: in45Mins, isActive: true,
  }, "[ACTIVE]   MATH201  (Dr. Abena Mensah)  [ONLINE]");

  // ── Session F — MATH301 ended ─
  const sessF = await makeSession({
    courseCode: "MATH301", courseName: "Numerical Methods",
    lecturerId: lec2._id, type: "inPerson",
    lecturerLat: LAT - 0.001, lecturerLng: LNG - 0.001,
    expiresAt: twoHoursAgo, isActive: false,
  }, "[ENDED]    MATH301  (Dr. Abena Mensah)");

  // ── Session G — CS101 expired but still isActive=true ─
  // Tests the server-side expiry guard when a student tries to check in
  const sessG = await makeSession({
    courseCode: "CS101", courseName: "Introduction to Programming",
    lecturerId: lec3._id, type: "inPerson",
    lecturerLat: LAT - 0.001, lecturerLng: LNG - 0.001,
    expiresAt: fiveMinsAgo, isActive: true,
  }, "[EXPIRED]  CS101  (Mr. Kofi Owusu)  — isActive=true but QR expired");

  // ── Session H — CS202 ended ─
  const sessH = await makeSession({
    courseCode: "CS202", courseName: "Database Systems",
    lecturerId: lec3._id, type: "inPerson",
    lecturerLat: LAT, lecturerLng: LNG,
    expiresAt: oneHourAgo, isActive: false,
  }, "[ENDED]    CS202  (Mr. Kofi Owusu)");

  // ─── 9. Attendance records ────────────────────────────────────────
  // Populate ended sessions with realistic attendance data so that the
  // student history screen, calendar screen, and dean analytics all
  // have real numbers to display.
  console.log("\n✅  Creating attendance records…");

  // Helper — mark a list of students present in a session
  async function markPresent(session, students, options = {}) {
    const {
      lat     = LAT,
      lng     = LNG,
      method  = "qr",
      minsBeforeExpiry = 25,
    } = options;

    let created = 0;
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
        method,
        distanceMetres: Math.floor(Math.random() * 85) + 3,
        studentLat:     lat  != null ? nearbyCoord(lat)  : null,
        studentLng:     lng  != null ? nearbyCoord(lng)  : null,
        checkedInAt:    new Date(
          session.expiresAt.getTime() - minsBeforeExpiry * 60 * 1000
        ),
      });
      created++;
    }
    if (created > 0) {
      console.log(`    ✓ ${created} record(s)  →  ${session.courseCode}`);
    }
  }

  // Resolve student docs by enrolled course
  const byCode = {};   // courseCode → [studentDoc]
  for (const { doc, enrolledIn } of studentDocs) {
    for (const code of enrolledIn) {
      if (!byCode[code]) byCode[code] = [];
      if (doc.isActive) byCode[code].push(doc);
    }
  }

  // ── Ended CS301 — all enrolled active students attended ─
  await markPresent(sessA, byCode["CS301"] ?? []);

  // ── Ended CS201 — 3 out of 4 attended (realistic absence) ─
  await markPresent(sessC, (byCode["CS201"] ?? []).slice(0, 3));

  // ── Ended CS401 — full attendance ─
  await markPresent(sessD, byCode["CS401"] ?? []);

  // ── Ended MATH301 — 2 students attended ─
  await markPresent(sessF, (byCode["MATH301"] ?? []).slice(0, 2));

  // ── Ended CS202 — 3 students attended ─
  await markPresent(sessH, (byCode["CS202"] ?? []).slice(0, 3));

  // ── Active CS301 — 2 students already checked in before you test ─
  await markPresent(sessB, (byCode["CS301"] ?? []).slice(0, 2),
    { minsBeforeExpiry: 10 });

  // ── Active MATH201 online — 1 student already checked in ─
  await markPresent(sessE, (byCode["MATH201"] ?? []).slice(0, 1),
    { lat: null, lng: null, method: "qr", minsBeforeExpiry: 5 });

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
  console.log(`   ${pad("Role", 10)}  ${pad("Email", 44)}  Notes`);
  console.log(`   ${pad("──────────",10)}  ${pad("────────────────────────────────────────────",44)}  ──────────────────────────`);
  console.log(`   ${pad("Admin",    10)}  ${pad(ADMIN.email, 44)}  mustChangePassword: true`);
  console.log(`   ${pad("Dean",     10)}  ${pad(DEAN.email,  44)}  mustChangePassword: true`);
  for (const l of LECTURERS) {
    console.log(`   ${pad("Lecturer", 10)}  ${pad(l.email, 44)}  mustChangePassword: true`);
  }
  for (const s of STUDENTS) {
    const note = !s.isActive
      ? "⛔ SUSPENDED — tests auth guard"
      : "mustChangePassword: true";
    console.log(`   ${pad("Student", 10)}  ${pad(s.email, 44)}  ${note}`);
  }

  console.log("\n📌  Sessions summary:");
  console.log("   [ENDED]   CS301, CS201, CS401, MATH301, CS202  — has attendance history");
  console.log("   [ACTIVE]  CS301 (in-person, 2 already checked in)");
  console.log("   [ACTIVE]  MATH201 (online, 1 already checked in)");
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