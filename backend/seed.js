/**
 * seed.js — Smart-Attend database seeder
 *
 * Usage:
 *   node seed.js            — seed the database
 *   node seed.js --wipe     — wipe all collections first, then seed
 *   node seed.js --wipe-only — wipe all collections and exit (no seed)
 *
 * ⚠️  NEVER run --wipe or --wipe-only against a production database.
 *     The script reads MONGO_URI from .env — double-check it points
 *     to your development/test database before running.
 */

require("dotenv").config();

const mongoose  = require("mongoose");
const bcrypt    = require("bcryptjs");
const crypto    = require("crypto");

// ── Models ─────────────────────────────────────────────────────────
const User              = require("./src/models/User");
const AttendanceSession = require("./src/models/AttendanceSession");
const Attendance        = require("./src/models/Attendance");

// ── CLI flags ──────────────────────────────────────────────────────
const args     = process.argv.slice(2);
const WIPE     = args.includes("--wipe") || args.includes("--wipe-only");
const WIPE_ONLY = args.includes("--wipe-only");

// ── Helpers ────────────────────────────────────────────────────────
const hash = (pw) => bcrypt.hash(pw, 10);

function generateSignature(sessionId, courseCode, expiresAtMs) {
  const QR_SECRET = process.env.QR_SECRET || "smart_attend_qr_secret";
  return crypto
    .createHmac("sha256", QR_SECRET)
    .update(`${sessionId}:${courseCode}:${expiresAtMs}`)
    .digest("hex");
}

// ─────────────────────────────────────────────────────────────────
//  SEED DATA DEFINITIONS
// ─────────────────────────────────────────────────────────────────

const ADMIN_DATA = {
  fullName:   "System Admin",
  email:      "admin@smartattend.dev",
  password:   "Admin@1234",          // change immediately after first login
  role:       "admin",
  department: "IT Services",
  isActive:   true,
};

const LECTURER_DATA = [
  {
    fullName:   "Dr. Kwame Mensah",
    email:      "kwame.mensah@smartattend.dev",
    password:   "Lecturer@1234",
    role:       "lecturer",
    staffId:    "STF-001",
    department: "Computer Science",
    isActive:   true,
  },
  {
    fullName:   "Prof. Ama Owusu",
    email:      "ama.owusu@smartattend.dev",
    password:   "Lecturer@1234",
    role:       "lecturer",
    staffId:    "STF-002",
    department: "Mathematics",
    isActive:   true,
  },
];

const STUDENT_DATA = [
  {
    fullName:    "Kofi Agyeman",
    email:       "kofi.agyeman@student.dev",
    password:    "Student@1234",
    role:        "student",
    indexNumber: "CS/2021/001",
    programme:   "BSc Computer Science",
    level:       "300",
    isActive:    true,
  },
  {
    fullName:    "Abena Boateng",
    email:       "abena.boateng@student.dev",
    password:    "Student@1234",
    role:        "student",
    indexNumber: "CS/2021/002",
    programme:   "BSc Computer Science",
    level:       "300",
    isActive:    true,
  },
  {
    fullName:    "Yaw Darko",
    email:       "yaw.darko@student.dev",
    password:    "Student@1234",
    role:        "student",
    indexNumber: "CS/2021/003",
    programme:   "BSc Computer Science",
    level:       "300",
    isActive:    true,
  },
  {
    fullName:    "Efua Asante",
    email:       "efua.asante@student.dev",
    password:    "Student@1234",
    role:        "student",
    indexNumber: "MATH/2022/001",
    programme:   "BSc Mathematics",
    level:       "200",
    isActive:    true,
  },
  {
    fullName:    "Kweku Frimpong",
    email:       "kweku.frimpong@student.dev",
    password:    "Student@1234",
    role:        "student",
    indexNumber: "CS/2021/004",
    programme:   "BSc Computer Science",
    level:       "300",
    isActive:    false, // suspended — tests the isActive middleware guard
  },
];

