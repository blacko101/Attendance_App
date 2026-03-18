const crypto            = require("crypto");
const AttendanceSession = require("../models/AttendanceSession");
const Attendance        = require("../models/Attendance");

// ── Constants ──────────────────────────────────────────────────────
const QR_SECRET    = process.env.QR_SECRET || "smart_attend_qr_secret";
const MAX_DISTANCE = 100; // metres — must match Flutter checkin_controller.dart

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
    await session.save();

    return res.status(201).json({
      message:   "Attendance session started.",
      sessionId: session._id,
      expiresAt: session.expiresAt,
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
//  GET MY COURSES
//  GET /api/attendance/my-courses
//  Auth: lecturer only
//  Returns all courses from the Course collection where
//  assignedLecturerId matches the authenticated lecturer.
// ─────────────────────────────────────────────────────────────────
exports.getMyCourses = async (req, res) => {
  try {
    // Course model lives in seed.js — access via mongoose.model()
    const mongoose = require("mongoose");
    const Course   = mongoose.models.Course;

    if (!Course) {
      return res.status(200).json({ courses: [] });
    }

    const courses = await Course.find({
      assignedLecturerId: req.user.id,
    }).sort({ courseCode: 1 });

    return res.status(200).json({
      count: courses.length,
      courses,
    });
  } catch (err) {
    console.error("getMyCourses error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET MY TIMETABLE
//  GET /api/attendance/my-timetable
//  Auth: lecturer only
//  Returns all timetable slots from the Timetable collection
//  where lecturerId matches the authenticated lecturer.
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

    return res.status(200).json({
      count: slots.length,
      slots,
    });
  } catch (err) {
    console.error("getMyTimetable error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};