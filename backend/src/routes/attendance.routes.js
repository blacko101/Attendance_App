const express    = require('express');
const router     = express.Router();
const authMiddleware = require('../middleware/auth.middleware');
const roleMiddleware = require('../middleware/role.middleware');
const {
  checkIn,
  getStudentAttendance,
} = require('../controllers/attendance.controller');

// Student check-in
router.post(
  '/checkin',
  authMiddleware,
  roleMiddleware('student'),
  checkIn
);

// Get student's attendance records
router.get(
  '/my',
  authMiddleware,
  roleMiddleware('student'),
  getStudentAttendance
);

module.exports = router;