const express        = require("express");
const router         = express.Router();
const authMiddleware = require("../middleware/auth.middleware");
const roleMiddleware = require("../middleware/role.middleware");

const {
  listUsers,
  getUser,
  setUserStatus,
  listSessions,
  getSessionReport,
  getStats,
} = require("../controllers/admin.controller");

// ── All admin routes require a valid JWT AND the "admin" role ──────
// Applying both middleware here at the router level means we never
// need to repeat them on individual route definitions below.
// Any request that fails either check is rejected before the handler runs.
router.use(authMiddleware);
router.use(roleMiddleware("admin"));

// ── Dashboard ──────────────────────────────────────────────────────
// GET /api/admin/stats
router.get("/stats", getStats);

// ── User management ────────────────────────────────────────────────
// GET  /api/admin/users              — list all users (filterable)
// GET  /api/admin/users/:id          — get one user
// PATCH /api/admin/users/:id/status  — suspend / reactivate
router.get("/users",                listUsers);
router.get("/users/:id",            getUser);
router.patch("/users/:id/status",   setUserStatus);

// ── Session management (read-only for admin) ───────────────────────
// GET /api/admin/sessions                      — all sessions
// GET /api/admin/sessions/:sessionId/report    — full attendance report
router.get("/sessions",                      listSessions);
router.get("/sessions/:sessionId/report",    getSessionReport);

module.exports = router;