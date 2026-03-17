const User              = require("../models/User");
const Attendance        = require("../models/Attendance");
const AttendanceSession = require("../models/AttendanceSession");

// ── Programme → Faculty lookup (mirrors school_data.dart) ─────────
const PROGRAMME_TO_FACULTY = {
  // School of Engineering & Technology
  "BSc Civil Engineering":    "School of Engineering & Technology",
  "BSc Computer Science":     "School of Engineering & Technology",
  "BSc Information Technology": "School of Engineering & Technology",
  // School of Architecture & Design
  "BSc Fashion Design":   "School of Architecture & Design",
  "BSc Interior Design":  "School of Architecture & Design",
  "BSc Landscape Design": "School of Architecture & Design",
  "BSc Graphic Design":   "School of Architecture & Design",
  "BSc Real Estate":      "School of Architecture & Design",
  // School of Nursing & Midwifery
  "BSc Nursing": "School of Nursing & Midwifery",
  // Faculty of Arts & Social Sciences
  "BA Communication Studies": "Faculty of Arts & Social Sciences",
  "BA Economics":             "Faculty of Arts & Social Sciences",
  "BA Development Studies":   "Faculty of Arts & Social Sciences",
  "BA Social Sciences":       "Faculty of Arts & Social Sciences",
  "BA Religious Studies":     "Faculty of Arts & Social Sciences",
  // Central Business School
  "BSc Accounting":               "Central Business School",
  "BSc Banking & Finance":        "Central Business School",
  "BSc Marketing":                "Central Business School",
  "BSc Human Resource Management":"Central Business School",
  "BSc Business Administration":  "Central Business School",
  // School of Medical Sciences
  "MBChB (Medicine)":          "School of Medical Sciences",
  "BSc Physician Assistantship":"School of Medical Sciences",
  // School of Pharmacy
  "Doctor of Pharmacy (PharmD)": "School of Pharmacy",
  // Central Law School
  "LLB (Bachelor of Laws)": "Central Law School",
  // School of Graduate Studies & Research
  "MSc Accounting":           "School of Graduate Studies & Research",
  "MPhil Accounting":         "School of Graduate Studies & Research",
  "MA Religious Studies":     "School of Graduate Studies & Research",
  "MPhil Theology":           "School of Graduate Studies & Research",
  "MBA Finance":              "School of Graduate Studies & Research",
  "MBA General Management":   "School of Graduate Studies & Research",
  "MBA Human Resource Management":"School of Graduate Studies & Research",
  "MBA Marketing":            "School of Graduate Studies & Research",
  "MBA Project Management":   "School of Graduate Studies & Research",
  "MBA Agribusiness":         "School of Graduate Studies & Research",
  "MPhil Economics":          "School of Graduate Studies & Research",
  "Master of Public Health":  "School of Graduate Studies & Research",
  "MA Development Policy":    "School of Graduate Studies & Research",
  "MPhil Development Policy": "School of Graduate Studies & Research",
  "PhD Finance":              "School of Graduate Studies & Research",
  "DBA (Doctor of Business Administration)":"School of Graduate Studies & Research",
  // Centre for Distance & Professional Education
  "Distance Business Programs":            "Centre for Distance & Professional Education",
  "Distance Theology Programs":            "Centre for Distance & Professional Education",
  "Professional / Diploma Programs (ATHE)":"Centre for Distance & Professional Education",
};

