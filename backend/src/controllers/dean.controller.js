const User              = require("../models/User");
const Attendance        = require("../models/Attendance");
const AttendanceSession = require("../models/AttendanceSession");

// ── Get the dean's faculty from their DB record ────────────────────
async function getDeanFaculty(userId) {
  const dean = await User.findById(userId)
    .select("faculty department departments");
  return dean?.faculty || dean?.department || null;
}

// ── Build a filter that matches any user belonging to this faculty ──
// Checks faculty string, department string, AND departments array so
// records created any way will be found.
function buildFacultyFilter(faculty) {
  if (!faculty) return {};
  return {
    $or: [
      { faculty:     faculty },
      { department:  faculty },
      { departments: faculty },
    ],
  };
}

// ─────────────────────────────────────────────────────────────────
//  GET DEAN STATS
//  GET /api/dean/stats
// ─────────────────────────────────────────────────────────────────
exports.getDeanStats = async (req, res) => {
  try {
    const faculty  = await getDeanFaculty(req.user.id);
    const fFilter  = buildFacultyFilter(faculty);

    // Count students and lecturers in this faculty
    const [totalStudents, totalLecturers] = await Promise.all([
      User.countDocuments({ role: "student",  ...fFilter }),
      User.countDocuments({ role: "lecturer", ...fFilter }),
    ]);

    // Get lecturer IDs to scope sessions
    const lectDocs = await User.find({ role: "lecturer", ...fFilter })
      .select("_id").lean();
    const lectIds = lectDocs.map((l) => l._id);

    // Get student IDs to scope attendance
    const studDocs = await User.find({ role: "student", ...fFilter })
      .select("_id").lean();
    const studIds = studDocs.map((s) => s._id);

    const sessionFilter = lectIds.length > 0
      ? { lecturerId: { $in: lectIds } }
      : {};

    const [totalSessions, heldSessions, uniqueCodes, totalAttendance] =
      await Promise.all([
        AttendanceSession.countDocuments(sessionFilter),
        AttendanceSession.countDocuments({ ...sessionFilter, isActive: false }),
        AttendanceSession.distinct("courseCode", sessionFilter),
        studIds.length > 0
          ? Attendance.countDocuments({ studentId: { $in: studIds } })
          : Promise.resolve(0),
      ]);

    const holdRate = totalSessions === 0
      ? 0 : (heldSessions / totalSessions) * 100;
    const attRate  = totalSessions === 0
      ? 0 : (totalAttendance / totalSessions) * 100;

    return res.status(200).json({
      totalStudents,
      totalLecturers,
      totalCourses:         uniqueCodes.length,
      classesScheduled:     totalSessions,
      classesHeld:          heldSessions,
      classesNotHeld:       totalSessions - heldSessions,
      overallAttendanceRate: parseFloat(Math.min(attRate,  100).toFixed(1)),
      classHoldingRate:      parseFloat(Math.min(holdRate, 100).toFixed(1)),
    });
  } catch (err) {
    console.error("getDeanStats error:", err.message);
    return res.status(500).json({ message: "Server error." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET DEAN COURSES
//  GET /api/dean/courses
// ─────────────────────────────────────────────────────────────────
exports.getDeanCourses = async (req, res) => {
  try {
    const faculty  = await getDeanFaculty(req.user.id);
    const fFilter  = buildFacultyFilter(faculty);

    const lectDocs = await User.find({ role: "lecturer", ...fFilter })
      .select("_id fullName staffId").lean();

    const lectIds  = lectDocs.map((l) => l._id);
    const lectById = Object.fromEntries(
      lectDocs.map((l) => [l._id.toString(), l])
    );

    const sessionFilter = lectIds.length > 0
      ? { lecturerId: { $in: lectIds } }
      : {};

    const sessions = await AttendanceSession.find(sessionFilter)
      .sort({ createdAt: -1 })
      .limit(500)
      .lean();

    // Group by courseCode
    const byCode = {};
    for (const s of sessions) {
      if (!byCode[s.courseCode]) byCode[s.courseCode] = [];
      byCode[s.courseCode].push(s);
    }

    const courses = Object.entries(byCode).map(([code, list]) => {
      const first = list[0];
      const held  = list.filter((s) => !s.isActive).length;
      const lect  = lectById[first.lecturerId?.toString()];
      return {
        id:               code,
        courseCode:       code,
        courseName:       first.courseName || code,
        lecturerName:     lect?.fullName   || "",
        totalStudents:    0,
        classesHeld:      held,
        classesScheduled: list.length,
        attendanceRate:   0,
      };
    });

    courses.sort((a, b) => a.courseCode.localeCompare(b.courseCode));
    return res.status(200).json({ count: courses.length, courses });
  } catch (err) {
    console.error("getDeanCourses error:", err.message);
    return res.status(500).json({ message: "Server error." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET DEAN STUDENTS (low attendance only)
//  GET /api/dean/students
//
//  Fetches all attendance records for all faculty students in ONE
//  query, then computes per-student rates in memory.
//  Fast regardless of student count — no N+1 queries.
// ─────────────────────────────────────────────────────────────────
exports.getDeanStudents = async (req, res) => {
  try {
    const faculty  = await getDeanFaculty(req.user.id);
    const fFilter  = buildFacultyFilter(faculty);

    const students = await User.find({ role: "student", ...fFilter })
      .select("fullName email indexNumber programme level")
      .lean();

    if (students.length === 0) {
      return res.status(200).json({ count: 0, students: [] });
    }

    const studIds = students.map((s) => s._id);

    // Fetch ALL attendance records for these students in ONE query
    const records = await Attendance.find({ studentId: { $in: studIds } })
      .select("studentId courseCode status")
      .lean();

    // Group records by studentId
    const byStudent = {};
    for (const r of records) {
      const sid = r.studentId.toString();
      if (!byStudent[sid]) byStudent[sid] = [];
      byStudent[sid].push(r);
    }

    const result = [];
    for (const s of students) {
      const sid  = s._id.toString();
      const recs = byStudent[sid] || [];
      if (recs.length === 0) continue;

      const attended = recs.filter((r) => r.status === "present").length;
      const rate     = (attended / recs.length) * 100;
      if (rate >= 75) continue;   // only surface low-attendance students

      // Count courses where this student is below 75%
      const byCourse = {};
      for (const r of recs) {
        if (!r.courseCode) continue;
        if (!byCourse[r.courseCode]) byCourse[r.courseCode] = { t: 0, a: 0 };
        byCourse[r.courseCode].t++;
        if (r.status === "present") byCourse[r.courseCode].a++;
      }
      const coursesAtRisk = Object.values(byCourse)
        .filter((c) => c.t > 0 && c.a / c.t < 0.75).length;

      result.push({
        id:             sid,
        fullName:       s.fullName    || "",
        indexNumber:    s.indexNumber || "",
        programme:      s.programme   || "",
        level:          s.level       || "",
        attendanceRate: parseFloat(rate.toFixed(1)),
        coursesAtRisk,
      });
    }

    result.sort((a, b) => a.attendanceRate - b.attendanceRate);
    return res.status(200).json({ count: result.length, students: result });
  } catch (err) {
    console.error("getDeanStudents error:", err.message);
    return res.status(500).json({ message: "Server error." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET DEAN LECTURERS (performance)
//  GET /api/dean/lecturers
//
//  Fetches all sessions for all faculty lecturers in ONE query,
//  then computes per-lecturer rates in memory.
// ─────────────────────────────────────────────────────────────────
exports.getDeanLecturers = async (req, res) => {
  try {
    const faculty   = await getDeanFaculty(req.user.id);
    const fFilter   = buildFacultyFilter(faculty);

    const lecturers = await User.find({ role: "lecturer", ...fFilter })
      .select("fullName staffId department faculty")
      .lean();

    if (lecturers.length === 0) {
      return res.status(200).json({ count: 0, lecturers: [] });
    }

    const lectIds = lecturers.map((l) => l._id);

    // Fetch ALL sessions for these lecturers in ONE query
    const sessions = await AttendanceSession.find({
      lecturerId: { $in: lectIds },
    }).select("lecturerId courseCode isActive").lean();

    // Group sessions by lecturerId
    const byLect = {};
    for (const s of sessions) {
      const lid = s.lecturerId.toString();
      if (!byLect[lid]) byLect[lid] = [];
      byLect[lid].push(s);
    }

    const result = lecturers.map((l) => {
      const lid   = l._id.toString();
      const lSess = byLect[lid] || [];
      const total = lSess.length;
      const held  = lSess.filter((s) => !s.isActive).length;
      const rate  = total === 0 ? 0 : (held / total) * 100;
      const courses = [...new Set(lSess.map((s) => s.courseCode))].length;

      return {
        id:               lid,
        fullName:         l.fullName || "",
        staffId:          l.staffId  || "",
        coursesAssigned:  courses,
        classesScheduled: total,
        classesHeld:      held,
        holdingRate:      parseFloat(rate.toFixed(1)),
      };
    });

    result.sort((a, b) => a.holdingRate - b.holdingRate);
    return res.status(200).json({ count: result.length, lecturers: result });
  } catch (err) {
    console.error("getDeanLecturers error:", err.message);
    return res.status(500).json({ message: "Server error." });
  }
};