const express        = require("express");
const router         = express.Router();
const authMiddleware = require("../middleware/auth.middleware");
const roleMiddleware = require("../middleware/role.middleware");

const {
  createSession,
  checkIn,
  getSessionStudents,
  getStudentAttendance,
  endSession,
} = require("../controllers/attendance.controller");

// ─────────────────────────────────────────────
//  POST /api/attendance/sessions
//  Lecturer starts an attendance session.
// ─────────────────────────────────────────────
router.post(
  "/sessions",
  authMiddleware,
  roleMiddleware("lecturer"),
  createSession
);

// ─────────────────────────────────────────────
//  POST /api/attendance/checkin
//  Student checks in using QR / 6-digit code payload.
// ─────────────────────────────────────────────
router.post(
  "/checkin",
  authMiddleware,
  roleMiddleware("student"),
  checkIn
);

// ─────────────────────────────────────────────
//  GET /api/attendance/sessions/:sessionId/students
//  Lecturer views who has checked in (live count).
// ─────────────────────────────────────────────
router.get(
  "/sessions/:sessionId/students",
  authMiddleware,
  roleMiddleware("lecturer"),
  getSessionStudents
);

// ─────────────────────────────────────────────
//  GET /api/attendance/student/:studentId
//  Attendance history — own record (student) or any record (lecturer/admin).
// ─────────────────────────────────────────────
router.get(
  "/student/:studentId",
  authMiddleware,
  getStudentAttendance
);

// ─────────────────────────────────────────────
//  PATCH /api/attendance/sessions/:sessionId/end
//  Lecturer manually ends a session before expiry.
// ─────────────────────────────────────────────
router.patch(
  "/sessions/:sessionId/end",
  authMiddleware,
  roleMiddleware("lecturer"),
  endSession
);

module.exports = router;