const mongoose = require("mongoose");

// ── Attendance ─────────────────────────────────
// One document per student per session
const attendanceSchema = new mongoose.Schema(
  {
    sessionId: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      "AttendanceSession",
      required: true,
    },
    studentId: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      "User",
      required: true,
    },
    courseCode: {
      type:     String,
      required: true,
    },
    status: {
      type:    String,
      enum:    ["present", "absent", "late"],
      default: "present",
    },
    // Distance from lecturer at time of check-in (inPerson only)
    distanceMetres: {
      type:    Number,
      default: null,
    },
    // Student's GPS at time of check-in
    studentLat: { type: Number, default: null },
    studentLng: { type: Number, default: null },

    // How they checked in
    method: {
      type:    String,
      enum:    ["qr", "code"],  // QR scan or 6-digit code
      default: "qr",
    },

    checkedInAt: {
      type:    Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

// Prevent duplicate check-in for same student + session
attendanceSchema.index(
  { sessionId: 1, studentId: 1 },
  { unique: true }
);

module.exports = mongoose.model("Attendance", attendanceSchema);