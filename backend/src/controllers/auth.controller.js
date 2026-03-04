const User   = require("../models/User");
const bcrypt = require("bcryptjs");
const jwt    = require("jsonwebtoken");

// ─────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────

/** Generate a signed JWT for a user. */
const generateToken = (user) => {
  return jwt.sign(
    { id: user._id, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: "1d" }
  );
};

/**
 * Validate registration input before hitting the DB.
 * NOTE: `role` is intentionally NOT accepted or validated here.
 * All public registrations are hardcoded to "student".
 * Role promotion is handled exclusively by the admin-only updateRole route.
 * Returns an error string on failure, or null on success.
 */
const validateRegisterInput = ({ fullName, email, password }) => {
  if (!fullName || fullName.trim().length < 2) {
    return "Full name must be at least 2 characters.";
  }
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!email || !emailRegex.test(email.trim())) {
    return "Please provide a valid email address.";
  }
  // FIX (Priority 10): Raised minimum from 6 → 8 characters.
  if (!password || password.length < 8) {
    return "Password must be at least 8 characters.";
  }
  return null; // no error
};

// ─────────────────────────────────────────────────────────────────
//  REGISTER
//  POST /api/auth/register
//  Body: { fullName, email, password, indexNumber?,
//          programme?, level?, staffId?, department? }
//
//  ⚠️  SECURITY — Role is NOT accepted from the request body.
//  Every public registration is locked to role:"student".
//  Elevating a user to "lecturer" or "admin" can ONLY be done
//  by an existing admin via PATCH /api/auth/users/:id/role.
//  This closes the critical privilege-escalation vulnerability
//  where a caller could send { "role": "admin" } and instantly
//  gain full admin access.
// ─────────────────────────────────────────────────────────────────
exports.register = async (req, res) => {
  try {
    const {
      fullName,
      email,
      password,
      // role is deliberately destructured and then DISCARDED below.
      // Naming it here makes the intent explicit to future maintainers.
      // eslint-disable-next-line no-unused-vars
      role: _ignoredRole,
      indexNumber,
      programme,
      level,
      staffId,
      department,
    } = req.body;

    // ── Validate input (role not included) ──
    const validationError = validateRegisterInput({ fullName, email, password });
    if (validationError) {
      return res.status(400).json({ message: validationError });
    }

    // ── Check for duplicate email ──
    const existingUser = await User.findOne({ email: email.trim().toLowerCase() });
    if (existingUser) {
      return res.status(409).json({ message: "An account with this email already exists." });
    }

    // ── Hash password ──
    const salt           = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // ── Create user — role is ALWAYS "student" for public registration ──
    const user = await User.create({
      fullName:    fullName.trim(),
      email:       email.trim().toLowerCase(),
      password:    hashedPassword,
      role:        "student",          // ← hardcoded — never trust the client
      indexNumber: indexNumber?.trim(),
      programme:   programme?.trim(),
      level:       level?.toString().trim(),
      staffId:     staffId?.trim(),
      department:  department?.trim(),
    });

    // ── Generate token ──
    const token = generateToken(user);

    // user.toJSON() strips the password hash via the schema's toJSON transform.
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
//  POST /api/auth/login
//  Body: { email, password }
//  Returns: { message, token, user }
// ─────────────────────────────────────────────────────────────────
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // ── Validate input ──
    if (!email || !password) {
      return res.status(400).json({ message: "Email and password are required." });
    }

    // ── Find user and explicitly re-include password ──
    // password has select:false in the schema — opt it back in only here.
    const user = await User.findOne({ email: email.trim().toLowerCase() })
      .select("+password");

    if (!user) {
      // Use identical message for missing user AND wrong password to
      // prevent user-enumeration attacks.
      return res.status(401).json({ message: "Invalid email or password." });
    }

    // ── Check account is active ──
    if (!user.isActive) {
      return res.status(403).json({
        message: "Your account has been suspended. Please contact admin.",
      });
    }

    // ── Compare password ──
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: "Invalid email or password." });
    }

    // ── Generate token ──
    const token = generateToken(user);

    // toJSON() strips the password hash from the response payload
    const safeUser = user.toJSON();

    return res.status(200).json({
      message: "Login successful.",
      token,
      user: safeUser,
    });

  } catch (error) {
    console.error("Login error:", error.message);
    return res.status(500).json({ message: "Server error. Please try again." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET CURRENT USER
//  GET /api/auth/me
//  Headers: Authorization: Bearer <token>
// ─────────────────────────────────────────────────────────────────
exports.getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user.id);

    if (!user) {
      return res.status(404).json({ message: "User not found." });
    }

    // Defence-in-depth: authMiddleware already checked isActive,
    // but we verify again in case this handler is ever called directly.
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
//  UPDATE USER ROLE  ← NEW — closes the privilege-escalation gap
//  PATCH /api/auth/users/:id/role
//  Headers: Authorization: Bearer <admin-token>
//  Body: { role: "student" | "lecturer" | "admin" }
//
//  This is the ONLY legitimate way to elevate a user's role.
//  Must be guarded by authMiddleware + roleMiddleware("admin")
//  in auth.routes.js — see route file for wiring.
// ─────────────────────────────────────────────────────────────────
exports.updateRole = async (req, res) => {
  try {
    const { role } = req.body;
    const validRoles = ["student", "lecturer", "admin"];

    if (!role || !validRoles.includes(role)) {
      return res.status(400).json({
        message: `Role must be one of: ${validRoles.join(", ")}.`,
      });
    }

    // Prevent an admin from accidentally locking themselves out
    // by demoting their own account.
    if (req.params.id === req.user.id) {
      return res.status(400).json({
        message: "You cannot change your own role.",
      });
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