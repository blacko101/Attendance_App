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
      // select: false — NEVER returned by any query unless the caller
      // explicitly does .select("+password"). Protects the bcrypt hash
      // from leaking into responses, logs, or any toString() of the doc.
      select:   false,
    },

    role: {
      type:    String,
      enum:    ["student", "lecturer", "admin"],
      default: "student",
    },

    // ── Student-only fields ────────────────────────────────────────
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
      trim: true, // e.g. "100", "200", "300", "400"
    },

    // ── Lecturer / Admin-only fields ───────────────────────────────
    staffId: {
      type: String,
      trim: true,
    },

    department: {
      type: String,
      trim: true,
    },

    // Used by admin to suspend accounts
    isActive: {
      type:    Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  }
);

// ── Indexes (Priority 13) ─────────────────────────────────────────
//
// Why sparse indexes?
//   indexNumber is only set on students; staffId is only set on
//   lecturers and admins. A normal index would create an entry for
//   every document where the field is null/undefined, wasting space
//   and adding write overhead for every user whose field is absent.
//   sparse: true tells MongoDB to only index documents where the
//   field actually exists, keeping the index small and fast.
//
// Why unique: true?
//   Two students should never share an index number; two staff
//   members should never share a staff ID. unique enforces this
//   at the DB layer so it cannot be violated even if the application
//   layer has a bug.
//
// Why background: true?  (relevant on existing collections)
//   Building an index in the foreground locks the collection until
//   it finishes. background: true lets reads and writes continue
//   during the build — important if you add this index to a
//   collection that already has data.

userSchema.index(
  { indexNumber: 1 },
  {
    unique:     true,
    sparse:     true,
    background: true,
    name:       "idx_user_indexNumber",
  }
);

userSchema.index(
  { staffId: 1 },
  {
    unique:     true,
    sparse:     true,
    background: true,
    name:       "idx_user_staffId",
  }
);

// role index — admin routes frequently filter/sort by role
// (e.g. "list all lecturers", "list all students").
// Not unique, not sparse — every user has a role.
userSchema.index(
  { role: 1 },
  {
    background: true,
    name:       "idx_user_role",
  }
);

// ── Serialisation safety net ──────────────────────────────────────
// Even though select:false already prevents the password from being
// fetched, this transform acts as a second layer: if the password
// field somehow ends up in the object (e.g. after User.create()),
// it is stripped before any JSON response is sent.
userSchema.set("toJSON", {
  transform: (doc, ret) => {
    delete ret.password;
    delete ret.__v;
    return ret;
  },
});

module.exports = mongoose.model("User", userSchema);