// ─────────────────────────────────────────────────────────────────
//  LIST ALL USERS
//  GET /api/admin/users
// ─────────────────────────────────────────────────────────────────
exports.listUsers = async (req, res) => {
  try {
    const { role, isActive, search, page = 1, limit = 20 } = req.query;

    const filter = {};

    const validRoles = ["student", "lecturer", "admin", "dean"];
    if (role) {
      if (!validRoles.includes(role)) {
        return res.status(400).json({ message: `role must be one of: ${validRoles.join(", ")}.` });
      }
      filter.role = role;
    }

    if (isActive !== undefined) filter.isActive = isActive === "true";

    if (search) {
      const escaped = search.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const pattern = new RegExp(escaped, "i");
      filter.$or = [{ fullName: pattern }, { email: pattern }];
    }

    const pageNum  = Math.max(1, parseInt(page, 10)  || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip     = (pageNum - 1) * limitNum;

    const [users, total] = await Promise.all([
      User.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limitNum),
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
// ─────────────────────────────────────────────────────────────────
exports.createUser = async (req, res) => {
  try {
    const {
      fullName, email,
      role = "student",
      indexNumber, programme, level,
      staffId,
      faculty,
      department,
      departments,   // array — for lecturers
    } = req.body;

    if (!fullName || !email) {
      return res.status(400).json({ message: "fullName and email are required." });
    }
    if (!email.toLowerCase().endsWith("@central.edu.gh")) {
      return res.status(400).json({ message: "Email must end in @central.edu.gh." });
    }

    // ── Student validation ───────────────────────────────────────
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

    // ── Lecturer validation ──────────────────────────────────────
    if (role === "lecturer") {
      const depts = Array.isArray(departments) ? departments : (department ? [department] : []);
      if (depts.length === 0) {
        return res.status(400).json({ message: "At least one department is required for lecturers." });
      }
    }

    const existing = await User.findOne({ email: email.toLowerCase() });
    if (existing) {
      return res.status(409).json({ message: "A user with this email already exists." });
    }

    const rawPassword    = "Central@123";
    const hashedPassword = await require("bcryptjs").hash(rawPassword, 10);

    // ── Auto-derive faculty for students ─────────────────────────
    let resolvedFaculty = faculty || "";
    if (role === "student" && programme) {
      resolvedFaculty = PROGRAMME_TO_FACULTY[programme] || resolvedFaculty;
    }

    // ── Normalise departments for lecturers ──────────────────────
    let resolvedDepartments = [];
    let resolvedDepartment  = department || undefined;
    if (role === "lecturer") {
      resolvedDepartments = Array.isArray(departments)
        ? departments.filter(Boolean)
        : (department ? [department] : []);
      resolvedDepartment = resolvedDepartments[0] || undefined;
    }

    const user = await User.create({
      fullName:           fullName.trim(),
      email:              email.trim().toLowerCase(),
      password:           hashedPassword,
      role,
      indexNumber:        indexNumber   || undefined,
      programme:          programme     || undefined,
      level:              level         ? String(level) : undefined,
      staffId:            staffId       || undefined,
      faculty:            resolvedFaculty || undefined,
      department:         resolvedDepartment,
      departments:        resolvedDepartments,
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
      return res.status(409).json({ message: `A user with this ${field} already exists.` });
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
    if (!user) return res.status(404).json({ message: "User not found." });
    return res.status(200).json({ user });
  } catch (err) {
    console.error("getUser error:", err.message);
    return res.status(500).json({ message: "Server error. Please try again." });
  }
};

// ─────────────────────────────────────────────────────────────────
//  UPDATE USER DETAILS
//  PATCH /api/admin/users/:id
//  Allows editing: fullName, staffId, indexNumber, programme,
//  level, faculty, department, departments
// ─────────────────────────────────────────────────────────────────
exports.updateUser = async (req, res) => {
  try {
    const allowed = [
      "fullName", "staffId", "indexNumber",
      "programme", "level",
      "faculty", "department", "departments",
    ];

    const updates = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) updates[key] = req.body[key];
    }

    // If programme changed, re-derive faculty automatically
    if (updates.programme) {
      updates.faculty = PROGRAMME_TO_FACULTY[updates.programme] || updates.faculty || "";
    }

    // Keep departments array and department field in sync for lecturers
    if (updates.departments && Array.isArray(updates.departments)) {
      updates.departments = updates.departments.filter(Boolean);
      updates.department  = updates.departments[0] || null;
    } else if (updates.department && !updates.departments) {
      updates.departments = [updates.department];
    }

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ message: "No valid fields to update." });
    }

    const user = await User.findByIdAndUpdate(
      req.params.id,
      { $set: updates },
      { new: true, runValidators: true }
    );

    if (!user) return res.status(404).json({ message: "User not found." });

    return res.status(200).json({ message: "User updated successfully.", user });
  } catch (err) {
    if (err.code === 11000) {
      const field = Object.keys(err.keyPattern || {})[0] || "field";
      return res.status(409).json({ message: `A user with this ${field} already exists.` });
    }
    console.error("updateUser error:", err.message);
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
      return res.status(400).json({ message: "You cannot change the status of your own account." });
    }
    const user = await User.findByIdAndUpdate(
      req.params.id,
      { isActive },
      { new: true, runValidators: true }
    );
    if (!user) return res.status(404).json({ message: "User not found." });
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
    const { courseCode, isActive, page = 1, limit = 20 } = req.query;
    const filter = {};
    if (courseCode) filter.courseCode = courseCode.toUpperCase();
    if (isActive !== undefined) filter.isActive = isActive === "true";

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
    if (!session) return res.status(404).json({ message: "Session not found." });

    const records = await Attendance.find({ sessionId: req.params.sessionId })
      .populate("studentId", "fullName email indexNumber programme level")
      .sort({ checkedInAt: 1 });

    return res.status(200).json({ session, count: records.length, records });
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
      totalUsers, totalStudents, totalLecturers, totalAdmins,
      suspendedUsers, totalSessions, activeSessions, totalAttendance,
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
      users:      { total: totalUsers, students: totalStudents, lecturers: totalLecturers, admins: totalAdmins, suspended: suspendedUsers },
      sessions:   { total: totalSessions, active: activeSessions },
      attendance: { total: totalAttendance },
    });
  } catch (err) {
    console.error("getStats error:", err.message);
    return res.status(500).json({ message: "Server error. Please try again." });
  }
};