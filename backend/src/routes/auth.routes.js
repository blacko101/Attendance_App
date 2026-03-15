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

// Protected
router.get("/me",               authMiddleware, getMe);
router.post("/change-password", authMiddleware, changePassword);

// Admin only
router.patch("/users/:id/role", authMiddleware, roleMiddleware("admin"), updateRole);

module.exports = router;