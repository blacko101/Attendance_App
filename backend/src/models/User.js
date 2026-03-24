const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    fullName: {
      type:     String,
      required: [true, "Full name is required"],
      trim:     true,
    },

    email: {
      type:      String,
      required:  [true, "Email is required"],
      unique:    true,
      lowercase: true,
      trim:      true,
      match:     [/^[^\s@]+@[^\s@]+\.[^\s@]+$/, "Please enter a valid email"],
    },

    password: {
      type:     String,
      required: [true, "Password is required"],
      select:   false,
    },

    role: {
      type:    String,
      enum:    ["student", "lecturer", "admin", "dean"],
      default: "student",
    },

    mustChangePassword: {
      type:    Boolean,
      default: false,
    },

    // ── Student-only fields ────────────────────────────────────────
    indexNumber:     { type: String, trim: true },
    programme:       { type: String, trim: true },
    level:           { type: String, trim: true },

    // ── Course enrollment (student) ────────────────────────────────
    // Array of courseCode strings the student has registered for.
    // Populated via POST /api/attendance/enroll.
    enrolledCourses: {
      type:    [String],
      default: [],
    },

    // ── Faculty the user belongs to ───────────────────────────────
    faculty:     { type: String, trim: true },
    department:  { type: String, trim: true },
    departments: { type: [String], default: [] },

    staffId:  { type: String, trim: true },

    // ── Face registration (student) ────────────────────────────────
    // Base64-encoded reference selfie captured on first login.
    // Used in Phase 3 to verify identity on every attendance check-in.
    profilePhoto: {
      type:    String,   // base64 encoded JPEG
      default: null,
    },

    faceRegistered: {
      type:    Boolean,
      default: false,
    },

    isActive: {
      type:    Boolean,
      default: true,
    },
  },
  { timestamps: true }
);

// ── Indexes ───────────────────────────────────────────────────────
userSchema.index({ indexNumber: 1 }, { unique: true, sparse: true, background: true, name: "idx_user_indexNumber" });
userSchema.index({ staffId: 1 },     { unique: true, sparse: true, background: true, name: "idx_user_staffId" });
userSchema.index({ role: 1 },        { background: true, name: "idx_user_role" });
userSchema.index({ faculty: 1 },     { background: true, sparse: true, name: "idx_user_faculty" });

// ── Serialisation safety ──────────────────────────────────────────
userSchema.set("toJSON", {
  transform: (doc, ret) => {
    delete ret.password;
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.model("User", userSchema);