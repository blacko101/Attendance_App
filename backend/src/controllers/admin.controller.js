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
//  Query params:
//    role     — filter by "student" | "lecturer" | "admin"
//    isActive — filter by "true" | "false"
//    search   — partial match on fullName or email
//    page     — page number (default 1)
//    limit    — results per page (default 20, max 100)
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

    // ── Role filter ──────────────────────────────
    const validRoles = ["student", "lecturer", "admin"];
    if (role) {
      if (!validRoles.includes(role)) {
        return res.status(400).json({
          message: `role must be one of: ${validRoles.join(", ")}.`,
        });
      }
      filter.role = role;
    }

    // ── Active / suspended filter ────────────────
    if (isActive !== undefined) {
      filter.isActive = isActive === "true";
    }

    // ── Name / email search ──────────────────────
    // Case-insensitive partial match. We use a regex rather than
    // $text search because the fields don't have a text index, and
    // partial matching ("jo" → "John") works better for a search box.
    if (search) {
      const escaped = search.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const pattern = new RegExp(escaped, "i");
      filter.$or = [{ fullName: pattern }, { email: pattern }];
    }

    // ── Pagination ───────────────────────────────
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
//  Body: { isActive: true | false }
//
//  Sets isActive on the account. Because authMiddleware checks
//  isActive on every request, a suspended user is effectively
//  locked out on their very next API call — no need to invalidate
//  their JWT manually.
// ─────────────────────────────────────────────────────────────────
exports.setUserStatus = async (req, res) => {
  try {
    const { isActive } = req.body;

    if (typeof isActive !== "boolean") {
      return res.status(400).json({ message: "isActive must be a boolean." });
    }

    // Prevent an admin from suspending their own account and locking
    // themselves out of the system entirely.
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
//  LIST ALL ATTENDANCE SESSIONS  (admin view — all lecturers)
//  GET /api/admin/sessions
//  Query params:
//    courseCode — filter by course
//    isActive   — "true" | "false"
//    page, limit
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
//  GET FULL ATTENDANCE REPORT FOR A SESSION  (admin view)
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
//
//  Returns high-level counts for the admin dashboard. Uses
//  Promise.all to run all DB queries in parallel — much faster
//  than awaiting them sequentially.
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