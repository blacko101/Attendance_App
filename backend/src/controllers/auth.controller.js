const User = require("../models/User");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

// ─────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────

/** Generate a signed JWT for a user */
const generateToken = (user) => {
  return jwt.sign(
    { id: user._id, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: "1d" }
  );
};

/** Validate registration input before hitting the DB */
const validateRegisterInput = ({ fullName, email, password, role }) => {
  if (!fullName || fullName.trim().length < 2) {
    return "Full name must be at least 2 characters.";
  }
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!email || !emailRegex.test(email.trim())) {
    return "Please provide a valid email address.";
  }
  if (!password || password.length < 6) {
    return "Password must be at least 6 characters.";
  }
  const validRoles = ["student", "lecturer", "admin"];
  if (role && !validRoles.includes(role)) {
    return `Role must be one of: ${validRoles.join(", ")}.`;
  }
  return null; // no error
};

// ─────────────────────────────────────────────────────────────────
//  REGISTER
//  POST /api/auth/register
//  Body: { fullName, email, password, role?, indexNumber?,
//          programme?, level?, staffId?, department? }
//  Returns token immediately — no second login needed
// ─────────────────────────────────────────────────────────────────
exports.register = async (req, res) => {
  try {
    const {
      fullName,
      email,
      password,
      role,
      indexNumber,
      programme,
      level,
      staffId,
      department,
    } = req.body;

    // ── Validate input ──
    const validationError = validateRegisterInput({ fullName, email, password, role });
    if (validationError) {
      return res.status(400).json({ message: validationError });
    }

    // ── Check duplicate email ──
    const existingUser = await User.findOne({ email: email.trim().toLowerCase() });
    if (existingUser) {
      return res.status(409).json({ message: "An account with this email already exists." });
    }

    // ── Hash password ──
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // ── Create user ──
    const user = await User.create({
      fullName:    fullName.trim(),
      email:       email.trim().toLowerCase(),
      password:    hashedPassword,
      role:        role || "student",
      indexNumber: indexNumber?.trim(),
      programme:   programme?.trim(),
      level:       level?.toString().trim(),
      staffId:     staffId?.trim(),
      department:  department?.trim(),
    });

    // ── Generate token immediately (no second login needed) ──
    const token = generateToken(user);

    // ── Return user + token (password excluded by toJSON transform) ──
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

    // ── Find user ──
    // Use .select("+password") because toJSON strips it — we need it to compare
    const user = await User.findOne({ email: email.trim().toLowerCase() })
      .select("+password");

    if (!user) {
      // 401 Unauthorized — correct status for failed authentication
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

    // ── Build safe user response (password excluded by toJSON) ──
    const safeUser = user.toJSON(); // password removed by schema transform

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
//  GET CURRENT USER (ME)
//  GET /api/auth/me
//  Headers: Authorization: Bearer <token>
//  Returns the logged-in user's full profile
// ─────────────────────────────────────────────────────────────────
exports.getMe = async (req, res) => {
  try {
    // req.user is set by authMiddleware { id, role }
    const user = await User.findById(req.user.id);

    if (!user) {
      return res.status(404).json({ message: "User not found." });
    }

    return res.status(200).json({ user });

  } catch (error) {
    console.error("GetMe error:", error.message);
    return res.status(500).json({ message: "Server error. Please try again." });
  }
};