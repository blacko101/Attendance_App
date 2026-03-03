const crypto = require('crypto');

const QR_SECRET     = process.env.QR_SECRET || 'smart_attend_qr_secret';
const MAX_DISTANCE  = 100; // metres

// ── Haversine distance in metres ──
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R    = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a    = Math.sin(dLat/2) ** 2 +
               Math.cos(lat1 * Math.PI/180) *
               Math.cos(lat2 * Math.PI/180) *
               Math.sin(dLon/2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ── Verify QR HMAC signature ──
function verifySignature(sessionId, courseCode, expiresAt, signature) {
  const data   = `${sessionId}:${courseCode}:${expiresAt}`;
  const digest = crypto
    .createHmac('sha256', QR_SECRET)
    .update(data)
    .digest('hex');
  return digest === signature;
}

// ── POST /api/attendance/checkin ──
exports.checkIn = async (req, res) => {
  try {
    const {
      sessionId,
      courseCode,
      studentLat,
      studentLng,
      distanceM,
    } = req.body;

    const studentId = req.user.id;

    if (!sessionId || !courseCode || !studentLat || !studentLng) {
      return res.status(400).json({ message: 'Missing required fields.' });
    }

    // TODO Sprint 7: Check against real Session model in DB
    // const session = await Session.findById(sessionId);
    // if (!session) return res.status(404).json({ message: 'Session not found.' });
    // if (session.expiresAt < Date.now()) return res.status(400).json({ message: 'Session expired.' });

    // TODO Sprint 7: Check for duplicate check-in
    // const existing = await Attendance.findOne({ sessionId, studentId });
    // if (existing) return res.status(409).json({ message: 'Already checked in.' });

    // TODO Sprint 7: Save to DB
    // await Attendance.create({ sessionId, studentId, courseCode,
    //   studentLat, studentLng, distanceM, checkedInAt: new Date() });

    // For now return success (full DB integration in Sprint 7)
    return res.status(200).json({
      message:     'Attendance marked successfully.',
      sessionId,
      courseCode,
      studentId,
      distanceM,
      checkedInAt: new Date().toISOString(),
    });

  } catch (error) {
    console.error('CheckIn error:', error.message);
    return res.status(500).json({ message: 'Server error. Please try again.' });
  }
};

// ── GET /api/attendance/my ──
exports.getStudentAttendance = async (req, res) => {
  try {
    const studentId = req.user.id;

    // TODO Sprint 7: Return real records from DB
    // const records = await Attendance.find({ studentId }).populate('session');
    return res.status(200).json({ attendance: [] });

  } catch (error) {
    console.error('GetAttendance error:', error.message);
    return res.status(500).json({ message: 'Server error.' });
  }
};