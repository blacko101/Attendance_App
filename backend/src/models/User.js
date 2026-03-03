const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    fullName: {
      type: String,
      required: [true, "Full name is required"],
      trim: true,
    },

    email: {
      type: String,
      required: [true, "Email is required"],
      unique: true,
      lowercase: true,
      trim: true,
      match: [/^[^\s@]+@[^\s@]+\.[^\s@]+$/, "Please enter a valid email"],
    },

    password: {
      type: String,
      required: [true, "Password is required"],
    },

    role: {
      type: String,
      enum: ["student", "lecturer", "admin"],
      default: "student",
    },

    // ── Student fields ──
    indexNumber: {
      type: String,
      trim: true,
    },

    programme: {
      type: String,
      trim: true,
    },

    level: {
      type: String,
      trim: true,  // e.g. "100", "200", "300", "400"
    },

    // ── Lecturer / Admin fields ──
    staffId: {
      type: String,
      trim: true,
    },

    department: {
      type: String,
      trim: true,
    },

    isActive: {
      type: Boolean,
      default: true,  // for suspending accounts
    },
  },
  {
    timestamps: true,
  }
);

// ── Always exclude password from any query result ──
// This runs on every find/findOne automatically
userSchema.set("toJSON", {
  transform: (doc, ret) => {
    delete ret.password;
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.model("User", userSchema);