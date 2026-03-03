const express = require("express");
const router = express.Router();

const { register, login, getMe } = require("../controllers/auth.controller");
const authMiddleware  = require("../middleware/auth.middleware");
const roleMiddleware  = require("../middleware/role.middleware");

// ── Public routes ──
router.post("/register", register);
router.post("/login",    login);

// ── Protected routes ──
router.get(
  "/me",
  authMiddleware,
  roleMiddleware("student", "lecturer", "admin"),
  getMe
);

module.exports = router;