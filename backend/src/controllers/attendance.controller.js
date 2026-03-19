const crypto            = require("crypto");
const AttendanceSession = require("../models/AttendanceSession");
const Attendance        = require("../models/Attendance");

// ── Constants ──────────────────────────────────────────────────────
const QR_SECRET    = process.env.QR_SECRET || "smart_attend_qr_secret";
const MAX_DISTANCE = 50; // metres — must match Flutter checkin_controller.dart

// ─────────────────────────────────────────────────────────────────
//  PRIVATE HELPERS
//  Not exported — used only within this controller.
// ─────────────────────────────────────────────────────────────────

/**
 * Haversine formula — returns distance between two GPS points in metres.
 * Uses the spherical law of cosines approximation with Earth radius 6,371,000 m.
 */
function haversine(lat1, lng1, lat2, lng2) {
  const R  = 6371000;
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lng2 - lng1) * Math.PI) / 180;
  const a  =
    Math.sin(Δφ / 2) ** 2 +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Generate a canonical HMAC-SHA256 signature for a session.
 * Signs: "<sessionId>:<courseCode>:<expiresAtMs>"
 * Called server-side only — the client never generates this.
 */
function generateSignature(sessionId, courseCode, expiresAtMs) {
  const data = `${sessionId}:${courseCode}:${expiresAtMs}`;
  return crypto
    .createHmac("sha256", QR_SECRET)
    .update(data)
    .digest("hex");
}

/**
 * Verify a client-supplied HMAC-SHA256 signature.
 * Uses timing-safe comparison to prevent oracle timing attacks.
 * Returns false (not throws) on any invalid input.
 */
