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
  registerFace,
} = require("../controllers/auth.controller");

router.post("/register", register);
router.post("/login",    login);

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

router.post("/login", login);

router.get("/me", authMiddleware, getMe);

router.post("/change-password", authMiddleware, changePassword);

// ── Face registration — student only ──────────────────────────────
router.post(
  "/register-face",
  authMiddleware,
  roleMiddleware("student"),
  registerFace
);

router.patch(
  "/users/:id/role",
  authMiddleware,
  roleMiddleware("admin"),
  updateRole
);

module.exports = router;