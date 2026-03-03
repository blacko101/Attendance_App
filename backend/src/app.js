const express = require("express");
const cors    = require("cors");

const authRoutes = require("./routes/auth.routes");
const attendanceRoutes = require('./routes/attendance.routes');
app.use('/api/attendance', attendanceRoutes);

const app = express();

// ── CORS ──
// Development: allow all. Production: lock to your frontend domain.
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(",")
  : ["http://localhost:3000", "http://10.0.2.2:3000"];

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, Postman, curl)
    if (!origin) return callback(null, true);
    if (allowedOrigins.includes(origin)) return callback(null, true);
    return callback(new Error(`CORS blocked: ${origin}`));
  },
  credentials: true,
}));

app.use(express.json());

// ── Routes ──
app.use("/api/auth", authRoutes);

// ── Health check ──
app.get("/", (req, res) => {
  res.json({ message: "Smart-Attend API is running ✅", version: "1.0.0" });
});

// ── 404 handler — unknown routes ──
app.use((req, res) => {
  res.status(404).json({ message: `Route ${req.originalUrl} not found.` });
});

// ── Global error handler — catches anything thrown in controllers ──
app.use((err, req, res, next) => {
  console.error("Unhandled error:", err.message);
  res.status(err.status || 500).json({
    message: err.message || "An unexpected error occurred.",
  });
});

module.exports = app;