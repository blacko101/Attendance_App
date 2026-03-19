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
  getMySessions,
  getMyCourses,
  getMyTimetable,
  getMyEnrolledCourses,
  getMyStudentTimetable,
  refreshQr,
  getSessionCount,
  // New enrollment endpoints
  getAvailableCourses,
  enrollCourses,
  getMyDashboardStats,
} = require("../controllers/attendance.controller");

// ─────────────────────────────────────────────
//  LECTURER ROUTES
// ─────────────────────────────────────────────
router.post("/sessions",                              authMiddleware, roleMiddleware("lecturer"), createSession);
router.get ("/sessions",                              authMiddleware, roleMiddleware("lecturer"), getMySessions);
router.get ("/my-courses",                            authMiddleware, roleMiddleware("lecturer"), getMyCourses);
router.get ("/my-timetable",                          authMiddleware, roleMiddleware("lecturer"), getMyTimetable);
router.get ("/sessions/:sessionId/students",          authMiddleware, roleMiddleware("lecturer"), getSessionStudents);
router.get ("/sessions/:sessionId/count",             authMiddleware, roleMiddleware("lecturer"), getSessionCount);
router.post("/sessions/:sessionId/refresh-qr",        authMiddleware, roleMiddleware("lecturer"), refreshQr);
router.patch("/sessions/:sessionId/end",              authMiddleware, roleMiddleware("lecturer"), endSession);

// ─────────────────────────────────────────────
//  STUDENT ROUTES
// ─────────────────────────────────────────────
router.post("/checkin",                               authMiddleware, roleMiddleware("student"), checkIn);
router.get ("/my-enrolled-courses",                   authMiddleware, roleMiddleware("student"), getMyEnrolledCourses);
router.get ("/my-student-timetable",                  authMiddleware, roleMiddleware("student"), getMyStudentTimetable);
router.get ("/available-courses",                     authMiddleware, roleMiddleware("student"), getAvailableCourses);
router.post("/enroll",                                authMiddleware, roleMiddleware("student"), enrollCourses);
router.get ("/my-dashboard-stats",                    authMiddleware, roleMiddleware("student"), getMyDashboardStats);

// ─────────────────────────────────────────────
//  SHARED ROUTES
// ─────────────────────────────────────────────
router.get("/student/:studentId",                     authMiddleware, getStudentAttendance);

module.exports = router;