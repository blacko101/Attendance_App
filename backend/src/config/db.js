const mongoose = require("mongoose");

// ─────────────────────────────────────────────────────────────────
//  connectDB
//
//  Connects to MongoDB and registers lifecycle event listeners so
//  the server handles mid-runtime disconnections gracefully instead
//  of silently failing on every subsequent DB call.
//
//  Connection options explained:
//
//  serverSelectionTimeoutMS — how long the driver waits to find a
//    healthy MongoDB server before throwing. Default is 30 s, which
//    means a misconfigured MONGO_URI hangs the startup for 30 s before
//    failing. 5 s gives fast feedback in development and CI.
//
//  socketTimeoutMS — how long to wait for a response on an open socket
//    before the driver closes it and tries another server. 45 s is the
//    recommended production value for most workloads.
//
//  maxPoolSize — maximum number of simultaneous connections in the
//    driver's connection pool. Default is 100. For a small-to-medium
//    attendance API, 10 is more than enough and avoids overwhelming
//    a shared Atlas cluster on a free/shared tier.
//
//  family: 4 — force IPv4. Without this, on some cloud environments
//    the driver tries IPv6 first, fails, then falls back to IPv4 —
//    adding ~2 s to every cold start.
// ─────────────────────────────────────────────────────────────────
const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI, {
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS:          45000,
      maxPoolSize:              10,
      family:                   4,
    });

    console.log("✅  MongoDB connected successfully");

    // ── Connection lifecycle events ──────────────────────────────
    // Mongoose fires these on the default connection object.
    // We register them AFTER the initial connect() resolves so they
    // only fire for mid-runtime state changes, not the initial connect.

    mongoose.connection.on("disconnected", () => {
      // Mongoose automatically attempts to reconnect when this fires.
      // Log it so ops teams can see the gap in monitoring dashboards.
      console.warn("⚠️   MongoDB disconnected — driver will attempt to reconnect…");
    });

    mongoose.connection.on("reconnected", () => {
      console.log("✅  MongoDB reconnected successfully");
    });

    mongoose.connection.on("error", (err) => {
      // Mid-runtime errors (e.g. auth revoked, network reset) are
      // logged here. The driver handles reconnection internally;
      // we don't call process.exit() because in-flight requests
      // should still be allowed to drain.
      console.error("❌  MongoDB runtime error:", err.message);
    });

  } catch (error) {
    // Initial connection failure — the server cannot serve any
    // requests without a DB, so exit immediately.
    console.error("❌  MongoDB initial connection failed:", error.message);
    process.exit(1);
  }
};

// ── Graceful shutdown ─────────────────────────────────────────────
// When the process receives SIGINT (Ctrl-C) or SIGTERM (Docker/k8s
// stop), close the Mongoose connection cleanly before exiting.
// This drains the connection pool and prevents the "connection closed"
// errors that occur when the process is killed mid-query.
const gracefulShutdown = async (signal) => {
  console.log(`\n${signal} received — closing MongoDB connection…`);
  await mongoose.connection.close();
  console.log("✅  MongoDB connection closed. Process exiting.");
  process.exit(0);
};

process.on("SIGINT",  () => gracefulShutdown("SIGINT"));
process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));

module.exports = connectDB;