// ─────────────────────────────────────────────────────────────────
//  MAIN
// ─────────────────────────────────────────────────────────────────
async function main() {
  console.log("\n🌱  Smart-Attend Seeder");
  console.log("─────────────────────────────────────");
  console.log(`   MONGO_URI : ${process.env.MONGO_URI}`);
  console.log(`   Mode      : ${WIPE_ONLY ? "wipe-only" : WIPE ? "wipe + seed" : "seed only"}`);
  console.log("─────────────────────────────────────\n");

  // ── Connect ──────────────────────────────────
  await mongoose.connect(process.env.MONGO_URI, {
    serverSelectionTimeoutMS: 5000,
    family: 4,
  });
  console.log("✅  Connected to MongoDB\n");

  // ── Wipe ─────────────────────────────────────
  // FIX: use drop() instead of deleteMany({}).
  // deleteMany() only removes documents — it leaves all indexes intact.
  // If the schema has changed since the collection was first created,
  // stale indexes on old field names survive the wipe and cause
  // E11000 duplicate key errors on the very next insert (because the
  // old fields are all null, which the unique index treats as a
  // duplicate on the second document).
  // drop() removes the collection AND all its indexes entirely.
  // The next insert recreates the collection fresh with current indexes.
  if (WIPE) {
    console.log("🗑   Wiping collections…");
    const db = mongoose.connection.db;
    const existingCollections = await db.listCollections().toArray();
    const names = existingCollections.map((c) => c.name);

    await Promise.all([
      names.includes("users")             ? db.collection("users").drop()             : Promise.resolve(),
      names.includes("attendancesessions") ? db.collection("attendancesessions").drop() : Promise.resolve(),
      names.includes("attendances")        ? db.collection("attendances").drop()        : Promise.resolve(),
    ]);
    console.log("    ✓ Users, Sessions and Attendance dropped (indexes cleared)\n");
  }

  if (WIPE_ONLY) {
    console.log("✅  Wipe complete. Exiting.");
    await mongoose.disconnect();
    process.exit(0);
  }

  // ─── 1. Admin ────────────────────────────────
  console.log("👤  Creating admin…");
  let admin = await User.findOne({ email: ADMIN_DATA.email });
  if (admin) {
    console.log("    ⚠️  Admin already exists — skipping");
  } else {
    admin = await User.create({
      ...ADMIN_DATA,
      password: await hash(ADMIN_DATA.password),
    });
    console.log(`    ✓ ${admin.fullName} (${admin.email})`);
  }

  // ─── 2. Lecturers ────────────────────────────
  console.log("\n👨‍🏫  Creating lecturers…");
  const lecturers = [];
  for (const data of LECTURER_DATA) {
    let lecturer = await User.findOne({ email: data.email });
    if (lecturer) {
      console.log(`    ⚠️  ${data.email} already exists — skipping`);
    } else {
      lecturer = await User.create({
        ...data,
        password: await hash(data.password),
      });
      console.log(`    ✓ ${lecturer.fullName} (${lecturer.email})`);
    }
    lecturers.push(lecturer);
  }

  // ─── 3. Students ─────────────────────────────
  console.log("\n🎓  Creating students…");
  const students = [];
  for (const data of STUDENT_DATA) {
    let student = await User.findOne({ email: data.email });
    if (student) {
      console.log(`    ⚠️  ${data.email} already exists — skipping`);
    } else {
      student = await User.create({
        ...data,
        password: await hash(data.password),
      });
      const flag = !student.isActive ? " [SUSPENDED]" : "";
      console.log(`    ✓ ${student.fullName} (${student.indexNumber})${flag}`);
    }
    students.push(student);
  }

  // ─── 4. Attendance sessions ───────────────────
  console.log("\n📋  Creating sample attendance sessions…");

  // Session 1 — ended (historical record)
  const pastExpiry  = new Date(Date.now() - 60 * 60 * 1000); // 1 hour ago
  let session1 = await AttendanceSession.findOne({
    courseCode: "CS301", lecturerId: lecturers[0]._id, isActive: false,
  });

  if (!session1) {
    session1 = await AttendanceSession.create({
      courseCode:  "CS301",
      courseName:  "Data Structures & Algorithms",
      lecturerId:  lecturers[0]._id,
      type:        "inPerson",
      lecturerLat: 5.6037,
      lecturerLng: -0.1870,
      expiresAt:   pastExpiry,
      signature:   "pending",            // will be set below
      isActive:    false,
    });
    session1.signature = generateSignature(
      session1._id.toString(),
      session1.courseCode,
      session1.expiresAt.getTime()
    );
    await session1.save();
    console.log(`    ✓ [ENDED] ${session1.courseCode} — ${session1.courseName}`);
  } else {
    console.log(`    ⚠️  Session CS301 (ended) already exists — skipping`);
  }

  // Session 2 — active (live right now)
  const futureExpiry = new Date(Date.now() + 30 * 60 * 1000); // expires in 30 min
  let session2 = await AttendanceSession.findOne({
    courseCode: "CS301", lecturerId: lecturers[0]._id, isActive: true,
  });

  if (!session2) {
    session2 = await AttendanceSession.create({
      courseCode:  "CS301",
      courseName:  "Data Structures & Algorithms",
      lecturerId:  lecturers[0]._id,
      type:        "inPerson",
      lecturerLat: 5.6037,
      lecturerLng: -0.1870,
      expiresAt:   futureExpiry,
      signature:   "pending",
      isActive:    true,
    });
    session2.signature = generateSignature(
      session2._id.toString(),
      session2.courseCode,
      session2.expiresAt.getTime()
    );
    await session2.save();
    console.log(`    ✓ [ACTIVE] ${session2.courseCode} — ${session2.courseName}`);
  } else {
    console.log(`    ⚠️  Session CS301 (active) already exists — skipping`);
  }

  // Session 3 — online session (no GPS)
  let session3 = await AttendanceSession.findOne({
    courseCode: "MATH201", lecturerId: lecturers[1]._id,
  });

  if (!session3) {
    const onlineExpiry = new Date(Date.now() + 45 * 60 * 1000);
    session3 = await AttendanceSession.create({
      courseCode:  "MATH201",
      courseName:  "Linear Algebra",
      lecturerId:  lecturers[1]._id,
      type:        "online",
      lecturerLat: null,
      lecturerLng: null,
      expiresAt:   onlineExpiry,
      signature:   "pending",
      isActive:    true,
    });
    session3.signature = generateSignature(
      session3._id.toString(),
      session3.courseCode,
      session3.expiresAt.getTime()
    );
    await session3.save();
    console.log(`    ✓ [ACTIVE/ONLINE] ${session3.courseCode} — ${session3.courseName}`);
  } else {
    console.log(`    ⚠️  Session MATH201 already exists — skipping`);
  }

  // ─── 5. Attendance records ────────────────────
  console.log("\n✅  Creating sample attendance records…");

  // Active students check in to the ended CS301 session
  const activeStudents = students.filter((s) => s.isActive);
  for (const student of activeStudents.slice(0, 3)) {
    const exists = await Attendance.findOne({
      sessionId: session1._id,
      studentId: student._id,
    });
    if (exists) {
      console.log(`    ⚠️  ${student.fullName} already checked in to CS301 — skipping`);
      continue;
    }
    await Attendance.create({
      sessionId:     session1._id,
      studentId:     student._id,
      courseCode:    session1.courseCode,
      status:        "present",
      method:        "qr",
      distanceMetres: Math.floor(Math.random() * 80) + 5, // 5–85 m
      studentLat:    5.6037 + (Math.random() - 0.5) * 0.001,
      studentLng:    -0.1870 + (Math.random() - 0.5) * 0.001,
      checkedInAt:   new Date(pastExpiry.getTime() - 20 * 60 * 1000),
    });
    console.log(`    ✓ ${student.fullName} → CS301 (present)`);
  }

  // ─── 6. Summary ───────────────────────────────
  const [uCount, sCount, aCount] = await Promise.all([
    User.countDocuments({}),
    AttendanceSession.countDocuments({}),
    Attendance.countDocuments({}),
  ]);

  console.log("\n─────────────────────────────────────");
  console.log("🌱  Seed complete!");
  console.log(`   Users              : ${uCount}`);
  console.log(`   Attendance sessions: ${sCount}`);
  console.log(`   Attendance records : ${aCount}`);
  console.log("\n📋  Test credentials (all roles):");
  console.log(`   Admin    : ${ADMIN_DATA.email}  /  ${ADMIN_DATA.password}`);
  LECTURER_DATA.forEach((l) =>
    console.log(`   Lecturer : ${l.email}  /  ${l.password}`)
  );
  STUDENT_DATA.forEach((s) =>
    console.log(`   Student  : ${s.email}  /  ${s.password}${!s.isActive ? "  ⛔ SUSPENDED" : ""}`)
  );
  console.log("─────────────────────────────────────\n");

  await mongoose.disconnect();
  process.exit(0);
}

main().catch((err) => {
  console.error("❌  Seeder error:", err.message);
  mongoose.disconnect();
  process.exit(1);
});