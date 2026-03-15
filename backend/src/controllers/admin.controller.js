const User              = require("../models/User");
const Attendance        = require("../models/Attendance");
const AttendanceSession = require("../models/AttendanceSession");

// ─────────────────────────────────────────────────────────────────
//  All handlers here are admin-only.
//  authMiddleware + roleMiddleware("admin") is applied in the
//  route file — these handlers do not repeat those checks.
// ─────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────
//  LIST ALL USERS
//  GET /api/admin/users
// ─────────────────────────────────────────────────────────────────
exports.listUsers = async (req, res) => {
  try {
    const {
      role,
      isActive,
      search,
      page  = 1,
      limit = 20,
    } = req.query;

    const filter = {};

    const validRoles = ["student", "lecturer", "admin"];
    if (role) {
      if (!validRoles.includes(role)) {
        return res.status(400).json({
          message: `role must be one of: ${validRoles.join(", ")}.`,
        });
      }
      filter.role = role;
    }

    if (isActive !== undefined) {
      filter.isActive = isActive === "true";
    }

    if (search) {
      const escaped = search.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const pattern = new RegExp(escaped, "i");
      filter.$or = [{ fullName: pattern }, { email: pattern }];
    }

    const pageNum  = Math.max(1, parseInt(page, 10)  || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip     = (pageNum - 1) * limitNum;

    const [users, total] = await Promise.all([
      User.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limitNum),
      User.countDocuments(filter),
    ]);

    return res.status(200).json({
      total,
      page:       pageNum,
      totalPages: Math.ceil(total / limitNum),
      count:      users.length,
      users,
    });

  } catch (err) {
    console.error("listUsers error:", err.message);
    return res.status(500).json({ message: "Server error. Please try again." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  CREATE USER
//  POST /api/admin/users
//  Auth: admin only
// ─────────────────────────────────────────────────────────────────
exports.createUser = async (req, res) => {
  try {
    const {
      fullName,
      email,
      role       = "student",
      indexNumber,
      programme,
      level,
      staffId,
      department,
    } = req.body;

    if (!fullName || !email) {
      return res.status(400).json({
        message: "fullName and email are required.",
      });
    }

    if (!email.toLowerCase().endsWith("@central.edu.gh")) {
      return res.status(400).json({
        message: "Email must end in @central.edu.gh.",
      });
    }

    if (role === "student") {
      if (!programme) {
        return res.status(400).json({ message: "programme is required for students." });
      }
      if (!level || !["100","200","300","400","500"].includes(String(level))) {
        return res.status(400).json({ message: "level must be 100, 200, 300, 400 or 500." });
      }
      if (!indexNumber) {
        return res.status(400).json({ message: "indexNumber is required for students." });
      }
    }

    const existing = await User.findOne({ email: email.toLowerCase() });
    if (existing) {
      return res.status(409).json({ message: "A user with this email already exists." });
    }

    // All admin-created accounts get the fixed default password.
    // mustChangePassword forces the user to change it on first login.
    const rawPassword    = "Central@123";
    const hashedPassword = await require("bcryptjs").hash(rawPassword, 10);

    const user = await User.create({
      fullName:           fullName.trim(),
      email:              email.trim().toLowerCase(),
      password:           hashedPassword,
      role,
      indexNumber:        indexNumber || undefined,
      programme:          programme   || undefined,
      level:              level       ? String(level) : undefined,
      staffId:            staffId     || undefined,
      department:         department  || undefined,
      isActive:           true,
      mustChangePassword: true,
    });

    return res.status(201).json({
      message:           "User created successfully.",
      user,
      temporaryPassword: rawPassword,
    });

  } catch (err) {
    if (err.code === 11000) {
      const field = Object.keys(err.keyPattern || {})[0] || "field";
      return res.status(409).json({
        message: `A user with this ${field} already exists.`,
      });
    }
    console.error("createUser error:", err.message);
    return res.status(500).json({ message: "Server error. Please try again." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET SINGLE USER
//  GET /api/admin/users/:id
// ─────────────────────────────────────────────────────────────────
exports.getUser = async (req, res) => {
  try {
    const user = await User.findById(req.params.id);

    if (!user) {
      return res.status(404).json({ message: "User not found." });
    }

    return res.status(200).json({ user });

  } catch (err) {
    console.error("getUser error:", err.message);
    return res.status(500).json({ message: "Server error. Please try again." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  SUSPEND / REACTIVATE USER
//  PATCH /api/admin/users/:id/status
// ─────────────────────────────────────────────────────────────────
exports.setUserStatus = async (req, res) => {
  try {
    const { isActive } = req.body;

    if (typeof isActive !== "boolean") {
      return res.status(400).json({ message: "isActive must be a boolean." });
    }

    if (req.params.id === req.user.id) {
      return res.status(400).json({
        message: "You cannot change the status of your own account.",
      });
    }

    const user = await User.findByIdAndUpdate(
      req.params.id,
      { isActive },
      { new: true, runValidators: true }
    );

    if (!user) {
      return res.status(404).json({ message: "User not found." });
    }

    return res.status(200).json({
      message: `Account ${isActive ? "reactivated" : "suspended"} successfully.`,
      user,
    });

  } catch (err) {
    console.error("setUserStatus error:", err.message);
    return res.status(500).json({ message: "Server error. Please try again." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  LIST ALL ATTENDANCE SESSIONS
//  GET /api/admin/sessions
// ─────────────────────────────────────────────────────────────────
exports.listSessions = async (req, res) => {
  try {
    const {
      courseCode,
      isActive,
      page  = 1,
      limit = 20,
    } = req.query;

    const filter = {};

    if (courseCode) filter.courseCode = courseCode.toUpperCase();

    if (isActive !== undefined) {
      filter.isActive = isActive === "true";
    }

    const pageNum  = Math.max(1, parseInt(page, 10)  || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip     = (pageNum - 1) * limitNum;

    const [sessions, total] = await Promise.all([
      AttendanceSession.find(filter)
        .populate("lecturerId", "fullName email staffId")
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limitNum),
      AttendanceSession.countDocuments(filter),
    ]);

    return res.status(200).json({
      total,
      page:       pageNum,
      totalPages: Math.ceil(total / limitNum),
      count:      sessions.length,
      sessions,
    });

  } catch (err) {
    console.error("listSessions error:", err.message);
    return res.status(500).json({ message: "Server error. Please try again." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET FULL ATTENDANCE REPORT FOR A SESSION
//  GET /api/admin/sessions/:sessionId/report
// ─────────────────────────────────────────────────────────────────
exports.getSessionReport = async (req, res) => {
  try {
    const session = await AttendanceSession.findById(req.params.sessionId)
      .populate("lecturerId", "fullName email");

    if (!session) {
      return res.status(404).json({ message: "Session not found." });
    }

    const records = await Attendance.find({ sessionId: req.params.sessionId })
      .populate("studentId", "fullName email indexNumber programme level")
      .sort({ checkedInAt: 1 });

    return res.status(200).json({
      session,
      count:   records.length,
      records,
    });

  } catch (err) {
    console.error("getSessionReport error:", err.message);
    return res.status(500).json({ message: "Server error. Please try again." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  DASHBOARD STATS
//  GET /api/admin/stats
// ─────────────────────────────────────────────────────────────────
exports.getStats = async (req, res) => {
  try {
    const [
      totalUsers,
      totalStudents,
      totalLecturers,
      totalAdmins,
      suspendedUsers,
      totalSessions,
      activeSessions,
      totalAttendance,
    ] = await Promise.all([
      User.countDocuments({}),
      User.countDocuments({ role: "student" }),
      User.countDocuments({ role: "lecturer" }),
      User.countDocuments({ role: "admin" }),
      User.countDocuments({ isActive: false }),
      AttendanceSession.countDocuments({}),
      AttendanceSession.countDocuments({ isActive: true }),
      Attendance.countDocuments({}),
    ]);

    return res.status(200).json({
      users: {
        total:     totalUsers,
        students:  totalStudents,
        lecturers: totalLecturers,
        admins:    totalAdmins,
        suspended: suspendedUsers,
      },
      sessions: {
        total:  totalSessions,
        active: activeSessions,
      },
      attendance: {
        total: totalAttendance,
      },
    });

  } catch (err) {
    console.error("getStats error:", err.message);
    return res.status(500).json({ message: "Server error. Please try again." });
  }
};