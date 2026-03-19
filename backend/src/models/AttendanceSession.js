const mongoose = require("mongoose");

// ── AttendanceSession ──────────────────────────
// Created by a lecturer when they press "Start Session".
// One document represents one live or completed attendance window.
const attendanceSessionSchema = new mongoose.Schema(
  {
    courseCode: {
      type:     String,
      required: true,
      trim:     true,
    },

    courseName: {
      type:     String,
      required: true,
    },

    lecturerId: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      "User",
      required: true,
    },

    type: {
      type:    String,
      enum:    ["inPerson", "online"],
      default: "inPerson",
    },

    // GPS coordinates — only populated for inPerson sessions
    lecturerLat: { type: Number, default: null },
    lecturerLng: { type: Number, default: null },

    // When the QR / 6-digit code stops being valid
    expiresAt: {
      type:     Date,
      required: true,
    },

    // HMAC-SHA256 signature generated server-side after insert.
    // Not required at creation — overwritten immediately after save.
    // Verified server-side on every student check-in.
    signature: {
      type:    String,
      default: "",
    },

    // 6-digit attendance code — generated server-side at session creation
    // and refreshed via POST /api/attendance/sessions/:id/refresh-code.
    // Students enter this code manually when they cannot scan the QR.
    code: {
      type:    String,
      default: null,
    },

    // Set to false when lecturer presses "End Session" or
    // when the server detects expiresAt has passed.
    // Do NOT use a MongoDB TTL index here — that hard-deletes the
    // document, which destroys historical attendance data.
    // Use isActive + expiresAt checks in route logic instead.
    isActive: {
      type:    Boolean,
      default: true,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("AttendanceSession", attendanceSessionSchema);