const express        = require("express");
const router         = express.Router();
const authMiddleware = require("../middleware/auth.middleware");
const roleMiddleware = require("../middleware/role.middleware");

const {
  listUsers,
  createUser,
  getUser,
  updateUser,
  setUserStatus,
  listSessions,
  getSessionReport,
  getStats,
  listCourses,
  listTimetable,
  createTimetableSlot,
  deleteTimetableSlot,
} = require("../controllers/admin.controller");

router.use(authMiddleware);
router.use(roleMiddleware("admin"));

// ── Dashboard ─────────────────────────────────
router.get("/stats", getStats);

// ── User management ───────────────────────────
router.get   ("/users",              listUsers);
router.post  ("/users",              createUser);
router.get   ("/users/:id",          getUser);
router.patch ("/users/:id",          updateUser);
router.patch ("/users/:id/status",   setUserStatus);

// ── Session management (read-only) ────────────
router.get   ("/sessions",                    listSessions);
router.get   ("/sessions/:sessionId/report",  getSessionReport);

// ── Course management ─────────────────────────
router.get   ("/courses",            listCourses);

// ── Timetable management ──────────────────────
router.get   ("/timetable",          listTimetable);
router.post  ("/timetable",          createTimetableSlot);
router.delete("/timetable/:id",      deleteTimetableSlot);

module.exports = router;