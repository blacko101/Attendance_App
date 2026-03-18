const express   = require("express");
const cors      = require("cors");
const helmet    = require("helmet");
const { rateLimit, ipKeyGenerator } = require("express-rate-limit");

// ── Route imports ──────────────────────────────────────────────────
const authRoutes       = require("./routes/auth.routes");
const attendanceRoutes = require("./routes/attendance.routes");
const adminRoutes      = require("./routes/admin.routes");

// ── App init ───────────────────────────────────────────────────────
const app = express();

app.use(helmet());

// ── CORS ───────────────────────────────────────────────────────────
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(",")
  : null;

app.use(cors({
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);

    if (allowedOrigins) {
      if (allowedOrigins.includes(origin)) return callback(null, true);
      return callback(new Error(`CORS blocked: ${origin}`));
    }

    const devPattern =
      /^http:\/\/(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$/;
    if (devPattern.test(origin)) return callback(null, true);

    return callback(new Error(`CORS blocked: ${origin}`));
  },
  credentials: true,
}));

// ── Body parser ────────────────────────────────────────────────────
app.use(express.json({ limit: "10kb" }));

// ══════════════════════════════════════════════════════════════════
//  RATE LIMITERS
//
//  Login uses a two-layer strategy:
//
//  Layer 1 — per email address (keyGenerator reads req.body.email).
//    • 5 failed attempts on the SAME account locks that account out
//      for 15 minutes, regardless of IP.
//    • This stops an attacker who rotates IPs from hammering one user.
//    • Threshold is low (5) because a real user rarely misses their
//      own password more than twice.
//
//  Layer 2 — per IP address (default keyGenerator).
//    • 20 attempts from the SAME IP locks that IP for 15 minutes,
//      regardless of which email was typed.
//    • This stops a single machine from cycling through many accounts.
//    • Threshold is higher (20) to avoid blocking shared networks
//      (offices, campuses) where many users share one public IP.
//
//  Both limiters run on every login request — both counters increment.
//  Whichever limit is hit first triggers the 429 response.
//
//  changePasswordLimiter — per IP, 20 per 15 min.
//    Change-password is not a brute-force target (requires a valid
//    JWT) so a relaxed IP-only limiter is sufficient.
//
//  checkinLimiter — per IP, 30 per 15 min.
//
//  generalLimiter — per IP, 100 per 15 min. Safety net on all routes.
// ══════════════════════════════════════════════════════════════════

// ── Layer 1: per-email login limiter ─────────────────────────────
// keyGenerator extracts the email from the POST body.
// Falls back to IP if no email is present (malformed request).
const loginEmailLimiter = rateLimit({
  windowMs:        15 * 60 * 1000,   // 15 minutes
  max:             5,                 // 5 attempts per email per window
  standardHeaders: true,
  legacyHeaders:   false,
  // Read the body AFTER express.json() has parsed it.
  // express-rate-limit calls keyGenerator synchronously so req.body
  // is already populated at this point.
  keyGenerator: (req) => {
    const email = req.body?.email;
    if (email && typeof email === "string" && email.trim().length > 0) {
      // Normalise — lowercase + trim — so "User@X.com" and "user@x.com"
      // share the same counter.
      return `login:email:${email.trim().toLowerCase()}`;
    }
    // Fallback to IP so malformed requests are still rate-limited
    // Use ipKeyGenerator to safely handle IPv6 address normalisation
    return `login:email:${ipKeyGenerator(req)}`;
  },
  message: {
    message:
      "Too many login attempts for this account. "
      + "Please try again in 15 minutes.",
  },
});

// ── Layer 2: per-IP login limiter ────────────────────────────────
const loginIpLimiter = rateLimit({
  windowMs:        15 * 60 * 1000,   // 15 minutes
  max:             20,                // 20 attempts per IP per window
  standardHeaders: true,
  legacyHeaders:   false,
  // Default keyGenerator uses req.ip — no override needed
  message: {
    message:
      "Too many login attempts from this device. "
      + "Please try again in 15 minutes.",
  },
});

// ── Change-password limiter (per IP) ────────────────────────────
const changePasswordLimiter = rateLimit({
  windowMs:        15 * 60 * 1000,
  max:             20,
  standardHeaders: true,
  legacyHeaders:   false,
  message: {
    message:
      "Too many password change attempts. "
      + "Please try again in 15 minutes.",
  },
});

// ── Check-in limiter (per IP) ────────────────────────────────────
const checkinLimiter = rateLimit({
  windowMs:        15 * 60 * 1000,
  max:             30,
  standardHeaders: true,
  legacyHeaders:   false,
  message: {
    message: "Too many check-in attempts. Please try again shortly.",
  },
});

// ── General safety-net limiter (per IP) ─────────────────────────
const generalLimiter = rateLimit({
  windowMs:        15 * 60 * 1000,
  max:             100,
  standardHeaders: true,
  legacyHeaders:   false,
  message: {
    message: "Too many requests from this IP. Please try again later.",
  },
});

// ── Apply rate limiters before routes ────────────────────────────
//
// Specific limiters MUST be registered before generalLimiter.
// Both login limiters run on every POST /api/auth/login — the first
// one to fire a 429 wins; the other never increments past that point.
app.use("/api/auth/login",           loginEmailLimiter);
app.use("/api/auth/login",           loginIpLimiter);
app.use("/api/auth/register",        loginIpLimiter);
app.use("/api/auth/change-password", changePasswordLimiter);
app.use("/api/attendance/checkin",   checkinLimiter);
app.use("/api",                      generalLimiter);

// ── Routes ───────────────────────────────────────────────────────
app.use("/api/auth",       authRoutes);
app.use("/api/attendance", attendanceRoutes);
app.use("/api/admin",      adminRoutes);

// ── Health check ─────────────────────────────────────────────────
app.get("/", (req, res) => {
  res.json({ message: "Smart-Attend API is running ✅", version: "1.0.0" });
});

// ── Malformed JSON handler ────────────────────────────────────────
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  if (err.type === "entity.parse.failed") {
    return res
      .status(400)
      .json({ message: "Invalid JSON in request body." });
  }
  next(err);
});

// ── 404 handler ──────────────────────────────────────────────────
app.use((req, res) => {
  res
    .status(404)
    .json({ message: `Route ${req.originalUrl} not found.` });
});

// ── Global error handler ─────────────────────────────────────────
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error("Unhandled error:", err.message);
  res.status(err.status || 500).json({
    message: err.message || "An unexpected error occurred.",
  });
});

module.exports = app;