const express        = require("express");
const router         = express.Router();
const authMiddleware = require("../middleware/auth.middleware");
const roleMiddleware = require("../middleware/role.middleware");

const {
  login,
  register,
  getMe,
  updateRole,
  changePassword,
} = require("../controllers/auth.controller");

router.post("/register", register);
router.post("/login",    login);

// ─────────────────────────────────────────────
//  ROLE-SCOPED LOGIN ENDPOINTS
//  ─────────────────────────────────────────────
//  Each route injects req.expectedRole before the
//  shared login handler runs. If the user's DB role
//  doesn't match, login returns 401 — same message
//  as a wrong password so no role info is leaked.
//
//  Student / Lecturer → /api/auth/login/<role>
//  Admin  / Dean      → /api/auth/<role>/login
//  (separate URL prefix keeps privileged routes
//   visually and structurally distinct)
// ─────────────────────────────────────────────
router.post(
  "/login/student",
  (req, _res, next) => { req.expectedRole = "student"; next(); },
  login
);

router.post(
  "/login/lecturer",
  (req, _res, next) => { req.expectedRole = "lecturer"; next(); },
  login
);

router.post(
  "/admin/login",
  (req, _res, next) => { req.expectedRole = "admin"; next(); },
  login
);

router.post(
  "/dean/login",
  (req, _res, next) => { req.expectedRole = "dean"; next(); },
  login
);

// ─────────────────────────────────────────────
//  LEGACY  POST /api/auth/login  — kept for
//  backward compatibility during migration.
//  No expectedRole set → role check is skipped.
//  TODO: Remove this route once all Flutter
//        clients have been updated to the
//        role-scoped endpoints above.
// ─────────────────────────────────────────────
router.post("/login", login);

// ─────────────────────────────────────────────
//  GET /api/auth/me  — protected
// ─────────────────────────────────────────────
router.get("/me", authMiddleware, getMe);

// ─────────────────────────────────────────────
//  PATCH /api/auth/users/:id/role  — admin only
// ─────────────────────────────────────────────
router.patch(
  "/users/:id/role",
  authMiddleware,
  roleMiddleware("admin"),
  updateRole
);

module.exports = router;