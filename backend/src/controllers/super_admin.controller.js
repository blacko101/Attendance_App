"use strict";

const User              = require("../models/User");
const Attendance        = require("../models/Attendance");
const AttendanceSession = require("../models/AttendanceSession");
const bcrypt            = require("bcryptjs");

// ─────────────────────────────────────────────────────────────────
//  GET SUPER ADMIN DASHBOARD
//  GET /api/super-admin/dashboard
//  Auth: super_admin only
//  Returns list of all department admins with their department's
//  student count and lecturer count.
// ─────────────────────────────────────────────────────────────────
exports.getDashboard = async (req, res) => {
  try {
    const admins = await User.find({ role: "admin", isActive: true })
      .sort({ faculty: 1 })
      .select("fullName email faculty department staffId createdAt");

    // For each admin, count students + lecturers in their faculty
    const enriched = await Promise.all(admins.map(async (a) => {
      const dept = a.faculty || a.department || "";
      const [students, lecturers] = await Promise.all([
        User.countDocuments({ role: "student", isActive: true, faculty: dept }),
        User.countDocuments({ role: "lecturer", isActive: true,
          $or: [{ faculty: dept }, { departments: dept }] }),
      ]);
      return {
        id:          a._id,
        fullName:    a.fullName,
        email:       a.email,
        department:  dept,
        staffId:     a.staffId || "",
        createdAt:   a.createdAt,
        students,
        lecturers,
      };
    }));

    // Overall system totals
    const [totalStudents, totalLecturers, totalAdmins] = await Promise.all([
      User.countDocuments({ role: "student",  isActive: true }),
      User.countDocuments({ role: "lecturer", isActive: true }),
      User.countDocuments({ role: "admin",    isActive: true }),
    ]);

    return res.status(200).json({
      totals: { totalStudents, totalLecturers, totalAdmins },
      admins: enriched,
    });
  } catch (err) {
    console.error("getDashboard error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  GET ADMIN DETAIL
//  GET /api/super-admin/admins/:id
//  Auth: super_admin only
//  Returns drill-down: courses with student counts by level,
//  list of lecturers in that department.
// ─────────────────────────────────────────────────────────────────
exports.getAdminDetail = async (req, res) => {
  try {
    const mongoose = require("mongoose");
    const Course   = mongoose.models.Course;

    const admin = await User.findById(req.params.id).select(
      "fullName email faculty department staffId createdAt"
    );
    if (!admin || admin.role !== "admin") {
      return res.status(404).json({ message: "Admin not found." });
    }

    const dept = admin.faculty || admin.department || "";

    // Lecturers in this department
    const lecturers = await User.find({
      role:     "lecturer",
      isActive: true,
      $or: [{ faculty: dept }, { departments: dept }],
    }).select("fullName email staffId");

    // Students by level
    const levels = ["100", "200", "300", "400", "500"];
    const studentsByLevel = await Promise.all(
      levels.map(async (level) => {
        const count = await User.countDocuments({
          role: "student", isActive: true,
          faculty: dept, level,
        });
        return { level, count };
      })
    );

    // Courses in this department with enrolled student counts
    let courses = [];
    if (Course) {
      const rawCourses = await Course.find({
        $or: [{ faculty: dept }, { department: dept }],
      }).sort({ courseCode: 1 }).select("courseCode courseName level programme enrolledStudents assignedLecturerName");

      courses = rawCourses.map(c => ({
        courseCode:          c.courseCode,
        courseName:          c.courseName,
        level:               c.level,
        programme:           c.programme,
        enrolledStudents:    c.enrolledStudents || 0,
        assignedLecturerName: c.assignedLecturerName || "TBA",
      }));
    }

    return res.status(200).json({
      admin: {
        id:         admin._id,
        fullName:   admin.fullName,
        email:      admin.email,
        department: dept,
        staffId:    admin.staffId || "",
        createdAt:  admin.createdAt,
      },
      studentsByLevel: studentsByLevel.filter(s => s.count > 0),
      totalStudents:   studentsByLevel.reduce((s, l) => s + l.count, 0),
      lecturers,
      courses,
    });
  } catch (err) {
    console.error("getAdminDetail error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  CREATE ADMIN
//  POST /api/super-admin/admins
//  Auth: super_admin only
//  Body: { fullName, email, department }
//  Auto-assigns default password "Central@123", mustChangePassword=true
// ─────────────────────────────────────────────────────────────────
exports.createAdmin = async (req, res) => {
  try {
    const { fullName, email, department } = req.body;

    if (!fullName || !email || !department) {
      return res.status(400).json({
        message: "fullName, email and department are required.",
      });
    }
    if (!email.toLowerCase().endsWith("@central.edu.gh")) {
      return res.status(400).json({
        message: "Email must end in @central.edu.gh.",
      });
    }

    const existing = await User.findOne({ email: email.toLowerCase() });
    if (existing) {
      return res.status(409).json({
        message: "A user with this email already exists.",
      });
    }

    const defaultPassword = "Central@123";
    const hashed = await bcrypt.hash(defaultPassword, 10);

    const admin = await User.create({
      fullName:          fullName.trim(),
      email:             email.toLowerCase().trim(),
      password:          hashed,
      role:              "admin",
      faculty:           department,
      department:        department,
      departments:       [department],
      mustChangePassword: true,
      isActive:          true,
    });

    return res.status(201).json({
      message:         "Admin created successfully.",
      defaultPassword, // returned once so super admin can share it
      admin: {
        id:         admin._id,
        fullName:   admin.fullName,
        email:      admin.email,
        department: admin.department,
      },
    });
  } catch (err) {
    console.error("createAdmin error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  LIST ALL FACULTIES
//  GET /api/super-admin/faculties
//  Auth: super_admin only
//  Returns list of faculties from the Faculty collection (DB-driven).
//  Falls back to deriving from existing admin faculty fields.
// ─────────────────────────────────────────────────────────────────
exports.listFaculties = async (req, res) => {
  try {
    const mongoose = require("mongoose");
    const Faculty  = mongoose.models.Faculty;

    if (Faculty) {
      const faculties = await Faculty.find({}).sort({ name: 1 });
      return res.status(200).json({ faculties });
    }

    // Fallback: derive from existing admin users
    const admins = await User.find({ role: "admin" }).select("faculty department");
    const names  = [...new Set(
      admins.map(a => a.faculty || a.department).filter(Boolean)
    )].sort();

    return res.status(200).json({
      faculties: names.map(n => ({ name: n, programmes: [] })),
    });
  } catch (err) {
    console.error("listFaculties error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  CREATE FACULTY
//  POST /api/super-admin/faculties
//  Auth: super_admin only
//  Body: { name }
// ─────────────────────────────────────────────────────────────────
exports.createFaculty = async (req, res) => {
  try {
    const mongoose = require("mongoose");

    // Register Faculty model if not already registered
    if (!mongoose.models.Faculty) {
      mongoose.model("Faculty", new mongoose.Schema({
        name:       { type: String, required: true, unique: true, trim: true },
        programmes: { type: [String], default: [] },
      }, { timestamps: true }));
    }
    const Faculty = mongoose.models.Faculty;

    const { name } = req.body;
    if (!name) {
      return res.status(400).json({ message: "Faculty name is required." });
    }

    const existing = await Faculty.findOne({ name: name.trim() });
    if (existing) {
      return res.status(409).json({ message: "This faculty already exists." });
    }

    const faculty = await Faculty.create({ name: name.trim() });
    return res.status(201).json({ faculty });
  } catch (err) {
    console.error("createFaculty error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
//  DEACTIVATE ADMIN
//  PATCH /api/super-admin/admins/:id/status
//  Auth: super_admin only
//  Body: { isActive: true | false }
// ─────────────────────────────────────────────────────────────────
exports.setAdminStatus = async (req, res) => {
  try {
    const { isActive } = req.body;
    const admin = await User.findOneAndUpdate(
      { _id: req.params.id, role: "admin" },
      { isActive: Boolean(isActive) },
      { new: true }
    ).select("fullName email faculty isActive");

    if (!admin) return res.status(404).json({ message: "Admin not found." });
    return res.status(200).json({ admin });
  } catch (err) {
    console.error("setAdminStatus error:", err.message);
    return res.status(500).json({ error: err.message });
  }
};