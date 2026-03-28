const express        = require("express");
const router         = express.Router();
const authMiddleware = require("../middleware/auth.middleware");
const roleMiddleware = require("../middleware/role.middleware");

const {
  getDashboard,
  getAdminDetail,
  createAdmin,
  listFaculties,
  createFaculty,
  setAdminStatus,
} = require("../controllers/super_admin.controller");

router.use(authMiddleware);
router.use(roleMiddleware("super_admin"));

// ── Dashboard ──────────────────────────────────
router.get("/dashboard",             getDashboard);

// ── Admin management ───────────────────────────
router.get("/admins/:id",            getAdminDetail);
router.post("/admins",               createAdmin);
router.patch("/admins/:id/status",   setAdminStatus);

// ── Faculty management ─────────────────────────
router.get("/faculties",             listFaculties);
router.post("/faculties",            createFaculty);

module.exports = router;