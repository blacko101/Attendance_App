const express = require("express");
const router = express.Router();
const { register, login } = require("../controllers/auth.controller");

const authMiddleware = require("../middleware/auth.middleware");
const roleMiddleware = require("../middleware/role.middleware");

router.post("/register", register);
router.post("/login", login);

// Protected test route
router.get(
  "/dashboard",
  authMiddleware,
  roleMiddleware("student", "lecturer", "admin"),
  (req, res) => {
    res.json({
      message: "Welcome to your dashboard",
      user: req.user,
    });
  }
);

module.exports = router;
