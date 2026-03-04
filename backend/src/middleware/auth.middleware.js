const jwt  = require("jsonwebtoken");
const User = require("../models/User");

// ─────────────────────────────────────────────────────────────────
//  authMiddleware
//
//  Validates the Bearer token on every protected request and attaches
//  a verified req.user = { id, role, iat, exp } to the request object.
//
//  Three checks run on every request — in order:
//
//    1. JWT signature & expiry  — is the token cryptographically valid?
//    2. Account exists          — has the user been deleted since issue?
//    3. Account is active       — has an admin suspended this account?
//
//  WHY we fetch from the DB instead of trusting the JWT payload
//  ─────────────────────────────────────────────────────────────
//  JWTs are self-contained and valid for 24 hours. That means:
//
//  • If an admin SUSPENDS a user, the old token stays valid for up to
//    24 h without the isActive check.  ← was already handled before.
//
//  • If an admin CHANGES a user's role (e.g. demotes a lecturer back
//    to student, or promotes a student to lecturer), the old token still
//    carries the previous role for up to 24 h.  ← Priority 8 fix.
//
//  The fix: extend the DB select from "isActive" to "isActive role".
//  We already pay the cost of a DB round-trip; fetching one extra field
//  (a short enum string) adds zero measurable latency.
//
//  After the DB fetch, req.user.role is set from the DATABASE value,
//  not from the JWT payload. The JWT payload role (decoded.role) is
//  intentionally discarded so stale role data can never reach a
//  roleMiddleware check.
// ─────────────────────────────────────────────────────────────────
const authMiddleware = async (req, res, next) => {
  const authHeader = req.headers.authorization;

  // ── 1. Token present? ──────────────────────────────────────────
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ message: "Access denied. No token provided." });
  }

  const token = authHeader.split(" ")[1];

  try {
    // ── 2. Token cryptographically valid and not expired? ─────────
    // jwt.verify throws JsonWebTokenError (tampered) or
    // TokenExpiredError (past exp) — both caught below.
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    // decoded = { id, role, iat, exp }
    // NOTE: decoded.role is the role at the time the token was signed.
    //       We do NOT use it for authorization — see step 4.

    // ── 3. Account still exists, is active, and get current role ──
    // FIX (Priority 8): select "isActive role" instead of just "isActive".
    // This fetches the authoritative role from the DB on every request,
    // ensuring a role change by an admin takes effect immediately without
    // waiting for the token to expire.
    const user = await User.findById(decoded.id).select("isActive role");

    if (!user) {
      // User was deleted after the token was issued.
      return res.status(401).json({ message: "Account not found." });
    }

    if (!user.isActive) {
      return res.status(403).json({
        message: "Your account has been suspended. Please contact admin.",
      });
    }

    // ── 4. Attach verified user data to request ────────────────────
    // CRITICAL: role comes from `user.role` (DB) — NOT from `decoded.role`
    // (JWT payload). This means:
    //   • An admin demotes lecturer → next request is immediately student.
    //   • An admin promotes student → next request is immediately lecturer.
    //   • The stale role in the JWT payload is completely ignored.
    //
    // We keep decoded.iat and decoded.exp on req.user so that any future
    // middleware or route handler can inspect token age if needed.
    req.user = {
      id:   decoded.id,
      role: user.role,   // ← authoritative DB value
      iat:  decoded.iat,
      exp:  decoded.exp,
    };

    next();

  } catch (error) {
    // jwt.verify throws for tampered or expired tokens.
    // Use a generic message — don't reveal whether the token was
    // expired vs. tampered, as that leaks implementation detail.
    return res.status(401).json({ message: "Invalid or expired token." });
  }
};

module.exports = authMiddleware;