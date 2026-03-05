const express    = require("express");
const cors       = require("cors");
const helmet     = require("helmet");
const rateLimit  = require("express-rate-limit");

// ── Route imports ──────────────────────────────────────────────────
const authRoutes       = require("./routes/auth.routes");
const attendanceRoutes = require("./routes/attendance.routes");
const adminRoutes      = require("./routes/admin.routes");

// ── App init ───────────────────────────────────────────────────────
const app = express();

// ── Security headers — Helmet (Priority 5) ─────────────────────────
//
// Helmet sets 11 security-related HTTP response headers in one call.
// It MUST be the very first app.use() so every response — including
// CORS pre-flights, 404s, and error responses — gets the headers.
//
// What each header does for this API:
//
//  Content-Security-Policy      — not critical for a pure JSON API
//                                 (no HTML served), but blocks any
//                                 accidental script injection if a
//                                 route ever returns HTML by mistake.
//
//  Cross-Origin-Opener-Policy   — prevents cross-origin windows from
//                                 retaining a reference to this page.
//
//  Cross-Origin-Resource-Policy — set to "same-origin" by default;
//                                 prevents other origins from embedding
//                                 responses as resources.
//
//  Referrer-Policy              — "no-referrer" — stops the browser
//                                 sending the full URL of the referring
//                                 page in the Referer header, which
//                                 could leak internal routes or tokens
//                                 embedded in query strings.
//
//  Strict-Transport-Security    — tells browsers to only contact this
//  (HSTS)                         server over HTTPS for the next year,
//                                 even if the user types http://.
//                                 Critical once deployed behind TLS.
//
//  X-Content-Type-Options       — "nosniff" — prevents browsers from
//                                 MIME-sniffing a response away from
//                                 the declared Content-Type. Stops an
//                                 attacker from uploading a JS file
//                                 disguised as JSON and having it execute.
//
//  X-DNS-Prefetch-Control       — "off" — disables browser DNS
//                                 pre-fetching, which can leak which
//                                 external hosts the API communicates with.
//
//  X-Download-Options           — "noopen" — stops IE from auto-opening
//                                 downloaded files in the context of the site.
//
//  X-Frame-Options              — "SAMEORIGIN" — blocks the API responses
//                                 from being framed by a foreign origin,
//                                 preventing clickjacking.
//
//  X-Permitted-Cross-Domain-Policies — "none" — blocks Adobe Flash and
//                                 Acrobat from making cross-domain requests.
//
//  X-Powered-By                 — REMOVED. Without Helmet, Express adds
//                                 "X-Powered-By: Express" to every response.
//                                 This tells attackers exactly what framework
//                                 and version to target. Helmet removes it.
//
// No custom config is needed — helmet() defaults are correct for a
// REST API. If you later add a web frontend that loads scripts from a
// CDN, you will need to configure the contentSecurityPolicy option.
app.use(helmet());

// ── CORS ───────────────────────────────────────────────────────────
// Must come AFTER helmet() so helmet's headers are set first, but
// BEFORE routes so pre-flight OPTIONS requests are handled correctly.
// Development: allow all listed origins.
// Production: set ALLOWED_ORIGINS="https://yourapp.com" in .env
// In development, Flutter Web can open on any port (e.g. localhost:52345).
// Rather than hardcoding every possible port, we allow any localhost origin
// in dev and lock it down via ALLOWED_ORIGINS in production.
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(",")
  : null; // null = use the function below for dev

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (Android emulator, Postman, curl)
    if (!origin) return callback(null, true);

    // Production: check against explicit whitelist
    if (allowedOrigins) {
      if (allowedOrigins.includes(origin)) return callback(null, true);
      return callback(new Error(`CORS blocked: ${origin}`));
    }

    // Development: allow any localhost or 10.0.2.2 origin
    // regardless of port (Flutter Web uses a random port)
    const devPattern = /^http:\/\/(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$/;
    if (devPattern.test(origin)) return callback(null, true);

    return callback(new Error(`CORS blocked: ${origin}`));
  },
  credentials: true,
}));

// ── Body parser ────────────────────────────────────────────────────
// Explicit 10kb limit (Priority 9): rejects oversized payloads before
// they reach any route handler, preventing memory pressure attacks.
app.use(express.json({ limit: "10kb" }));

// ── Rate limiters (Priority 4) ─────────────────────────────────────
//
// Three separate limiters with different thresholds to match the
// risk profile of each endpoint group:
//
//  1. authLimiter    — tightest. Protects login/register from brute-force
//                      and credential-stuffing. 10 attempts per 15 min per IP.
//
//  2. checkinLimiter — moderate. A student legitimately checks in once per
//                      session, but we allow some headroom for retries
//                      (GPS failure, network retry). 30 per 15 min per IP.
//
//  3. generalLimiter — broad safety net on all remaining API routes.
//                      100 requests per 15 min per IP.
//
// standardHeaders: true  → sends RateLimit-* headers (RFC 6585 draft 7)
//                          so clients can back off gracefully.
// legacyHeaders: false   → suppresses the old X-RateLimit-* headers to
//                          avoid sending duplicate/conflicting info.

const authLimiter = rateLimit({
  windowMs:        15 * 60 * 1000, // 15 minutes
  max:             10,              // max 10 requests per window per IP
  standardHeaders: true,
  legacyHeaders:   false,
  message: {
    message: "Too many attempts from this IP. Please try again in 15 minutes.",
  },
});

const checkinLimiter = rateLimit({
  windowMs:        15 * 60 * 1000, // 15 minutes
  max:             30,              // max 30 check-in attempts per window per IP
  standardHeaders: true,
  legacyHeaders:   false,
  message: {
    message: "Too many check-in attempts. Please try again shortly.",
  },
});

const generalLimiter = rateLimit({
  windowMs:        15 * 60 * 1000, // 15 minutes
  max:             100,             // max 100 requests per window per IP
  standardHeaders: true,
  legacyHeaders:   false,
  message: {
    message: "Too many requests from this IP. Please try again later.",
  },
});

// ── Apply rate limiters before routes ──────────────────────────────
//
// Order matters: specific limiters MUST be registered before the
// generalLimiter so that /api/auth and /api/attendance/checkin are
// governed by their own stricter rules, not the general 100/window cap.
app.use("/api/auth",               authLimiter);
app.use("/api/attendance/checkin", checkinLimiter);
app.use("/api",                    generalLimiter);

// ── Routes ─────────────────────────────────────────────────────────
app.use("/api/auth",       authRoutes);
app.use("/api/attendance", attendanceRoutes);
app.use("/api/admin",      adminRoutes);

// ── Health check ───────────────────────────────────────────────────
app.get("/", (req, res) => {
  res.json({ message: "Smart-Attend API is running ✅", version: "1.0.0" });
});

// ── Malformed JSON handler (Priority 11) ───────────────────────────
// express.json() throws a SyntaxError with type "entity.parse.failed"
// when the body is not valid JSON. Without this handler, the global
// error handler below catches it and returns a generic 500.
// MUST sit before the global error handler.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  if (err.type === "entity.parse.failed") {
    return res.status(400).json({ message: "Invalid JSON in request body." });
  }
  next(err);
});

// ── 404 handler ────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ message: `Route ${req.originalUrl} not found.` });
});

// ── Global error handler ───────────────────────────────────────────
// 4-argument signature is required for Express to treat this as an
// error handler. Catches anything not handled by the JSON handler above.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error("Unhandled error:", err.message);
  res.status(err.status || 500).json({
    message: err.message || "An unexpected error occurred.",
  });
});

module.exports = app;