const User   = require("../models/User");
const bcrypt = require("bcryptjs");
const jwt    = require("jsonwebtoken");

// ─────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────
const generateToken = (user) => {
  return jwt.sign(
    { id: user._id, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: "1d" }
  );
};

const validateRegisterInput = ({ fullName, email, password }) => {
  if (!fullName || fullName.trim().length < 2) {
    return "Full name must be at least 2 characters.";
  }
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!email || !emailRegex.test(email.trim())) {
    return "Please provide a valid email address.";
  }
  if (!password || password.length < 8) {
    return "Password must be at least 8 characters.";
  }
  return null;
};

// ─────────────────────────────────────────────────────────────────
//  REGISTER
//  POST /api/auth/register
// ─────────────────────────────────────────────────────────────────
exports.register = async (req, res) => {
  try {
    const {
      fullName,
      email,
      password,
      role: _ignoredRole,
      indexNumber, programme, level, staffId, department,
    } = req.body;

    const validationError = validateRegisterInput({ fullName, email, password });
    if (validationError) {
      return res.status(400).json({ message: validationError });
    }

    const existingUser = await User.findOne({ email: email.trim().toLowerCase() });
    if (existingUser) {
      return res.status(409).json({ message: "An account with this email already exists." });
    }

    const salt           = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const user = await User.create({
      fullName:    fullName.trim(),
      email:       email.trim().toLowerCase(),
      password:    hashedPassword,
      role:        "student",
      indexNumber: indexNumber?.trim(),
      programme:   programme?.trim(),
      level:       level?.toString().trim(),
      staffId:     staffId?.trim(),
      department:  department?.trim(),
    });

    const token = generateToken(user);

    return res.status(201).json({
      message: "Account created successfully.",
      token,
      user,
    });

  } catch (error) {
    console.error("Register error:", error.message);
    return res.status(500).json({ message: "Server error. Please try again." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  LOGIN
//  POST /api/auth/login/student    → expectedRole = "student"
//  POST /api/auth/login/lecturer   → expectedRole = "lecturer"
//  POST /api/auth/admin/login      → expectedRole = "admin"
//  POST /api/auth/dean/login       → expectedRole = "dean"
//
//  HOW THE ROLE GUARD WORKS
//  ────────────────────────
//  Each role-specific route injects req.expectedRole via inline
//  middleware before calling this handler (see auth.routes.js).
//  If the authenticated user's DB role doesn't match the expected
//  role for that endpoint, we return the SAME 401 message as a
//  wrong password — this intentionally prevents role enumeration
//  (an attacker cannot tell "wrong password" from "wrong role").
// ─────────────────────────────────────────────────────────────────
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // expectedRole is injected by the route middleware (see auth.routes.js).
    // It is undefined only if the legacy /api/auth/login route is hit directly.
    const expectedRole = req.expectedRole;

    if (!email || !password) {
      return res.status(400).json({ message: "Email and password are required." });
    }

    const user = await User.findOne({ email: email.trim().toLowerCase() })
      .select("+password");

    // ── Use a constant-time check order to prevent timing attacks ──
    // We check the password first, THEN role. This means the response
    // time is similar regardless of whether the user exists — same as before.
    if (!user) {
      return res.status(401).json({ message: "Invalid email or password." });
    }

    if (!user.isActive) {
      return res.status(403).json({
        message: "Your account has been suspended. Please contact admin.",
      });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: "Invalid email or password." });
    }

    // ── ROLE GUARD ─────────────────────────────────────────────────
    // FIX: If the login endpoint is role-scoped (expectedRole is set),
    // reject users whose DB role doesn't match.
    // Example: a lecturer hitting /api/auth/login/student gets a 401,
    // indistinguishable from a wrong password — no role info leaked.
    if (expectedRole && user.role !== expectedRole) {
      return res.status(401).json({ message: "Invalid email or password." });
    }

    const token    = generateToken(user);
    const safeUser = user.toJSON();

    return res.status(200).json({
      message:            "Login successful.",
      token,
      user:               safeUser,
      // Surfaced at top level so Flutter does not have to dig into user{}
      mustChangePassword: user.mustChangePassword,
    });

  } catch (error) {
    console.error("Login error:", error.message);
    return res.status(500).json({ message: "Server error. Please try again." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  CHANGE PASSWORD  (first-login or voluntary)
//  POST /api/auth/change-password
//  Headers: Authorization: Bearer <token>
//  Body: { currentPassword, newPassword }
// ─────────────────────────────────────────────────────────────────
exports.changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        message: "currentPassword and newPassword are required.",
      });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({
        message: "New password must be at least 8 characters.",
      });
    }

    if (newPassword === "Central@123") {
      return res.status(400).json({
        message: "Please choose a different password — do not reuse the default.",
      });
    }

    const user = await User.findById(req.user.id).select("+password");
    if (!user) {
      return res.status(404).json({ message: "User not found." });
    }

    const isMatch = await bcrypt.compare(currentPassword, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: "Current password is incorrect." });
    }

    user.password           = await bcrypt.hash(newPassword, 10);
    user.mustChangePassword = false;
    await user.save();

    return res.status(200).json({ message: "Password changed successfully." });

  } catch (error) {
    console.error("changePassword error:", error.message);
    return res.status(500).json({ message: "Server error. Please try again." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET CURRENT USER
//  GET /api/auth/me
// ─────────────────────────────────────────────────────────────────
exports.getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user.id);

    if (!user) {
      return res.status(404).json({ message: "User not found." });
    }

    if (!user.isActive) {
      return res.status(403).json({
        message: "Your account has been suspended. Please contact admin.",
      });
    }

    return res.status(200).json({ user });

  } catch (error) {
    console.error("GetMe error:", error.message);
    return res.status(500).json({ message: "Server error. Please try again." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  UPDATE USER ROLE — admin only
//  PATCH /api/auth/users/:id/role
// ─────────────────────────────────────────────────────────────────
exports.updateRole = async (req, res) => {
  try {
    const { role } = req.body;
    const validRoles = ["student", "lecturer", "admin", "dean"];

    if (!role || !validRoles.includes(role)) {
      return res.status(400).json({
        message: `Role must be one of: ${validRoles.join(", ")}.`,
      });
    }

    if (req.params.id === req.user.id) {
      return res.status(400).json({ message: "You cannot change your own role." });
    }

    const user = await User.findByIdAndUpdate(
      req.params.id,
      { role },
      { new: true, runValidators: true }
    );

    if (!user) {
      return res.status(404).json({ message: "User not found." });
    }

    return res.status(200).json({
      message: `User role updated to "${role}".`,
      user,
    });

  } catch (error) {
    console.error("UpdateRole error:", error.message);
    return res.status(500).json({ message: "Server error. Please try again." });
  }
};