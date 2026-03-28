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
      enum:    ["student", "lecturer", "admin", "dean", "super_admin"],
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

    enrolledCourses: {
      type:    [String],
      default: [],
    },

    // ── Shared faculty / department fields ────────────────────────
    faculty:     { type: String, trim: true },   // the faculty/school name
    department:  { type: String, trim: true },   // same as faculty for admins
    departments: { type: [String], default: [] },

    staffId:  { type: String, trim: true },

    // ── Face registration (student) ────────────────────────────────
    profilePhoto: {
      type:    String,
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

userSchema.index({ indexNumber: 1 }, { unique: true, sparse: true, background: true, name: "idx_user_indexNumber" });
userSchema.index({ staffId: 1 },     { unique: true, sparse: true, background: true, name: "idx_user_staffId" });
userSchema.index({ role: 1 },        { background: true, name: "idx_user_role" });
userSchema.index({ faculty: 1 },     { background: true, sparse: true, name: "idx_user_faculty" });

userSchema.set("toJSON", {
  transform: (doc, ret) => {
    delete ret.password;
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.model("User", userSchema);