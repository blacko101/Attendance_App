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
      enum:    ["student", "lecturer", "admin"],
      default: "student",
    },

    // When true the user must change their password on next login.
    // Set to true whenever an admin creates the account.
    // Cleared to false after the user successfully changes their password.
    mustChangePassword: {
      type:    Boolean,
      default: false,
    },

    // ── Student-only fields ────────────────────────────────────────
    indexNumber: { type: String, trim: true },
    programme:   { type: String, trim: true },
    level:       { type: String, trim: true },

    // ── Lecturer / Admin-only fields ───────────────────────────────
    staffId:    { type: String, trim: true },
    department: { type: String, trim: true },

    isActive: {
      type:    Boolean,
      default: true,
    },
  },
  { timestamps: true }
);

userSchema.index({ indexNumber: 1 }, { unique: true, sparse: true, background: true, name: "idx_user_indexNumber" });
userSchema.index({ staffId:     1 }, { unique: true, sparse: true, background: true, name: "idx_user_staffId" });
userSchema.index({ role:        1 }, { background: true,                             name: "idx_user_role" });

userSchema.set("toJSON", {
  transform: (doc, ret) => {
    delete ret.password;
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.model("User", userSchema);