function verifySignature(sessionId, courseCode, expiresAt, signature) {
  const data     = `${sessionId}:${courseCode}:${expiresAt}`;
  const expected = crypto
    .createHmac("sha256", QR_SECRET)
    .update(data)
    .digest("hex");
  try {
    return crypto.timingSafeEqual(
      Buffer.from(expected, "hex"),
      Buffer.from(signature,  "hex")
    );
  } catch {
    // Catches: wrong length, non-hex characters, any other Buffer error.
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────
//  CREATE SESSION
//  POST /api/attendance/sessions
//  Auth: lecturer only
//
//  Creates an attendance window. The server generates the HMAC
//  signature itself (using the real DB _id) so no client-supplied
//  or fallback "mock" value can ever be stored.
// ─────────────────────────────────────────────────────────────────
exports.createSession = async (req, res) => {
  try {
    const {
      courseCode,
      courseName,
      type,
      lecturerLat,
      lecturerLng,
      durationSeconds,
    } = req.body;

    // ── Required fields ──────────────────────────
    if (!courseCode || !courseName || !durationSeconds) {
      return res.status(400).json({
        message: "courseCode, courseName and durationSeconds are required.",
      });
    }

    // ── Resolve session type ─────────────────────
    // Default to "inPerson" if omitted. Resolved before the GPS check
    // so the check runs correctly even when type is undefined.
    const resolvedType = type || "inPerson";

    // ── GPS required for in-person sessions ──────
    // Use == null (not !value) to correctly allow coordinates of exactly 0
    // (equator / prime meridian), which are valid but falsy.
    if (resolvedType === "inPerson" && (lecturerLat == null || lecturerLng == null)) {
      return res.status(400).json({
        message: "GPS coordinates required for in-person sessions.",
      });
    }

    const expiresAt = new Date(Date.now() + durationSeconds * 1000);

    // ── Step 1: Insert with placeholder signature ─
    // We need the DB-generated _id to build the canonical HMAC,
    // so we insert first, then overwrite the placeholder immediately.
    // "" is used instead of "mock" so it is obviously not a valid HMAC.
    const session = await AttendanceSession.create({
      courseCode,
      courseName,
      lecturerId:  req.user.id,
      type:        resolvedType,
      lecturerLat: lecturerLat ?? null,
      lecturerLng: lecturerLng ?? null,
      expiresAt,
      signature:   "",   // placeholder — overwritten in step 2
      isActive:    true,
    });

    // ── Step 2: Generate the real HMAC and save ───
    // Binds session._id + courseCode + expiresAt (Unix ms).
    // The Flutter app receives this and embeds it in the QR payload.
    // Students scan → send these four fields → server re-derives HMAC → compares.
    const signature = generateSignature(
      session._id.toString(),
      session.courseCode,
      session.expiresAt.getTime()
    );

    session.signature = signature;

    // ── Step 3: Generate 6-digit code and save ────
    // Server-generated so the backend always knows the current code.
    // Rotated on request via POST /sessions/:id/refresh-code.
    const code = String(Math.floor(100000 + Math.random() * 900000));
    session.code = code;
    await session.save();

    return res.status(201).json({
      message:   "Attendance session started.",
      sessionId: session._id,
      expiresAt: session.expiresAt,
      code,       // 6-digit code — display on lecturer screen
      // qrPayload is everything the Flutter lecturer app needs to render the QR.
      // Embed all four fields verbatim — the student app reads them on scan
      // and sends them unchanged to POST /api/attendance/checkin.
      qrPayload: {
        sessionId:  session._id,
        courseCode: session.courseCode,
        expiresAt:  session.expiresAt.getTime(),
        signature,
      },
    });

  } catch (err) {
    console.error("createSession error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  CHECK IN
//  POST /api/attendance/checkin
//  Auth: student only
//
//  Validates the QR payload (HMAC + expiry + courseCode cross-check),
//  optionally verifies GPS proximity, then atomically records attendance.
// ─────────────────────────────────────────────────────────────────
exports.checkIn = async (req, res) => {
  try {
    const {
      sessionId,
      courseCode,
      expiresAt,
      signature,
      studentLat,
      studentLng,
      method,
    } = req.body;

    // ── 0. All QR fields must be present ─────────
    // Missing any field means the payload is incomplete or tampered with.
    if (!sessionId || !courseCode || !expiresAt || !signature) {
      return res.status(400).json({
        message: "sessionId, courseCode, expiresAt and signature are required.",
      });
    }

    // ── 1. Verify HMAC signature ──────────────────
    // Uses timingSafeEqual internally — prevents timing oracle attacks.
    if (!verifySignature(sessionId, courseCode, expiresAt, signature)) {
      return res.status(400).json({ message: "Invalid QR code." });
    }

    // ── 2. Check expiry ───────────────────────────
    // new Date() handles both Unix-ms integers and ISO strings safely.
    if (Date.now() > new Date(expiresAt).getTime()) {
      return res.status(400).json({ message: "QR code has expired." });
    }

    // ── 3. Find active session ────────────────────
    const session = await AttendanceSession.findById(sessionId);
    if (!session || !session.isActive) {
      return res.status(404).json({ message: "Session not found or has ended." });
    }

    // ── 4. Cross-check courseCode against DB ──────
    // Prevents a valid QR for Course A from being replayed to check in to Course B.
    if (session.courseCode !== courseCode) {
      return res.status(400).json({ message: "Invalid QR code." });
    }

    // ── 5. GPS proximity check (inPerson only) ────
    let distanceMetres = null;
    if (session.type === "inPerson") {
      if (studentLat == null || studentLng == null) {
        return res.status(400).json({
          message: "GPS location required for in-person attendance.",
        });
      }
      distanceMetres = haversine(
        session.lecturerLat,
        session.lecturerLng,
        studentLat,
        studentLng
      );
      if (distanceMetres > MAX_DISTANCE) {
        return res.status(400).json({
          message: `You are ${Math.round(distanceMetres)}m away. Must be within ${MAX_DISTANCE}m.`,
          distanceMetres,
        });
      }
    }

    // ── 6. Atomically record attendance ──────────
    // findOneAndUpdate with upsert + $setOnInsert prevents duplicate
    // check-ins without a separate round-trip. If the document already
    // exists (same sessionId + studentId), $setOnInsert is a no-op.
    const record = await Attendance.findOneAndUpdate(
      { sessionId, studentId: req.user.id },
      {
        $setOnInsert: {
          sessionId,
          studentId:     req.user.id,
          courseCode:    session.courseCode,
          status:        "present",
          distanceMetres,
          studentLat:    studentLat ?? null,
          studentLng:    studentLng ?? null,
          method:        method || "qr",
          checkedInAt:   new Date(),
        },
      },
      { upsert: true, new: true }
    );

    return res.status(200).json({
      message:       "Attendance recorded successfully.",
      attendanceId:  record._id,
      courseCode:    session.courseCode,
      distanceMetres,
    });

  } catch (err) {
    // Duplicate key — the unique index on {sessionId, studentId} fired.
    // This is the safety net if the findOneAndUpdate race condition is ever hit.
    if (err.code === 11000) {
      return res.status(409).json({
        message: "You have already checked in for this session.",
      });
    }
    console.error("checkIn error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET SESSION STUDENTS
//  GET /api/attendance/sessions/:sessionId/students
//  Auth: lecturer only — ownership enforced
// ─────────────────────────────────────────────────────────────────
exports.getSessionStudents = async (req, res) => {
  try {
    // Ownership check: only the lecturer who created the session can view it.
    const session = await AttendanceSession.findOne({
      _id:        req.params.sessionId,
      lecturerId: req.user.id,
    });

    if (!session) {
      return res.status(404).json({ message: "Session not found." });
    }

    const records = await Attendance.find({ sessionId: req.params.sessionId })
      .populate("studentId", "fullName email indexNumber");

    return res.status(200).json({ count: records.length, students: records });

  } catch (err) {
    console.error("getSessionStudents error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET STUDENT ATTENDANCE HISTORY
//  GET /api/attendance/student/:studentId
//  Auth: any authenticated user
//  Students can only view their own records.
//  Lecturers and admins can view any student.
// ─────────────────────────────────────────────────────────────────
exports.getStudentAttendance = async (req, res) => {
  try {
    const { studentId } = req.params;

    // Students are restricted to their own history.
    // req.user.id (JWT string) vs studentId (URL param string) — safe comparison.
    if (req.user.role === "student" && req.user.id !== studentId) {
      return res.status(403).json({ message: "Access denied." });
    }

    const records = await Attendance.find({ studentId })
      .sort({ checkedInAt: -1 })
      .populate("sessionId", "courseCode courseName type");

    return res.status(200).json({ count: records.length, records });

  } catch (err) {
    console.error("getStudentAttendance error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  END SESSION
//  PATCH /api/attendance/sessions/:sessionId/end
//  Auth: lecturer only — ownership enforced
// ─────────────────────────────────────────────────────────────────
exports.endSession = async (req, res) => {
  try {
    // Ownership check: only the creating lecturer can end the session.
    const session = await AttendanceSession.findOne({
      _id:        req.params.sessionId,
      lecturerId: req.user.id,
    });

    if (!session) {
      return res.status(404).json({ message: "Session not found." });
    }

    session.isActive = false;
    await session.save();

    return res.status(200).json({
      message:   "Session ended successfully.",
      sessionId: session._id,
    });

  } catch (err) {
    console.error("endSession error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET LECTURER'S OWN SESSIONS  (Priority 14)
//  GET /api/attendance/sessions
//  Auth: lecturer only
//  Query params:
//    isActive — "true" | "false" to filter live vs ended sessions
//    page, limit
// ─────────────────────────────────────────────────────────────────
exports.getMySessions = async (req, res) => {
  try {
    const {
      isActive,
      page  = 1,
      limit = 20,
    } = req.query;

    const filter = { lecturerId: req.user.id };

    // Optional active/ended filter
    if (isActive !== undefined) {
      filter.isActive = isActive === "true";
    }

    const pageNum  = Math.max(1, parseInt(page, 10)  || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip     = (pageNum - 1) * limitNum;

    const [sessions, total] = await Promise.all([
      AttendanceSession.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limitNum),
      AttendanceSession.countDocuments(filter),
    ]);

    return res.status(200).json({
      total,
      page:       pageNum,
      totalPages: Math.ceil(total / limitNum),
      count:      sessions.length,
      sessions,
    });

  } catch (err) {
    console.error("getMySessions error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};
// ─────────────────────────────────────────────────────────────────
//  GET STUDENT ENROLLED COURSES
//  GET /api/attendance/my-enrolled-courses
//  Auth: student only
//  Returns courses from the Course collection where the student's
//  programme matches, or uses the Timetable to find their courses.
// ─────────────────────────────────────────────────────────────────
exports.getMyEnrolledCourses = async (req, res) => {
  try {
    const mongoose = require("mongoose");
    const Course   = mongoose.models.Course;
    const User     = require("../models/User");

    if (!Course) {
      return res.status(200).json({ courses: [] });
    }

    // Get the student's programme from their user record
    const student = await User.findById(req.user.id).select("programme level faculty");
    if (!student) {
      return res.status(404).json({ message: "Student not found." });
    }

    // Find courses matching the student's programme
    // Also pull in attendance records so we can compute per-course rates
    const Attendance = require("../models/Attendance");
    const AttendanceSession = require("../models/AttendanceSession");

    const courses = await Course.find({
      $or: [
        { programme: student.programme },
        { faculty: student.faculty },
        { department: student.faculty },
      ],
    }).sort({ courseCode: 1 });

    // For each course, compute the student's attendance rate
    const enriched = await Promise.all(courses.map(async (c) => {
      // Find sessions for this course
      const sessions = await AttendanceSession.find({
        courseCode: c.courseCode,
        isActive: false,
      }).select("_id");

      const sessionIds = sessions.map((s) => s._id);
      const totalClasses = sessionIds.length;

      // Find how many this student attended
      const attended = await Attendance.countDocuments({
        sessionId: { $in: sessionIds },
        studentId: req.user.id,
        status: "present",
      });

      const absent = totalClasses - attended;
      const rate = totalClasses === 0 ? 0 : (attended / totalClasses) * 100;

      return {
        _id:              c._id,
        courseCode:       c.courseCode,
        courseName:       c.courseName,
        department:       c.department,
        faculty:          c.faculty,
        creditHours:      c.creditHours,
        assignedLecturerName: c.assignedLecturerName,
        enrolledStudents: c.enrolledStudents,
        totalClasses,
        attended,
        absent,
        attendanceRate:   parseFloat(rate.toFixed(1)),
      };
    }));

    return res.status(200).json({
      count:   enriched.length,
      courses: enriched,
    });
  } catch (err) {
    console.error("getMyEnrolledCourses error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET STUDENT TIMETABLE
//  GET /api/attendance/my-student-timetable
//  Auth: student only
//  Returns timetable slots for the student's programme from the
//  Timetable collection.
// ─────────────────────────────────────────────────────────────────
exports.getMyStudentTimetable = async (req, res) => {
  try {
    const mongoose  = require("mongoose");
    const Timetable = mongoose.models.Timetable;
    const User      = require("../models/User");

    if (!Timetable) {
      return res.status(200).json({ slots: [] });
    }

    const student = await User.findById(req.user.id).select("programme level faculty");
    if (!student) {
      return res.status(404).json({ message: "Student not found." });
    }

    const slots = await Timetable.find({
      $or: [
        { programme: student.programme },
        // fallback: match by level if programme not set on slot
        ...(student.level ? [{ level: student.level }] : []),
      ],
    }).sort({ day: 1, startTime: 1 });

    return res.status(200).json({
      count: slots.length,
      slots,
    });
  } catch (err) {
    console.error("getMyStudentTimetable error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  REFRESH QR PAYLOAD
//  POST /api/attendance/sessions/:sessionId/refresh-qr
//  Auth: lecturer only — ownership enforced
//
//  Returns a fresh short-lived QR payload for an active session.
//  The session's main expiresAt is unchanged — only the QR window
//  is refreshed (15-second window). Students scanning an old QR
//  that has passed its window get "QR expired" until they scan the
//  new one. This prevents QR screenshot replay attacks.
// ─────────────────────────────────────────────────────────────────
exports.refreshQr = async (req, res) => {
  try {
    const session = await AttendanceSession.findOne({
      _id:        req.params.sessionId,
      lecturerId: req.user.id,
      isActive:   true,
    });

    if (!session) {
      return res.status(404).json({
        message: "Session not found, not active, or not yours.",
      });
    }

    // Has the overall session expired?
    if (session.expiresAt < new Date()) {
      session.isActive = false;
      await session.save();
      return res.status(400).json({ message: "Session has expired." });
    }

    // Short-lived QR window: 20 seconds from now, but never beyond
    // the session's own expiresAt
    const windowMs  = 20 * 1000;
    const qrExpires = new Date(
      Math.min(Date.now() + windowMs, session.expiresAt.getTime())
    );

    const signature = generateSignature(
      session._id.toString(),
      session.courseCode,
      qrExpires.getTime()
    );

    return res.status(200).json({
      qrPayload: {
        sessionId:  session._id,
        courseCode: session.courseCode,
        expiresAt:  qrExpires.getTime(),
        signature,
      },
    });
  } catch (err) {
    console.error("refreshQr error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET LIVE SESSION STUDENT COUNT
//  GET /api/attendance/sessions/:sessionId/count
//  Auth: lecturer only — ownership enforced
//  Returns the current number of students who have checked in.
// ─────────────────────────────────────────────────────────────────
exports.getSessionCount = async (req, res) => {
  try {
    const session = await AttendanceSession.findOne({
      _id:        req.params.sessionId,
      lecturerId: req.user.id,
    });

    if (!session) {
      return res.status(404).json({ message: "Session not found." });
    }

    const count = await Attendance.countDocuments({
      sessionId: req.params.sessionId,
    });

    return res.status(200).json({ count, isActive: session.isActive });
  } catch (err) {
    console.error("getSessionCount error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET LECTURER'S ASSIGNED COURSES
//  GET /api/attendance/my-courses
//  Auth: lecturer only
// ─────────────────────────────────────────────────────────────────
exports.getMyCourses = async (req, res) => {
  try {
    const mongoose = require("mongoose");
    const Course   = mongoose.models.Course;
    const User     = require("../models/User");

    if (!Course) {
      return res.status(200).json({ courses: [] });
    }

    const courses = await Course.find({
      assignedLecturerId: req.user.id,
    }).sort({ courseCode: 1 });

    // Compute live enrolled student count for each course by checking
    // how many students have this course's programme assigned to them.
    // Falls back to the stored enrolledStudents field if User query fails.
    const enriched = await Promise.all(courses.map(async (c) => {
      let count = c.enrolledStudents ?? 0;
      try {
        // Count active students whose programme matches this course's programme
        if (c.programme) {
          count = await User.countDocuments({
            role:      "student",
            isActive:  true,
            programme: c.programme,
          });
        }
      } catch (_) {
        // keep stored value on error
      }
      return {
        ...c.toObject(),
        enrolledStudents: count,
      };
    }));

    return res.status(200).json({ count: enriched.length, courses: enriched });
  } catch (err) {
    console.error("getMyCourses error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET LECTURER'S TIMETABLE SLOTS
//  GET /api/attendance/my-timetable
//  Auth: lecturer only
// ─────────────────────────────────────────────────────────────────
exports.getMyTimetable = async (req, res) => {
  try {
    const mongoose  = require("mongoose");
    const Timetable = mongoose.models.Timetable;

    if (!Timetable) {
      return res.status(200).json({ slots: [] });
    }

    const slots = await Timetable.find({
      lecturerId: req.user.id,
    }).sort({ day: 1, startTime: 1 });

    return res.status(200).json({ count: slots.length, slots });
  } catch (err) {
    console.error("getMyTimetable error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET AVAILABLE COURSES FOR ENROLLMENT
//  GET /api/attendance/available-courses
//  Auth: student only
//
//  Returns all courses from the Course collection that match the
//  student's programme or faculty. Shows which ones the student
//  has already enrolled in so the UI can pre-tick them.
// ─────────────────────────────────────────────────────────────────
exports.getAvailableCourses = async (req, res) => {
  try {
    const mongoose = require("mongoose");
    const Course   = mongoose.models.Course;
    const User     = require("../models/User");

    if (!Course) {
      return res.status(200).json({ courses: [] });
    }

    // Get student profile to find their programme + faculty
    const student = await User.findById(req.user.id)
      .select("programme faculty level enrolledCourses");
    if (!student) {
      return res.status(404).json({ message: "Student not found." });
    }

    // Find courses matching the student's programme or faculty
    const courses = await Course.find({
      $or: [
        { programme: student.programme },
        { faculty:   student.faculty   },
        { department: student.faculty  },
      ],
    }).sort({ courseCode: 1 });

    const enrolled = student.enrolledCourses || [];

    const result = courses.map((c) => ({
      _id:                  c._id,
      courseCode:           c.courseCode,
      courseName:           c.courseName,
      creditHours:          c.creditHours,
      level:                c.level,
      programme:            c.programme,
      faculty:              c.faculty || c.department,
      assignedLecturerName: c.assignedLecturerName || "",
      enrolledStudents:     c.enrolledStudents || 0,
      isEnrolled:           enrolled.includes(c.courseCode),
    }));

    return res.status(200).json({
      count:          result.length,
      courses:        result,
      enrolledCodes:  enrolled,
    });
  } catch (err) {
    console.error("getAvailableCourses error:", err.message);
    return res.status(500).json({ message: "Server error." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  ENROLL IN COURSES
//  POST /api/attendance/enroll
//  Auth: student only
//  Body: { courseCodes: string[], password: string }
//
//  Verifies the student's password, then saves the selected course
//  codes to the student's enrolledCourses array. Idempotent — re-
//  enrolling in an already-enrolled course is a no-op.
// ─────────────────────────────────────────────────────────────────
exports.enrollCourses = async (req, res) => {
  try {
    const bcrypt = require("bcryptjs");
    const User   = require("../models/User");

    const { courseCodes, password } = req.body;

    if (!Array.isArray(courseCodes) || courseCodes.length === 0) {
      return res.status(400).json({ message: "Please select at least one course." });
    }
    if (!password) {
      return res.status(400).json({ message: "Password is required to confirm enrollment." });
    }

    // Verify password — must select password explicitly (select: false in schema)
    const student = await User.findById(req.user.id).select("+password");
    if (!student) {
      return res.status(404).json({ message: "Student not found." });
    }

    const passwordMatch = await bcrypt.compare(password, student.password);
    if (!passwordMatch) {
      return res.status(401).json({ message: "Incorrect password. Enrollment not confirmed." });
    }

    // Merge with existing enrollments (no duplicates)
    const existing = student.enrolledCourses || [];
    const merged   = [...new Set([...existing, ...courseCodes])];

    await User.findByIdAndUpdate(req.user.id, {
      $set: { enrolledCourses: merged },
    });

    // Update enrolledStudents count on each course
    const mongoose = require("mongoose");
    const Course   = mongoose.models.Course;
    if (Course) {
      for (const code of courseCodes) {
        if (!existing.includes(code)) {
          await Course.findOneAndUpdate(
            { courseCode: code },
            { $inc: { enrolledStudents: 1 } }
          );
        }
      }
    }

    return res.status(200).json({
      message:        "Enrollment successful.",
      enrolledCourses: merged,
    });
  } catch (err) {
    console.error("enrollCourses error:", err.message);
    return res.status(500).json({ message: "Server error." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET STUDENT DASHBOARD STATS
//  GET /api/attendance/my-dashboard-stats
//  Auth: student only
//
//  Returns overall attended/absent counts and the student's name
//  so the home tab doesn't need a separate /api/auth/me call.
// ─────────────────────────────────────────────────────────────────
exports.getMyDashboardStats = async (req, res) => {
  try {
    const User       = require("../models/User");
    const Attendance = require("../models/Attendance");

    const student = await User.findById(req.user.id)
      .select("fullName indexNumber programme level faculty enrolledCourses");
    if (!student) {
      return res.status(404).json({ message: "Student not found." });
    }

    // All attendance records for this student
    const records = await Attendance.find({ studentId: req.user.id });
    const total    = records.length;
    const attended = records.filter((r) => r.status === "present").length;
    const absent   = total - attended;

    return res.status(200).json({
      fullName:       student.fullName,
      indexNumber:    student.indexNumber || "",
      programme:      student.programme   || "",
      level:          student.level       || "",
      enrolledCourses: student.enrolledCourses || [],
      totalClasses:   total,
      attended,
      absent,
      attendanceRate: total === 0 ? 0 : parseFloat(((attended / total) * 100).toFixed(1)),
    });
  } catch (err) {
    console.error("getMyDashboardStats error:", err.message);
    return res.status(500).json({ message: "Server error." });
  }
};
// ─────────────────────────────────────────────────────────────────
//  GET WEEKLY STATS
//  GET /api/attendance/my-weekly-stats
//  Auth: lecturer only
//  Returns this week's session counts: scheduled(from timetable),
//  held, notHeld, inPerson, online.
// ─────────────────────────────────────────────────────────────────
exports.getMyWeeklyStats = async (req, res) => {
  try {
    const mongoose  = require("mongoose");
    const Timetable = mongoose.models.Timetable;

    const now    = new Date();
    // Monday 00:00 of current week
    const day    = now.getDay() === 0 ? 7 : now.getDay(); // Sun=7
    const monday = new Date(now);
    monday.setDate(now.getDate() - (day - 1));
    monday.setHours(0, 0, 0, 0);
    const sunday = new Date(monday);
    sunday.setDate(monday.getDate() + 6);
    sunday.setHours(23, 59, 59, 999);

    // Timetable slots this week for this lecturer
    let scheduled = 0;
    if (Timetable) {
      scheduled = await Timetable.countDocuments({ lecturerId: req.user.id });
    }

    // Sessions actually run this week
    const weekSessions = await AttendanceSession.find({
      lecturerId: req.user.id,
      createdAt:  { $gte: monday, $lte: sunday },
    });

    const held     = weekSessions.filter(s => !s.isActive || s.expiresAt < now).length;
    const inPerson = weekSessions.filter(s => s.type === "inPerson").length;
    const online   = weekSessions.filter(s => s.type === "online").length;
    const notHeld  = Math.max(0, scheduled - held);

    return res.status(200).json({ scheduled, held, notHeld, inPerson, online });
  } catch (err) {
    console.error("getMyWeeklyStats error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET COURSE SUMMARY (for Summary page)
//  GET /api/attendance/my-course-summary
//  Auth: lecturer only
//  Returns every assigned course with aggregate session stats and
//  full session history (each session has its student count).
// ─────────────────────────────────────────────────────────────────
exports.getMyCourseSummary = async (req, res) => {
  try {
    const mongoose = require("mongoose");
    const Course   = mongoose.models.Course;

    if (!Course) return res.status(200).json({ courses: [] });

    // All courses assigned to this lecturer
    const courses = await Course.find({
      assignedLecturerId: req.user.id,
    }).sort({ courseCode: 1 });

    const enriched = await Promise.all(courses.map(async (c) => {
      // All sessions for this course by this lecturer
      const sessions = await AttendanceSession.find({
        lecturerId: req.user.id,
        courseCode: c.courseCode,
        isActive:   false,   // only completed sessions
      }).sort({ createdAt: -1 });

      // For each session, get student attendance count
      const sessionHistory = await Promise.all(sessions.map(async (s) => {
        const present = await Attendance.countDocuments({
          sessionId: s._id,
          status:    "present",
        });
        const total = await Attendance.countDocuments({ sessionId: s._id });
        return {
          sessionId:    s._id,
          date:         s.createdAt,
          type:         s.type,
          studentsPresent: present,
          studentsAbsent:  total - present,
          totalStudents:   total,
          expiresAt:    s.expiresAt,
        };
      }));

      const held     = sessions.length;
      const inPerson = sessions.filter(s => s.type === "inPerson").length;
      const online   = sessions.filter(s => s.type === "online").length;

      return {
        _id:              c._id,
        courseCode:       c.courseCode,
        courseName:       c.courseName,
        department:       c.department,
        faculty:          c.faculty,
        creditHours:      c.creditHours,
        totalStudents:    c.enrolledStudents || 0,
        assignedLecturerName: c.assignedLecturerName,
        held,
        inPerson,
        online,
        sessionHistory,
      };
    }));

    return res.status(200).json({ count: enriched.length, courses: enriched });
  } catch (err) {
    console.error("getMyCourseSummary error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET SESSION ATTENDANCE DETAIL
//  GET /api/attendance/sessions/:sessionId/detail
//  Auth: lecturer only — ownership enforced
//  Returns full student list with present/absent status.
// ─────────────────────────────────────────────────────────────────
exports.getSessionDetail = async (req, res) => {
  try {
    const User = require("../models/User");

    const session = await AttendanceSession.findOne({
      _id:        req.params.sessionId,
      lecturerId: req.user.id,
    });
    if (!session) {
      return res.status(404).json({ message: "Session not found." });
    }

    // All students who checked in
    const records = await Attendance.find({ sessionId: req.params.sessionId })
      .populate("studentId", "fullName email indexNumber");

    const present = records.map(r => ({
      studentId:   r.studentId?._id,
      fullName:    r.studentId?.fullName || "Unknown",
      email:       r.studentId?.email || "",
      indexNumber: r.studentId?.indexNumber || "",
      status:      "present",
      checkedInAt: r.checkedInAt,
    }));

    // Students enrolled in this course but who did NOT check in
    const mongoose = require("mongoose");
    const Course   = mongoose.models.Course;
    let absent = [];

    if (Course) {
      const course = await Course.findOne({ courseCode: session.courseCode });
      if (course) {
        // Find enrolled students from User.enrolledCourses
        const enrolledStudents = await User.find({
          role:           "student",
          isActive:       true,
          enrolledCourses: session.courseCode,
        }).select("fullName email indexNumber");

        const presentIds = new Set(present.map(p => p.studentId?.toString()));
        absent = enrolledStudents
          .filter(s => !presentIds.has(s._id.toString()))
          .map(s => ({
            studentId:   s._id,
            fullName:    s.fullName,
            email:       s.email,
            indexNumber: s.indexNumber || "",
            status:      "absent",
            checkedInAt: null,
          }));
      }
    }

    return res.status(200).json({
      sessionId:    session._id,
      courseCode:   session.courseCode,
      courseName:   session.courseName,
      date:         session.createdAt,
      type:         session.type,
      present,
      absent,
      totalPresent: present.length,
      totalAbsent:  absent.length,
    });
  } catch (err) {
    console.error("getSessionDetail error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};
// ─────────────────────────────────────────────────────────────────
//  REFRESH 6-DIGIT CODE
//  POST /api/attendance/sessions/:sessionId/refresh-code
//  Auth: lecturer only — ownership enforced
//
//  Generates a new 6-digit code, saves it to the session, and
//  returns it so the lecturer screen can display the updated code.
//  Called every _kCodeRotateSeconds by the active session screen.
// ─────────────────────────────────────────────────────────────────
exports.refreshCode = async (req, res) => {
  try {
    const session = await AttendanceSession.findOne({
      _id:        req.params.sessionId,
      lecturerId: req.user.id,
      isActive:   true,
    });

    if (!session) {
      return res.status(404).json({
        message: "Session not found, not active, or not yours.",
      });
    }

    if (session.expiresAt < new Date()) {
      session.isActive = false;
      await session.save();
      return res.status(400).json({ message: "Session has expired." });
    }

    const code = String(Math.floor(100000 + Math.random() * 900000));
    session.code = code;
    await session.save();

    return res.status(200).json({ code });
  } catch (err) {
    console.error("refreshCode error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  CHECK IN BY 6-DIGIT CODE
//  POST /api/attendance/checkin-by-code
//  Auth: student only
//  Body: { code, studentLat?, studentLng? }
//
//  Finds the active session matching the code, validates it,
//  checks GPS proximity for in-person sessions, then records
//  attendance. Prevents duplicate check-ins via unique index.
// ─────────────────────────────────────────────────────────────────
exports.checkInByCode = async (req, res) => {
  try {
    const { code, studentLat, studentLng } = req.body;

    if (!code || String(code).length !== 6) {
      return res.status(400).json({ message: "A valid 6-digit code is required." });
    }

    // Find an active session with this code that hasn't expired
    const session = await AttendanceSession.findOne({
      code:     String(code),
      isActive: true,
      expiresAt: { $gt: new Date() },
    });

    if (!session) {
      return res.status(404).json({
        message: "Invalid or expired code. Ask your lecturer for a new one.",
      });
    }

    // GPS proximity check for in-person sessions
    let distanceMetres = null;
    if (session.type === "inPerson") {
      if (studentLat == null || studentLng == null) {
        return res.status(400).json({
          message: "GPS location required for in-person attendance.",
        });
      }
      distanceMetres = haversine(
        session.lecturerLat,
        session.lecturerLng,
        studentLat,
        studentLng
      );
      if (distanceMetres > MAX_DISTANCE) {
        return res.status(400).json({
          message: `You are ${Math.round(distanceMetres)}m away. Must be within ${MAX_DISTANCE}m.`,
          distanceMetres,
        });
      }
    }

    // Atomically record attendance — unique index prevents duplicates
    const record = await Attendance.findOneAndUpdate(
      { sessionId: session._id, studentId: req.user.id },
      {
        $setOnInsert: {
          sessionId:      session._id,
          studentId:      req.user.id,
          courseCode:     session.courseCode,
          status:         "present",
          method:         "code",
          distanceMetres,
          studentLat:     studentLat ?? null,
          studentLng:     studentLng ?? null,
          checkedInAt:    new Date(),
        },
      },
      { upsert: true, new: true }
    );

    return res.status(200).json({
      message:      "Attendance recorded successfully.",
      attendanceId: record._id,
      courseCode:   session.courseCode,
      courseName:   session.courseName,
    });

  } catch (err) {
    if (err.code === 11000) {
      return res.status(409).json({
        message: "You have already checked in for this session.",
      });
    }
    console.error("checkInByCode error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};