const express        = require("express");
const router         = express.Router();
const authMiddleware = require("../middleware/auth.middleware");
const roleMiddleware = require("../middleware/role.middleware");

const {
  login,
  register,
  getMe,
  updateRole,
} = require("../controllers/auth.controller");

// ─────────────────────────────────────────────
//  POST /api/auth/register  — public
// ─────────────────────────────────────────────
router.post("/register", register);

// ─────────────────────────────────────────────
//  POST /api/auth/login  — public
// ─────────────────────────────────────────────
router.post("/login", login);

// ─────────────────────────────────────────────
//  GET /api/auth/me  — protected
// ─────────────────────────────────────────────
router.get("/me", authMiddleware, getMe);

// ─────────────────────────────────────────────
//  PATCH /api/auth/users/:id/role  — admin only
//  The only legitimate way to elevate a user's role
// ─────────────────────────────────────────────
router.patch(
  "/users/:id/role",
  authMiddleware,
  roleMiddleware("admin"),
  updateRole
);

module.exports = router;