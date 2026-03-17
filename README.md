# Smart-Attend

A full-stack attendance management system built for **Central University, Ghana**.  
Lecturers generate QR codes to start attendance sessions. Students scan them to check in.  
Admins, deans, and lecturers each have dedicated dashboards with real data from MongoDB.

---

## Table of Contents

- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Roles & Access](#roles--access)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Backend Setup](#backend-setup)
  - [Flutter Setup](#flutter-setup)
  - [Running on a Physical Device](#running-on-a-physical-device)
- [Database Seeding](#database-seeding)
- [Test Credentials](#test-credentials)
- [API Reference](#api-reference)
- [App URLs](#app-urls)
- [Security](#security)
- [Environment Variables](#environment-variables)
- [Known Limitations](#known-limitations)

---

## Overview

Smart-Attend replaces paper-based attendance with a QR-code system.

**How it works:**

1. A lecturer opens the app and starts an attendance session for a course.
2. The backend generates a cryptographically signed QR code (HMAC-SHA256) tied to that session.
3. The lecturer displays the QR on their screen — students scan it with their phones.
4. The student app sends the QR payload + their GPS coordinates to the backend.
5. The backend verifies the HMAC signature, checks expiry, validates GPS proximity (≤ 100 m for in-person sessions), and records the attendance.
6. The lecturer sees a live count of students checked in. The dean and admin see aggregated analytics.

---

## Tech Stack

| Layer     | Technology                                      |
|-----------|-------------------------------------------------|
| Mobile    | Flutter 3 (Dart) — Android, iOS, Web            |
| Backend   | Node.js + Express 5                             |
| Database  | MongoDB + Mongoose 9                            |
| Auth      | JWT (jsonwebtoken) + bcryptjs                   |
| QR        | qr_flutter (display) + mobile_scanner (scan)    |
| Location  | geolocator                                      |
| Fonts     | Google Fonts (Poppins)                          |
| Security  | Helmet, express-rate-limit, CORS                |

---

## Project Structure

```
Attendance_App/
├── backend/                        # Node.js REST API
│   ├── src/
│   │   ├── controllers/
│   │   │   ├── auth.controller.js       # login, register, getMe, changePassword
│   │   │   ├── attendance.controller.js # createSession, checkIn, endSession
│   │   │   └── admin.controller.js      # listUsers, createUser, getStats
│   │   ├── middleware/
│   │   │   ├── auth.middleware.js       # JWT verification, isActive check
│   │   │   └── role.middleware.js       # role-based access control
│   │   ├── models/
│   │   │   ├── User.js                  # student, lecturer, admin, dean
│   │   │   ├── AttendanceSession.js     # QR session with HMAC signature
│   │   │   └── Attendance.js            # per-student check-in record
│   │   ├── routes/
│   │   │   ├── auth.routes.js
│   │   │   ├── attendance.routes.js
│   │   │   └── admin.routes.js
│   │   ├── config/
│   │   │   └── db.js                    # MongoDB connection
│   │   └── app.js                       # Express app, middleware, rate limiters
│   ├── server.js                        # Entry point
│   ├── seed.js                          # Full database seeder
│   └── .env                             # Environment variables (not committed)
│
└── smart_attend/                   # Flutter app
    └── lib/
        ├── core/
        │   └── config/
        │       └── app_config.dart      # Base URL configuration
        └── features/
            ├── auth/                    # Login, change password, session service
            ├── student/                 # Dashboard, courses, calendar, profile
            ├── lecturer/                # Dashboard, QR generation, session management
            ├── dean/                    # Department login portal, analytics dashboard
            ├── super_admin/             # User management, analytics, timetable
            └── attendance/              # QR scanner, check-in controller
```

---

## Roles & Access

| Role        | Login Page          | Access                                                      |
|-------------|---------------------|-------------------------------------------------------------|
| Student     | Main login (`/`)    | Scan QR, view attendance history, calendar, profile         |
| Lecturer    | Main login (`/`)    | Start sessions, display QR, view check-in counts            |
| Admin       | Main login (`/`)    | Full user management, analytics, course & timetable control |
| Dean        | Dean portal (`/#/dean`) | Department analytics, low attendance alerts, lecturer performance |

> **Dean portal** is a completely separate URL. Share `http://<host>/#/dean` only with department heads — it never shows the student/staff login page.

---

## Getting Started

### Prerequisites

| Tool        | Version   | Notes                          |
|-------------|-----------|--------------------------------|
| Node.js     | 18+       | LTS recommended                |
| MongoDB     | 6+        | Local or Atlas                 |
| Flutter     | 3.10+     | `flutter doctor` to verify     |
| Dart        | 3.10+     | Bundled with Flutter           |
| Git         | Any       |                                |

---

### Backend Setup

```bash
# 1. Navigate to the backend folder
cd backend

# 2. Install dependencies
npm install

# 3. Create your environment file
cp .env.example .env
```

Edit `.env` with your values:

```env
PORT=5000
MONGO_URI=mongodb://127.0.0.1:27017/smart_attend
JWT_SECRET=your_long_random_secret_here
QR_SECRET=your_qr_hmac_secret_here
```

Generate secure secrets with:
```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

```bash
# 4. Seed the database with test data
node seed.js --wipe

# 5. Start the backend
node server.js
```

The API will be running at `http://localhost:5000`.  
Visit `http://localhost:5000/` to confirm — you should see:
```json
{ "message": "Smart-Attend API is running ✅", "version": "1.0.0" }
```

---

### Flutter Setup

```bash
# 1. Navigate to the Flutter app folder
cd smart_attend

# 2. Install Flutter dependencies
flutter pub get
```

**Configure the backend URL** in `lib/core/config/app_config.dart`:

```dart
static String get _host {
  if (kIsWeb) return 'http://localhost:5000';   // Flutter Web
  return 'http://10.0.2.2:5000';               // Android emulator
  // Physical device: return 'http://<YOUR_PC_IP>:5000';
}
```

```bash
# 3. Run the app
flutter run                    # default device
flutter run -d chrome          # web browser
flutter run -d edge            # Microsoft Edge
flutter run -d emulator-...    # Android emulator
```

---

### Running on a Physical Device

When testing on a real Android/iOS device connected via Wi-Fi hotspot:

1. Find your PC's IP address:
   - **Windows:** Open CMD → run `ipconfig` → look for your hotspot adapter's IPv4 address (e.g. `10.105.189.143`)
   - **Mac/Linux:** run `ifconfig`

2. Update `app_config.dart`:
   ```dart
   return 'http://10.105.189.143:5000';  // replace with your actual IP
   ```

3. Open port 5000 on Windows Firewall (run as administrator):
   ```bash
   netsh advfirewall firewall add rule name="Node 5000" dir=in action=allow protocol=TCP localport=5000
   ```

4. Run `flutter run` — the app on your phone will connect to the backend on your PC.

---

## Database Seeding

The seeder creates all 6 collections from scratch with realistic test data.

```bash
cd backend

# Safe run — skips records that already exist
node seed.js

# Full wipe then re-seed (use this for a clean slate)
node seed.js --wipe

# Wipe only — empties all collections without re-seeding
node seed.js --wipe-only
```

**What gets created:**

| Collection          | Contents                                                        |
|---------------------|-----------------------------------------------------------------|
| `users`             | 1 admin, 1 dean, 3 lecturers, 10 students                      |
| `courses`           | 7 courses (CS101–CS401, MATH201, MATH301) with lecturer links   |
| `timetables`        | 14 weekly slots — 2 days per course with rooms and levels       |
| `semesters`         | 3 semesters — current (2025/2026 Sem 2) and 2 historical        |
| `attendancesessions`| 8 sessions — ended, active (in-person & online), expired        |
| `attendances`       | ~20 check-in records spread across ended and active sessions    |

> ⚠️ Never run `--wipe` against a production database. Always double-check `MONGO_URI` in `.env` before running the seeder.

---

## Test Credentials

All seeded accounts use the default password: **`Central@123`**

Every account has `mustChangePassword: true` — on first login the user is redirected to set a personal password before reaching their dashboard.

| Role     | Email                              | Notes                        |
|----------|------------------------------------|------------------------------|
| Admin    | admin@central.edu.gh               | Full system access           |
| Dean     | dean.set@central.edu.gh            | Login via `/#/dean` only     |
| Lecturer | kwame.asante@central.edu.gh        | Teaches CS301, CS201, CS401  |
| Lecturer | abena.mensah@central.edu.gh        | Teaches MATH201, MATH301     |
| Lecturer | kofi.owusu@central.edu.gh          | Teaches CS101, CS202         |
| Student  | ama.boateng@central.edu.gh         | Level 300, Computer Science  |
| Student  | yaw.darko@central.edu.gh           | Level 300, Computer Science  |
| Student  | efua.asante@central.edu.gh         | Level 300, Computer Science  |
| Student  | kweku.frimpong@central.edu.gh      | Level 300, Computer Science  |
| Student  | akosua.nkrumah@central.edu.gh      | Level 200, Computer Science  |
| Student  | kobina.aidoo@central.edu.gh        | ⛔ Suspended — tests auth guard |
| Student  | adwoa.poku@central.edu.gh          | Level 300, Mathematics       |
| Student  | fiifi.mensah@central.edu.gh        | Level 300, Mathematics       |
| Student  | nana.appiah@central.edu.gh         | Level 200, Computer Science  |
| Student  | ato.quaye@central.edu.gh           | Level 300, Information Tech  |

---

## API Reference

All endpoints are prefixed with `/api`.

### Auth — `/api/auth`

| Method  | Endpoint                   | Auth      | Description                          |
|---------|----------------------------|-----------|--------------------------------------|
| `POST`  | `/login`                   | Public    | Login — returns JWT + user object    |
| `POST`  | `/register`                | Public    | Register a new student account       |
| `GET`   | `/me`                      | JWT       | Get current user's profile           |
| `POST`  | `/change-password`         | JWT       | Change password (requires current pw)|
| `PATCH` | `/users/:id/role`          | Admin JWT | Update a user's role                 |

### Attendance — `/api/attendance`

| Method  | Endpoint                              | Auth          | Description                              |
|---------|---------------------------------------|---------------|------------------------------------------|
| `POST`  | `/sessions`                           | Lecturer JWT  | Start a new attendance session           |
| `POST`  | `/checkin`                            | Student JWT   | Check in using QR payload + GPS          |
| `GET`   | `/sessions/:sessionId/students`       | Lecturer JWT  | List students checked in to a session    |
| `GET`   | `/student/:studentId`                 | JWT           | Get a student's attendance history       |
| `PATCH` | `/sessions/:sessionId/end`            | Lecturer JWT  | End a session early                      |

### Admin — `/api/admin`

| Method  | Endpoint                          | Auth       | Description                          |
|---------|-----------------------------------|------------|--------------------------------------|
| `GET`   | `/stats`                          | Admin JWT  | School-wide dashboard stats          |
| `GET`   | `/users`                          | Admin JWT  | List users (filter by role/status)   |
| `POST`  | `/users`                          | Admin JWT  | Create a new user account            |
| `GET`   | `/users/:id`                      | Admin JWT  | Get a single user                    |
| `PATCH` | `/users/:id/status`               | Admin JWT  | Suspend or reactivate a user         |
| `GET`   | `/sessions`                       | Admin JWT  | List all attendance sessions         |
| `GET`   | `/sessions/:sessionId/report`     | Admin JWT  | Full attendance report for a session |

---

## App URLs

| URL                        | Page                                      |
|----------------------------|-------------------------------------------|
| `http://<host>/#/`         | Welcome screen → main login               |
| `http://<host>/#/login`    | Student / Lecturer / Admin login          |
| `http://<host>/#/dean`     | Dean department portal (separate login)   |

Share the `/#/dean` URL only with department heads. It bypasses the main login entirely and shows a department dropdown + password field.

---

## Security

| Feature                  | Implementation                                                         |
|--------------------------|------------------------------------------------------------------------|
| Password hashing         | bcryptjs with salt rounds = 10                                         |
| Authentication           | JWT (24-hour expiry), verified on every request                        |
| Role enforcement         | DB role fetched on every request — stale JWT roles are ignored         |
| Account suspension       | `isActive` checked on every request — suspended users are blocked instantly |
| QR signing               | HMAC-SHA256 — server signs with `QR_SECRET`, verifies on check-in      |
| GPS proximity            | Student must be within 100 m of lecturer for in-person sessions        |
| Rate limiting — login    | 5 attempts per email per 15 min + 20 attempts per IP per 15 min        |
| Rate limiting — general  | 100 requests per IP per 15 min                                         |
| Security headers         | Helmet (11 headers including HSTS, CSP, X-Frame-Options)               |
| CORS                     | Locked to allowed origins in production via `ALLOWED_ORIGINS` env var  |
| Body size limit          | 10 KB max — prevents memory pressure attacks                           |

---

## Environment Variables

| Variable          | Required | Default                              | Description                        |
|-------------------|----------|--------------------------------------|------------------------------------|
| `PORT`            | No       | `5000`                               | Port the server listens on         |
| `MONGO_URI`       | Yes      | —                                    | MongoDB connection string          |
| `JWT_SECRET`      | Yes      | —                                    | Secret for signing JWTs            |
| `QR_SECRET`       | No       | `smart_attend_qr_secret`             | Secret for HMAC QR signatures      |
| `ALLOWED_ORIGINS` | No       | All localhost origins allowed        | Comma-separated CORS whitelist     |

---

## Known Limitations

| Area              | Current State                                                              | Next Step                                          |
|-------------------|----------------------------------------------------------------------------|----------------------------------------------------|
| Courses           | Derived from session history — no dedicated `/courses` endpoint            | Add Course collection routes to backend            |
| Timetable         | Seeded in MongoDB but no backend CRUD endpoints yet                        | Add `/api/admin/timetable` routes                  |
| Semesters         | Seeded in MongoDB but no backend CRUD endpoints yet                        | Add `/api/admin/semesters` routes                  |
| Student enrollment| No explicit enrollment — courses inferred from attendance records          | Add enrollment collection                          |
| Dean departments  | Each department needs its own dean user account in the database            | Admin creates dean accounts via the Users panel    |
| Offline support   | No offline mode — requires active network connection                       | Add local caching with sqflite or Hive             |
| Push notifications| Not implemented                                                            | Add FCM for session start/end alerts               |
| File uploads      | Bulk CSV upload validates format but creates users one by one              | Add multipart upload endpoint to backend           |